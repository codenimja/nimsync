## nimsync — Adaptive Backpressure Flow Control
##
## This module implements dynamic backpressure mechanisms for streaming systems,
## with adaptive rate limiting that learns from system conditions.
##
## Key Features:
## - Credit-based flow control (TCP-inspired)
## - Adaptive rate limiting with latency feedback
## - Exponential Moving Average (EMA) for smooth adaptation
## - Congestion detection and response
## - Zero-overhead when disabled

import std/[atomics, times, math]
import ./errors

type
  ## Backpressure policy mode
  BackpressureMode* = enum
    Disabled   ## No flow control
    Block      ## Block on full (original)
    Drop       ## Drop when full
    Overflow   ## Use overflow buffer
    Credits    ## Credit-based flow control
    Adaptive   ## Adaptive with latency feedback
    Predictive ## ML-based demand forecasting

  ## Credit-based flow control state
  CreditState* = ref object
    ## Available credits for sender
    senderCredits*: Atomic[int]
    ## Available credits for receiver
    receiverCredits*: Atomic[int]
    ## Total credits in system
    totalCredits*: int
    ## Last credit refresh time
    lastRefreshTime*: int64
    ## Credit refresh interval (ns)
    refreshInterval*: int64

  ## Adaptive rate limiting state
  AdaptiveRateLimiter* = ref object
    ## Current sending rate (msgs/sec)
    currentRate*: Atomic[float]
    ## Target rate (msgs/sec)
    targetRate*: float
    ## Exponential Moving Average (EMA) of latency
    latencyEma*: Atomic[float]
    ## EMA smoothing factor (0.1 = 10% new, 90% old)
    emaAlpha*: float
    ## Congestion window (adaptive)
    congestionWindow*: Atomic[int]
    ## RTT samples (for latency estimation)
    rttMin*: Atomic[float]
    ## Maximum observed RTT
    rttMax*: Atomic[float]
    ## Multiplicative decrease factor
    decreaseFactor*: float
    ## Additive increase per cycle
    increasePerCycle*: int
    ## Last adjustment time
    lastAdjustmentTime*: int64

  ## Congestion detector
  CongestionDetector* = ref object
    ## Queue depth threshold for congestion
    queueDepthThreshold*: int
    ## Latency threshold (ns) for congestion
    latencyThreshold*: int64
    ## Current queue depth
    currentQueueDepth*: Atomic[int]
    ## Is congested?
    isCongested*: Atomic[bool]
    ## Congestion start time
    congestionStartTime*: int64

## Create credit-based flow control state
proc newCreditState*(totalCredits: int = 1000,
    refreshIntervalMs: int = 100): CreditState =
  CreditState(
    senderCredits: totalCredits,
    receiverCredits: totalCredits,
    totalCredits: totalCredits,
    lastRefreshTime: (getTime().toUnix * 1_000_000_000 + getTime(
    ).nanosecond).int64,
    refreshInterval: refreshIntervalMs.int64 * 1_000_000
  )

## Consume credits (returns true if allowed)
proc consumeCredit*(credits: CreditState): bool =
  let available = atomicLoad(addr credits.senderCredits)
  if available > 0:
    discard atomicDec(addr credits.senderCredits)
    return true
  false

## Return credits to the system (receiver signals it processed)
proc releaseCredit*(credits: CreditState) =
  let total = atomicLoad(addr credits.receiverCredits)
  if total < credits.totalCredits:
    discard atomicInc(addr credits.receiverCredits)

## Refresh credits periodically
proc refreshCredits*(credits: CreditState) =
  let now = getTime().toUnixNanos()
  if now - credits.lastRefreshTime >= credits.refreshInterval:
    # Reset to initial state
    atomicStore(addr credits.senderCredits, credits.totalCredits)
    atomicStore(addr credits.receiverCredits, credits.totalCredits)
    credits.lastRefreshTime = now

## Create adaptive rate limiter
proc newAdaptiveRateLimiter*(targetRate: float = 10000.0,
                             emaAlpha: float = 0.1,
                             initialWindow: int = 100): AdaptiveRateLimiter =
  AdaptiveRateLimiter(
    currentRate: targetRate,
    targetRate: targetRate,
    latencyEma: 0.0,
    emaAlpha: emaAlpha,
    congestionWindow: initialWindow,
    rttMin: float.high,
    rttMax: 0.0,
    decreaseFactor: 0.8, # MIAD: multiplicative decrease
    increasePerCycle: 1, # MIAD: additive increase
    lastAdjustmentTime: getTime().toUnixNanos()
  )

## Update latency measurement and adapt rate
proc recordLatency*(limiter: AdaptiveRateLimiter, latencyNs: int64) =
  let latency = float(latencyNs)

  # Update RTT bounds
  let currentMin = atomicLoad(addr limiter.rttMin)
  if latency < currentMin:
    atomicStore(addr limiter.rttMin, latency)

  let currentMax = atomicLoad(addr limiter.rttMax)
  if latency > currentMax:
    atomicStore(addr limiter.rttMax, latency)

  # Update EMA
  let oldEma = atomicLoad(addr limiter.latencyEma)
  let newEma = oldEma * (1.0 - limiter.emaAlpha) + latency * limiter.emaAlpha
  atomicStore(addr limiter.latencyEma, newEma)

  # Adapt congestion window (MIAD)
  let targetLatency = 100.0 * 1_000_000 # 100ms target
  let currentWindow = atomicLoad(addr limiter.congestionWindow)

  if newEma > targetLatency:
    # Congestion detected: multiply by decrease factor
    let newWindow = max(1, int(float(currentWindow) * limiter.decreaseFactor))
    atomicStore(addr limiter.congestionWindow, newWindow)
  else:
    # No congestion: add increase
    let newWindow = currentWindow + limiter.increasePerCycle
    atomicStore(addr limiter.congestionWindow, newWindow)

## Check if rate limit allows send
proc allowSend*(limiter: AdaptiveRateLimiter): bool =
  let window = atomicLoad(addr limiter.congestionWindow)
  window > 0

## Get current congestion window
proc getCongestionWindow*(limiter: AdaptiveRateLimiter): int =
  atomicLoad(addr limiter.congestionWindow)

## Create congestion detector
proc newCongestionDetector*(queueThreshold: int = 1000,
                            latencyThresholdMs: int = 100): CongestionDetector =
  CongestionDetector(
    queueDepthThreshold: queueThreshold,
    latencyThreshold: latencyThresholdMs.int64 * 1_000_000,
    currentQueueDepth: 0,
    isCongested: false,
    congestionStartTime: 0
  )

## Update queue depth and detect congestion
proc updateQueueDepth*(detector: CongestionDetector, depth: int,
    latencyNs: int64) =
  atomicStore(addr detector.currentQueueDepth, depth)

  let exceeds = depth > detector.queueDepthThreshold or latencyNs >
      detector.latencyThreshold
  let wasCongested = atomicLoad(addr detector.isCongested)

  if exceeds and not wasCongested:
    # Transition to congested
    atomicStore(addr detector.isCongested, true)
    detector.congestionStartTime = getTime().toUnixNanos()
  elif not exceeds and wasCongested:
    # Transition to uncongested
    atomicStore(addr detector.isCongested, false)

## Check if currently congested
proc isCongested*(detector: CongestionDetector): bool =
  atomicLoad(addr detector.isCongested)

## Get congestion duration (ns)
proc getCongestionDuration*(detector: CongestionDetector): int64 =
  if atomicLoad(addr detector.isCongested):
    getTime().toUnixNanos() - detector.congestionStartTime
  else:
    0

## Adaptive backpressure controller combining multiple strategies
type
  AdaptiveBackpressure* = ref object
    mode*: BackpressureMode
    credits*: CreditState
    limiter*: AdaptiveRateLimiter
    detector*: CongestionDetector
    lastModeSwitch*: int64

## Create adaptive backpressure controller
proc newAdaptiveBackpressure*(initialMode: BackpressureMode = Adaptive): AdaptiveBackpressure =
  AdaptiveBackpressure(
    mode: initialMode,
    credits: newCreditState(),
    limiter: newAdaptiveRateLimiter(),
    detector: newCongestionDetector(),
    lastModeSwitch: getTime().toUnixNanos()
  )

## Check if send is allowed
proc canSend*(backpressure: AdaptiveBackpressure, queueDepth: int = 0): bool =
  case backpressure.mode:
  of Disabled:
    true
  of Block, Drop, Overflow:
    true # Let channel handle it
  of Credits:
    consumeCredit(backpressure.credits)
  of Adaptive:
    # Check both credits and rate limiter
    if not consumeCredit(backpressure.credits):
      return false
    allowSend(backpressure.limiter)
  of Predictive:
    # Predictive would use ML model
    true

## Signal that data was processed (release backpressure)
proc onProcessed*(backpressure: AdaptiveBackpressure, latencyNs: int64) =
  releaseCredit(backpressure.credits)
  recordLatency(backpressure.limiter, latencyNs)

## Update congestion state
proc updateCongestion*(backpressure: AdaptiveBackpressure, queueDepth: int,
    latencyNs: int64) =
  updateQueueDepth(backpressure.detector, queueDepth, latencyNs)

  # Adaptive mode switching
  let now = getTime().toUnixNanos()
  if now - backpressure.lastModeSwitch > 1_000_000_000: # 1 second
    if isCongested(backpressure.detector):
      # Switch to more aggressive backpressure
      if backpressure.mode != Credits:
        backpressure.mode = Credits
        backpressure.lastModeSwitch = now
    else:
      # Can relax backpressure
      if backpressure.mode == Credits:
        backpressure.mode = Adaptive
        backpressure.lastModeSwitch = now

## Format backpressure state as string
proc formatState*(backpressure: AdaptiveBackpressure): string =
  let latencyMs = atomicLoad(addr backpressure.limiter.latencyEma) / 1_000_000.0
  let window = getCongestionWindow(backpressure.limiter)
  let congested = isCongested(backpressure.detector)

  "AdaptiveBackpressure(\n" &
  "  Mode: " & $backpressure.mode & "\n" &
  "  Latency EMA: " & formatFloat(latencyMs, ffDecimal, 2) & "ms\n" &
  "  Congestion Window: " & $window & "\n" &
  "  Congested: " & $congested & "\n" &
  ")"
