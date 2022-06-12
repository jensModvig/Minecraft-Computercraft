local songName = "data/perry_the_platypus.dfpwm"

local myURL = "https://download1586.mediafire.com/50fgoowiw08g/l0bfyja5zdagn7i/song_perry_the_platypus.dfpwm"
local file = fs.open(songName, "w")
http.request(myURL)
local event, url, handle
repeat
    event, url, handle = os.pullEvent("http_success")
until url == myURL
print("Recieved file " .. url .. " Start saving...")
file.write(handle.readAll())
handle.close()
file.close()
print("File saved")


local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
 
local decoder = dfpwm.make_decoder()
for chunk in io.lines(songName, 16 * 1024) do
    local buffer = decoder(chunk)
 
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end