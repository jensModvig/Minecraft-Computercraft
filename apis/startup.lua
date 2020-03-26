--[[
    BS - Better Startup - 2013 Sangar

    This program is licensed under the MIT license.
    http://opensource.org/licenses/mit-license.php

    This startup script allows for multiple startup scripts. Just drop them in
    the folder as configured in the startupPath variable (default: /autorun).
    All scripts in that folder will be run in sequence, in order of their names
    when private.run() is called. Alternatively use the API to modifiy scripts.
    Startup scripts can be disabled without having to delete/move them by
    simply adding an extension to the filename as configured in the
    disabledPostfix variable (default: disabled). This can also be done via
    the API.
]]

-------------------------------------------------------------------------------
-- Config                                                                    --
-------------------------------------------------------------------------------

-- The path to the folder containing all startup scripts.
local startupPath = "/autorun"

-- The extension startup and daemon scripts have that should be ignored.
local disabledPostfix = "disabled"

-- The time in seconds to wait for a user to chose whether to cancel startup or
-- not, before automatically resuming. It set to zero startup will resume
-- instantly, if set to a negative value startup will always be aborted and if
-- set to math.huge will wait indefinitely for input (and not show a timer).
local errorTimeout = 5

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Startup API                                                               --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- If this API was loaded before, reuse it to avoid unnecessary garbage.
if startup then
    local env = getfenv()
    for k, v in pairs(startup) do
        env[k] = v
    end
    return
end

-- Internal forward declarations. They have to be declared here so that
-- functions can access them.
local private

-------------------------------------------------------------------------------
-- Public API                                                                --
-------------------------------------------------------------------------------

-- The current version of the API.
version = "1.3"

--[[
    Adds a new startup script with the specified priority by copying the
    specified file into the startup folder.

    @param name the name for the script.
    @param priority the startup priority of the script, an integer in [0, 99].
    @param path the path to the file to copy.
    @return true if the script was installed successfully; (false, reason) if
        there is no such file or a script with that name already exists.
]]
function addFile(name, priority, path)
    assert(type(name) == "string" and name ~= "",
        "'name' must be a non-empty string")
    assert(type(path) == "string" and path ~= "",
        "'path' must be a non-empty string")
    priority = private.formatPriority(priority)

    if not fs.exists(path) or fs.isDir(path) then
        return false, "no such file"
    end
    if exists(name) then
        return false, "script with that name already exists"
    end

    local scriptPath = fs.combine(startupPath, priority .. "_" .. name)
    local file = assert(fs.open(scriptPath, "w"),
        "Could not open startup script file for writing")
    file.write(string.format("shell.run(%q)", path))
    file.close()
    return true
end

--[[
    Adds a new startup script with the specified priority by creating a script
    with the specified code in the startup folder.

    @param name the name for the script.
    @param priority the startup priority of the script, an integer in [0, 99].
    @param code the code of the startup script.
    @return true if the script was installed successfully; (false, reason) if a
        script with that name already exists.
]]
function addString(name, priority, code)
    assert(type(name) == "string" and name ~= "",
        "'name' must be a non-empty string")
    assert(type(code) == "string" and code ~= "",
        "'code' must be a non-empty string")
    priority = private.formatPriority(priority)

    if exists(name) then
        return false, "script with that name already exists"
    end

    local path = fs.combine(startupPath, priority .. "_" .. name)
    local file = assert(fs.open(path, "w"),
        "Could not open file '" .. path .. "' for writing.")
    file.write(code)
    file.close()
    return true
end

--[[
    Checks whether a script with the specified name exists.

    @param name the name of the script to check for.
    @return true if such a script exists, enabled or disabled; false otherwise.
]]
function exists(name)
    assert(type(name) == "string" and name ~= "",
        "'name' must be a non-empty string")
    return select(1, private.find(name))
end

--[[
    Remove the startup script with the specified name.

    IMPORTANT: this deletes the actual file from the system.

    @param name the name of the script to remove.
    @return true if the script was removed; false otherwise.
]]
function remove(name)
    if not exists(name) then
        return false
    end
    fs.delete(scriptPath(name))
    return true
end

--[[
    Checks whether startup scripts can be disabled without being deleted.

    @return true if scripts can be disabled/enabled; false otherwise.
]]
function canDisableScripts()
    return disabledPostfix and disabledPostfix ~= ""
end

--[[
    Enables the startup script with the specified name.

    @param name the name of the startup script.
    @return true if the script is or was enabled; false otherwise.
]]
function enable(name)
    if not canDisableScripts() or not exists(name) then
        return false
    end
    if not isEnabled(name) then
        local priority = getPriority(name)
        local pathEnabled = fs.combine(startupPath, priority .. "_" .. name)
        local pathDisabled = pathEnabled .. "." .. disabledPostfix
        if fs.exists(pathEnabled) then
            fs.delete(pathEnabled)
        end
        private.checkedMove(pathDisabled, pathEnabled)
    end
    return true
end

--[[
    Disables the startup script with the specified name.

    @param name the name of the startup script.
    @return true if the script is or was disabled; false otherwise.
]]
function disable(name)
    if not canDisableScripts() or not exists(name) then
        return false
    end
    if isEnabled(name) then
        local priority = getPriority(name)
        local pathEnabled = fs.combine(startupPath, priority .. "_" .. name)
        local pathDisabled = pathEnabled .. "." .. disabledPostfix
        if fs.exists(pathDisabled) then
            fs.delete(pathDisabled)
        end
        private.checkedMove(pathEnabled, pathDisabled)
    end
    return true
end

--[[
    Tests whether the startup script with the specified name is enabled.

    @param name the name of the script to check.
    @return true if the script is enabled; false otherwise.
]]
function isEnabled(name)
    assert(type(name) == "string" and name ~= "",
        "'name' must be a non-empty string")
    local success, _, enabled = private.find(name)
    return success and enabled
end

--[[
    Returns the current priority of the script with the specified name.

    @param name the name of the script.
    @return the priority of the script; math.huge if there is no such script.
]]
function getPriority(name)
    if not exists(name) then
        return math.huge
    end
    local _, priority, _ = private.find(name)
    return tonumber(priority)
end

--[[
    Sets the new priority for the script with the specified name.

    @param name the name of the script.
    @param priority the new priority, an integer in [0, 99]
    @return true if the priority is or was applied; false otherwise.
]]
function setPriority(name, priority)
    priority = private.formatPriority(priority)
    if not exists(name) then
        return false
    end
    local currentPriority = getPriority(name)
    local oldPath = fs.combine(startupPath, currentPriority .. "_" .. name)
    local newPath = fs.combine(startupPath, priority .. "_" .. name)
    if not isEnabled(name) then
        oldPath = oldPath .. "." .. disabledPostfix
        newPath = newPath .. "." .. disabledPostfix
    end
    private.checkedMove(oldPath, newPath)
    return true
end

--[[
    Returns an iterator function over all startup scripts.

    This will include any known scripts, whether they're enabled or not does
    not make a difference.

    Usage: for name in startup.iter() do ... end

    @return an iterator over all known scripts.
]]
function iter()
    local list = fs.list(startupPath)
    table.sort(list)
    local index
    return function()
        local name
        index, name = next(list, index)
        if name and name:match("^%d%d_.+$") then
            name = name:sub(4)
            if canDisableScripts() then
                return select(1, name:gsub("%." .. disabledPostfix .. "$", ""))
            else
                return name
            end
        end
    end
end

--[[
    Returns the path to the startup script with the specified alias.

    This can be useful for backups and automatic installer scripts (for
    example, JAM uses this for replicating a system environment onto a floppy
    disk and back again).

    @param name the name of the script to get the path to.
    @return the path to the script file.
]]
function scriptPath(name)
    assert(exists(name), "no such script")
    local _, priority, enabled = private.find(name)
    local path = fs.combine(startupPath, priority .. "_" .. name)
    if not enabled then
        path = path .. "." .. disabledPostfix
    end
    return path
end

--[[
    Runs all startup scripts in the startup scripts folder in alphabetic order.

    Note that this will print status and error messages to the screen.

    @return true if all scripts ran successfully; false otherwise (this
        includes the case where remaining scripts ran either because we're
        configured to continue regardless, or because the user said it's OK).
]]
function run()
    -- Get list of startup scripts.
    local list = fs.list(startupPath)
    -- Make sure the list is sorted.
    table.sort(list)
    -- Run all startup scripts.
    local success = true
    for _, name in ipairs(list) do
        local path = fs.combine(startupPath, name)
        if private.shouldRun(path) then
            print("> " .. path)
            -- Try to load the script.
            local result, message = loadfile(path)
            if result then
                -- Give each script its own environment so they do not
                -- interfere with each other, then do a protected call.
                setfenv(result, setmetatable({}, {__index = getfenv(2)}))
                result, message = pcall(result)
            end
            -- Check if we had an error, if so, depending on our configuration,
            -- give the user chance to decide whether to go on or not, or
            -- decide for ourselves what to do.
            if not result then
                success = false
                printError(message)
                if errorTimeout < 0 then
                    print("Skipping remaining scripts.")
                    break
                elseif errorTimeout ~= 0 then
                    print("Resume startup?")
                    if not private.prompt() then
                        break
                    end
                end
            end
        end
    end
    return success
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Internals                                                                 --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Private namespace.
private = {}

--[[
    Utility function for validating and formatting priorities.

    @param priority the input priority.
    @return the priority as a formatted string.
]]
function private.formatPriority(priority)
    assert(type(priority) == "number", "'priority' must be a number")
    assert(priority == math.floor(priority), "'priority' must be integral")
    assert(priority >= 0 and priority <= 99,
        "'priority' must be in the interval [0, 99]")
    return string.format("%2d", priority)
end

--[[
    Utility function for finding an existing startup script.

    @param name the name of the script.
    @return (true, priority, enabled) on success; false otherwise.
]]
function private.find(name)
    local pattern = "^(%d%d)_(.+)$"
    -- Check all files. Make sure the list is sorted, just in case someone got
    -- the crazy idea to put in two scripts with the same "name", so that we
    -- have deterministic behavior.
    local list = fs.exists(startupPath) and fs.list(startupPath) or {}
    table.sort(list)
    for _, fileName in ipairs(list) do
        local path = fs.combine(startupPath, fileName)
        if not fs.isDir(path) then
            -- If we allow disabling scripts, check for disabled scripts first
            -- because the "pattern" is more selective (we cut off the postfix).
            if canDisableScripts() then
                -- Determine the end of the string without the extension.
                local length = fileName:len() - (disabledPostfix:len() + 1)
                -- Make sure it's not negative, because that has a special
                -- meaning for the string.sub() function (start from the back).
                length = math.max(0, length)
                local priority, scriptName =
                    fileName:sub(1, length):match(pattern)
                if scriptName == name then
                    return true, priority, false
                end
            end
            do
                local priority, scriptName = fileName:match(pattern)
                if scriptName == name then
                    return true, priority, true
                end
            end
        end
    end
    return false
end

--[[
    Utility function for checking whether a startup script should be run.

    @param the path to the script.
    @return true if the script is a file and not disabled; false otherwise.
]]
function private.shouldRun(path)
    if fs.isDir(path) then
        return false
    end
    if not fs.getName(path):match("^%d%d_.+$") then
        return false
    end
    if disabledPostfix and disabledPostfix ~= "" then
        return path:sub(-disabledPostfix:len()) ~= disabledPostfix
    end
    return true
end

--[[
    Performs a fs.move() but checks if there's enough disk space first and
    throws a more meaningful error than "could not copy file" if not.

    @param from the path to move the file from.
    @param to the path to move the file to.
]]
function private.checkedMove(from, to)
    local toSize = math.max(512, fs.getSize(from) + fs.getName(to):len())
    assert(fs.getFreeSpace(to) >= toSize, "Out of disk space!")
    fs.move(from, to)
end

--[[
    Utility function waiting for the user to press a key or a timeout.

    @return true if the prompt was positively confirmed; false otherwise.
]]
function private.prompt()
    write("> [Y/n] ")
    term.setCursorBlink(true)
    local countdown = errorTimeout
    local update = nil
    while true do
        if countdown ~= math.huge then
            update = update or os.startTimer(1)
            write(countdown)
        end
        local type, arg = os.pullEvent()
        if countdown ~= math.huge then
            local x, y = term.getCursorPos()
            term.setCursorPos(x - 1, y)
        end
        if type == "key" and arg == keys.y  or arg == keys.enter then
            -- Return success if the prompt was confirmed.
            os.sleep(0.1)
            print("y")
            term.setCursorBlink(false)
            return true
        elseif type == "key" and arg == keys.n then
            -- Return failure if the prompt was denied.
            os.sleep(0.1)
            print("n")
            term.setCursorBlink(false)
            return false
        elseif type == "key" then
            -- Stop the countdown if any other key was pressed.
            if countdown ~= math.huge then
                -- Erase the countdown number.
                local x, y = term.getCursorPos()
                write((" "):rep(tostring(countdown):len()))
                term.setCursorPos(x, y)
            end
            countdown = math.huge
        elseif type == "timer" and arg == update then
            -- Our regular timer update to update the displayed countdown.
            countdown = countdown - 1
            update = nil
            if countdown == 0 then
                print("y")
                term.setCursorBlink(false)
                return true
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Environment checking                                                      --
-------------------------------------------------------------------------------

-- Ensure we have a path set for our startup files.
assert(type(startupPath) == "string" and startupPath ~= "",
    "The setting 'startupPath' must be a non-empty string.")

-- Ensure the folder with startup files exists.
assert(not fs.exists(startupPath) or fs.isDir(startupPath),
    "Folder for startup scripts cannot be created because a file " ..
    "with that name already exists ('" .. startupPath .. "').")

-- Ensure our timeout is a number.
assert(type(errorTimeout) == "number",
    "The setting 'errorTimeout' must be a number.")

-------------------------------------------------------------------------------
-- Initialization                                                            --
-------------------------------------------------------------------------------

-- Create folder if it doesn't exist.
fs.makeDir(startupPath)