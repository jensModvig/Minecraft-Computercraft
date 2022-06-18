
local json = require("/apis/json")

local dataDir = "/data/"

fs.makeDir(dataDir)

function calcPath(suggestedPath)
    if suggestedPath ~= nil then
        return dataDir..suggestedPath
    else
        return dataDir..shell.getRunningProgram()
    end
end

function load(suggestedPath)
    return json.decodeFromFile(calcPath(suggestedPath))
end

function save(options, suggestedPath)
    local file = fs.open(calcPath(suggestedPath), "w")
    file.write(json.encodePretty(options))
    file.close()
end

return {
    load = load,
    save = save
}