local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local EnemyRegistry = require(ReplicatedStorage.Shared.EnemyRegistry)

type EnemyType = EnemyRegistry.EnemyType

export type Entity = number

export type EnemyRecord = {
	id: Entity,
	type: EnemyType,
	
	pathId: number,
	speed: number,
	progress: number,
	hp: number,
	maxHp: number,
	syncProgress: number,
	syncTime: number,
	
	alive: boolean,
	dirty: boolean,
	speedDirty: boolean,
	hpDirty: boolean,
}

export type StateEntry = { id: number, progress: number }
export type SpeedEntry = { id: number, newSpeed: number, progress: number }
export type DamageEntry = { id: number, hp: number }

local World = {}
World.__index = World

export type World = typeof(setmetatable({} :: {
	_nextId: number,
	_aliveCount: number,
	_enemies: { [Entity]: EnemyRecord },
	_idPool: { Entity },
	
	get: (id: number)-> EnemyRecord?,
	spawn: (self: any, enemyType: EnemyType, pathId: number, now: number) -> Entity,
}, World))

function World.new(): World
	return setmetatable({
		_nextId = 1,
		_aliveCount = 0,
		_enemies = {} :: { [Entity]: EnemyRecord },
		_idPool = {} :: { Entity },
	}, World)
end

function World:spawn(enemyType: EnemyType, pathId: number, now: number): Entity
	local def = EnemyRegistry.Definitions[enemyType]
	assert(def, "Unknown enemy type: " .. tostring(enemyType))

	local id = table.remove(self._idPool) or self._nextId
	if id == self._nextId then self._nextId += 1 end

	self._enemies[id] = {
		id = id,
		type = enemyType,
		pathId = pathId,
		syncTime = now,
		
		speed = def.baseSpeed,
		hp = def.baseHp,
		maxHp = def.baseHp,
		
		progress = 0,
		syncProgress = 0,
		
		alive = true,
		dirty = false,
		speedDirty = false,
		hpDirty = false,
	}

	self._aliveCount += 1
	return id
end

function World:get(id: Entity): EnemyRecord?
	return self._enemies[id]
end

function World:kill(id: Entity): ()
	local enemy = self._enemies[id]
	if not enemy or not enemy.alive then return end
	enemy.alive = false
	self._aliveCount -= 1
	self._enemies[id] = nil
	table.insert(self._idPool, id)
end

function World:forEachAlive(callback: (EnemyRecord) -> ()): ()
	for _, enemy in self._enemies do
		if enemy.alive then callback(enemy) end
	end
end

function World:advanceProgress(enemy: EnemyRecord, dt: number, pathLength: number, now: number): ()
	local safeLen = if pathLength > 0 then pathLength else 1
	enemy.progress = math.clamp(enemy.progress + enemy.speed * dt / safeLen, 0, 1)

	local predicted = math.clamp(
		enemy.syncProgress + enemy.speed * (now - enemy.syncTime) / safeLen,
		0, 1
	)

	if math.abs(enemy.progress - predicted) > Constants.CORRECTION_EPSILON then
		enemy.dirty = true
	end
end

function World:setSpeed(id: Entity, newSpeed: number): ()
	local enemy = self._enemies[id]
	if not enemy or not enemy.alive then return end
	if math.abs(enemy.speed - newSpeed) < Constants.SPEED_EPSILON then return end
	enemy.speed = newSpeed
	enemy.speedDirty = true
end

function World:applyDamage(id: Entity, damage: number): ()
	local enemy = self._enemies[id]
	if not enemy or not enemy.alive then return end
	enemy.hp = math.max(0, enemy.hp - damage)
	enemy.hpDirty = true
end

function World:drainDirty(out: { StateEntry }, now: number): ()
	table.clear(out)
	for _, enemy in self._enemies do
		if enemy.alive and enemy.dirty then
			out[#out + 1] = { id = enemy.id, progress = enemy.progress }
			enemy.dirty = false
			enemy.syncProgress = enemy.progress
			enemy.syncTime = now
		end
	end
end

function World:drainSpeedDirty(out: { SpeedEntry }, now: number): ()
	table.clear(out)
	for _, enemy in self._enemies do
		if enemy.alive and enemy.speedDirty then
			out[#out + 1] = {
				id = enemy.id,
				newSpeed = enemy.speed,
				progress = enemy.progress,
			}
			enemy.speedDirty = false
			enemy.syncProgress = enemy.progress
			enemy.syncTime = now
		end
	end
end

function World:drainHpDirty(out: { DamageEntry }): ()
	table.clear(out)
	for _, enemy in self._enemies do
		if enemy.alive and enemy.hpDirty then
			out[#out + 1] = { id = enemy.id, hp = enemy.hp }
			enemy.hpDirty = false
		end
	end
end

function World:aliveCount(): number
	return self._aliveCount
end

return World