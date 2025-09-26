--[[
	WinsLeaderboard.luau
	Tracks and publishes top player wins to all physical leaderboard models named "WinsLeaderboard" under lobby baseplates.

	Implementation details:
	- Uses an OrderedDataStore "BloxTactics_WinsLeaderboard" to store total wins keyed by userId.
	- PlayerDataManager increments per-player wins; this module listens for explicit update requests via :RecordWin(userId, username).
	- Every UPDATE_INTERVAL seconds (default 90) the module pulls the top N (default 10) entries, resolves usernames (cached), and updates all leaderboard SurfaceGuis.
	- To avoid duplicate OrderedDataStore writes, wins are only updated when we detect local cached wins value differs from PlayerData.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local RemoteEvents = require(script.Parent.RemoteEvents)
local PlayerDataManager = require(script.Parent.PlayerData)

local WinsLeaderboard = {}

local ORDERED_DS = DataStoreService:GetOrderedDataStore("BloxTactics_WinsLeaderboard")
local UPDATE_INTERVAL = 90
local TOP_N = 10

-- Cache { userId -> {username = string, wins = number} }
local _winsCache: {[number]: {username: string, wins: number}} = {}
local _lastPull = 0

-- Simple throttle for ordered store updates (avoid hammering within a few seconds)
local WRITE_THROTTLE_SECONDS = 10
local _lastWriteTimes: {[number]: number} = {}

-- Update ordered datastore for a player if their cached wins increased
local function updateOrderedStore(userId: number, wins: number)
	local now = os.time()
	local last = _lastWriteTimes[userId] or 0
	if now - last < WRITE_THROTTLE_SECONDS then
		return
	end
	_lastWriteTimes[userId] = now
	spawn(function()
		local ok, err = pcall(function()
			-- Ensure integer, non-negative value for OrderedDataStore
			local safeWins = math.floor(math.max(0, wins))
			ORDERED_DS:SetAsync(tostring(userId), safeWins)
		end)
		if not ok then
			warn(string.format("[WinsLeaderboard] Failed to SetAsync for user %d: %s", userId, tostring(err)))
		end
	end)
end

-- Public API: record a win (called after PlayerDataManager increments wins)
function WinsLeaderboard.recordWin(userId: number)
	local data = PlayerDataManager.getPlayerData(userId)
	if not data then return end
	local wins = data.wins or 0
	local username = data.username or (Players:GetPlayerByUserId(userId) and Players:GetPlayerByUserId(userId).Name) or ("User" .. userId)
	local cached = _winsCache[userId]
	if not cached or cached.wins ~= wins then
		_winsCache[userId] = {username = username, wins = wins}
		updateOrderedStore(userId, wins)
	end
end

-- Pull top entries from ordered datastore
local function pullTopWins(): { {userId: number, username: string, wins: number} }
	local results = {}
	local ok, pages = pcall(function()
		-- NOTE: minValue/maxValue must be integers; use 0 .. 2147483647 (signed 32-bit max)
		return ORDERED_DS:GetSortedAsync(false, TOP_N, 0, 2147483647) -- false => descending
	end)
	if not ok then
		warn("[WinsLeaderboard] Failed to GetSortedAsync: " .. tostring(pages))
		return results
	end

	local page = pages:GetCurrentPage()
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		local wins = entry.value
		if userId and wins then
			local username = _winsCache[userId] and _winsCache[userId].username
			if not username then
				-- Try live player first
				local plr = Players:GetPlayerByUserId(userId)
				if plr then
					username = plr.Name
				else
					-- Try existing player data cache
					local pdata = PlayerDataManager.getPlayerData(userId)
					if pdata and pdata.username then
						username = pdata.username
					else
						-- Fallback to API lookup (works even if player not in server)
						local okName, resolved = pcall(function()
							return Players:GetNameFromUserIdAsync(userId)
						end)
						if okName and typeof(resolved) == "string" then
							username = resolved
						else
							username = "User" .. userId -- final fallback
						end
					end
				end
				-- Cache resolved username for future cycles
				_winsCache[userId] = {username = username, wins = wins}
			end
			results[#results+1] = {userId = userId, username = username, wins = wins}
		end
	end
	return results
end

local function updatePhysicalLeaderboards(topData)
	-- Find all models named WinsLeaderboard in Workspace
	for _, leaderboardModel in ipairs(workspace:GetDescendants()) do
		if leaderboardModel:IsA("Model") and leaderboardModel.Name == "WinsLeaderboard" then
			local scoreBlock = leaderboardModel:FindFirstChild("ScoreBlock")
			if scoreBlock and scoreBlock:IsA("BasePart") then
				local surfaceGui = scoreBlock:FindFirstChild("Leaderboard")
				if surfaceGui and surfaceGui:IsA("SurfaceGui") then
					local namesFolder = surfaceGui:FindFirstChild("Names")
					local scoresFolder = surfaceGui:FindFirstChild("Score")
					local photosFolder = surfaceGui:FindFirstChild("Photos")
					if namesFolder and scoresFolder and photosFolder then
						for i = 1, TOP_N do
							local entry = topData[i]
							local nameLabel = namesFolder:FindFirstChild("Name" .. i)
							local scoreLabel = scoresFolder:FindFirstChild("Score" .. i)
							local photoLabel = photosFolder:FindFirstChild("Photo" .. i)
							if nameLabel and nameLabel:IsA("TextLabel") then
								nameLabel.Text = entry and entry.username or "-"
							end
							if scoreLabel and scoreLabel:IsA("TextLabel") then
								if entry then
									scoreLabel.Text = string.format("Wins: %d", entry.wins)
								else
									scoreLabel.Text = "Wins: 0"
								end
							end
							if photoLabel and photoLabel:IsA("ImageLabel") then
								if entry then
									photoLabel.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.userId)
								else
									photoLabel.Image = "rbxassetid://0"
								end
							end
						end
					end
				end
			end
		end
	end
end

local function broadcast(topData)
	local event = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.LEADERBOARD_WINS_UPDATE)
	if not event then return end
	-- Broadcast raw data to all players (clients can optionally show UI later)
	local payload = {}
	for i, entry in ipairs(topData) do
		payload[i] = {userId = entry.userId, username = entry.username, wins = entry.wins}
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		event:FireClient(plr, payload)
	end
end

local function updateCycle()
	local topData = pullTopWins()
	updatePhysicalLeaderboards(topData)
	broadcast(topData)
end

function WinsLeaderboard.forceRefresh()
	updateCycle()
end

-- Periodic updater
spawn(function()
	while true do
		local now = os.time()
		if now - _lastPull >= UPDATE_INTERVAL then
			_lastPull = now
			local ok, err = pcall(updateCycle)
			if not ok then
				warn("[WinsLeaderboard] updateCycle failed: " .. tostring(err))
			end
		end
		wait(5) -- check every 5s whether interval passed
	end
end)

-- Hook into player added to seed username cache & ensure wins cached
Players.PlayerAdded:Connect(function(plr)
	local pdata = PlayerDataManager.getPlayerData(plr.UserId)
	if pdata then
		_winsCache[plr.UserId] = {username = plr.Name, wins = pdata.wins or 0}
		updateOrderedStore(plr.UserId, pdata.wins or 0)
	end
end)

return WinsLeaderboard
