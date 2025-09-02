--[[
	init.server.luau
	Main server initialization - Now uses LobbyManager for multiple game instances
]]

-- Load the LobbyManager module
local LobbyManager = require(script.Parent.Server.LobbyManager)
local RemoteEvents = require(script.Parent.Server.RemoteEvents)
local Players = game:GetService("Players")

print("BloxTactics Server initialized successfully!")

-- Initialize the lobby system
local function initializeGame()
	print("Initializing BloxTactics game systems...")
	
	-- Initialize RemoteEvents first (client needs these)
	print("Setting up RemoteEvents...")
	-- RemoteEvents are automatically created when the module is required
	
	-- Initialize the Lobby Manager (this handles everything else)
	LobbyManager.init()
	
	print("Game systems initialized!")
end

-- Initialize the game
initializeGame()