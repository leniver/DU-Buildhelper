-- Add your lua parameters exposed to user 
--[[ 
customVariable = "value"    --export: Description of the variable (Default: value)
]]

debug = false --export: Enable debug mode, will load the code from local directory and be more verbose (Default: false)
localDirectory = "du-skeleton" --export: Local directory containing the code for debuging purpose (Default: du-skeleton)

localDirectory = "autoconf/custom/" .. localDirectory .. "/"