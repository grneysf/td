--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ECS = require(ReplicatedStorage.Shared.ECS.World)
local Net = require(ReplicatedStorage.Shared.Net.Net)

local StateReceiver = {}
StateReceiver.__index = StateReceiver

function StateReceiver.new(world: ECS.ClientWorld, net: Net.ClientNet)
	local self = setmetatable({ _janitor = Janitor.new(), _world = world }, StateReceiver)
	local janitor = self._janitor

	local function track(disconnect: () -> ())
		janitor:Add({ Destroy = disconnect }, "Destroy")
	end

	track(net:onSpawnBatch(function(batch)
		print("got sb", #batch.entries)
		local now = os.clock()
		for _, e in batch.entries do
			world:upsertSpawn(e.id, e.pathId, e.speed, e.maxHp, e.typeId, now)
		end
	end))

	track(net:onStateDelta(function(batch)
		local now = os.clock()
		for _, e in batch.entries do
			world:applyCorrection(e.id, e.progress, now)
		end
	end))

	track(net:onSpeedBatch(function(batch)
		local now = os.clock()
		for _, e in batch.entries do
			world:applySpeedChange(e.id, e.newSpeed, e.progress, now)
		end
	end))

	track(net:onDamageBatch(function(batch)
		for _, e in batch.entries do
			world:applyDamage(e.id, e.hp)
		end
	end))

	track(net:onDeathBatch(function(batch)
		for _, e in batch.entries do
			world:remove(e.id)
		end
	end))

	return self
end

function StateReceiver:destroy(): ()
	self._janitor:Cleanup()
end

return StateReceiver