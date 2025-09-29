--// Services we need
local Players = game:GetService("Players")
local DataStore = game:GetService("DataStoreService")

-- Module for formatting numbers into compact forms (like 1K, 1M etc.)
local Formating = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FormatNumberAlt"))

-- Ordered DataStores for each leaderboard (keeps top scores sorted automatically)
local CookiesLB = DataStore:GetOrderedDataStore("CookiesLeaderboards_123")
local TimeLB = DataStore:GetOrderedDataStore("TimeLeaderboards_123")
local RebirthsLB = DataStore:GetOrderedDataStore("RebirthsLeaderboards_123")
local LevelLB = DataStore:GetOrderedDataStore('Data_Store')

-- Folder in Workspace where leaderboard GUIs live
local Leaderboards = game:GetService("Workspace"):WaitForChild("World1"):WaitForChild("Leaderboards")

-- Grabbing each individual leaderboard display
local CookiesLeader = Leaderboards:WaitForChild("Cookies")
local TimeLeader = Leaderboards:WaitForChild("PlayTime")
local RebirthsLeader = Leaderboards:WaitForChild("Rebirths")
local LevelLeader = Leaderboards:WaitForChild('Levels')

-- How often the leaderboard refreshes (in seconds)
local ResetTime = 60 * 2.5


--// Function that handles updating all leaderboard displays
local function updateLeaderboards()
	-- Using pcall to catch errors so script won’t fully break if something fails
	local success, errorMessage = pcall(function()

		-- Grab the top 25 entries for each leaderboard
		local CookiesData = CookiesLB:GetSortedAsync(false, 25)
		local TimeData = TimeLB:GetSortedAsync(false, 25)
		local RebirthsData = RebirthsLB:GetSortedAsync(false, 25)
		local LevelData = LevelLB:GetSortedAsync(false,25)

		-- CurrentPage returns an array of data entries (key = userId, value = stat)
		local CookiesPage = CookiesData:GetCurrentPage()
		local TimePage = TimeData:GetCurrentPage()
		local RebirthsPage = RebirthsData:GetCurrentPage()
		local LevelPage = LevelData:GetCurrentPage()


		--// COOKIES LEADERBOARD
		for CookiesRank, CookiesDataVal in ipairs(CookiesPage) do
			local UserName = game.Players:GetNameFromUserIdAsync(tonumber(CookiesDataVal.key))
			local UserId = game.Players:GetUserIdFromNameAsync(UserName)
			local Value = CookiesDataVal.value
			local IsOnLeaderboard = false 

			-- Check if this player is already displayed (avoids duplicate entries)
			for _, v in pairs(CookiesLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
				if v:IsA("Frame") and v.PName.Text == UserName then
					break
				end
			end

			-- If player has a value and isn’t on the board, make a new entry
			if Value and IsOnLeaderboard == false then
				local NewClone = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("GUI"):WaitForChild("CookiesSample"):Clone()

				-- Fill in their info
				NewClone.PName.Text = UserName
				NewClone.Image.Image = game.Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				NewClone.Value.Text = Formating.FormatCompact(Value)
				NewClone.Image.Place.Text = "#" .. CookiesRank

				-- Parent into the leaderboard GUI
				NewClone.Parent = CookiesLeader.Interface.Interface.Interface.Frame.Body.Players
				NewClone.Visible = true

				-- Add special colors for top 3 players
				if CookiesRank == 1 then 
					NewClone.PName.TextColor3 = Color3.fromRGB(255, 255, 0) -- gold
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(255, 255, 0)
				elseif CookiesRank == 2 then
					NewClone.PName.TextColor3 = Color3.fromRGB(146, 204, 221) -- silver/blue
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(146, 204, 221)
				elseif CookiesRank == 3 then
					NewClone.PName.TextColor3 = Color3.fromRGB(188, 106, 47) -- bronze
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(188, 106, 47)
				end 
			end
		end
--im going insane im underpaid and i have 3 children to feed pls pay me Elite34  ~war

		--// PLAYTIME LEADERBOARD
		for TimeRank, TimeDataVal in ipairs(TimePage) do
			local UserName = game.Players:GetNameFromUserIdAsync(tonumber(TimeDataVal.key))
			local UserId = game.Players:GetUserIdFromNameAsync(UserName)
			local Value = TimeDataVal.value
			local IsOnLeaderboard = false

			for _, v in pairs(TimeLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
				if v:IsA("Frame") and v.PName.Text == UserName then
					break
				end
			end

			if Value and IsOnLeaderboard == false then
				local NewClone = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("GUI"):WaitForChild("PlayTimeSample"):Clone()

				NewClone.PName.Text = UserName
				NewClone.Image.Image = game.Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

				-- If less than 1 hour, show minutes; otherwise show hours
				if (Value/60)/60 < 1 then
					NewClone.Value.Text = string.format("%.0f", (Value/60)) .. "m"
				else
					NewClone.Value.Text = string.format("%.0f", (Value/60)/60) .. "h"
				end

				NewClone.Image.Place.Text = "#" .. TimeRank
				NewClone.Parent = TimeLeader.Interface.Interface.Interface.Frame.Body.Players
				NewClone.Visible = true

				-- Color coding for top 3
				if TimeRank == 1 then 
					NewClone.PName.TextColor3 = Color3.fromRGB(255, 255, 0)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(255, 255, 0)
				elseif TimeRank == 2 then
					NewClone.PName.TextColor3 = Color3.fromRGB(146, 204, 221)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(146, 204, 221)
				elseif TimeRank == 3 then
					NewClone.PName.TextColor3 = Color3.fromRGB(188, 106, 47)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(188, 106, 47)
				end 
			end
		end


		--// REBIRTHS LEADERBOARD
		for RebirthRank, RebirthDataVal in ipairs(RebirthsPage) do
			local UserName = game.Players:GetNameFromUserIdAsync(tonumber(RebirthDataVal.key))
			local UserId = game.Players:GetUserIdFromNameAsync(UserName)
			local Value = RebirthDataVal.value
			local IsOnLeaderboard = false

			for _, v in pairs(RebirthsLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
				if v:IsA("Frame") and v.PName.Text == UserName then
					break
				end
			end

			if Value and IsOnLeaderboard == false then
				local NewClone = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("GUI"):WaitForChild("RebirthsSample"):Clone()

				NewClone.PName.Text = UserName
				NewClone.Image.Image = game.Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				NewClone.Value.Text = Formating.FormatCompact(Value)
				NewClone.Image.Place.Text = "#" .. RebirthRank

				NewClone.Parent = RebirthsLeader.Interface.Interface.Interface.Frame.Body.Players
				NewClone.Visible = true

				-- Top 3 colors again
				if RebirthRank == 1 then 
					NewClone.PName.TextColor3 = Color3.fromRGB(255, 255, 0)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(255, 255, 0)
				elseif RebirthRank == 2 then
					NewClone.PName.TextColor3 = Color3.fromRGB(146, 204, 221)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(146, 204, 221)
				elseif RebirthRank == 3 then
					NewClone.PName.TextColor3 = Color3.fromRGB(188, 106, 47)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(188, 106, 47)
				end 
			end
		end


		--// LEVELS LEADERBOARD
		for LevelRank, LevelDataVal in ipairs(LevelPage) do
			local UserName = game.Players:GetNameFromUserIdAsync(tonumber(LevelDataVal.key))
			local UserId = game.Players:GetUserIdFromNameAsync(UserName)
			local Value = LevelDataVal.value
			local IsOnLeaderboard = false

			for _, v in pairs(LevelLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
				if v:IsA("Frame") and v.PName.Text == UserName then
					break
				end
			end

			if Value and IsOnLeaderboard == false then
				local NewClone = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("GUI"):WaitForChild("LevelSample"):Clone()

				NewClone.PName.Text = UserName
				NewClone.Image.Image = game.Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				NewClone.Value.Text = Formating.FormatCompact(Value)
				NewClone.Image.Place.Text = "#" .. LevelRank

				NewClone.Parent = LevelLeader.Interface.Interface.Interface.Frame.Body.Players
				NewClone.Visible = true

				-- Top 3 highlight
				if LevelRank == 1 then 
					NewClone.PName.TextColor3 = Color3.fromRGB(255, 255, 0)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(255, 255, 0)
				elseif LevelRank == 2 then
					NewClone.PName.TextColor3 = Color3.fromRGB(146, 204, 221)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(146, 204, 221)
				elseif LevelRank == 3 then
					NewClone.PName.TextColor3 = Color3.fromRGB(188, 106, 47)
					NewClone.Image.Place.TextColor3 = Color3.fromRGB(188, 106, 47)
				end 
			end
		end

	end)

	if not success then
		Warn("Something Went Wrong")
	else
		--print("Leaderboards updated successfully")
	end
end


--// Loop that refreshes leaderboards every ResetTime
while task.wait(ResetTime) do

	-- Save each player’s current stats into the datastore
	for _, player in pairs(game.Players:GetPlayers()) do
		local CookiesValue = player:WaitForChild("leaderstats"):WaitForChild("Cookies")
		local TimeValue = player:WaitForChild("MainData"):WaitForChild("TimeSpent")
		local RebirthsValue = player:WaitForChild("leaderstats"):WaitForChild("Rebirths")
		local LevelValue = player:WaitForChild('STATS'):WaitForChild('Level')

		CookiesLB:SetAsync(player.UserId, CookiesValue.Value)
		TimeLB:SetAsync(player.UserId, TimeValue.Value)
		RebirthsLB:SetAsync(player.UserId, RebirthsValue.Value)
		LevelLB:SetAsync(player.UserId, LevelValue.Value)
	end

	-- Clear out old entries from the GUI before redrawing
	for _, frame in pairs(CookiesLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
		if frame:IsA("Frame") then frame:Destroy() end
	end
	for _, frame in pairs(TimeLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
		if frame:IsA("Frame") then frame:Destroy() end
	end
	for _, frame in pairs(RebirthsLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
		if frame:IsA("Frame") then frame:Destroy() end
	end
	for _, frame in pairs(LevelLeader.Interface.Interface.Interface.Frame.Body.Players:GetChildren()) do
		if frame:IsA("Frame") then frame:Destroy() end
	end

	-- Finally, rebuild the leaderboards with updated data
	updateLeaderboards()
end
