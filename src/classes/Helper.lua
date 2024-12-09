---@class Helper : Class
---@field new function(unit:ControlUnit, system:System, core:CoreUnit, construct:Construct):Helper
---@field private __unit ControlUnit
---@field private __system System
---@field private __construct Construct
---@field private __databank Databank
---@field private __points table
---@field private __subPoints table
---@field private __pointsCount number
---@field private __hidden boolean
---@field private __hoveringElement [string, number, number?]
---@field private __clickedElement [string, number, number?]
---@field private __config HelperConfig
---@field private __data HelperData
Helper = Class()

--- Requirement should be declared here to make easy the reading of debug log.
--- local constants = require("cpml/constants")
--- local asin, acos, abs, min = math.asin, math.acos, math.abs, math.min
local sqrt, tan, rad, acos, abs, floor, max, min = math.sqrt, math.tan, math.rad, math.acos, math.abs, math.floor, math.max, math.min
local strlen, format = string.len, string.format
local concat, sort = table.concat, table.sort
---
local voxel2meter = 0.25
local voxelStep = 1 / 84
local rad2deg = 180 / math.pi
local near = 0.1
local far = 100000000.0
local epsilon = 1e-6
local field = -far / (far - near)
local nq = near * field
local json = require('dkjson')

---@param unit ControlUnit
---@param system System
---@param construct Construct
---@param databank Databank
function Helper:init(unit, system, construct, databank)
    self.__unit = unit
    self.__system = system
    self.__system.showScreen(true)
    self.__construct = construct
    self.__databank = databank

    self.__points = {}
    self.__subPoints = {}
    self.__subPointLimit = 21
    self.__pointsCount = 0
    self.__hoveringElement = { "", 0 }
    self.__clickedElement = { "", 0 }
    self.__currentSelectedPosition = { 1, 1, 1 }

    self.__altDown = false
    self.__shiftDown = false
    self.__ctrlDown = false
    self.__hidden = false
    self.__restoringSave = nil

    self.__config = {
        lineColor = "lightblue",
        lineWidth = 5,
        dotColor = "blue",
        dotRadius = 10,
        subDotRadius = 8,
        hoverColor = "darkblue",
    }

    self.__data = {
        construct = {
            position = { 0, 0, 0 },
            up = { 0, 0, 0 },
            forward = { 0, 0, 0 },
            right = { 0, 0, 0 },
        },
        camera = {
            position = { 0, 0, 0 },
            up = { 0, 0, 0 },
            forward = { 0, 0, 0 },
            right = { 0, 0, 0 },
        },
        screen = {
            height = 0,
            width = 0,
        },
        tanFov = 0,
        aspectRatio = 0,
        template = ""
    }
    self:updateData(true)

    self:loadPoints()
    self:loadConfig()
    self:initEvents()
end

function Helper:initEvents()
    ---@diagnostic disable-next-line: undefined-field
    self.__system:onEvent("onActionStart", function(__, action)
        wrapper:execute(function() self:onActionStart(action) end)
    end)
    ---@diagnostic disable-next-line: undefined-field
    self.__system:onEvent("onActionStop", function(__, action)
        wrapper:execute(function() self:onActionStop(action) end)
    end)
    ---@diagnostic disable-next-line: undefined-field
    self.__system:onEvent("onInputText", function(__, text)
        wrapper:execute(function() self:onInputText(text) end)
    end)
    ---@diagnostic disable-next-line: undefined-field
    self.__unit:onEvent("onTimer", function(__, timerId)
        wrapper:execute(function() self:onTimer(timerId) end)
    end)

    self.__unit.setTimer("dataUpdateFull", 10)
    self.__unit.setTimer("dataUpdatePosition", 1 / 1000)
    self.__unit.setTimer("update", 1 / 10000)
end

function Helper:loadConfig()
    if self.__databank ~= nil and self.__databank.hasKey("dh-config") then
        local data = json.decode(self.__databank.getStringValue("dh-config"))
        if type(data) == "table" then
            for key, value in pairs(self.__config) do
                self.__config[key] = (data[key] ~= nil and data[key]) or value
            end
        end
    end
end

function Helper:loadPoints(name)
    if name == nil then
        name = "dh-points"
    end
    if self.__databank ~= nil and self.__databank.hasKey(name) then
        local data = json.decode(self.__databank.getStringValue(name))
        if type(data) == "table" then
            self.__points = data
            self.__pointsCount = #self.__points
            self:buildSubpoints()
            return true
        end
    end
    return false
end

function Helper:savePoints(name)
    if name == nil then
        name = "dh-points"
    end
    if self.__databank ~= nil then
        self.__databank.setStringValue(name, json.encode(self.__points))
    end
end

function Helper:removeSave(name)
    if name ~= nil and self.__databank ~= nil and self.__databank.hasKey(name) then
        self.__databank.clearValue(name)
    end
end

function Helper:restoreSave()
    if self.__restoringSave ~= nil then
        local restoringSave = self.__restoringSave
        self.__restoringSave = nil
        local name = "dh-save-" .. restoringSave
        if self.__databank ~= nil and self.__databank.hasKey(name) then
            self:loadPoints(name)
            self:savePoints()
            self.__system.print([["]] .. restoringSave .. [[" points restored.]])
        else
            self.__system.print("Give save is not existing")
        end
    end
end

function Helper:clearPoints()
    self.__points = {}
    self.__pointsCount = 0
    self.__hoveringElement = { "", 0 }
    self.__clickedElement = { "", 0 }
    self:savePoints()
end

function Helper:removePointAt(index)
    if index <= self.__pointsCount and index > 0 then
        local j = 1;
        for i = 1, self.__pointsCount do
            if i ~= index then
                if (i ~= j) then
                    self.__points[j] = self.__points[i]
                    self.__points[i] = nil
                end
                j = j + 1
            else
                self.__points[i] = nil;
            end
        end
        self.__pointsCount = self.__pointsCount - 1
        if self.__clickedElement[1] == "point" then
            if index == self.__clickedElement[2] then
                self.__clickedElement = { "", 0 }
            elseif index < self.__clickedElement[2] then
                self.__clickedElement[2] = self.__clickedElement[2] - 1
            end
        end
        self:buildSubpoints()
        self:savePoints()
    end
end

function Helper:removeLastPoint()
    self:removePointAt(self.__pointsCount)
end

function Helper:formatCoordinates(coordinates)
    local x, y, z = coordinates[1], coordinates[2], coordinates[3]
    local xx, yy, zz = coordinates[4] or 0, coordinates[5] or 0, coordinates[6] or 0
    return format("%s:%s, %s:%s, %s:%s", x, xx, z, zz, y, yy)
end

function Helper:tranposePoint(coordinates)
    local x, y, z = self:getXYZFromCoordinates(coordinates)
    return {
        x * self.__data.construct.right[1] + y * self.__data.construct.up[1] + z * self.__data.construct.forward[1],
        x * self.__data.construct.right[2] + y * self.__data.construct.up[2] + z * self.__data.construct.forward[2],
        x * self.__data.construct.right[3] + y * self.__data.construct.up[3] + z * self.__data.construct.forward[3],
    }
end

function Helper:addPoint(coordinates)
    if coordinates ~= nil then
        local rotatedPos = self:tranposePoint(coordinates)
        self.__pointsCount = self.__pointsCount + 1
        self.__points[self.__pointsCount] = { rotatedPos[1], rotatedPos[2], rotatedPos[3], coordinates }
        self:buildSubpointsAt(self.__pointsCount, false)
        self:savePoints()
        self.__system.print(format("Point added (%s)", self:formatCoordinates(coordinates)))
    else
        self.__system.print("Unable to parse the given coordinates.")
    end
end

function Helper:closeShape()
    -- TODO: Check that the last point is not equal to the first one (already closed)
    if self.__pointsCount > 2 then
        self.__pointsCount = self.__pointsCount + 1
        if self.__clickedElement[1] == "point" then
            self.__points[self.__pointsCount] = self.__points[self.__clickedElement[2]]
        elseif self.__clickedElement[1] == "subpoint" then
            self.__points[self.__pointsCount] = self.__subPoints[self.__clickedElement[2]][self.__clickedElement[3]]
        else
            self.__points[self.__pointsCount] = self.__points[1]
        end
        self:buildSubpointsAt(self.__pointsCount, false)
        self:savePoints()
    else
        self.__system.print("You need at least 3 point to close the shape.")
    end
end

function Helper:movePoint(coordinates)
    if self.__clickedElement[1] == "point" then
        if coordinates ~= nil then
            self.__points[self.__clickedElement[2]] = coordinates
            self:buildSubpointsAt(self.__clickedElement[2], true)
        else
            self.__system.print("Unable to parse the given coordinates.")
        end
    else
        self.__system.print("Select a corner point before trying to move it.")
    end
end

function Helper:propagatePoint(distance)
    if self.__pointsCount >= 2 then
        local a = self.__points[self.__pointsCount - 1][4]
        local b = self.__points[self.__pointsCount][4]

        local x1, y1, z1 = a[1] + a[4] * voxelStep, a[2] + a[5] * voxelStep, a[3] + a[6] * voxelStep
        local x2, y2, z2 = b[1] + b[4] * voxelStep, b[2] + b[5] * voxelStep, b[3] + b[6] * voxelStep

        local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
        local length = sqrt(dx * dx + dy * dy + dz * dz)
        if length > epsilon then
            local nx, ny, nz = dx / length, dy / length, dz / length
            for i = distance, 1, -1 do
                local x, y, z = x1 + nx * i, y1 + ny * i, z1 + nz * i
                local coordinates = self:getCoordinatesFromXYZ(x, y, z)
                if coordinates ~= nil then
                    self:addPoint(coordinates)
                    return
                end
            end
        end
        self.__system.print("Unable to propagate the distance, no voxel position has been found.")
    else
        self.__system.print("You need at least 2 points to propagate the line.")
    end
end

function Helper:modifyPoint(index, x, y, z)
    if index > 0 and index <= self.__pointsCount then
        local coordinates = self.__points[index][4]
        local xx, yy, zz = coordinates[4] + x, coordinates[5] + y, coordinates[6] + z
        local vx, vy, vz = xx % 84, yy % 84, zz % 84
        local ix, iy, iz = floor(xx / 84), floor(yy / 84), floor(zz / 84)
        coordinates = { coordinates[1] + ix, coordinates[2] + iy, coordinates[3] + iz, vx, vy, vz }
        local rotatedPos = self:tranposePoint(coordinates)
        self.__points[index] = { rotatedPos[1], rotatedPos[2], rotatedPos[3], coordinates }
        self:buildSubpointsAt(index, true)
        self:savePoints()
    end
end

function Helper:buildSubpointsAt(index, doNext)
    if index > 1 and index <= self.__pointsCount then
        local previous = index - 1
        local x1, y1, z1 =
            self.__points[previous][4][1] + self.__points[previous][4][4] * voxelStep,
            self.__points[previous][4][2] + self.__points[previous][4][5] * voxelStep,
            self.__points[previous][4][3] + self.__points[previous][4][6] * voxelStep

        local x2, y2, z2 =
            self.__points[index][4][1] + self.__points[index][4][4] * voxelStep,
            self.__points[index][4][2] + self.__points[index][4][5] * voxelStep,
            self.__points[index][4][3] + self.__points[index][4][6] * voxelStep
        local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
        local length = sqrt(dx * dx + dy * dy + dz * dz)
        local subPoints = {}
        if length > epsilon then
            local nx, ny, nz = dx / length, dy / length, dz / length
            local steps = floor(length / voxelStep)
            local lastFound = 0
            for j = self.__subPointLimit, steps do
                if lastFound < j then
                    local t = j * voxelStep
                    local x, y, z = x1 + nx * t, y1 + ny * t, z1 + nz * t
                    local coordinates = self:getCoordinatesFromXYZ(x, y, z)
                    if coordinates ~= nil then
                        local rotatedPos = self:tranposePoint(coordinates)
                        subPoints[#subPoints + 1] = { rotatedPos[1], rotatedPos[2], rotatedPos[3], coordinates }
                        lastFound = j + self.__subPointLimit
                    end
                end
            end
            self.__subPoints[index] = subPoints
        end
        if doNext and index < self.__pointsCount then
            self:buildSubpointsAt(index + 1, false)
        end
    end
end

function Helper:buildSubpoints()
    if self.__pointsCount > 1 then
        for i = 2, self.__pointsCount do
            self:buildSubpointsAt(i, false)
        end
    end
end

function Helper:getXYZFromCoordinates(coordinates)
    local ox, oy, oz = coordinates[1], coordinates[2], coordinates[3]
    local xx, yy, zz = coordinates[4] or 0, coordinates[5] or 0, coordinates[6] or 0
    local x, y, z = ox + voxelStep * xx, oy + voxelStep * yy, oz + voxelStep * zz
    return (x + 0.5) * voxel2meter, (y + 0.5) * voxel2meter, (z + 0.5) * voxel2meter
end

function Helper:getCoordinatesFromXYZ(x, y, z)
    local precision = voxelStep / 4
    local cx, cy, cz =
        floor(x / voxelStep + 0.5) * voxelStep,
        floor(y / voxelStep + 0.5) * voxelStep,
        floor(z / voxelStep + 0.5) * voxelStep

    if abs(x - cx) < precision and abs(y - cy) < precision and abs(z - cz) < precision then
        x, y, z = floor(cx), floor(cy), floor(cz)
        return { x, y, z, floor((cx - x) / voxelStep + 0.5), floor((cy - y) / voxelStep + 0.5), floor((cz - z) / voxelStep + 0.5) }
    end
    return nil
end

function Helper:explodeCoordinates(coordinates)
    local explode = function(c, cc)
        local t = { { c, cc } }
        local i = 1
        while cc + i * 84 < 127 do
            t[#t + 1] = { c - i, cc + i * 84 }
            i = i + 1
        end
        i = 1
        while cc - i * 84 > -127 do
            t[#t + 1] = { c + i, cc - i * 84 }
            i = i + 1
        end
        return t
    end

    return explode(coordinates[1], coordinates[4]), explode(coordinates[3], coordinates[6]), explode(coordinates[2], coordinates[5])
end

function Helper:onActionStart(action)
    if action == "speedup" then
        self.__currentSelectedPosition = { 1, 1, 1 }
        self.__clickedElement = self.__hoveringElement
    elseif action == "option1" then
        self.__currentSelectedPosition[1] = self.__currentSelectedPosition[1] + 1
    elseif action == "option2" then
        self.__currentSelectedPosition[2] = self.__currentSelectedPosition[2] + 1
    elseif action == "option3" then
        self.__currentSelectedPosition[3] = self.__currentSelectedPosition[3] + 1
    elseif action == "option8" then
        if self.__ctrlDown then
            self.__subPointLimit = 21
        elseif self.__shiftDown then
            self.__subPointLimit = min(self.__subPointLimit + 1, 84)
        else
            self.__subPointLimit = max(self.__subPointLimit - 1, 1)
        end
        self:buildSubpointsAt(2, true)
    elseif action == "option9" then
        self.__hidden = not self.__hidden
    elseif action == "lshift" then
        self.__shiftDown = true
    elseif action == "brake" then
        self.__ctrlDown = true
    elseif action == "lalt" then
        self.__altDown = true
    elseif self.__clickedElement[1] == "point" then
        local mul = (self.__shiftDown and 84) or (self.__ctrlDown and 4) or 1
        if action == "strafeleft" then
            self:modifyPoint(self.__clickedElement[2], -1 * mul, 0, 0)
        elseif action == "straferight" then
            self:modifyPoint(self.__clickedElement[2], 1 * mul, 0, 0)
        elseif action == "up" then
            if self.__altDown then
                self:modifyPoint(self.__clickedElement[2], 0, 0, 1 * mul)
            else
                self:modifyPoint(self.__clickedElement[2], 0, 1 * mul, 0)
            end
        elseif action == "down" then
            if self.__altDown then
                self:modifyPoint(self.__clickedElement[2], 0, 0, -1 * mul)
            else
                self:modifyPoint(self.__clickedElement[2], 0, -1 * mul, 0)
            end
        end
    end
end

function Helper:onActionStop(action)
    if action == "lshift" then
        self.__shiftDown = false
    elseif action == "brake" then
        self.__ctrlDown = false
    elseif action == "lalt" then
        self.__altDown = false
    end
end

--/add -59+9 132+34 -68-56
function Helper:onInputText(text)
    if text:sub(1, 4) == "/add" then
        local coordinates = self:parseCoordinates(text:sub(6))
        self:addPoint(coordinates)
    elseif text == "/points" then
        self:printPoints()
    elseif text == "/rem" then
        self:removeLastPoint()
        self.__system.print("Last point removed")
    elseif text:sub(1, 5) == "/move" then
        local coordinates = self:parseCoordinates(text:sub(7))
        self:movePoint(coordinates)
    elseif text == "/close" then
        self:closeShape()
    elseif text:sub(1, 10) == "/propagate" then
        local distance = tonumber(text:sub(12))
        if distance ~= nil and distance > 0 then
            self:propagatePoint(distance)
        else
            self.__system.print("You have to give a positive distance in voxel")
        end
    elseif text:sub(1, 5) == "/save" then
        local name = text:sub(7)
        if name ~= nil and name ~= "" then
            self:savePoints("dh-save-" .. name)
            self.__system.print([[Points saved under "]] .. name .. [["]])
        else
            self.__system.print("You need to assign a name to your saved item.")
        end
    elseif text:sub(1, 8) == "/restore" then
        local name = text:sub(10)
        if name ~= nil and name ~= "" then
            self.__restoringSave = name
        else
            self.__system.print("You give the name of the save you want to retore.")
        end
    elseif text:sub(1, 7) == "/remove" then
        local name = text:sub(9)
        if name ~= nil and name ~= "" then
            self:removeSave("dh-save-" .. name)
            self.__system.print([[Save "]] .. name .. [[" removed]])
        end
    elseif text == "/displaysave" then
        self:printSaves()
    elseif text == "/clear" then
        self:clearPoints()
        self.__system.print("All points have been cleared")
    elseif text:sub(1, 7) == "/config" then
        local params = text:sub(9)
        if params == nil or strlen(params) == 0 then
            self:printConfig()
        else
            local key, value = text:match("^%s*([^%s]+)%s+([^%s]+)")
            if key ~= nil and value ~= nil then
                self:setConfig(key, value)
            end
        end
    elseif text == "/help" then
        self:printHelp()
    else
        self.__system.print("Command not found or wrong format (see /help)")
    end
end

function Helper:parseCoordinates(text)
    local x, z, y = text:match("^%s*(%-?%d+%.?%d*[%+%-]?%d*)%s+(%-?%d+%.?%d*[%+%-]?%d*)%s+(%-?%d+%.?%d*[%+%-]?%d*)%s*$")
    if x ~= nil and y ~= nil and z ~= nil then
        local xx, yy, zz = 0, 0, 0
        x, xx = (x .. "+0"):match("^(%-?%d+%.?%d*)%+?(%-?%d+)")
        y, yy = (y .. "+0"):match("^(%-?%d+%.?%d*)%+?(%-?%d+)")
        z, zz = (z .. "+0"):match("^(%-?%d+%.?%d*)%+?(%-?%d+)")
        return { x, y, z, xx, yy, zz };
    end
    return nil
end

function Helper:setConfig(key, value)
    if self.__config[key] ~= nil then
        self.__config[key] = value
        if self.__databank ~= nil then
            self.__databank.setStringValue("dh-config", json.encode(self.__config))
        end
    end
end

---@param type string
---@param index number
---@param subindex number?
---@return boolean
function Helper:isElementClicked(type, index, subindex)
    return self.__clickedElement[1] == type and self.__clickedElement[2] == index and self.__clickedElement[3] == subindex
end

function Helper:printPoints()
    self.__system.print("")
    self.__system.print("--- List of points ---")
    for i = 1, self.__pointsCount do
        self.__system.print(self:formatCoordinates(self.__points[i][4]))
    end
    self.__system.print("")
end

function Helper:printConfig()
    local keys = {}
    for key in pairs(self.__config) do
        keys[#keys + 1] = key
    end
    sort(keys)
    self.__system.print("")
    self.__system.print("--- Configuration ---")
    for __, key in ipairs(keys) do
        self.__system.print(format("%s %s", key, self.__config[key]))
    end
    self.__system.print("")
end

function Helper:printSaves()
    if self.__databank ~= nil then
        local keys = self.__databank.getKeyList()
        sort(keys)
        self.__system.print("--- Saves ---")
        for i, key in ipairs(keys) do
            if key:sub(1, 8) == "dh-save-" then
                self.__system.print(key:sub(9))
            end
        end
        self.__system.print("")
    else
        self.__system.print("No databank found.")
    end
end

function Helper:printHelp()
    local pointCommands = {
        ["/add <number>(+-)<number> <number>(+-)<number> <number>(+-)<number>"] = "Add a point with voxel precision tools coordinates",
        ["/rem"] = "Remove last inserted point",
        ["/move <number>(+-)<number> <number>(+-)<number> <number>(+-)<number>"] = "Move selected point to the new position",
        ["/close"] = "Close the shape (require at least 3 points)",
        ["/propagate distance"] = "Propagate the last vector for a distance",
        ["/clear"] = "Clear all points",
        ["/points"] = "Print all points",
    }
    local saveCommands = {
        ["/save name"] = "Save current point configuration in database with given name",
        ["/restore name"] = "Restore point configuration from database with given name",
        ["/remove name"] = "Remove point configuration from database with given name",
        ["/displaysave"] = "Display all saved point configurations",
    }
    local globalCommands = {
        ["/config"] = "Print configuration",
        ["/config <key> <value>"] = "Set a specific configuration",
        ["/help"] = "Print help",
    }
    local print = function(commands)
        local keys = {}
        for key in pairs(commands) do
            keys[#keys + 1] = key
        end
        sort(keys)
        for __, key in ipairs(keys) do
            self.__system.print(format("%s - %s", key, commands[key]))
        end
    end
    self.__system.print("")
    self.__system.print("--- Build Helper Commands ---")
    print(pointCommands)
    self.__system.print("------")
    print(saveCommands)
    self.__system.print("------")
    print(globalCommands)
    self.__system.print("")
end

function Helper:onTimer(timerId)
    if timerId == "dataUpdateFull" then
        self:updateData(true)
    elseif timerId == "dataUpdatePosition" then
        self:updateData(false)
    elseif timerId == "update" then
        self:update()
    end
end

---@param fullUpdate boolean
function Helper:updateData(fullUpdate)
    self.__data.construct = {
        position = self.__construct.getWorldPosition(),
        forward = self.__construct.getWorldOrientationForward(),
        right = self.__construct.getWorldOrientationRight(),
        up = self.__construct.getWorldOrientationUp(),
    }
    self.__data.camera = {
        position = self.__system.getCameraWorldPos(),
        forward = self.__system.getCameraWorldForward(),
        right = self.__system.getCameraWorldRight(),
        up = self.__system.getCameraWorldUp(),
    }
    if fullUpdate then
        local vFov = self.__system.getCameraVerticalFov()
        self.__data.screen.width = self.__system.getScreenWidth()
        self.__data.screen.height = self.__system.getScreenHeight()
        self.__data.tanFov = 1.0 / tan(rad(vFov) * 0.5)
        self.__data.aspectRatio = self.__data.screen.height / self.__data.screen.width * self.__data.tanFov
        self.__data.template = [[
            <style>
                svg {
                    left:0px;
                    position:absolute;
                    top:0px;
                }
                .info {
                    background: #ffffff;
                    border-radius: 10px;
                    display: flex;
                    left: 40px;
                    padding: 20px;
                    position: absolute;
                    top: 40px;
                }
            </style>
            <div class="info">%s</div>
            <div>
                <svg viewBox="0 0 ]] .. self.__data.screen.width .. [[ ]] .. self.__data.screen.height .. [[">%s</svg>
            </div>
        ]]
    end
end

function Helper:update()
    if self.__hidden then
        self:restoreSave()
        self.__system.setScreen("")
        return
    end
    local camWPx, camWPy, camWPz = self.__data.camera.position[1], self.__data.camera.position[2], self.__data.camera.position[3]
    local camWFx, camWFy, camWFz = self.__data.camera.forward[1], self.__data.camera.forward[2], self.__data.camera.forward[3]
    local camWRx, camWRy, camWRz = self.__data.camera.right[1], self.__data.camera.right[2], self.__data.camera.right[3]
    local camWUx, camWUy, camWUz = self.__data.camera.up[1], self.__data.camera.up[2], self.__data.camera.up[3]

    local cPosX, cPosY, cPosZ = self.__data.construct.position[1], self.__data.construct.position[2], self.__data.construct.position[3]

    local posX, posY, posZ = 0, 0, 0
    local vx, vy, vz = 0, 0, 0
    local sx, sy, sz = 0, 0, 0
    local sPX, sPY = 0, 0
    local dist = 0
    local html = {}
    local svgT = {}
    local ind = 0

    local function projection2D()
        vx = posX * camWRx + posY * camWRy + posZ * camWRz
        vy = posX * camWFx + posY * camWFy + posZ * camWFz
        vz = posX * camWUx + posY * camWUy + posZ * camWUz
        sx = (self.__data.aspectRatio * vx) / vy
        sy = (-self.__data.tanFov * vz) / vy
        sz = (-field * vy + nq) / vy
        sPX, sPY = (sx + 1) * self.__data.screen.width * 0.5, (sy + 1) * self.__data.screen.height * 0.5 -- screen pos X Y
        dist = sqrt(posX * posX + posY * posY + posZ * posZ) or 0                                        -- distance from camera to pos
    end

    local drawCircle = function(src, radius, clicked)
        local x, y, z = src[1] + cPosX, src[2] + cPosY, src[3] + cPosZ
        local isTargeted = false
        local color = self.__config.dotColor
        posX = x - camWPx
        posY = y - camWPy
        posZ = z - camWPz
        projection2D()
        if sz < 1 then
            local angle = acos((posX * camWFx + posY * camWFy + posZ * camWFz) / (sqrt(posX * posX + posY * posY + posZ * posZ) * sqrt(camWFx * camWFx + camWFy * camWFy + camWFz * camWFz)))
            isTargeted = abs(angle * rad2deg) < 1
            if isTargeted then
                color = self.__config.hoverColor
            end
            radius = radius / dist
            ind = ind + 1
            if clicked then
                local strokeWidth = 1 / dist
                svgT[ind] = format([[<circle fill="%s" stroke="white" stroke-width="%.1f" cx="%.1f" cy="%.1f" r="%.1f" />]], color, strokeWidth, sPX, sPY, radius)
            else
                svgT[ind] = format([[<circle fill="%s" cx="%.1f" cy="%.1f" r="%.1f" />]], color, sPX, sPY, radius)
            end
        end
        return isTargeted
    end

    local drawLine = function(points, count)
        local color = self.__config.lineColor
        for i = 1, count do
            local x1, y1, z1 = points[i][1], points[i][2], points[i][3]
            posX = x1 + cPosX - camWPx
            posY = y1 + cPosY - camWPy
            posZ = z1 + cPosZ - camWPz
            projection2D()
            if sz < 1 and i + 1 <= count then
                local strokeWidth = self.__config.lineWidth / dist
                ind = ind + 1
                svgT[ind] = format([[<polyline fill="none" stroke="%s" stroke-width="%.1f" stroke-opacity="0.5" points="%.1f,%.1f ]], color, strokeWidth, sPX, sPY)

                for j = i + 1, count do
                    local x2, y2, z2 = points[j][1], points[j][2], points[j][3]
                    posX = x2 + cPosX - camWPx
                    posY = y2 + cPosY - camWPy
                    posZ = z2 + cPosZ - camWPz
                    projection2D()
                    if sz < 1 then
                        ind = ind + 1
                        svgT[ind] = format([[%.1f,%.1f ]], sPX, sPY)
                    end
                end
                ind = ind + 1
                svgT[ind] = [["/>]]
                break
            end
        end
    end

    local hoveringIndex = { "", 0 }
    if self.__pointsCount > 1 then
        drawLine(self.__points, self.__pointsCount)
    end
    for i = 1, self.__pointsCount do
        if drawCircle(self.__points[i], self.__config.dotRadius, self:isElementClicked("point", i)) then
            hoveringIndex = { "point", i }
        end
        if self.__subPoints[i] ~= nil then
            for j = 1, #self.__subPoints[i] do
                if drawCircle(self.__subPoints[i][j], self.__config.subDotRadius, self:isElementClicked("subpoint", i, j)) then
                    hoveringIndex = { "subpoint", i, j }
                end
            end
        end
        self.__hoveringElement = hoveringIndex
    end

    if self.__clickedElement[1] ~= "" then
        local x, y, z = nil, nil, nil
        if self.__clickedElement[1] == "point" then
            x, y, z = self:explodeCoordinates(self.__points[self.__clickedElement[2]][4])
        elseif self.__clickedElement[1] == "subpoint" then
            x, y, z = self:explodeCoordinates(self.__subPoints[self.__clickedElement[2]][self.__clickedElement[3]][4])
        end
        if x ~= nil and y ~= nil and z ~= nil then
            local xc, yc, zc = #x, #y, #z
            local px, py, pz = x[self.__currentSelectedPosition[1] % xc + 1], y[self.__currentSelectedPosition[2] % yc + 1], z[self.__currentSelectedPosition[3] % zc + 1]
            html[#html + 1] = "<ul>"
            html[#html + 1] = format("<li>X: %s:%s</li>", px[1], px[2])
            html[#html + 1] = format("<li>Y: %s:%s</li>", py[1], py[2])
            html[#html + 1] = format("<li>Z: %s:%s</li>", pz[1], pz[2])
            html[#html + 1] = "</ul>"
        end
    end

    self:restoreSave()
    self.__system.setScreen(format(self.__data.template, concat(html), concat(svgT)))
end
