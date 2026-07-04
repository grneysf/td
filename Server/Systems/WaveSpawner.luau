--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveDefinitions = require(script.WaveDefinitions)
local PathSelector    = require(script.PathSelector)

type EnemyType = WaveDefinitions.EnemyType

export type SpawnRequest = {
	enemyType: EnemyType,
	pathId:    number,
}

const DEFAULT_SPAWN_DELAY = 0.05
const DEFAULT_COOLDOWN    = 10

type WaveState = "WaitingClear" | "Spawning" | "WaitingWaveClear" | "Cooldown"

type WaveSpawnerType = {
	_world: any,
	_wave: number,
	_state: WaveState,
	_started: boolean,
	_spawnList: { SpawnRequest },
	_spawnIndex: number,
	_timer: number,
	_spawnDelay: number,
	_cooldown: number,
	_cooldownTotal: number,
	_lastPrintedSecond: number,
	_outSpawns: { SpawnRequest },
	_pathSelector: PathSelector.PathSelectorType,
	_buildWave: (WaveSpawnerType, WaveDefinitions.WaveDef) -> (),
	drain: (WaveSpawnerType) -> { SpawnRequest },
	start: (WaveSpawnerType) -> boolean?,
	isStarted: (WaveSpawnerType) -> boolean,
	update: (WaveSpawnerType, number) -> (),
	skipCooldown: (WaveSpawnerType) -> (),
}

local WaveSpawner = {}
WaveSpawner.__index = WaveSpawner

function WaveSpawner.new(world: any): WaveSpawnerType
	local self = setmetatable({}, WaveSpawner) :: WaveSpawnerType
	self._world       = world
	self._wave        = 0
	self._state       = "WaitingClear"
	self._started     = false
	self._spawnList   = {} :: { SpawnRequest }
	self._spawnIndex  = 0
	self._timer       = 0
	self._spawnDelay  = DEFAULT_SPAWN_DELAY
	self._cooldown       = 0
	self._cooldownTotal  = 0
	self._lastPrintedSecond = -1
	self._outSpawns    = table.create(8) :: { SpawnRequest }
	self._pathSelector = PathSelector.new()

	local skipRemote = ensureSkipRemote()
	skipRemote.OnServerEvent:Connect(function(_plr: Player)
		self:skipCooldown()
	end)

	return self
end

function WaveSpawner._buildWave(self: WaveSpawnerType, waveDef: WaveDefinitions.WaveDef)
	local selector = self._pathSelector
	selector:refresh()
	local pathCount = selector:count()

	local normalized = {} :: { { enemyType: EnemyType, count: number, pathId: number?, onEach: boolean? } }
	for _, group in waveDef.spawns do
		for _, entry in ipairs(WaveDefinitions.normalizeGroup(group)) do
			normalized[#normalized + 1] = {
				enemyType = entry.enemyType,
				count     = entry.count,
				pathId    = group.pathId,
				onEach   = group.onEach,
			}
		end
	end

	local total = 0
	for _, group in normalized do
		if group.onEach then
			total += group.count * pathCount
		else
			total += group.count
		end
	end

	local list = table.create(total) :: { SpawnRequest }
	local i    = 0

	for _, group in normalized do
		if group.onEach then
			for _ = 1, group.count do
				for _, pathId in selector:ids() do
					i += 1
					list[i] = { enemyType = group.enemyType, pathId = pathId }
				end
			end
		else
			local pathId = group.pathId or selector:pick()
			for _ = 1, group.count do
				i += 1
				list[i] = { enemyType = group.enemyType, pathId = pathId }
			end
		end
	end

	self._spawnList  = list
	self._spawnIndex = 0
	self._spawnDelay = waveDef.spawnDelay or DEFAULT_SPAWN_DELAY
	self._timer      = 0
end

function WaveSpawner.drain(self: WaveSpawnerType): { SpawnRequest }
	local out = self._outSpawns
	if #out == 0 then return out end
	self._outSpawns = table.create(#out) :: { SpawnRequest }
	return out
end

function WaveSpawner.start(self: WaveSpawnerType)
	if self._started then return false end
	self._started = true
	return true
end

function WaveSpawner.isStarted(self: WaveSpawnerType)
	return self._started
end

function WaveSpawner.skipCooldown(self: WaveSpawnerType)
	if self._state ~= "Cooldown" then return end
	self._cooldown = 0
end

function WaveSpawner.update(self: WaveSpawnerType, dt: number)
	local state = self._state

	if state == "WaitingClear" then
		if not self._started then return end
		if self._world:aliveCount() ~= 0 then return end

		self._wave += 1
		local waveDef = WaveDefinitions.Waves[self._wave]
		if not waveDef then return end

		self:_buildWave(waveDef)
		self._state = "Spawning"
		return
	end

	if state == "Spawning" then
		self._timer += dt
		while self._timer >= self._spawnDelay do

			self._timer -= self._spawnDelay
			self._spawnIndex += 1

			local req = self._spawnList[self._spawnIndex]
			if req then
				self._outSpawns[#self._outSpawns + 1] = req
			else
				self._state = "WaitingWaveClear"
				break
			end
		end
		return
	end

	if state == "WaitingWaveClear" then
		if self._world:aliveCount() ~= 0 then return end

		local waveDef = WaveDefinitions.Waves[self._wave]
		local cooldown = waveDef and (waveDef.cooldown or DEFAULT_COOLDOWN) or DEFAULT_COOLDOWN

		self._cooldown      = cooldown
		self._cooldownTotal = cooldown
		self._lastPrintedSecond = -1
		self._state = "Cooldown"

		print(string.format("wave %d finished.  cd: %d s.", self._wave, math.ceil(cooldown)))
		return
	end

	if state == "Cooldown" then
		self._cooldown -= dt

		local secondsLeft = math.max(0, math.ceil(self._cooldown))
		if secondsLeft ~= self._lastPrintedSecond then
			self._lastPrintedSecond = secondsLeft
			print(string.format("next wave in %d", secondsLeft))
		end

		if self._cooldown <= 0 then
			self._state = "WaitingClear"
		end
	end
end

return WaveSpawner
