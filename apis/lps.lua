local pose = require("/apis/pose")
local options = require("/apis/persistanceOptions")
local data = options.load("lps")

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
local function face(goal)
  return _face(goal, lPose, turnLeft, turnRight)
end

data.waypoints = {}
local function gotoPose(x, y, z, f)
    function travelAxis(difference, action, facing)
        if difference == 0 then return end
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
local function getPose() return lPose:copy() end
local function registerOnMove(onMove)
  onMoveFunc = onMove
end

-- function sign(number)
--   return (number > 0 and 1) or (number == 0 and 0) or -1
-- end

-- Takes the waypoint list to execute and calculates the current pose
local function calculatePose()

    if #data.waypoints == 0 then
        error("LPS file must contain at least one waypoint (current position).")
    end
    if data.waypoints[1].f == nil then
      error("The first waypoint must contain a facing,")
    end

    -- edge case with only one waypoint
    if #data.waypoints == 1 then
        return data.waypoints[1]

    ------ Find the waypoint steps before and after running out of fuel ------------
    local movesDone = data.startFuel - turtle.getFuelLevel()
    local to_analyze = []
    local i = 2
    while data.waypoints[i] do
        movesDone = movesDone - data.waypoints[i-1]:get_move_distance(data.waypoints[i])
        if movesDone <= 0 then
            if #to_analyze == 0 then
                to_analyze[1] = data.waypoints[i-1]
            end
            to_analyze[#to_analyze+1] = data.waypoints[i]

        if movesDone < 0 then
            break

        i = i + 1
    end

    
    -----  Calculate the exact pose ---------
    local possible_facings = {}
    local current_pose = to_analyze[#to_analyze+1]

    local function log_facing()
        possible_facings[current_pose.f] = true
    end
    -- turnRight and turnLeft logs the facing before the turn.
    local function turnRight() turn(log_facing, 0, current_pose) end
    local function turnLeft() turn(log_facing, 2, current_pose) end
    local function face(goal)
      return _face(goal, current_pose, turnLeft, turnRight)
    end

    function travelAxis(difference, facing, axis)
        if difference == 0 then
          return
        end
        if facing ~= nil then
            if movesDone == 0 then
                face(facing)
            else
              current_pose.f = facing % 4 + 1
            end
        end
        -- We are done, turtle needs to move, but no more fuel used
        if movesDone == 0 then
          return true
        end
        local stepsMoved = math.min(math.abs(difference), -movesDone)
        movesDone = movesDone + stepsMoved
        current_pose[axis] = current_pose[axis] + math.sign(difference)*stepsMoved
    end

    for i = #to_analyze, 2, -1 do
        local prvevious_waypoint, this_waypoint = to_analyze[i-1], to_analyze[i]
        if movesDone == 0 then
        
        -- reversed order (yzx) and opposite facing
        if  travelAxis(prvevious_waypoint.y - this_waypoint.y, nil, "y") or
            travelAxis(prvevious_waypoint.z - this_waypoint.z, prvevious_waypoint.z < this_waypoint.z and 2 or 4, "z") or
            travelAxis(prvevious_waypoint.x - this_waypoint.x, prvevious_waypoint.x < this_waypoint.x and 1 or 3, "x") then
          break
        end
    end
    -- log the facing after the turn
    possible_facings[current_pose.f] = true

    local possible_poses = {}
    for i = 1, 4 do
      if possible_facings[i] ~= nil
          possible_poses[#possible_poses+1] = Pose(current_pose.x, current_pose.y, current_pose.z, i)
    end
    return possible_poses
end

if data.waypoints ~= nil then
    local calc = calculatePose()
    lPose = pose.new(calc.pose.x, calc.pose.y, calc.pose.z, calc.pose.f)
    print("pose calculated to ", lPose:tostring())
    local i = 0
    data.waypoints[1] = pose.new(calc.pose.x, calc.pose.y, calc.pose.z, calc.pose.f)
    while data.waypoints[calc.nxtWaypointIdx + i] do
      data.waypoints[i + 2] = data.waypoints[calc.nxtWaypointIdx + i]
      data.waypoints[calc.nxtWaypointIdx + i] = nil
      i = i + 1
    end
    data.startFuel = turtle.getFuelLevel()
    options.save(data, "lps")
end


local function navigate(success, error)
  data.startFuel = turtle.getFuelLevel()
  options.save(data, "lps")
  local status, err = pcall(function()--try
    for _, v in pairs(data.waypoints) do
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