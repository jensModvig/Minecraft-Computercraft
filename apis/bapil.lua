--[[
    BAPIL - Blocking API Loader - 2013 Sangar

    This program is licensed under the MIT license.
    http://opensource.org/licenses/mit-license.php

    Pronounced "Bapple" (http://youtu.be/vE3roH38yks), this API provides
    replacements for the original API loading and unloading facilities.

    loadAPI blocks instead of printing an error if an API is already in the
    process of being loaded from another coroutine. It's possible to provide a
    timout. Also, it will not load an API again if it was already loaded, use
    reloadAPI for that. It furthermore loads all APIs via a protected call,
    which means you don't have to reboot the machine if an API fails loading.
    Lastly, unloadAPI also resolves paths.
]]

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- API Loader API                                                            --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- If this API was loaded before, reuse it to avoid loosing our state.
if bapil then
    local env = getfenv()
    for k, v in pairs(bapil) do
        env[k] = v
    end
    return
end

-- Namespace forward declarations.
local private

-------------------------------------------------------------------------------
-- Public API                                                                --
-------------------------------------------------------------------------------

-- The current version of the API.
version = "1.0"

--[[
    Alternative API loader with a few features the built-in one is missing.

    This will block if the API is currently being loaded by another coroutine.
    Note that this also means it'll be possible to create deadlocks (in the
    most basic case by an API loading itself), so you'll have to make sure
    there aren't any. Or use a timeout.

    This will also try to resolve the specified path using the global path
    variable (see path() and setPath()), if it's not an absolute path.

    @param path the path to the API file to load.
    @param timeout an optional timeout to wait if the API is already being
        loaded by another coroutine. Set this to zero to return immediately if
        the API is already being loaded by another coroutine.
    @return true on success; (false, reason) on failure.
]]
function loadAPI(path, timeout)
    -- Resolve the path and get the API's name from the file name.
    path = resolveAPI(path)
    local name = fs.getName(path):gsub("%.lua$", "")

    -- Check if the API is already loaded.
    if _G[name] then
        if type(_G[name]) == "table" then
            return true
        else
            return false, "trying to override global variable"
        end
    end

    -- Thread guard. Wait if another coroutine already is loading this API.
    timeout = timeout or math.huge
    while private.loadingAPIs[name] and timeout > 0 do
        timeout = timeout - 0.1
        os.sleep(0.1)
    end
    if private.loadingAPIs[name] then
        return false, "timeout"
    end

    -- If the API was loaded successfully by the other coroutine we are done.
    -- Otherwise we can't be sure the other coroutine didn't just unload the
    -- API again, so we'll have to try loading it again.
    if _G[name] then
        return true
    end

    -- Begin loading the API. Aquire lock.
    private.loadingAPIs[name] = true

    -- Wrapping it in a function for more linear indentation.
    local result, reason
    (function()
        -- Try to load the file.
        result, reason = loadfile(path)
        if not result then
            return
        end

        -- Try to execute the script. This can yield.
        local environment = {__bapil__ = true}
        local retval
        setfenv(result, setmetatable(environment, {__index = _G}))
        result, retval = pcall(result)
        if not result then
            reason = retval
            return
        end

        local api
        if retval == nil then
            -- Great! Set the environment as the API's entry. Since os.loadAPI
            -- copies all entries to a new table we do this here, too, though I
            -- don't really see the point (but this ignores the tables metatable,
            -- so we'd get different behavior if we skip this, which would be bad).
            api = {}
            for k, v in pairs(environment) do
                api[k] = v
            end

        elseif type(retval) == "table" then
            -- If the script returns table, use it as api.
            api = retval

        elseif type(retval) == "function" then
            -- As api can be only table, let's wrap returned function to table
            -- with metatable.
            api = {}
            api[name] = retval
            setmetatable(api, {
                __call = function (_, ...)
                    return retval(...)
                end
            })

        else
            result = false
            reason = "attempt use " .. type(retval) .. " as api"
            return
        end

        _G[name] = api

        if type(api) == "table" then
            -- If api has __load__ function, call it with the global environment.
            local __load__ = api.__load__
            if __load__ then
                setfenv(__load__, _G)
                __load__()
            end
        end
    end)()

    -- Done loading the API. Release lock.
    private.loadingAPIs[name] = false
    return result, reason
end

--[[
    Unloads a global API.

    @param the path to or name of the API to unload.
]]
function unloadAPI(path)
    local name = fs.getName(path)
    local api = _G[name]

    if api and type(api) == "table" then
        -- If api has __unload__ function, call it with the global environment.
        local __unload__ = api.__unload__
        if __unload__ then
            setfenv(__unload__, _G)
            __unload__()
        end
    end

    os.unloadAPI(name)
end

--[[
    Reloads an API.

    This simply unloads and then loads the API again. It's only provided
    because the original os.loadAPI() would always reload an API, so we want to
    provide a similarly convenient alternative.

    @param path the path to or name of the API.
    @param timeout same as for bapil.loadAPI().
    @return true on success; (false, reason) on failure.
]]
function reloadAPI(path, timeout)
    unloadAPI(path)
    return loadAPI(path, timeout)
end

--[[
    The current path environment in which to look for APIs.

    This is like shell.path() but for APIs loaded via this API. It's a string
    of paths separated by colons in which to search for APIs.

    @return the current path environment.
]]
function path()
    return private.path
end

--[[
    Set the path environment in which to look for APIs.

    @param path the new path environment.
    @see bapil.path()
]]
function setPath(path)
    private.path = path
end

--[[
    Tries to resolve a path using our internal path variable.

    This is essentially a simplified version of what shell.resolveProgram()
    does, but for APIs.

    @param the path or name of the API.
    @return the resolved path, which may be the same as the specified one.
]]
function resolveAPI(name)
    if string.sub(name, 1, 1) == '/' or string.sub(name, 1, 1) == '\\' then
        return name
    end
    for path in string.gmatch(private.path, "[^:]+") do
        path = fs.combine(path, name)
        if fs.exists(path) and not fs.isDir(path) then
            return path
        end
    end
    return name
end

--[[
    Replaces the API loading related functions in the OS API.

    @param restore whether to restore the original OS API functions.
]]
function hijackOSAPI(restore)
    if restore then
        if not os._bapil then return end
        os.loadAPI   = os._bapil.loadAPI
        os.unloadAPI = os._bapil.unloadAPI
        os._bapil = nil
    else
        if os._bapil then return end
        os._bapil = {
            loadAPI   = os.loadAPI,
            unloadAPI = os.unloadAPI
        }
        os.loadAPI   = loadAPI
        os.unloadAPI = unloadAPI
    end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Internals                                                                 --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Private namespace.
private = {}

-- The list of paths we can use to search for APIs when given relative paths.
private.path = "/rom/apis" .. (turtle and ":/rom/apis/turtle" or "") .. ":/apis"

-- Table of currently loading APIs.
private.loadingAPIs = {}