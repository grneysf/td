--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local F16 = require(ReplicatedStorage.Shared.Net.F16)
local Constants = require(ReplicatedStorage.Shared.Constants)

export type SpawnEntry = { id: number, pathId: number, typeId: number, speed: number, maxHp: number }
export type StateEntry = { id: number, progress: number }
export type SpeedEntry = { id: number, newSpeed: number, progress: number }
export type DamageEntry = { id: number, hp: number }
export type DeathEntry = { id: number }

export type SpawnBatch = { entries: { SpawnEntry } }
export type StateDelta = { entries: { StateEntry } }
export type SpeedBatch = { entries: { SpeedEntry } }
export type DamageBatch = { entries: { DamageEntry } }
export type DeathBatch = { entries: { DeathEntry } }

const SZ_SPAWN = 8
const SZ_STATE = 4
const SZ_SPEED = 6
const SZ_DAMAGE = 4
const SZ_DEATH = 2

local function writeU8(b: buffer, o: number, v: number): number
	buffer.writeu8(b, o, v)
	return o + 1
end

local function writeU16(b: buffer, o: number, v: number): number
	buffer.writeu16(b, o, v)
	return o + 2
end

local function writeF16(b: buffer, o: number, v: number): number
	buffer.writeu16(b, o, F16.encode(v))
	return o + 2
end

local function writeSpeedF16(b: buffer, o: number, v: number): number
	buffer.writeu16(b, o, F16.encodeSpeed(v))
	return o + 2
end

local function readU8(b: buffer, o: number): (number, number)
	return buffer.readu8(b, o), o + 1
end

local function readU16(b: buffer, o: number): (number, number)
	return buffer.readu16(b, o), o + 2
end

local function readF16(b: buffer, o: number): (number, number)
	return F16.decode(buffer.readu16(b, o)), o + 2
end

local function readSpeedF16(b: buffer, o: number): (number, number)
	return F16.decodeSpeed(buffer.readu16(b, o)), o + 2
end

local Buffers = {}

function Buffers.packSpawnBatch(entries: { SpawnEntry }): buffer
	local n   = math.min(#entries, Constants.MAX_SPAWN_BATCH)
	local buf = buffer.create(1 + n * SZ_SPAWN)
	local o   = writeU8(buf, 0, n)
	for i = 1, n do
		local e = entries[i]
		o = writeU16(buf, o, e.id)
		o = writeU8(buf, o, e.pathId)
		o = writeU8(buf, o, e.typeId)
		o = writeSpeedF16(buf, o, e.speed)
		o = writeU16(buf, o, e.maxHp)
	end
	return buf
end

function Buffers.unpackSpawnBatch(buf: buffer): SpawnBatch
	local n, o = readU8(buf, 0)
	local entries: { SpawnEntry } = table.create(n)
	for i = 1, n do
		local id, pathId, typeId, speed, maxHp
		id,     o = readU16(buf, o)
		pathId, o = readU8(buf, o)
		typeId, o = readU8(buf, o)
		speed,  o = readSpeedF16(buf, o)
		maxHp,  o = readU16(buf, o)
		entries[i] = { id = id, pathId = pathId, typeId = typeId, speed = speed, maxHp = maxHp }
	end
	return { entries = entries }
end

function Buffers.packStateDelta(entries: { StateEntry }): buffer
	local n   = math.min(#entries, Constants.MAX_STATE_BATCH)
	local buf = buffer.create(1 + n * SZ_STATE)
	local o   = writeU8(buf, 0, n)
	for i = 1, n do
		local e = entries[i]
		o = writeU16(buf, o, e.id)
		o = writeF16(buf, o, e.progress)
	end
	return buf
end

function Buffers.unpackStateDelta(buf: buffer): StateDelta
	local n, o = readU8(buf, 0)
	local entries: { StateEntry } = table.create(n)
	for i = 1, n do
		local id, progress
		id,       o = readU16(buf, o)
		progress, o = readF16(buf, o)
		entries[i] = { id = id, progress = progress }
	end
	return { entries = entries }
end

function Buffers.packSpeedBatch(entries: { SpeedEntry }): buffer
	local n   = math.min(#entries, Constants.MAX_SPEED_BATCH)
	local buf = buffer.create(1 + n * SZ_SPEED)
	local o   = writeU8(buf, 0, n)
	for i = 1, n do
		local e = entries[i]
		o = writeU16(buf, o, e.id)
		o = writeSpeedF16(buf, o, e.newSpeed)
		o = writeF16(buf, o, e.progress)
	end
	return buf
end

function Buffers.unpackSpeedBatch(buf: buffer): SpeedBatch
	local n, o = readU8(buf, 0)
	local entries: { SpeedEntry } = table.create(n)
	for i = 1, n do
		local id, newSpeed, progress
		id,       o = readU16(buf, o)
		newSpeed, o = readSpeedF16(buf, o)
		progress, o = readF16(buf, o)
		entries[i] = { id = id, newSpeed = newSpeed, progress = progress }
	end
	return { entries = entries }
end

function Buffers.packDamageBatch(entries: { DamageEntry }): buffer
	local n   = math.min(#entries, Constants.MAX_DAMAGE_BATCH)
	local buf = buffer.create(1 + n * SZ_DAMAGE)
	local o   = writeU8(buf, 0, n)
	for i = 1, n do
		local e = entries[i]
		o = writeU16(buf, o, e.id)
		o = writeU16(buf, o, e.hp)
	end
	return buf
end

function Buffers.unpackDamageBatch(buf: buffer): DamageBatch
	local n, o = readU8(buf, 0)
	local entries: { DamageEntry } = table.create(n)
	for i = 1, n do
		local id, hp
		id, o = readU16(buf, o)
		hp, o = readU16(buf, o)
		entries[i] = { id = id, hp = hp }
	end
	return { entries = entries }
end

function Buffers.packDeathBatch(entries: { DeathEntry }): buffer
	local n   = math.min(#entries, Constants.MAX_DEATH_BATCH)
	local buf = buffer.create(1 + n * SZ_DEATH)
	local o   = writeU8(buf, 0, n)
	for i = 1, n do
		o = writeU16(buf, o, entries[i].id)
	end
	return buf
end

function Buffers.unpackDeathBatch(buf: buffer): DeathBatch
	local n, o = readU8(buf, 0)
	local entries: { DeathEntry } = table.create(n)
	for i = 1, n do
		local id
		id, o      = readU16(buf, o)
		entries[i] = { id = id }
	end
	return { entries = entries }
end

return Buffers