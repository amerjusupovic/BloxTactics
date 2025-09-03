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
	print("Initializing Lobby Manager...")
	LobbyManager.init()
	
	-- Initialize Board Detection system after lobby system is ready
	print("Waiting for lobby system to initialize...")
	wait(1) -- Give lobby system time to initialize
	local BoardDetection = require(script.Parent.Server.BoardDetection)
	BoardDetection.init()
	
	print("Game systems initialized!")
end

-- Initialize the game
initializeGame()