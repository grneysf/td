--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Promise = require(ReplicatedStorage.Packages.Janitor.Promise)
local Paths = require(ReplicatedStorage.Shared.Path.Paths)
local ECS = require(ReplicatedStorage.Shared.ECS.World)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local CatmullRom = require(ReplicatedStorage.Shared.Path.CatmullRom)
local StateReceiver = require(script.Systems.StateReceiverSystem)
local Interpolation = require(script.Systems.InterpolationSystem)
local AnimationSystem = require(script.Systems.AnimationSystem)
local VFXSystem = require(script.Systems.VFXSystem)

local janitor = Janitor.new()

local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EnemySync")
local pathFunc = remotes:WaitForChild("PathSync")
if not pathFunc:IsA("RemoteFunction") then
	warn("PathSync rf not found")
	return
end

local net = Net.client()
local world = ECS.ClientWorld.new()

Promise.promisify(pathFunc.InvokeServer)(pathFunc):andThen(function(waypoints: Paths.WaypointMap)
	for pathId, points in waypoints do
		Paths.register(CatmullRom.create(pathId, points))
	end
	print(string.format("Registered %d paths from server", #Paths.getAll()))

	local net = Net.client() 
	local world = ECS.ClientWorld.new()

	janitor:Add(StateReceiver.new(world, net), "destroy")
	janitor:Add(RunService.RenderStepped:Connect(function(dt: number)
		Interpolation.step(world, os.clock())
		AnimationSystem.step(world, dt)
		VFXSystem.step(world)
	end), "Disconnect")

	print("Visual layer online")
end):catch(function(err)
	warn("Failed to retrieve paths from server:", err)
end)
