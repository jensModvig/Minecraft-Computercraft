os.loadAPI("apis/state")
local program = state.new("/.program-state")
-- Add some states. Mind the colon! The first state added to the state
-- machine is assumed to be the entry state.
program:add("start", function()
    print("Running program...")
    stateGlobal = "This variable is available in all states."
    -- State variables will also be saved with the state.
    if wasRestarted == nil then
        wasRestarted = false
    else
        wasRestarted = true
    end
    save()
    -- If the program were to be terminated while waiting for this sleep
    -- call to return, wasRestarted would already hold a value (false), and
    -- be consequently set to true when the program is resumed.
    os.sleep(5)
    switchTo("end")
end)
program:add("end", function()
    print("Shutting down...")
    if wasRestarted then
        print("This program was interrupted at least once!")
    else
        print("This program finished in one go.")
    end
    -- Setting the next state to nil will make the state machine's run
    -- function return.
    switchTo(nil)
end)
program:run()