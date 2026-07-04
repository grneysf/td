--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Buffers = require(ReplicatedStorage.Shared.Net.Buffers)

export type SpawnBatch  = Buffers.SpawnBatch
export type StateDelta  = Buffers.StateDelta
export type SpeedBatch  = Buffers.SpeedBatch
export type DamageBatch = Buffers.DamageBatch
export type DeathBatch  = Buffers.DeathBatch

export type ServerNet = {
	fireSpawnBatch:  (self: ServerNet,  batch: SpawnBatch)  -> (),
	fireStateDelta:  (self: ServerNet,  batch: StateDelta)  -> (),
	fireSpeedBatch:  (self: ServerNet,  batch: SpeedBatch)  -> (),
	fireDamageBatch: (self: ServerNet,  batch: DamageBatch) -> (),
	fireDeathBatch:  (self: ServerNet,  batch: DeathBatch)  -> (),
}

export type ClientNet = {
	onSpawnBatch:  (self: ClientNet, handler: (batch: SpawnBatch)  -> ()) -> () -> (),
	onStateDelta:  (self: ClientNet, handler: (batch: StateDelta)  -> ()) -> () -> (),
	onSpeedBatch:  (self: ClientNet, handler: (batch: SpeedBatch)  -> ()) -> () -> (),
	onDamageBatch: (self: ClientNet, handler: (batch: DamageBatch) -> ()) -> () -> (),
	onDeathBatch:  (self: ClientNet, handler: (batch: DeathBatch)  -> ()) -> () -> (),
}

const SPAWN_NAME  = "SpawnBatch"
const STATE_NAME  = "StateDelta"
const SPEED_NAME  = "SpeedBatch"
const DAMAGE_NAME = "DamageBatch"
const DEATH_NAME  = "DeathBatch"

local RELIABLE_NAMES   = { SPAWN_NAME, SPEED_NAME, DAMAGE_NAME, DEATH_NAME }
local UNRELIABLE_NAMES = { STATE_NAME }

local remotes: { [string]: Instance } = {}

local syncFolder: Folder = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("EnemySync")

if RunService:IsServer() then
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotesFolder.Name = "Remotes"

	local enemySyncFolder = remotesFolder:FindFirstChild("EnemySync") or Instance.new("Folder")
	enemySyncFolder.Name = "EnemySync"
	

	local ALL_NAMES = { SPAWN_NAME, STATE_NAME, SPEED_NAME, DAMAGE_NAME, DEATH_NAME }
	for _, name in ALL_NAMES do
		local existing = enemySyncFolder:FindFirstChild(name)
		if existing then existing:Destroy() end
	end

	for _, name in RELIABLE_NAMES do
		local re = Instance.new("RemoteEvent")
		re.Name   = name
		re.Parent = enemySyncFolder
		remotes[name] = re
	end

	for _, name in UNRELIABLE_NAMES do
		local re = Instance.new("UnreliableRemoteEvent")
		re.Name   = name
		re.Parent = enemySyncFolder
		remotes[name] = re
	end
	
	enemySyncFolder.Parent = remotesFolder
	remotesFolder.Parent   = ReplicatedStorage
else
	syncFolder = ReplicatedStorage
		:WaitForChild("Remotes")
		:WaitForChild("EnemySync") :: Folder

end

local CHUNK_SIZE = 50

local function fireAll<T>(name: string, pack: ({ T }) -> buffer, entries: { T })
	local n = #entries
	if n == 0 then return end
	local re = remotes[name] :: RemoteEvent
	if n <= CHUNK_SIZE then
		re:FireAllClients(pack(entries))
		return
	end
	for i = 1, n, CHUNK_SIZE do
		local tail  = math.min(i + CHUNK_SIZE - 1, n)
		local chunk = table.move(entries, i, tail, 1, table.create(tail - i + 1))
		re:FireAllClients(pack(chunk))
	end
end

local Net = {}

function Net.server(): ServerNet
	return {
		fireSpawnBatch = function(_, batch)
			fireAll(SPAWN_NAME,  Buffers.packSpawnBatch,  batch.entries)
		end,
		fireStateDelta = function(_, batch)
			fireAll(STATE_NAME,  Buffers.packStateDelta,  batch.entries)
		end,
		fireSpeedBatch = function(_, batch)
			fireAll(SPEED_NAME,  Buffers.packSpeedBatch,  batch.entries)
		end,
		fireDamageBatch = function(_, batch)
			fireAll(DAMAGE_NAME, Buffers.packDamageBatch, batch.entries)
		end,
		fireDeathBatch = function(_, batch)
			fireAll(DEATH_NAME,  Buffers.packDeathBatch,  batch.entries)
		end,
	}
end

local function getRemote(name: string): RemoteEvent
	if remotes[name] then return remotes[name] :: RemoteEvent end
	local re = syncFolder:WaitForChild(name)
	remotes[name] = re
	return re :: RemoteEvent
end


function Net.client(): ClientNet
	local function wrap<T>(name: string, unpack: (buffer) -> T, handler: (T) -> ()): () -> ()
		local re   = getRemote(name) 
		local conn = re.OnClientEvent:Connect(function(payload: buffer)
			handler(unpack(payload))
		end)
		return function() conn:Disconnect() end
	end

	return {
		onSpawnBatch  = function(_, h) return wrap(SPAWN_NAME,  Buffers.unpackSpawnBatch,  h) end,
		onStateDelta  = function(_, h) return wrap(STATE_NAME,  Buffers.unpackStateDelta,  h) end,
		onSpeedBatch  = function(_, h) return wrap(SPEED_NAME,  Buffers.unpackSpeedBatch,  h) end,
		onDamageBatch = function(_, h) return wrap(DAMAGE_NAME, Buffers.unpackDamageBatch, h) end,
		onDeathBatch  = function(_, h) return wrap(DEATH_NAME,  Buffers.unpackDeathBatch,  h) end,
	}
end

return Net