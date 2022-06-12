local username = "jensModvig"
local repo = "Minecraft-Computercraft"
local gitgetDir = "programs/gitget.lua"
local function hte()
    if fs.exists(gitgetDir) then
        shell.run(gitgetDir, username, repo)
    else
        print("GitGet application does not exist. Downloading...")
        shell.run("pastebin", "get", "W5ZkVYSi", gitgetDir)
        shell.run(gitgetDir, username, repo)
    end
    print("Installed.")
end
if http then
    print("HTTP enabled. You can continue.")
    hte()
else
    print("HTTP not enabled. App will not continue.")
end

-- specify where programs are located
shell.setDir(".:/programs:/rom/programs:/rom/programs/turtle:")