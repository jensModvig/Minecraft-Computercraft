-- Skip if we already ran.
if startup then
    return false
end

-- Install custom API loader.
os.loadAPI("apis/bapil.lua")
bapil.hijackOSAPI()

-- Optional: add some aliases, for example:
--bapil.setPath(bapil.path() .. ":/ccapis:/lama")
--shell.setPath(shell.path() .. ":/ccapis/programs:/lama/programs")

-- Load stacktrace API and install tpcall as replacement for pcall.
assert(os.loadAPI("apis/stacktrace.lua"))
_G.pcall = stacktrace.tpcall

-- Load daemon API and install it.
-- Alternatively: have this in a startup script.
assert(os.loadAPI("apis/daemon.lua"))
daemon.install()

-- Load startup API and perform startup.
assert(os.loadAPI("apis/startup.lua"))
return startup.run()