local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyRegistry = require(ReplicatedStorage.Shared.EnemyRegistry)

type EnemyType = EnemyRegistry.EnemyType

export type Entity = number

export type ClientEnemyRecord = {
	id: Entity,
	
	pathId: number,
	typeId: number,
	speed: number,
	renderProgress: number,
	hp: number,
	maxHp: number,
	syncProgress: number,
	syncTime: number,
	
	alive: boolean,
	
	model: Model?,
	
	type: EnemyType,
}

local ClientWorld = {}
ClientWorld.__index = ClientWorld

export type ClientWorld = typeof(setmetatable({} :: {
	_enemies: { [Entity]: ClientEnemyRecord },
}, ClientWorld))

function ClientWorld.new(): ClientWorld
	return setmetatable({ _enemies = {} :: { [Entity]: ClientEnemyRecord } }, ClientWorld)
end

function ClientWorld:upsertSpawn(
	id: Entity, pathId: number, speed: number, maxHp: number, typeId: number, now: number
): ()
	local existing = self._enemies[id]
	if existing then
		existing.pathId = pathId
		existing.speed = speed
		existing.maxHp = maxHp
		existing.hp = maxHp
		existing.alive = true
		existing.syncProgress = 0
		existing.syncTime = now
		return
	end

	self._enemies[id] = {
		id = id,
		pathId = pathId,
		speed = speed,
		renderProgress = 0,
		hp = maxHp,
		maxHp = maxHp,
		alive = true,
		syncProgress = 0,
		syncTime = now,
		model = nil,
		type = EnemyRegistry.TypeById[typeId] or "template",
		typeId = typeId,
	}
end

function ClientWorld:applyCorrection(id: Entity, progress: number, now: number): ()
	local enemy = self._enemies[id]
	if not enemy or not enemy.alive then return end
	enemy.syncProgress = progress
	enemy.syncTime = now
end

function ClientWorld:applySpeedChange(
	id: Entity, newSpeed: number, progress: number, now: number
): ()
	local enemy = self._enemies[id]
	if not enemy or not enemy.alive then return end
	enemy.speed = newSpeed
	enemy.syncProgress = progress
	enemy.syncTime = now
end

function ClientWorld:applyDamage(id: Entity, hp: number): ()
	local enemy = self._enemies[id]
	if enemy and enemy.alive then enemy.hp = hp end
end

function ClientWorld:remove(id: Entity): ()
	self._enemies[id] = nil
end

function ClientWorld:get(id: Entity): ClientEnemyRecord?
	return self._enemies[id]
end

function ClientWorld:forEachAlive(callback: (ClientEnemyRecord) -> ()): ()
	for _, enemy in self._enemies do
		if enemy.alive then callback(enemy) end
	end
end

return ClientWorld