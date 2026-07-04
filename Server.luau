--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Promise = require(ReplicatedStorage.Packages.Janitor.Promise)
local Constants = require(ReplicatedStorage.Shared.Constants)
local ECS = require(ReplicatedStorage.Shared.ECS.World)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local EnemyRegistry = require(ReplicatedStorage.Shared.EnemyRegistry)

type EnemyType = EnemyRegistry.EnemyType
type Entity = ECS.Entity

const SPEED_BUFF_AMOUNT = 5
const SPEED_BUFF_DURATION = 10

local PathSync = require(script.Systems.PathSync)
local WaveSpawner = require(script.Systems.WaveSpawner)
local PathMovement = require(script.Systems.PathMovement)
local DamageSystem = require(script.Systems.DamageSystem)
local NetworkSync = require(script.Systems.NetworkSync)

local playerActions = ReplicatedStorage:FindFirstChild("Remotes")
if not playerActions then
	warn("Remotes folder not found")
	return
end
playerActions = playerActions:FindFirstChild("PlayerActions")
if not playerActions then
	warn("PlayerActions folder not found")
	return
end

local startWaveEvent = playerActions:FindFirstChild("StartWave")
if not startWaveEvent or not startWaveEvent:IsA("RemoteEvent") then
	warn("StartWave re not found")
	return
end

local speedBuffEvent = playerActions:FindFirstChild("SpeedBuff")
if not speedBuffEvent or not speedBuffEvent:IsA("RemoteEvent") then
	warn("SpeedBuff re not found")
	return
end

local janitor = Janitor.new()

PathSync.init()

local world = ECS.World.new()
local waveSpawner = WaveSpawner.new(world)
local network = NetworkSync.new(Net.server(), world)
local damageSystem = DamageSystem.new(world)

local function killEnemy(id: number)
	local enemy = world:get(id)
	if not enemy or not enemy.alive then return end
	network:queueDeath(id)
	world:kill(id)
end

local simAccumulator = 0
local netAccumulator = 0

-- temp

janitor:Add(startWaveEvent.OnServerEvent:Connect(function(player: Player)
	if waveSpawner:isStarted() then return end
	if waveSpawner:start() then
		print(player.Name .. " started the wave")
	end
end), "Disconnect")

janitor:Add(speedBuffEvent.OnServerEvent:Connect(function()
	local buffed: { [Entity]: EnemyType } = {}

	world:forEachAlive(function(enemy)
		if enemy.type == "template" then
			world:setSpeed(enemy.id, enemy.speed + SPEED_BUFF_AMOUNT)
			buffed[enemy.id] = "template"
		elseif enemy.type == "ind6" then
			world:setSpeed(enemy.id, enemy.speed - SPEED_BUFF_AMOUNT)
			buffed[enemy.id] = "ind6"
		end
	end)

	janitor:AddPromise(Promise.delay(SPEED_BUFF_DURATION):andThen(function()
		for id, enemyType in buffed do
			local enemy = world:get(id)
			if enemy and enemy.alive then
				if enemyType == "template" then
					world:setSpeed(id, enemy.speed - SPEED_BUFF_AMOUNT)
				else
					world:setSpeed(id, enemy.speed + SPEED_BUFF_AMOUNT)
				end
			end
		end
	end))
end), "Disconnect")

-- temp

janitor:Add(RunService.Heartbeat:Connect(function(dt: number)
	simAccumulator += dt
	netAccumulator += dt

	while simAccumulator >= Constants.SIM_DT do
		simAccumulator -= Constants.SIM_DT
		local now = os.clock()

		waveSpawner:update(Constants.SIM_DT)
		for _, req in waveSpawner:drain() do
			local id = world:spawn(req.enemyType, req.pathId, now)
			local record = world:get(id)
			if not record then continue end

			local def = EnemyRegistry.Definitions[req.enemyType]
			network:queueSpawn({
				id = id,
				pathId = req.pathId,
				typeId = def and def.typeId or 0,
				speed = record.speed,
				maxHp = record.maxHp,
			})
		end

		for _, id in PathMovement.step(world, Constants.SIM_DT, now) do
			killEnemy(id)
		end

		for _, id in damageSystem:step(Constants.SIM_DT) do
			killEnemy(id)
		end
	end

	while netAccumulator >= Constants.NET_DT do
		netAccumulator -= Constants.NET_DT
		local now = os.clock()
		network:flushReliable(now)
		network:flushStateDelta(now)
	end
end), "Disconnect")

print(string.format("%d Hz sim / %d Hz net", Constants.SIM_HZ, Constants.NET_HZ))