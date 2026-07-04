--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyRegistry     = require(ReplicatedStorage.Shared.EnemyRegistry)

export type EnemyType = EnemyRegistry.EnemyType

export type WaveGroup = {
	enemyType: EnemyType | { EnemyType },

	count:     number | { number }, -- single count applies to all types; array = per type counts
	pathId:    number?, -- if not specified picks random path

	onEach:   boolean?, -- if true spawns 'count' enemies on each path
}

export type WaveDef = {
	spawns:     { WaveGroup },

	spawnDelay: number?,
	cooldown:   number?,
}

local WAVES: { WaveDef } = {
	[1] = {
		spawns = {
			{ enemyType = {"template", "ind3"},  count = {50,100}, onEach = true },
			--{ enemyType = "ind6",  count = 100, pathId = 1},
		},
		spawnDelay = 0.05,
		cooldown   = 2,
	},
	[2] = {
		spawns     = { { enemyType = "template", count = 20 } },
		spawnDelay = 0.15,
		cooldown   = 3,
	},
}

local function normalizeGroup(group: WaveGroup): { { enemyType: EnemyType, count: number } }
	local rawTypes  = group.enemyType
	local rawCounts = group.count

	local types:  { EnemyType }
	local counts: { number }

	if typeof(rawTypes) == "table" then
		types = rawTypes :: any
	else
		types = { rawTypes :: any }
	end

	if typeof(rawCounts) == "table" then
		counts = rawCounts :: any
	else
		counts = { rawCounts :: any }
	end

	local result = {}
	for idx, etype in types do
		local c = counts[idx] or counts[1]
		result[idx] = { enemyType = etype, count = c }
	end
	return result
end

local WaveDefinitions = {}
WaveDefinitions.Waves          = WAVES
WaveDefinitions.normalizeGroup = normalizeGroup

return WaveDefinitions