
-- usage
-- First argument sets x and z
-- parse({ ... }, {{"x", "z"}, {"z"}}, {x=31, z=31}, "quarry")

-- if default variable is required, then its default value should be set to the string "REQUIRED"

-- ordered arguments further to the right override ordered arguments to the left.
-- named arguments override ordered arguments.

local function parse(input, argOrder, defaults, nameOfCommand)
    function getUsage()
        local i = 1
        local usage = "Usage: \n" .. shell.getRunningProgram()
        while argOrder[i] do
            usage = usage .. " <"
            for _, v in pairs(argOrder[i]) do
                usage = usage .. v .. "/"
            end
            usage = usage:sub(1, -2) .. ">"
            i = i + 1
        end
        return usage
    end

    local argN = 1
    local output = {}
    local named_args = {}

    -- default variables
    for k, v in pairs(defaults) do
        output[k] = v
    end
    local i = 1
    -- 
    while input[i] do
        -- named arguments 
        if string.sub(input[i], 1, 1) == "-" and tonumber(string.sub(input[i], 2, 2)) ~= nil then
            local arg_name = string.sub(input[i], 2)
            if named_args[arg_name] then
                error("Argument: \"" .. arg_name .. "\" provided twice.\n" .. getUsage())
            end
            if defaults[arg_name] == nil then
                error("Unknown argument: \"" .. arg_name .. "\" provided.\n" .. getUsage())
            end
            -- is next argument entry a new argument?
            if input[i+1] ~= nil and string.sub(input[i+1], 1, 1) ~= "-" then
                named_args[arg_name] = tonumber(input[i+1])
                i = i + 1 -- skip next
            else
                named_args[arg_name] = true
            end
        -- ordered arguments
        else
            if argOrder[argN] == nil then
                error("Too many arguments provided.\n" .. getUsage())
            end
            for _, param in ipairs(argOrder[argN]) do
                output[param] = tonumber(input[i])
            end
            argN = argN + 1
        end
        i = i + 1
    end
    -- named variables override others
    for k, v in pairs(named_args) do
        output[k] = v
    end
    -- check if required variables arent set using named or ordered arguments
    for k, v in pairs(output) do
        if (v == "REQUIRED") then
            error("Required argument " .. k .. " not set.\n".. getUsage())
        end
    end
    return output
end

return { parse = parse }