--[[
	MarketplaceHandler.luau
	Handles developer product purchases (arena skins, etc.) and grants ownership.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local PlayerDataManager = require(script.Parent.PlayerData)
local RemoteEvents = require(script.Parent.RemoteEvents)

local MarketplaceHandler = {}

-- Map productId -> handler function(player, receiptInfo)
-- For now only Volcanic Arena product.
local productHandlers: {[number]: (Player, any) -> boolean} = {}

-- Helper to safely get remote event
local function getEvent(name: string)
	return RemoteEvents.getEvent(name)
end

local function grantArenaOwnership(player: Player, arenaName: string)
	local data = PlayerDataManager.getPlayerData(player.UserId)
	if not data then return false end
	data.arenaOwnership = data.arenaOwnership or {}
	data.arenaOwnership[arenaName] = true
	-- Also store normalized variants (remove spaces) for robustness
	data.arenaOwnership[arenaName:gsub("%s+", "")] = true
	print("[MarketplaceHandler] Granted ownership of arena '" .. arenaName .. "' to " .. player.Name)
	-- Persist soon (not strictly immediate, but we attempt save)
	PlayerDataManager.savePlayerData(player.UserId)
	-- Send updated player data so client can refresh UI state
	local updatePlayerDataEvent = getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)
	if updatePlayerDataEvent then
		updatePlayerDataEvent:FireClient(player, data)
	end
	local notify = getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
	if notify then
		notify:FireClient(player, "Purchased arena: " .. arenaName .. "!", 3)
	end
	return true
end

-- Register product handlers
for arenaKey, productId in pairs(Constants.ARENA_PRODUCTS) do
	local displayName
	-- Accept keys like VolcanicArena or Volcanic_Frame etc.
	local base = arenaKey:gsub("[_]", "")
	if base:lower():find("volcanic") then
		-- Standardize to in-game template folder likely named "Volcanic Arena"
		displayName = "Volcanic Arena"
	else
		displayName = arenaKey
	end
	productHandlers[productId] = function(player, receipt)
		-- Grant all reasonable variants
		grantArenaOwnership(player, displayName)
		grantArenaOwnership(player, displayName:gsub("Arena", " Frame")) -- alternate naming
		return true
	end
end

-- ProcessReceipt callback
function MarketplaceHandler.init()
	local function process(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- Player left; return NotProcessedYet so Roblox retries later
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local handler = productHandlers[receiptInfo.ProductId]
		if handler then
			local ok = false
			local success, err = pcall(function()
				ok = handler(player, receiptInfo)
			end)
			if not success then
				warn("[MarketplaceHandler] Error granting product " .. tostring(receiptInfo.ProductId) .. ": " .. tostring(err))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if ok then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			else
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end
		-- Unknown product; grant by default to avoid charging without reward
		warn("[MarketplaceHandler] No handler for productId " .. tostring(receiptInfo.ProductId) .. "; granting by default")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	MarketplaceService.ProcessReceipt = process
end

return MarketplaceHandler
