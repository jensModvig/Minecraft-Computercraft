local username = "jensModvig"
local repo = "Minecraft-Computercraft"
local gitgetDir = "programs/gitget.lua"
local function iGitget()
    if not fs.exists(gitgetDir) then
        print("GitGet application does not exist. Downloading...")
        shell.run("pastebin", "get", "W5ZkVYSi", gitgetDir)
    end
    shell.run(gitgetDir, username, repo)
end
if http then
    iGitget()
else
    print("HTTP not enabled. Cant download github downloader")
end