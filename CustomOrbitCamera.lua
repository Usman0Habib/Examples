local Data = script.Parent.Parent.Data
local Campos = require(Data.CameraPos)
local PlanetData = require(Data.PlanetData)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- table stores renderstep connections for each player so we can disconnect and cleanup later
local cameraConnections = {}
-- table stores camera state data (angles, distance, zoom limits) for smooth orbit controls
local cameraStates = {}

local Functions = {

	HideZones = function()
		local TS = game:GetService("TweenService")
		local info  = TweenInfo.new(3,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
		local OutGoal = {Transparency = 1}

		local RingFolder = workspace:WaitForChild("Habitibility")

		local function TweenOut(Ring)
			local TweenOut = TS:Create(Ring,info,OutGoal)
			TweenOut:Play()
		end
		for i,v in RingFolder:GetChildren() do
			if v:IsA("UnionOperation") or v:IsA("Part") then
				TweenOut(v)
			end
		end
	end,

	Showzones = function()
		local TS = game:GetService("TweenService")
		local info  = TweenInfo.new(3,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
		local InGoal = {Transparency = 0.5}

		local RingFolder = workspace:WaitForChild("Habitibility")

		local function TweenIn(Ring)
			local TweenIn = TS:Create(Ring,info,InGoal)
			TweenIn:Play()
		end
		for i,v in RingFolder:GetChildren() do
			if v:IsA("UnionOperation") or v:IsA("Part") then
				TweenIn(v)
			end
		end
	end,

	SwitchToTopView = function(Camera:Camera, Player:Player)
		local SunPart = workspace:WaitForChild("Sun"):WaitForChild("SunPart")

		local userId = Player.UserId

		-- disconnect any active camera orbit loop from previous lock state
		if cameraConnections[userId] then
			cameraConnections[userId]:Disconnect()
			cameraConnections[userId] = nil
		end

		-- clear camera state data to prevent orbit math from interfering during tween
		if cameraStates[userId] then
			cameraStates[userId] = nil
		end

		-- update ui to show camera is no longer locked on a planet
		if Player:FindFirstChild("PlayerData") and Player.PlayerData:FindFirstChild("LockedOn") then
			Player.PlayerData.LockedOn.Value = ""
		end

		-- switch to scriptable mode for full manual camera control during tween
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CameraSubject = nil

		-- wait one renderstep to let camera settle before capturing start position
		local settleConn
		settleConn = RunService.RenderStepped:Connect(function()
			settleConn:Disconnect()

			-- capture settled camera position as tween start point
			local startCFrame = Camera.CFrame

			local tweenDuration = 3
			local elapsedTime = 0

			-- target position is directly above sun
			local sunHeight = 2000
			local topDownPos = SunPart.Position + Vector3.new(0, sunHeight, 0)

			local tweenConn
			tweenConn = RunService.RenderStepped:Connect(function()
				if SunPart and SunPart.Parent then
					elapsedTime = elapsedTime + RunService.RenderStepped:Wait()
					-- alpha goes from 0 to 1 over tweenduration
					local alpha = math.min(elapsedTime / tweenDuration, 1)

					-- quintic easing provides smooth acceleration/deceleration curve
					local easedAlpha = alpha < 0.5 
						and 16 * alpha * alpha * alpha * alpha * alpha
						or 1 - math.pow(-2 * alpha + 2, 5) / 2

					-- lerp camera position smoothly from current to topdown
					local newPos = startCFrame.Position:Lerp(topDownPos, easedAlpha)
					Camera.CFrame = CFrame.new(newPos, SunPart.Position)

					-- when tween finishes, switch to orbit mode
					if alpha >= 1 then
						tweenConn:Disconnect()

						-- measure distance to sun for orbit radius
						local lockedDistance = (Camera.CFrame.Position - SunPart.Position).Magnitude

						-- initialize orbit state with azimuth/elevation angles and zoom bounds
						cameraStates[userId] = {
							subject = SunPart,
							distance = lockedDistance,
							minDistance = lockedDistance * 0.5,
							maxDistance = lockedDistance * 3,
							azimuth = 0,  -- horizontal rotation angle
							elevation = math.pi / 2,  -- vertical angle, pi/2 is looking down from top
						}

						-- renderstep loop updates camera position based on stored angles and distance
						local orbitConn
						orbitConn = RunService.RenderStepped:Connect(function()
							if SunPart and SunPart.Parent and cameraStates[userId] then
								local state = cameraStates[userId]

								-- convert euler angles to 3d position offset from subject
								local relativePos = CFrame.fromEulerAnglesYXZ(state.elevation, state.azimuth, 0) * Vector3.new(0, 0, -state.distance)
								local newCameraPos = state.subject.Position + relativePos

								-- apply calculated position looking at subject
								Camera.CFrame = CFrame.new(newCameraPos, state.subject.Position)
							else
								if orbitConn then
									orbitConn:Disconnect()
								end
								-- cleanup if sun deleted
								Functions.UnlockCamera(Player)
							end
						end)

						cameraConnections[userId] = orbitConn
					end
				else
					tweenConn:Disconnect()
				end
			end)
		end)
	end,

	UnlockCamera = function(Player)
		local userId = Player.UserId

		-- stop orbit renderstep loop
		if cameraConnections[userId] then
			cameraConnections[userId]:Disconnect()
			cameraConnections[userId] = nil
		end

		-- remove stored camera angles and distance data
		if cameraStates[userId] then
			cameraStates[userId] = nil
		end

		-- clear ui locked state indicator
		if Player:FindFirstChild("PlayerData") and Player.PlayerData:FindFirstChild("LockedOn") then
			Player.PlayerData.LockedOn.Value = ""
		end
	end,

	LockCamera = function(Player, Camera, Planetstr)
		-- resolve planet reference from either instance or string name
		local Planet
		if typeof(Planetstr) == "Instance" then
			Planet = Planetstr
		elseif typeof(Planetstr) == "string" then
			Planet = workspace:FindFirstChild("Planets"):FindFirstChild(Planetstr) 
				or workspace:FindFirstChild("TestingPlanets"):FindFirstChild(Planetstr)
		end

		if not Planet or not Planet:FindFirstChild("Ghost") then
			return
		end

		-- ghost is invisible orbit center part
		local Ghost = Planet:FindFirstChild("Ghost")
		if not Ghost or not Ghost:IsA("BasePart") then
			return
		end

		local userId = Player.UserId

		-- disconnect previous camera state before locking to new planet
		if cameraConnections[userId] then
			cameraConnections[userId]:Disconnect()
			cameraConnections[userId] = nil
		end

		if cameraStates[userId] then
			cameraStates[userId] = nil
		end

		if Player:FindFirstChild("PlayerData") and Player.PlayerData:FindFirstChild("LockedOn") then
			Player.PlayerData.LockedOn.Value = ""
		end

		-- update ui to show which planet is currently locked
		Player.PlayerData.LockedOn.Value = Planet.Name

		-- retrieve planet size from data table to scale camera distance
		local Radius = PlanetData[tostring(Planetstr)].Size.X / 2

		-- offset scales with planet radius so camera distance matches planet size
		local CAMERA_OFFSET = math.max(10, Radius * 0.5)
		local surfaceDistance = Radius + CAMERA_OFFSET

		-- switch to scriptable for manual camera control during tween
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CameraSubject = nil

		-- record current camera position before starting tween animation
		local startCFrame = Camera.CFrame

		local tweenDuration = 3
		local elapsedTime = 0
		local tweenFinished = false

		local tweenConn
		tweenConn = RunService.RenderStepped:Connect(function()
			if Planet and Planet.Parent and Ghost and Ghost.Parent then
				elapsedTime = elapsedTime + RunService.RenderStepped:Wait()

				-- alpha represents tween progress from 0 to 1
				local alpha = math.min(elapsedTime / tweenDuration, 1)

				-- only update camera position during tween phase
				if not tweenFinished then
					-- calculate direction from camera toward planet surface point
					local directionVector = Camera.CFrame.Position - Ghost.Position
					local distance = directionVector.Magnitude

					-- handle edge case where camera is extremely close to subject
					local currentOffsetDirection
					if distance < 1 then
						currentOffsetDirection = Vector3.new(0, 0, -1)
					else
						currentOffsetDirection = directionVector.Unit
					end

					-- target adjusts every frame to follow orbiting planet
					local targetPosition = Ghost.Position + currentOffsetDirection * surfaceDistance

					-- quintic easing for smooth motion curve
					local easedAlpha = alpha < 0.5 
						and 16 * alpha * alpha * alpha * alpha * alpha
						or 1 - math.pow(-2 * alpha + 2, 5) / 2

					-- interpolate from start position toward target
					local newCameraPos = startCFrame.Position:Lerp(targetPosition, easedAlpha)
					Camera.CFrame = CFrame.new(newCameraPos, Ghost.Position)
				end

				-- after tween completes, switch to orbit control mode
				if alpha >= 1 and not tweenFinished then
					tweenFinished = true
					tweenConn:Disconnect()

					-- calculate azimuth and elevation angles from final camera position
					local relativePos = Camera.CFrame.Position - Ghost.Position
					local distance = relativePos.Magnitude

					local azimuth = 0
					local elevation = math.pi / 2

					-- derive angles from position vectors for accurate starting point
					if distance > 0.1 then
						azimuth = math.atan2(relativePos.X, relativePos.Z)
						elevation = math.asin(math.clamp(relativePos.Y / distance, -1, 1))
					end

					-- store state for orbit loop, zoom limits scale with planet size
					cameraStates[userId] = {
						subject = Ghost,
						distance = distance,
						minDistance = Radius + (Radius * 0.2),
						maxDistance = Radius + (Radius * 4),
						azimuth = azimuth,
						elevation = elevation,
					}

					-- renderstep loop maintains camera orbit based on stored angles/distance
					local orbitConn
					orbitConn = RunService.RenderStepped:Connect(function()
						if Planet and Planet.Parent and Ghost and Ghost.Parent and cameraStates[userId] then
							local state = cameraStates[userId]

							-- spherical coords: convert angles + distance into world position
							local relativePos = CFrame.fromEulerAnglesYXZ(state.elevation, state.azimuth, 0) * Vector3.new(0, 0, -state.distance)
							local newCameraPos = state.subject.Position + relativePos

							-- update camera while looking at planet center
							Camera.CFrame = CFrame.new(newCameraPos, state.subject.Position)
						else
							if orbitConn then
								orbitConn:Disconnect()
							end
							-- cleanup if planet removed
							Functions.UnlockCamera(Player)
						end
					end)

					cameraConnections[userId] = orbitConn
				end
			else
				-- planet no longer exists, stop tween
				if tweenConn then
					tweenConn:Disconnect()
				end
				Functions.UnlockCamera(Player)
			end
		end)
	end,
}

-- listen for mouse input to rotate and zoom camera during orbit
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local camera = workspace.CurrentCamera
	local player = game.Players.LocalPlayer
	if not player then return end

	local userId = player.UserId
	if not cameraStates[userId] then return end

	local state = cameraStates[userId]

	-- right click drag rotates camera around subject
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			-- calculate mouse movement delta
			local mouseDelta = input.Position - (state.lastMousePos or input.Position)

			-- adjust azimuth and elevation based on mouse movement sensitivity
			state.azimuth = state.azimuth - (mouseDelta.X * 0.005)  -- x movement changes horizontal angle
			state.elevation = math.clamp(state.elevation + (mouseDelta.Y * 0.005), -math.pi / 2 + 0.1, math.pi / 2 - 0.1)  -- y movement changes vertical angle, clamped to prevent flipping
		end
		state.lastMousePos = input.Position
	end

	-- scroll wheel zooms in and out while maintaining orbit angles
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local scrollDelta = input.Position.Z
		local zoomSensitivity = 50

		-- adjust distance inversely to scroll direction
		state.distance = state.distance - (scrollDelta * zoomSensitivity)

		-- enforce min/max zoom bounds
		state.distance = math.max(state.minDistance, math.min(state.distance, state.maxDistance))
	end
end)

-- cleanup camera state when player leaves game to prevent memory leaks
game.Players.PlayerRemoving:Connect(function(Player)
	Functions.UnlockCamera(Player)
end)

return Functions
