## nimsync/errors — Comprehensive Error Handling System
##
## This module provides a robust error handling framework for nimsync with:
## - Hierarchical error types with rich context
## - Error recovery patterns and strategies
## - Performance-oriented error propagation
## - Integration with cancellation and supervision
## - Detailed error reporting and debugging
## - Zero-allocation error paths in hot paths
## - Error metrics and monitoring

# {.experimental: "views".}  # Temporarily disabled

import std/[strformat, monotimes, options, tables, strutils, math]
import std/times except Duration
import chronos

type
  ErrorSeverity* {.pure.} = enum
    ## Classification of error severity for handling decisions
    Info = 0       ## Informational, no action needed
    Warning = 1    ## Warning condition, operation can continue
    Error = 2      ## Error condition, operation should be retried
    Critical = 3   ## Critical error, component should restart
    Fatal = 4      ## Fatal error, system should shutdown

  ErrorCategory* {.pure.} = enum
    ## Categories of errors for classification and handling
    Network = "network"           ## Network-related errors
    Timeout = "timeout"           ## Timeout and deadline errors
    Resource = "resource"         ## Resource exhaustion errors
    Validation = "validation"     ## Input validation errors
    Concurrency = "concurrency"   ## Concurrency-related errors
    System = "system"             ## System-level errors
    User = "user"                 ## User-caused errors
    Internal = "internal"         ## Internal logic errors

  ErrorContext* = object
    ## Rich context for error reporting and debugging
    operation: string             ## What operation failed
    component: string             ## Which component failed
    timestamp: MonoTime          ## When the error occurred
    threadId: int                ## Which thread the error occurred on
    taskId: uint64               ## Associated task ID if any
    metadata: Table[string, string]  ## Additional context
    when defined(debug):
      stackTrace: string         ## Stack trace for debugging
      sourceLocation: string     ## Source file and line

  ErrorInfo* = object
    ## Comprehensive error information
    message: string
    code: int
    severity: ErrorSeverity
    category: ErrorCategory
    context: ErrorContext
    cause: Option[ref CatchableError]  ## Root cause error
    recoverable: bool             ## Whether error is recoverable
    retryable: bool              ## Whether operation should be retried
    when defined(statistics):
      occurrenceCount: int       ## How many times this error occurred

# Base error types for nimsync
type
  NimAsyncError* = object of CatchableError
    ## Base error type for all nimsync errors
    info*: ErrorInfo

  # Core component errors
  ChannelError* = object of NimAsyncError
  ChannelClosedError* = object of ChannelError
  ChannelFullError* = object of ChannelError
  ChannelTimeoutError* = object of ChannelError

  TaskGroupError* = object of NimAsyncError
  TaskSpawnError* = object of TaskGroupError
  TaskCancelledError* = object of TaskGroupError
  TaskResourceError* = object of TaskGroupError

  CancellationError* = object of NimAsyncError
  TimeoutError* = object of CancellationError
  DeadlineExceededError* = object of CancellationError

  StreamError* = object of NimAsyncError
  StreamClosedError* = object of StreamError
  BackpressureError* = object of StreamError
  StreamTimeoutError* = object of StreamError

  ActorError* = object of NimAsyncError
  ActorNotFoundError* = object of ActorError
  MailboxFullError* = object of ActorError
  SupervisionError* = object of ActorError
  ActorStartupError* = object of ActorError

  # System-level errors
  ResourceExhaustedError* = object of NimAsyncError
  ConfigurationError* = object of NimAsyncError
  SystemError* = object of NimAsyncError

# Error context builders
proc initErrorContext*(operation: string, component: string): ErrorContext =
  ## Create basic error context
  result = ErrorContext(
    operation: operation,
    component: component,
    timestamp: getMonoTime(),
    threadId: getThreadId(),
    taskId: 0,
    metadata: initTable[string, string]()
  )

  when defined(debug):
    result.stackTrace = getStackTrace()
    result.sourceLocation = ""

proc withMetadata*(context: var ErrorContext, key: string, value: string): ErrorContext =
  ## Add metadata to error context
  context.metadata[key] = value
  return context

proc withTaskId*(context: var ErrorContext, taskId: uint64): ErrorContext =
  ## Associate error with specific task
  context.taskId = taskId
  return context

when defined(debug):
  proc withSourceLocation*(context: var ErrorContext, file: string, line: int): ErrorContext =
    ## Add source location for debugging
    context.sourceLocation = fmt"{file}:{line}"
    return context

# Error creation helpers
proc newChannelError*(message: string, category: ErrorCategory = ErrorCategory.Concurrency,
                     severity: ErrorSeverity = ErrorSeverity.Error,
                     context: ErrorContext): ref ChannelError =
  ## Create a channel-specific error
  result = newException(ChannelError, message)
  result.info = ErrorInfo(
    message: message,
    code: 1001,
    severity: severity,
    category: category,
    context: context,
    cause: none(ref CatchableError),
    recoverable: true,
    retryable: category == ErrorCategory.Timeout
  )

proc newChannelClosedError*(channelId: string, context: ErrorContext): ref ChannelClosedError =
  ## Create channel closed error
  let message = fmt"Channel '{channelId}' is closed"
  result = newException(ChannelClosedError, message)
  result.info = ErrorInfo(
    message: message,
    code: 1002,
    severity: ErrorSeverity.Error,
    category: ErrorCategory.Concurrency,
    context: context,
    cause: none(ref CatchableError),
    recoverable: false,
    retryable: false
  )

proc newChannelFullError*(channelId: string, capacity: int, context: ErrorContext): ref ChannelFullError =
  ## Create channel full error
  let message = fmt"Channel '{channelId}' is full (capacity: {capacity})"
  result = newException(ChannelFullError, message)
  result.info = ErrorInfo(
    message: message,
    code: 1003,
    severity: ErrorSeverity.Warning,
    category: ErrorCategory.Resource,
    context: context,
    cause: none(ref CatchableError),
    recoverable: true,
    retryable: true
  )

proc newTaskGroupError*(message: string, severity: ErrorSeverity = ErrorSeverity.Error,
                       context: ErrorContext): ref TaskGroupError =
  ## Create task group error
  result = newException(TaskGroupError, message)
  result.info = ErrorInfo(
    message: message,
    code: 2001,
    severity: severity,
    category: ErrorCategory.Concurrency,
    context: context,
    cause: none(ref CatchableError),
    recoverable: severity <= ErrorSeverity.Error,
    retryable: severity <= ErrorSeverity.Warning
  )

proc newTimeoutError*(operation: string, timeout: chronos.Duration, context: ErrorContext): ref TimeoutError =
  ## Create timeout error
  let message = fmt"Operation '{operation}' timed out after {timeout}"
  result = newException(TimeoutError, message)
  result.info = ErrorInfo(
    message: message,
    code: 3001,
    severity: ErrorSeverity.Error,
    category: ErrorCategory.Timeout,
    context: context,
    cause: none(ref CatchableError),
    recoverable: true,
    retryable: true
  )

proc newStreamError*(message: string, severity: ErrorSeverity = ErrorSeverity.Error,
                    context: ErrorContext): ref StreamError =
  ## Create stream error
  result = newException(StreamError, message)
  result.info = ErrorInfo(
    message: message,
    code: 4001,
    severity: severity,
    category: ErrorCategory.Concurrency,
    context: context,
    cause: none(ref CatchableError),
    recoverable: severity <= ErrorSeverity.Error,
    retryable: severity <= ErrorSeverity.Warning
  )

proc newActorError*(message: string, severity: ErrorSeverity = ErrorSeverity.Error,
                   context: ErrorContext): ref ActorError =
  ## Create actor error
  result = newException(ActorError, message)
  result.info = ErrorInfo(
    message: message,
    code: 5001,
    severity: severity,
    category: ErrorCategory.Concurrency,
    context: context,
    cause: none(ref CatchableError),
    recoverable: severity <= ErrorSeverity.Error,
    retryable: severity <= ErrorSeverity.Warning
  )

proc newResourceExhaustedError*(resource: string, limit: int, context: ErrorContext): ref ResourceExhaustedError =
  ## Create resource exhausted error
  let message = fmt"Resource '{resource}' exhausted (limit: {limit})"
  result = newException(ResourceExhaustedError, message)
  result.info = ErrorInfo(
    message: message,
    code: 6001,
    severity: ErrorSeverity.Critical,
    category: ErrorCategory.Resource,
    context: context,
    cause: none(ref CatchableError),
    recoverable: false,
    retryable: false
  )

# Error wrapping and chaining
proc wrapError*[T: NimAsyncError](error: ref T, cause: ref CatchableError): ref T =
  ## Wrap an error with a root cause
  error.info.cause = some(cause)
  return error

proc chainError*[T: NimAsyncError](error: ref T, operation: string): ref T =
  ## Chain errors to show operation hierarchy
  let chainedMessage = fmt"{operation}: {error.info.message}"
  error.info.message = chainedMessage
  return error

# Error reporting and formatting
proc formatError*(error: ref NimAsyncError): string =
  ## Format error for human-readable output
  result = fmt"[{error.info.severity}] {error.info.category}: {error.info.message}"

  if error.info.context.operation != "":
    result.add(fmt" (operation: {error.info.context.operation})")

  if error.info.context.component != "":
    result.add(fmt" (component: {error.info.context.component})")

  if error.info.cause.isSome:
    result.add(fmt" (caused by: {error.info.cause.get().msg})")

  when defined(debug):
    if error.info.context.sourceLocation != "":
      result.add(fmt" (at: {error.info.context.sourceLocation})")

proc formatErrorDetailed*(error: ref NimAsyncError): string =
  ## Format error with full details for debugging
  result = formatError(error)

  result.add(fmt"\nError Code: {error.info.code}")
  result.add(fmt"\nSeverity: {error.info.severity}")
  result.add(fmt"\nCategory: {error.info.category}")
  result.add(fmt"\nRecoverable: {error.info.recoverable}")
  result.add(fmt"\nRetryable: {error.info.retryable}")
  result.add(fmt"\nTimestamp: {error.info.context.timestamp}")
  result.add(fmt"\nThread ID: {error.info.context.threadId}")

  if error.info.context.taskId != 0:
    result.add(fmt"\nTask ID: {error.info.context.taskId}")

  if error.info.context.metadata.len > 0:
    result.add("\nMetadata:")
    for key, value in error.info.context.metadata:
      result.add(fmt"\n  {key}: {value}")

  when defined(debug):
    if error.info.context.stackTrace != "":
      result.add(fmt"\nStack Trace:\n{error.info.context.stackTrace}")

# Error recovery patterns
type
  ErrorRecoveryStrategy* {.pure.} = enum
    ## Strategies for error recovery
    Ignore = "ignore"           ## Ignore the error and continue
    Retry = "retry"             ## Retry the operation
    Fallback = "fallback"       ## Use fallback mechanism
    Escalate = "escalate"       ## Escalate to higher level
    Abort = "abort"             ## Abort the operation

  ErrorRecoveryResult* {.pure.} = enum
    ## Result of error recovery attempt
    Recovered = "recovered"     ## Successfully recovered
    Retrying = "retrying"       ## Will retry operation
    Failed = "failed"           ## Recovery failed
    Escalated = "escalated"     ## Escalated to higher level

proc shouldRetry*(error: ref NimAsyncError, attempt: int, maxAttempts: int): bool =
  ## Determine if an operation should be retried
  if attempt >= maxAttempts:
    return false

  if not error.info.retryable:
    return false

  # More sophisticated retry logic based on error type
  case error.info.category:
  of ErrorCategory.Timeout:
    return attempt < 3  # Retry timeouts up to 3 times
  of ErrorCategory.Network:
    return attempt < 5  # Retry network errors up to 5 times
  of ErrorCategory.Resource:
    return attempt < 2  # Limited retries for resource errors
  else:
    return error.info.retryable and attempt < maxAttempts

proc getRetryDelay*(error: ref NimAsyncError, attempt: int): chronos.Duration =
  ## Calculate delay before retry attempt
  let baseDelayMs = case error.info.category:
    of ErrorCategory.Timeout: 100
    of ErrorCategory.Network: 500
    of ErrorCategory.Resource: 1000
    else: 250

  # Exponential backoff with jitter
  let backoffMultiplier = pow(2.0, (attempt - 1).float).int
  let delayMs = baseDelayMs * backoffMultiplier
  let jitterMs = delayMs div 10  # 10% jitter

  return chronos.milliseconds(delayMs + jitterMs)

# Error metrics and monitoring
when defined(statistics):
  import std/atomics

  type
    ErrorMetrics* = object
      totalErrors: Atomic[int64]
      errorsByCategory: array[ErrorCategory, Atomic[int64]]
      errorsBySeverity: array[ErrorSeverity, Atomic[int64]]
      retryAttempts: Atomic[int64]
      recoveryAttempts: Atomic[int64]

  var globalErrorMetrics* = ErrorMetrics()

  proc recordError*(error: ref NimAsyncError) =
    ## Record error metrics
    discard globalErrorMetrics.totalErrors.fetchAdd(1, moRelaxed)
    discard globalErrorMetrics.errorsByCategory[error.info.category].fetchAdd(1, moRelaxed)
    discard globalErrorMetrics.errorsBySeverity[error.info.severity].fetchAdd(1, moRelaxed)

  proc recordRetry*() =
    ## Record retry attempt
    discard globalErrorMetrics.retryAttempts.fetchAdd(1, moRelaxed)

  proc recordRecovery*() =
    ## Record recovery attempt
    discard globalErrorMetrics.recoveryAttempts.fetchAdd(1, moRelaxed)

  proc getErrorMetrics*(): tuple[
    totalErrors: int64,
    byCategory: array[ErrorCategory, int64],
    bySeverity: array[ErrorSeverity, int64],
    retryAttempts: int64,
    recoveryAttempts: int64
  ] =
    ## Get current error metrics
    var byCategory: array[ErrorCategory, int64]
    var bySeverity: array[ErrorSeverity, int64]

    for category in ErrorCategory:
      byCategory[category] = globalErrorMetrics.errorsByCategory[category].load(moAcquire)

    for severity in ErrorSeverity:
      bySeverity[severity] = globalErrorMetrics.errorsBySeverity[severity].load(moAcquire)

    return (
      totalErrors: globalErrorMetrics.totalErrors.load(moAcquire),
      byCategory: byCategory,
      bySeverity: bySeverity,
      retryAttempts: globalErrorMetrics.retryAttempts.load(moAcquire),
      recoveryAttempts: globalErrorMetrics.recoveryAttempts.load(moAcquire)
    )

# High-level error handling utilities
template withErrorHandling*(operation: string, component: string, body: untyped): untyped =
  ## Execute code with automatic error context and handling
  let context = initErrorContext(operation, component)

  try:
    body
  except NimAsyncError as e:
    when defined(statistics):
      recordError(e)
    raise e
  except CatchableError as e:
    # Wrap non-nimsync errors
    let wrappedError = newException(NimAsyncError, e.msg)
    wrappedError.info = ErrorInfo(
      message: e.msg,
      code: 9999,
      severity: ErrorSeverity.Error,
      category: ErrorCategory.Internal,
      context: context,
      cause: some(e),
      recoverable: false,
      retryable: false
    )
    when defined(statistics):
      recordError(wrappedError)
    raise wrappedError

template withRetry*(maxAttempts: int, operation: string, component: string, body: untyped): untyped =
  ## Execute operation with automatic retry logic
  var attempt = 1
  var lastError: ref NimAsyncError = nil

  while attempt <= maxAttempts:
    try:
      withErrorHandling(operation, component):
        body
      break  # Success, exit retry loop

    except NimAsyncError as e:
      lastError = e

      if shouldRetry(e, attempt, maxAttempts):
        when defined(statistics):
          recordRetry()

        let delay = getRetryDelay(e, attempt)
        await sleepAsync(delay)
        attempt += 1
      else:
        raise e

  if attempt > maxAttempts and not lastError.isNil:
    raise lastError

# Error propagation helpers for async code
proc propagateError*[T](future: Future[T], operation: string, component: string): Future[T] {.async.} =
  ## Propagate errors with additional context
  try:
    return await future
  except NimAsyncError as e:
    let context = initErrorContext(operation, component)
    raise chainError(e, fmt"{component}.{operation}")
  except CatchableError as e:
    let context = initErrorContext(operation, component)
    let wrappedError = newException(NimAsyncError, fmt"{operation} failed: {e.msg}")
    wrappedError.info.context = context
    raise wrappedError

# Error handling for critical sections
proc handleCriticalError*(error: ref NimAsyncError, component: string) =
  ## Handle critical errors that require immediate attention
  if error.info.severity >= ErrorSeverity.Critical:
    # Log critical error
    echo fmt"CRITICAL ERROR in {component}: {formatErrorDetailed(error)}"

    # In a real implementation, this might:
    # - Send alerts to monitoring systems
    # - Trigger automatic restarts
    # - Save crash dumps
    # - Notify operations teams

proc handleFatalError*(error: ref NimAsyncError) =
  ## Handle fatal errors that require system shutdown
  if error.info.severity == ErrorSeverity.Fatal:
    echo fmt"FATAL ERROR: {formatErrorDetailed(error)}"
    echo "System will shut down"

    # In a real implementation, this might:
    # - Gracefully shutdown all components
    # - Save state for recovery
    # - Generate detailed crash reports
    # - Exit the process

    quit(1)