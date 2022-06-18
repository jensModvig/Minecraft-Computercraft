
local json = require("/apis/json")

local dataDir = "/data/programs/"
local fileName = dataDir .. shell.getRunningProgram()

fs.makeDir(dataDirper)

function load()
    return json.decodeFromFile(fileName)
end

function save(options)
    local file = fs.open(fileName, "w")
    file.write(json.encodePretty(options))
    file.close() -- Remember to call close, otherwise changes may not be written!
end