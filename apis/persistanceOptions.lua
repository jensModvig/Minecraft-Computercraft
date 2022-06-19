
local json = require("/apis/json")

local dataDir = "/data/"

fs.makeDir(dataDir)

function calcPath(suggestedPath)
    if suggestedPath ~= nil then
        return dataDir..suggestedPath .. ".json"
    else
        return dataDir..shell.getRunningProgram() .. ".json"
    end
end

function load(suggestedPath)
    suggestedPath = calcPath(suggestedPath)
    if fs.exists(suggestedPath) and not fs.isDir(suggestedPath) then
        return json.decodeFromFile(suggestedPath)
    end
    return {}
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