--[[
    SILO - Simlpe Logger - 2013 Sangar

    This program is licensed under the MIT license.
    http://opensource.org/licenses/mit-license.php

    This API provides very simplistic logging, purely for the sake of uniform
    output to log files, and some utility stuff.
]]

-------------------------------------------------------------------------------
-- Config                                                                    --
-------------------------------------------------------------------------------

-- The folder into which to write log files.
local logFolder = "/logs/"

-------------------------------------------------------------------------------
-- Public API                                                                --
-------------------------------------------------------------------------------

-- The current version of the API.
version = "1.1"

--[[
    Creates a new logger that will log to the log file with the specified name.

    Usage:
    local log = logger.new("program_name")
    -- Mind the colon.
    log:info("This is a test.")
    log:info("The result is %d.", 123)
    log:info(nil, 123, "no format", true, "these will just be concatenated")
    log:warn("Not good...")
    log:err("I'm dying!")
    log:log("DEBUG", "herp derp")

    @param name the name of the logfile to use.
    @param rotate whether to automatically use a new log file when a new day
        begins (logfile names will be postfixed with the current day).
]]
function new(name, rotate)
    -- Formats days to a date in the proleptic Gregorian calendar.
    local function formatDays(days)
        -- Get the year and days we are into that year.
        local year = math.floor(days / 365.2425)
        days = math.ceil(days % 365.2425)
        -- Figure out the month and days we are into that month.
        local monthLengths
        -- Leap years! Hell yes.
        if year % 4 == 0 and year % 100 ~= 0 or year % 400 == 0 then
            monthLengths = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
        else
            monthLengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
        end
        local month = 1
        while days > monthLengths[month] do
            assert(month < 13)
            days = days - monthLengths[month]
            month = month + 1
        end
        -- Return a nicely formatted string.
        return string.format("%04d-%02d-%02d", year, month, days)
    end
    -- Formats time in a 24 hour style, with the hour being guaranteed to be
    -- two digits (prefixed zero) unlike textutils.formatTime().
    local function formatTime(time)
        return string.format("%02d:%02d", math.floor(time),
                             math.floor(60 * (time - math.floor(time))))
    end
    return setmetatable({}, {__index = {
        log = function(self, level, format, ...)
            assert(type(self) == "table", "bad call (use colons)")
            assert(type(level) == "string", "'level' must be a string")
            assert(format == nil or type(format) == "string",
                "'format' must be a string or omitted")

            -- Format the file name, in particular if we should automatically
            -- append the day to the file name.
            local fileName = name
            if rotate then
                fileName = fileName .. string.format("-%08d", os.day())
            end
            fileName = fileName .. ".log"

            -- Format the message, prepending the date and time, then the
            -- message level and finally the message itself.
            local messageFormat = string.format("%s %s [%s] %%s",
                                       formatDays(os.day()),
                                       formatTime(os.time()),
                                       level)
            local message
            if format then
                message = string.format(format, ...)
            else
                -- We have no format string, just concatenate the values.
                message = table.concat({...}, ", ")
            end
            message = string.format(messageFormat, message)

            -- Create log folder if necessary and write the log message.
            fs.makeDir(logFolder)
            local file = fs.open(fs.combine(logFolder, fileName), "a")
            file.writeLine(message)
            file.close()
        end,
        info = function(self, format, ...)
            assert(type(self) == "table", "bad call (use colons)")
            self:log("INFO", format, ...)
        end,
        warn = function(self, format, ...)
            assert(type(self) == "table", "bad call (use colons)")
            self:log("WARNING", format, ...)
        end,
        err = function(self, format, ...)
            assert(type(self) == "table", "bad call (use colons)")
            self:log("ERROR", format, ...)
        end
    }})
end