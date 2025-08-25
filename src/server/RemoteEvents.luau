--[[
	RemoteEvents.luau
	RemoteEvents setup and management
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local RemoteEvents = {}

-- Create RemoteEvents folder
local remoteEventsFolder = Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

-- Create all RemoteEvents
local events = {}

for _, eventName in pairs(Constants.REMOTE_EVENT_NAMES) do
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = eventName
	remoteEvent.Parent = remoteEventsFolder
	events[eventName] = remoteEvent
end

-- Function to get a RemoteEvent by name
function RemoteEvents.getEvent(eventName: string): RemoteEvent?
	return events[eventName]
end

-- Function to get all events
function RemoteEvents.getAllEvents(): {[string]: RemoteEvent}
	return events
end

return RemoteEvents
