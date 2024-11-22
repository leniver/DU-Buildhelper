---@class Class
---@field new function(...:any[...])
---@field init function(...:any[...])
---@field class function():table
---@field super function():table
---@field instanceOf function(klass:table):boolean
Class = {}

---@param base table
---@return table
local function extend(_, base)
    local new_class = {}
    local class_mt = { __index = new_class }

    if base then
        setmetatable(new_class, { __index = base })
    end

    ---@param ... any[...]
    ---@return table
    function new_class:new(...)
        local inst = {}
        setmetatable(inst, class_mt)
        inst:init(...)
        return inst
    end

    ---@param ... any[...]
    function new_class:init(...)
        DUSystem.print("init must be implemented")
    end

    ---@return table
    function new_class:class()
        return new_class
    end

    ---@return table
    function new_class:super()
        return base
    end

    ---@param klass table
    ---@return boolean
    function new_class:instanceOf(klass)
        local is_a = false
        local cur = new_class
        while (cur and not is_a) do
            if (cur == klass) then
                is_a = true
            else
                cur = cur:super()
            end
        end

        return is_a
    end

    return new_class
end

setmetatable(Class, { __call = extend })