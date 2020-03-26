--[[
    PCT - Protected Call with Traceback - 2013 Sangar

    This program is licensed under the MIT license.
    http://opensource.org/licenses/mit-license.php

    This API provides a single function: tpcall(). It is functionally the same
    as pcall, except that it returns a full stack trace as the second result on
    failure, instead of just the exact error location.
]]

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Stacktrace API                                                            --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Keep a local copy of pcall, in case we get installed as pcall replacement.
local pcall, xpcall = pcall, xpcall

-------------------------------------------------------------------------------
-- Public API                                                                --
-------------------------------------------------------------------------------

-- The current version of the API.
version = "1.0b"

--[[
    Custom protected function caller that produces a traceback on errors.

    @param f the function to call in protected mode.
    @param ... any arguments to pass to the function.
    @return true and all results from the called function on success; false and
        an error message plus stacktrace (in one string) otherwise.
]]
function tpcall(f, ...)
    -- Computes the current stack level.
    local function stacklevel()
        -- Start outside this function.
        local level = -1
        for i = 1, math.huge do
            -- This is the trick: we use the fact that error() takes an integer
            -- parameter that tells it which level to prepend to the message.
            -- So we keep walking the stack until nothing gets prepended,
            -- meaning we've reached the bottom.
            local _, location = pcall(error, "", i)
            if location == "" then
                break
            end
            level = level + 1
        end
        return level
    end
    -- Level of the function that we should call, filled in below.
    local baseLevel
    -- Needed for closure to allow us passing along arguments.
    local args = {...}
    return xpcall(
        function()
            -- Plus one to get to the level of the function we're calling.
            baseLevel = stacklevel() + 1
            return f(unpack(args))
        end,
        function(message)
            -- Skip if we were terminated.
            if message == "Terminated" then
                return message
            end
            -- Format the message itself.
            do
                local file, line, what =
                    message:match("^([^:]+):(%-?%d*):?%s*(.*)$")
                if file then
                    message = what ~= "" and ("error: " .. what) or "error"
                    message = message .. "\n at " .. file
                    if line ~= "" then
                        message = message .. ":" .. line
                    end
                end
            end
            -- Generate a stack trace, starting one above the original error
            -- location since we already have that (add 2 more for the error
            -- and the pcall we use to get the locations) up to the level of
            -- our actual function.
            for level = 4, stacklevel() - baseLevel + 3 do
                -- Again, we use the fact that we can tell error() which level
                -- to prepend to the message. We then parse that location.
                local _, location = pcall(error, "", level)
                -- Get the message parts and format them.
                local file, line = location:match("^([^:]+):(%-?%d*).*$")
                if file then
                    line = line ~= "" and line or "native"
                    message = message .. "\n at " .. file .. ":" .. line
                else
                    message = message .. "\n at " .. location
                end
            end
            return message
        end)
end