local username = "jensModvig"
local repo = "Minecraft-Computercraft"
local gitgetDir = "programs/gitget.lua"
local function iGitget()
    if fs.exists(gitgetDir) then
        shell.run(gitgetDir, username, repo)
    else
        print("GitGet application does not exist. Downloading...")
        shell.run("pastebin", "get", "W5ZkVYSi", gitgetDir)
        shell.run(gitgetDir, username, repo)
    end
end
if http then
    iGitget()
else
    print("HTTP not enabled. Cant download github downloader")
end