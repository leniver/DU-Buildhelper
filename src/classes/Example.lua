---@class Example : Class
---@field customField number
Example = Class()

--- Requirement should be declared here to make easy the reading of debug log.
--- local constants = require("cpml/constants")
--- local asin, acos, abs, min = math.asin, math.acos, math.abs, math.min

---Object initialization will be call by Class when object is created: local object = Example.new(DUSystem)
---@param system System
function Example:init(system)
    self:super().init(self)

    self.customField = 0
end

---Example of a function
---@return boolean
function Example:test()
    -- Do something 
    return false
end