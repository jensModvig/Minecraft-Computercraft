local pose = require("/apis/pose")
local options = require("/apis/persistanceOptions")

local DATAPATH = "lps"

local data = options.load(DATAPATH)
-- first time setup
if data.waypoints == nil then
    data.waypoints = { { x=0, y=0, z=0, f=1} }
    data.startFuel = turtle.getFuelLevel()
    options.save(data, DATAPATH)
end

print("lps version 1")

local dir_map = {
    vector.new(1,0,0), -- north/front
    vector.new(0,0,1), -- east/right
    vector.new(-1,0,0),-- south/back
    vector.new(0,0,-1) -- west/left
}

local lPose = pose.new(0,0,0,1)
local onMoveFunc

local function move(ahead, dig, attack, detect, relative)
    while not ahead() do
        if detect() and not dig() then
            error("cant mine block")
        end
        attack()
        if turtle.getFuelLevel() == 0 then
            error("no more fuel")
        end
    end
    lPose = lPose:add(dir_map[lPose.f]:mul(relative.x)):add(vector.new(0,relative.y,0))
    if (onMoveFunc) then
        onMoveFunc()
    end
end
local function forward() return move(turtle.forward, turtle.dig, turtle.attack, turtle.detect, vector.new(1,0,0)) end
local function up() return move(turtle.up, turtle.digUp, turtle.attackUp, turtle.detectUp, vector.new(0,1,0)) end
local function down() return move(turtle.down, turtle.digDown, turtle.attackDown, turtle.detectDown, vector.new(0,-1,0)) end

local function turn(action, moduloOffset, pose)
    action()
    pose.f = (pose.f + moduloOffset) % 4 + 1
end
local function turnRight() turn(turtle.turnRight, 0, lPose) end
local function turnLeft() turn(turtle.turnLeft, 2, lPose) end

local function _face(goal, pose, left_action, right_action)
    if goal%4+1 == pose.f then
        left_action()
    else
        for i=1,math.abs(goal-(pose.f%4))%4 do
            right_action()
        end
    end
end
local function face(goal) _face(goal, lPose, turnLeft, turnRight) end


local function getPose() return lPose:copy() end
local function registerOnMove(onMove)
    onMoveFunc = onMove
end

-- function sign(number)
--   return (number > 0 and 1) or (number == 0 and 0) or -1
-- end

-- Takes the waypoint list to execute and calculates the current pose
local function calculatePoses()

    if #data.waypoints == 0 then
        error("LPS file must contain at least one waypoint (current position).")
    end
    if data.waypoints[1].f == nil then
        error("The first waypoint must contain a facing,")
    end
    
    -----  Calculate the exact pose ---------
    local possible_facings = {}
    local current_pose = data.waypoints[1]
    local moves_left = data.startFuel - turtle.getFuelLevel()

    local function log_facing()
        possible_facings[current_pose.f] = true
    end
    -- turnRight and turnLeft logs the facing before the turn.
    local function turnRight() turn(log_facing, 0, current_pose) end
    local function turnLeft() turn(log_facing, 2, current_pose) end
    local function face(goal) _face(goal, current_pose, turnLeft, turnRight) end

    function travelAxis(difference, facing, axis)
        if difference == 0 then
            return false
        end
        if facing ~= nil then
            -- we are in final position, so calculate all the possible turns
            if moves_left == 0 then
                face(facing)
            -- we know we arent in final position, so we can just assume that turtle has made the correct facing
            else
                -- wrap facing betweem 1 and 4
                current_pose.f = (facing - 1) % 4 + 1
            end
        end
        -- We are done, turtle needs to move, but no more fuel left
        if moves_left == 0 then
            return true
        end
        local abs_diff = math.abs(difference)
        local stepsMoved = math.min(abs_diff, moves_left)
        moves_left = moves_left - stepsMoved
        current_pose[axis] = current_pose[axis] + math.sign(difference)*stepsMoved
        -- turtle needs to move, but no more fuel left
        if stepsMoved < abs_diff then
            return true
        end
        return false
    end

    local next_waypoint_idx = nil
    for i = 2, #data.waypoints do
        -- reversed order (yzx) and opposite facing
        if  travelAxis(current_pose.x - data.waypoints[i].x, current_pose.x < data.waypoints[i].x and 3 or 1, "x") or
            travelAxis(current_pose.z - data.waypoints[i].z, current_pose.z < data.waypoints[i].z and 4 or 2, "z") or
            travelAxis(current_pose.y - data.waypoints[i].y, nil, "y") then

            next_waypoint_idx = i
            break
        end
    end
    -- log the facing after the turn
    possible_facings[current_pose.f] = true

    local possible_poses = {}
    for i = 1, 4 do
        if possible_facings[i] ~= nil then
            possible_poses[#possible_poses+1] = pose.new(current_pose.x, current_pose.y, current_pose.z, i)
        end
    end
    return {
        idx = next_waypoint_idx,
        poses = possible_poses
    }
end

if data.waypoints ~= nil then
    local data = calculatePoses()
    print("found ", #data.poses, " possible poses, they are:")
    for _, pose in ipairs(data.poses) do
        print(pose:tostring())
    end
    
    local waypoint_data = {
        startFuel = turtle.getFuelLevel(),
        waypoints = {}
    }
    lPose = data.poses[1]

    -- Remove waypoints before the new pose
    table.insert(waypoint_data.waypoints, lPose)
    if data.idx ~= nil then
        for i = data.idx, #waypoint_data.waypoints do
            table.insert(waypoint_data.waypoints, lPose)
        end
    end
    data = waypoint_data

    options.save(data, DATAPATH)
end


local function gotoPose(x, y, z, f)
    print("going to ", x, " ", y, " ", z, " ", f)
    function travelAxis(difference, action, facing)
        if difference == 0 then
            return
        end
        face(facing)
        for i=1,math.abs(difference) do
            action()
        end
    end
    travelAxis(x - lPose.x, forward, x < lPose.x and 3 or 1)
    travelAxis(z - lPose.z, forward, z < lPose.z and 4 or 2)
    travelAxis(y - lPose.y, y < lPose.y and down or up, lPose.f)
    if (f) then
        face(f)
    end
end

local function navigate(success, error)
    data.startFuel = turtle.getFuelLevel()
    options.save(data, DATAPATH)
    local status, err = pcall(function()--try
        for i, v in pairs(data.waypoints) do
            print("going to idx ", i)
            gotoPose(v.x, v.y, v.z, v.f)
        end
    end ) if not status then-- catch
        error(err)
    end
    success()
end

return {
    forward = forward,
    up = up,
    down = down,
    turnRight = turnRight,
    turnLeft = turnLeft,
    face = face,
    gotoPose = gotoPose,
    getPose = getPose,
    registerOnMove = registerOnMove,
    navigate=navigate,
    waypoints=data.waypoints
}