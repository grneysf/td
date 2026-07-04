--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathLoader = require(ReplicatedStorage.Shared.Path.PathLoader)
local Paths = require(ReplicatedStorage.Shared.Path.Paths)

local PathSync = {}

function PathSync.init(): Paths.WaypointMap
	local waypoints = PathLoader.load()

	local remotesRoot: Folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesRoot then
		remotesRoot = Instance.new("Folder")
		remotesRoot.Name = "Remotes"
		remotesRoot.Parent = ReplicatedStorage
	end
	local folder = remotesRoot:FindFirstChild("EnemySync")
	if not folder or not folder:IsA("Folder") then
		folder = Instance.new("Folder")
		folder.Name = "EnemySync"
		folder.Parent = remotesRoot
	end

	local pathFunc = folder:FindFirstChild("PathSync")
	local remoteFunc: RemoteFunction
	if pathFunc and pathFunc:IsA("RemoteFunction") then
		remoteFunc = pathFunc
	else
		remoteFunc = Instance.new("RemoteFunction")
		remoteFunc.Name = "PathSync"
		remoteFunc.Parent = folder
	end

	remoteFunc.OnServerInvoke = function(_player: Player)
		return waypoints
	end

	return waypoints
end

return PathSync