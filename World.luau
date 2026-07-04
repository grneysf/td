--!strict

local ServerWorld = require(script.Server)
local ClientWorldModule = require(script.Client)

export type Entity = ServerWorld.Entity
export type EnemyRecord = ServerWorld.EnemyRecord
export type ClientEnemyRecord = ClientWorldModule.ClientEnemyRecord
export type World = ServerWorld.World
export type ClientWorld = ClientWorldModule.ClientWorld
export type StateEntry = ServerWorld.StateEntry
export type SpeedEntry = ServerWorld.SpeedEntry
export type DamageEntry = ServerWorld.DamageEntry


return {
	World = ServerWorld,
	ClientWorld = ClientWorldModule,
}