# VERSION.nim - Semantic Versioning for nimsync
import std/strformat

const
  NIMSYNC_MAJOR* = 1
  NIMSYNC_MINOR* = 1
  NIMSYNC_PATCH* = 0
  NIMSYNC_PRERELEASE* = ""
  NIMSYNC_BUILD* = ""

proc version*: string =
  if NIMSYNC_PRERELEASE != "":
    fmt"{NIMSYNC_MAJOR}.{NIMSYNC_MINOR}.{NIMSYNC_PATCH}-{NIMSYNC_PRERELEASE}"
  else:
    fmt"{NIMSYNC_MAJOR}.{NIMSYNC_MINOR}.{NIMSYNC_PATCH}"

when isMainModule:
  echo fmt"nimsync v{version()}"