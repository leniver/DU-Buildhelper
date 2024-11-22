-- This is where you initialize your program
local load = function()
    --- math.randomseed(DUSystem.getUtcTime()) -- Uncomment this line if random is needed

    --- local exampleObject = Example.new(DUSystem)
end

if localDirectory then
    wrapper = Wrapper.new(DUUnit, DUSystem, DULibrary)
    -- In debug mode, declared lua files can be reloaded with Ctrl+Shift+R
    wrapper:reload(load, {
        localDirectory .. "includes/tools",
        localDirectory .. "includes/Wrapper",
        -- Add lua file you want to be able to reload
        localDirectory .. "init"
    })
else
    load()
end