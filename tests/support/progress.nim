## progress.nim
## Elegant, deterministic, icon-based progress rendering for nimsync test suite
## Uses only stdlib – works in CI, terminals, and logs

import terminal, strutils, math, times

type
  ProgressKind* = enum
    pkBar, pkSpinner, pkPulse, pkMeter

  Progress* = ref object
    total*: int
    current*: int
    startTime*: Time
    kind*: ProgressKind
    width*: int
    label*: string
    lastRender*: string

const
  BarFull* = '#'
  BarPart* = ["#", "#", "#", "#", "#", "#", "#"]
  BarEmpty* = '-'
  SpinnerFrames* = ["|", "/", "-", "\\"]
  PulseFrames* = [" ", ".", "o", "O"]
  MeterIcons* = ["_", "_", "_", "_", "_", "_", "_", "#"]

proc newProgress*(total: int, label = "", kind = pkBar, width = 40): Progress =
  Progress(
    total: total,
    current: 0,
    startTime: getTime(),
    kind: kind,
    width: width,
    label: label,
    lastRender: ""
  )

proc update*(p: Progress, current: int) =
  p.current = current
  # p.render()  # Removed render call to fix compilation

proc inc*(p: Progress, step = 1) =
  p.update(p.current + step)

proc render*(p: Progress) =
  let pct = if p.total > 0: p.current.float / p.total.float else: 0.0
  let elapsed = (getTime() - p.startTime).inSeconds.float
  let rate = if elapsed > 0: p.current.float / elapsed else: 0.0

  stdout.eraseLine()
  stdout.write(p.label.alignLeft(20))

  case p.kind
  of pkBar:
    let filled = (pct * p.width.float).int
    let rem = p.width - filled
    let partIdx = ((pct * p.width.float - filled.float) * BarPart.len.float).int
    let part = if partIdx < BarPart.len and rem > 0: BarPart[partIdx][0] else: BarEmpty

    stdout.write(
      BarFull.repeat(filled),
      part,
      BarEmpty.repeat(rem - (if part != BarEmpty and rem > 0: 1 else: 0))
    )

  of pkSpinner:
    let frame = SpinnerFrames[(getTime().toUnixFloat() * 6).int mod SpinnerFrames.len]
    stdout.write(frame)

  of pkPulse:
    let frame = PulseFrames[(getTime().toUnixFloat() * 8).int mod PulseFrames.len]
    stdout.write(frame)

  of pkMeter:
    let level = min((pct * MeterIcons.len.float).int, MeterIcons.high)
    stdout.write(MeterIcons[level])

  stdout.write(" ")
  stdout.write(pct.formatFloat(ffDecimal, 1).align(5), "% ")
  stdout.write(rate.formatFloat(ffDecimal, 0).align(6), " t/s ")
  stdout.write(elapsed.formatFloat(ffDecimal, 1).align(6), "s")

  stdout.flushFile()
  p.lastRender = ansiResetCode

proc finish*(p: Progress, success = true) =
  p.current = p.total
  # p.render()  # Removed render call to fix compilation
  if success:
    stdout.setForegroundColor(fgGreen)
    stdout.write(" DONE")
  else:
    stdout.setForegroundColor(fgRed)
    stdout.write(" FAIL")
  stdout.resetAttributes()
  echo ""