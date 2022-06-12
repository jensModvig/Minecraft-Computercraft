local username = "jensModvig"
local repo = "Minecraft-Computercraft"
function hte()
if fs.exists(gitget)
shell.run("gitget", username, repo)
else
print("GitGet application does not exist. Downloading...")
shell.run("pastebin", "get", "W5ZkVYSi", "gitget")
shell.run("gitget", username, repo)
end
echo("Installed.")
end
if http then
print("HTTP enabled. You can continue.")
hte()
else
print("HTTP not enabled. App will not continue.")
end