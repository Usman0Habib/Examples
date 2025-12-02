--[[ 

--NOTE: Used UIS for custom input controls instead of CAS, I can use CAS if later 
i want rebindable controls and mobile freidnly version but as of now i dont see any need


]]


local Data = script.Parent.Parent.Data
local Campos = require(Data.CameraPos)
local PlanetData = require(Data.PlanetData)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- tuning values for camera behavior
local TWEEN_DURATION = 3
local TOP_VIEW_HEIGHT = 2000
local ZOOM_SENSITIVITY = 50
local ORBIT_ROTATION_SPEED = 0.005
local MIN_DISTANCE_THRESHOLD = 1
local MIN_ELEVATION_CLAMP = -math.pi / 2 + 0.1
local MAX_ELEVATION_CLAMP = math.pi / 2 - 0.1

-- tracks active renderstep loops per player id
local cameraConnections = {}
-- stores orbit state (angles, distance, zoom bounds) indexed by userid
local cameraStates = {}

local Functions = {}

-- looks for planet in either instance form or by name string
local function resolvePlanet(planetRef)
	if typeof(planetRef) == "Instance" then
		return planetRef
	elseif typeof(planetRef) == "string" then
		local planetsFolder = workspace:FindFirstChild("Planets")
		local testFolder = workspace:FindFirstChild("TestingPlanets")
		return (planetsFolder and planetsFolder:FindFirstChild(planetRef)) or (testFolder and testFolder:FindFirstChild(planetRef))
	end
	return nil
end

-- makes sure planet exists and has the ghost orbit point
local function validatePlanet(planet)
	if not planet or not planet:FindFirstChild("Ghost") then
		return false
	end
	local ghost = planet:FindFirstChild("Ghost")
	return ghost and ghost:IsA("BasePart")
end

-- wipes camera state and disconnects any running loops for given player
local function clearPlayerCamera(player)
	local userId = player.UserId

	if cameraConnections[userId] then
		cameraConnections[userId]:Disconnect()
		cameraConnections[userId] = nil
	end

	if cameraStates[userId] then
		cameraStates[userId] = nil
	end

	local playerData = player:FindFirstChild("PlayerData")
	if playerData and playerData:FindFirstChild("LockedOn") then
		playerData.LockedOn.Value = ""
	end
end

-- switches camera to manual control mode
local function setupScriptableCamera(camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
end

-- smooth easing curve, faster start/end than linear
local function quinticEase(alpha)
	if alpha < 0.5 then
		return 16 * alpha * alpha * alpha * alpha * alpha
	else
		return 1 - math.pow(-2 * alpha + 2, 5) / 2
	end
end

-- positions camera based on spherical cords (azimuth, elevation, distance from subject)
local function updateOrbitPosition(camera, subject, azimuth, elevation, distance)
	if not subject or not subject.Parent then
		return false
	end

	local relativePos = CFrame.fromEulerAnglesYXZ(elevation, azimuth, 0) * Vector3.new(0, 0, -distance)
	local newCameraPos = subject.Position + relativePos
	camera.CFrame = CFrame.new(newCameraPos, subject.Position)
	return true
end

-- converts camera world position back to orbit angles so we can smoothly continue orbiting
local function calculateOrbitAngles(cameraPos, subject)
	local relativePos = cameraPos - subject.Position
	local distance = relativePos.Magnitude

	if distance < MIN_DISTANCE_THRESHOLD then
		return 0, math.pi / 2
	end

	local azimuth = math.atan2(relativePos.X, relativePos.Z)
	local elevation = math.asin(math.clamp(relativePos.Y / distance, -1, 1))
	return azimuth, elevation
end

-- sets up orbit loop after tween finishes, enables mouse controls
local function beginOrbit(player, camera, subject, radiusData)
	local userId = player.UserId

	local distance = (camera.CFrame.Position - subject.Position).Magnitude
	local azimuth, elevation = calculateOrbitAngles(camera.CFrame.Position, subject)

	cameraStates[userId] = {
		subject = subject,
		distance = distance,
		minDistance = radiusData.min,
		maxDistance = radiusData.max,
		azimuth = azimuth,
		elevation = elevation,
	}

	local orbitConn
	orbitConn = RunService.RenderStepped:Connect(function()
		if not subject or not subject.Parent or not cameraStates[userId] then
			orbitConn:Disconnect()
			clearPlayerCamera(player)
			return
		end

		local state = cameraStates[userId]
		updateOrbitPosition(camera, state.subject, state.azimuth, state.elevation, state.distance)
	end)

	cameraConnections[userId] = orbitConn
end

-- animates camera from current pos to topdown sun view over 3 seconds
local function tweenToTopView(player, camera, sunPart)
	local userId = player.UserId
	setupScriptableCamera(camera)

	local startCFrame = camera.CFrame
	local targetPos = sunPart.Position + Vector3.new(0, TOP_VIEW_HEIGHT, 0)
	local elapsedTime = 0

	local tweenConn
	tweenConn = RunService.RenderStepped:Connect(function(dt)
		elapsedTime += dt
		local alpha = math.min(elapsedTime / TWEEN_DURATION, 1)

		if not sunPart or not sunPart.Parent then
			tweenConn:Disconnect()
			return
		end

		local easedAlpha = quinticEase(alpha)
		local newPos = startCFrame.Position:Lerp(targetPos, easedAlpha)
		camera.CFrame = CFrame.new(newPos, sunPart.Position)

		if alpha >= 1 then
			tweenConn:Disconnect()
			local lockedDist = (camera.CFrame.Position - sunPart.Position).Magnitude
			beginOrbit(player, camera, sunPart, {
				min = lockedDist * 0.5,
				max = lockedDist * 3,
			})
		end
	end)
end

-- smoothly flies camera toward planet while it orbits then switches to orbit mode
local function tweenToPlanet(player, camera, ghost, radiusData)
	local userId = player.UserId
	setupScriptableCamera(camera)

	local startCFrame = camera.CFrame
	local surfaceDistance = radiusData.surface
	local elapsedTime = 0
	local tweenFinished = false

	local planet = ghost.Parent

	local tweenConn
	tweenConn = RunService.RenderStepped:Connect(function(dt)
		if not planet or not planet.Parent or not ghost or not ghost.Parent then
			tweenConn:Disconnect()
			clearPlayerCamera(player)
			return
		end

		elapsedTime += dt
		local alpha = math.min(elapsedTime / TWEEN_DURATION, 1)

		if not tweenFinished then
			local directionVector = camera.CFrame.Position - ghost.Position
			local distance = directionVector.Magnitude

			-- if camera ends up on top of planet, pick a sensible direction to orbit from
			local offsetDir = distance < MIN_DISTANCE_THRESHOLD and Vector3.new(0, 0, -1) or directionVector.Unit
			local targetPos = ghost.Position + offsetDir * surfaceDistance

			local easedAlpha = quinticEase(alpha)
			local newCameraPos = startCFrame.Position:Lerp(targetPos, easedAlpha)
			camera.CFrame = CFrame.new(newCameraPos, ghost.Position)
		end

		if alpha >= 1 and not tweenFinished then
			tweenFinished = true
			tweenConn:Disconnect()
			beginOrbit(player, camera, ghost, radiusData)
		end
	end)
end

-- fade out zone rings
function Functions.HideZones()
	local TS = game:GetService("TweenService")
	local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local outGoal = {Transparency = 1}

	local ringFolder = workspace:WaitForChild("Habitibility")

	for _, v in ringFolder:GetChildren() do
		if v:IsA("UnionOperation") or v:IsA("Part") then
			local tween = TS:Create(v, info, outGoal)
			tween:Play()
		end
	end
end

-- fade in zone rngs
function Functions.Showzones()
	local TS = game:GetService("TweenService")
	local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local inGoal = {Transparency = 0.5}

	local ringFolder = workspace:WaitForChild("Habitibility")

	for _, v in ringFolder:GetChildren() do
		if v:IsA("UnionOperation") or v:IsA("Part") then
			local tween = TS:Create(v, info, inGoal)
			tween:Play()
		end
	end
end

-- pan to topdown sun view
function Functions.SwitchToTopView(camera, player)
	local sunPart = workspace:WaitForChild("Sun"):WaitForChild("SunPart")

	clearPlayerCamera(player)
	tweenToTopView(player, camera, sunPart)
end

-- stop following whatevers locked
function Functions.UnlockCamera(player)
	clearPlayerCamera(player)
end

-- fly camera toward a specific planet and lock orbit to it
function Functions.LockCamera(player, camera, planetRef)
	local planet = resolvePlanet(planetRef)
	if not validatePlanet(planet) then
		return
	end

	local ghost = planet:FindFirstChild("Ghost")
	clearPlayerCamera(player)

	player.PlayerData.LockedOn.Value = planet.Name

	local radius = PlanetData[tostring(planetRef)].Size.X / 2
	local cameraOffset = math.max(10, radius * 0.5)

	tweenToPlanet(player, camera, ghost, {
		surface = radius + cameraOffset,
		min = radius + (radius * 0.2),
		max = radius + (radius * 4),
	})
end

-- rightclick drag to rotate, scroll to zoom
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local camera = workspace.CurrentCamera
	local player = game.Players.LocalPlayer
	if not player then return end

	local userId = player.UserId
	local state = cameraStates[userId]
	if not state then return end

	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local mouseDelta = input.Position - (state.lastMousePos or input.Position)
			state.azimuth -= mouseDelta.X * ORBIT_ROTATION_SPEED
			state.elevation = math.clamp(state.elevation + mouseDelta.Y * ORBIT_ROTATION_SPEED, MIN_ELEVATION_CLAMP, MAX_ELEVATION_CLAMP)
		end
		state.lastMousePos = input.Position
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local scrollDelta = input.Position.Z
		state.distance -= scrollDelta * ZOOM_SENSITIVITY
		state.distance = math.max(state.minDistance, math.min(state.distance, state.maxDistance))
	end
end)

-- cleanp on player disconnect
game.Players.PlayerRemoving:Connect(function(player)
	Functions.UnlockCamera(player)
end)

return Functions
