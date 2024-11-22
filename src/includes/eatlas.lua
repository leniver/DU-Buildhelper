-- This is an extension of atlas with some functions

local floor, random, cos, sin, rad, atan, acos, pi, deg, ceil  = math.floor, math.random, math.cos, math.sin, math.rad, math.atan, math.acos, math.pi, math.deg, math.ceil
local eatlas = {
    bodies = require("atlas") ---@type Planet[][]
}

local num = ' *([+-]?%d+%.?%d*e?[+-]?%d*)'
local posPattern = '::pos{' .. num .. ',' .. num .. ',' .. num .. ',' .. num .. ',' .. num .. '}'

-- Convert the center of each bodies to a vec3
for i in pairs(eatlas.bodies) do
    for j, p in pairs(eatlas.bodies[i]) do
        p.center = vec3(p.center)
        eatlas.bodies[i][j] = p
    end
end


---@param n number
---@param decimal number
---@return number
local function FormatNumber(n, decimal)
    return floor(n * decimal) / decimal
end

function eatlas.WaypointToWorldCoordinates(waypoint)
    local position = nil
    if waypoint ~= nil then
        local sys, id, x, y, z = waypoint:match(posPattern)
        if x ~= nil then
            sys = tonumber(sys)
            id = tonumber(id)
            if id == 0 then
                position = vec3(x, y, z)
            elseif eatlas.bodies[sys][id] ~= nil then
                x = rad(tonumber(x) or 0) or 0
                y = rad(tonumber(y) or 0) or 0
                z = tonumber(z)
                local planet = eatlas.bodies[sys][id]
                local xproj = cos(x)
                position = planet.center + (planet.radius + z) * vec3(xproj * cos(y), xproj * sin(y), sin(x))
            end
        end
    end
    return position
end

---@param vector vec3
---@return {planet:Planet, vector:vec3}|nil
function eatlas.VectorToPosition(vector)
    local planet, distance = eatlas.GetClosestPlanet(vector)
    if distance == nil or distance == 0 then
        return nil
    end

    local altitude = distance - planet.radius
    local coords = vector - planet.center
    local phi = atan(coords.y, coords.x)
    local longitude = phi >= 0 and phi or (2 * pi + phi)
    local latitude = pi / 2 - acos(coords.z / distance)

    return {
        planet = planet,
        vector = vec3(FormatNumber(deg(latitude), 10000), FormatNumber(deg(longitude), 10000), FormatNumber(altitude, 10000))
    }
end

---@param vector vec3
---@param id number|nil
---@return string
function eatlas.VectorToWaypoint(vector, id)
    return ("::pos{0,%s,%s,%s,%s}"):format(id or 0, vector:unpack())
end

---@param vector vec3
---@return {planet:Planet, vector:vec3}|nil
function eatlas.VectorToMapPosition(vector)
    local planet, distance = eatlas.GetClosestPlanet(vector)
    if distance == nil then
        return nil
    end

    local altitude = distance - planet.radius
    local coords = vector - planet.center
    local phi = atan(coords.y, coords.x)
    local longitude = phi >= 0 and phi or (2 * pi + phi)
    local latitude = pi / 2 - acos(coords.z / distance)

    return {
        planet = planet,
        vector = vec3(FormatNumber(deg(latitude), 10000), FormatNumber(deg(longitude), 10000), FormatNumber(altitude, 10000))
    }
end


---@param vector vec3
---@param system number|nil
---@return Planet, number
function eatlas.GetClosestPlanet(vector, system)
    local distance = nil ---@type number
    local planet = nil ---@type Planet
    for __, p in pairs(eatlas.bodies[system or 0]) do
        local currentDistance = FormatNumber((vector - p.center):len(), 1000)
        if distance == nil or currentDistance < distance then
            distance = currentDistance
            planet = p
        end
    end

    return planet, distance
end

return eatlas