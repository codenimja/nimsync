## Simplified nimsync module for testing

import std/[times, strformat]

# Public API surface
proc version*(): string =
  ## Returns the nimsync library version.
  "0.0.1"

proc versionInfo*(): tuple[version: string, buildTime: string, features: seq[string]] =
  ## Get detailed version and build information
  var features: seq[string] = @[]

  # Compile-time feature detection
  when defined(release):
    features.add("release")
  when defined(danger):
    features.add("danger")
  when defined(debug):
    features.add("debug")
  when compileOption("mm", "orc"):
    features.add("orc")
  when compileOption("mm", "arc"):
    features.add("arc")

  return (
    version: version(),
    buildTime: CompileDate & " " & CompileTime,
    features: features
  )