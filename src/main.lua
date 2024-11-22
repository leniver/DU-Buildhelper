--- This code will be copied into unit->start
DUUnit = unit

require("parameters")
if debug then
  require(localDirectory .. "requires_dev")
  require(localDirectory .. "init")
else
  require("requires_prod")
  require("init")
end