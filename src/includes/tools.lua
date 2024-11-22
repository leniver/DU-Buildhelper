local floor, random = math.floor, math.random

---@param t table
---@param fnKeep function
---@return table
function ArrayRemove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

--- Don't forget to call math.randomseed at initialization
---@param n number
---@return integer
function Rand(n)
    return floor(random() * n)
end