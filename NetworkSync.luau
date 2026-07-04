--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Buffers   = require(ReplicatedStorage.Shared.Net.Buffers)
local Net       = require(ReplicatedStorage.Shared.Net.Net)
local ECS       = require(ReplicatedStorage.Shared.ECS.World)

export type SpawnEntry = Buffers.SpawnEntry

local NetworkSync   = {}
NetworkSync.__index = NetworkSync

function NetworkSync.new(net: Net.ServerNet, world: ECS.World)
	return setmetatable({
		_net   = net,
		_world = world,
		_spawnQueue = table.create(16) :: { SpawnEntry },
		_deathQueue = table.create(8)  :: { { id: number } },
		_stateScratch  = table.create(Constants.MAX_STATE_BATCH)  :: { ECS.StateEntry  },
		_speedScratch  = table.create(Constants.MAX_SPEED_BATCH)  :: { ECS.SpeedEntry  },
		_damageScratch = table.create(Constants.MAX_DAMAGE_BATCH) :: { ECS.DamageEntry },
	}, NetworkSync)
end

function NetworkSync:queueSpawn(entry: SpawnEntry)
	self._spawnQueue[#self._spawnQueue + 1] = entry
end

function NetworkSync:queueDeath(id: number)
	self._deathQueue[#self._deathQueue + 1] = { id = id }
end

local function flushInChunks<T>(queue: { T }, maxChunk: number, fire: (chunk: { T }) -> ())
	local total = #queue
	if total == 0 then return end
	local i = 1
	while i <= total do
		local size  = math.min(maxChunk, total - i + 1)
		local chunk = table.create(size)
		for j = 1, size do chunk[j] = queue[i]; i += 1 end
		fire(chunk)
	end
	table.clear(queue)
end

function NetworkSync:flushReliable(now: number)
	flushInChunks(self._spawnQueue, Constants.MAX_SPAWN_BATCH, function(chunk)
		self._net:fireSpawnBatch({ entries = chunk })
	end)

	self._world:drainSpeedDirty(self._speedScratch, now)
	flushInChunks(self._speedScratch, Constants.MAX_SPEED_BATCH, function(chunk)
		self._net:fireSpeedBatch({ entries = chunk })
	end)

	self._world:drainHpDirty(self._damageScratch)
	flushInChunks(self._damageScratch, Constants.MAX_DAMAGE_BATCH, function(chunk)
		self._net:fireDamageBatch({ entries = chunk })
	end)

	flushInChunks(self._deathQueue, Constants.MAX_DEATH_BATCH, function(chunk)
		self._net:fireDeathBatch({ entries = chunk })
	end)
end

function NetworkSync:flushStateDelta(now: number)
	self._world:drainDirty(self._stateScratch, now)

	local scratch = self._stateScratch
	local total   = #scratch
	if total == 0 then return end

	local i = 1
	while i <= total do
		local size  = math.min(Constants.MAX_STATE_BATCH, total - i + 1)
		local chunk = table.create(size)
		for j = 1, size do chunk[j] = scratch[i]; i += 1 end
		self._net:fireStateDelta({ entries = chunk })
	end
end

return NetworkSync