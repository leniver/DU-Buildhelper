--- This code will be copied into unit->start
DUUnit = unit

require("parameters")

---@if env "development"
  debug = false                         --export: Enable debug mode, will load the code from local directory and be more verbose (Default: false)
  localDirectory = "du-buildhelper"     --export: Local directory containing the code for debuging purpose
  localDirectory = "autoconf/custom/" .. localDirectory .. "/"

  require(localDirectory .. "includes/tools")
  require(localDirectory .. "includes/Wrapper")
  require(localDirectory .. "includes/Class")

  require(localDirectory .. "classes/Helper")

  require(localDirectory .. "init")
---@else
  require("includes/tools")
  require("includes/Wrapper")
  require("includes/Class")

  require("classes/Helper")

  require("init")
---@end
