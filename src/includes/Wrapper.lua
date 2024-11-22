---@class Wrapper
---@field unit ControlUnit
---@field system System
---@field library Library
---@field stopped boolean
---@field stopOnError boolean
---@field rethrowErrorAlways boolean
---@field rethrowErrorIfStopped boolean
---@field printSameErrorOnlyOnce boolean
---@field printError boolean
---@field error function
---@field traceback function
Wrapper = {}
Wrapper.__index = Wrapper

setmetatable(Wrapper, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

---@type {[string] : boolean}
local logs = {}

---@param unit ControlUnit
---@param system System
---@param library Library
---@return Wrapper
function Wrapper.new(unit, system, library)
    local self = setmetatable({}, Wrapper)

    self.unit = unit
    self.system = system
    self.library = library
    self.stopped = false
    self.stopOnError = false
    self.rethrowErrorAlways = false
    self.rethrowErrorIfStopped = true
    self.printSameErrorOnlyOnce = true
    self.printError = true
    self.error = function(a)
        if self.stopped then
            return
        end
        a = tostring(a):gsub('"%-%- |STDERROR%-EVENTHANDLER[^"]*"', 'chunk')
        local b = self.unit or self or {}
        if self.printError and self.system and self.system.print then
            if not self.printSameErrorOnlyOnce or logs[a] == nil then
                logs[a] = true
                self.system.print(a)
            end
        end
        if self.stopOnError then
            self.stopped = true
        end
        if self.stopped and b and b.exit then
            b.exit()
        end
        if self.rethrowErrorAlways or (self.stopped and self.rethrowErrorIfStopped) then
            error(a)
        end
    end
    self.traceback = traceback or (debug and debug.traceback) or function(a, b) return b or a end

    return self
end

---@param callback any
function Wrapper:execute(callback)
    if not self.stopped then
        local a, b = xpcall(callback, self.traceback, self.unit)
        if not a then
            self.error(b)
        end
    end
end

---@param callback function
---@param localRequires? string[]
function Wrapper:reload(callback, localRequires)
    self.library.clearAllEventHandlers()

    if debug then
        local shiftDown = false
        local ctrlDown = false
        ---@diagnostic disable-next-line: undefined-field
        self.system:onEvent('onActionStart', function(_, action)
            if action == "brake" then
                ctrlDown = true
            elseif ctrlDown then
                if action == "lshift" then
                    shiftDown = true
                elseif shiftDown and action == "speedup" then
                    if localRequires then
                        for i = 1, #localRequires do
                            local lib = localRequires[i]
                            if package.loaded[lib] then
                                DUSystem.print("Reload: " .. lib)
                                package.loaded[lib] = nil
                                require(lib)
                            end
                        end
                    end
                    self:reload(callback, localRequires)
                end
            end
        end)
        ---@diagnostic disable-next-line: undefined-field
        self.system:onEvent('onActionStop', function(_, action)
            if action == "brake" then
                ctrlDown = false
            elseif action == "lshift" then
                shiftDown = true
            end
        end)
    end

    self:execute(callback)
end
