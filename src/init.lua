-- This is where you initialize your program
local load = function()
    local databank = DULibrary.getLinkByClass("DataBankUnit")

    DUUnit.hideWidget()

    Helper:new(DUUnit, DUSystem, DUConstruct, databank)
    --- local exampleObject = Example.new(DUSystem)
end

wrapper = Wrapper.new(DUUnit, DUSystem, DULibrary)
---@if env "development"
    -- In debug mode, declared lua files can be reloaded with Ctrl+Shift+R
    wrapper:reload(load, {
        localDirectory .. "includes/tools",
        localDirectory .. "includes/Wrapper",

        localDirectory .. "classes/Helper",
        localDirectory .. "init"
    })
---@else
    load()
---@end