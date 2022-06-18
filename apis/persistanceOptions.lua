
os.loadAPI("apis/json")

local dataDir = "/data/programs/"
local fileName = dataDir .. shell.getRunningProgram()

makeDir(dataDir)

function load()
    decodeFromFile(fileName)
end

function save(options)
    local file = fs.open(fileName, "w")
    file.write(encodePretty(options))
    file.close() -- Remember to call close, otherwise changes may not be written!
end