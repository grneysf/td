--!strict

export type EnemyType = "ind3" | "ind6" | "template"
export type Resistances = { physical: number, magical: number }
export type EnemyDef = {
	model:    string,
	baseHp:   number,
	baseSpeed: number,
	typeId:   number,
	resists:  Resistances,
}

local EnemyRegistry = {}

local definitions: { [EnemyType]: EnemyDef } = {
	ind3 = {
		model = "ind3",
		baseHp = 50,
		baseSpeed = 10,
		typeId = 1,
		resists = { physical = 0, magical = 0 },
	},
	ind6 = {
		model = "ind6",
		baseHp = 50,
		baseSpeed = 10,
		typeId = 2,
		resists = { physical = 0, magical = 0 },
	},
	template = {
		model = "Template",
		baseHp = 100,
		baseSpeed = 5,
		typeId = 3,
		resists = { physical = 0, magical = 0 },
	},
}
EnemyRegistry.Definitions = definitions

local typeById: { [number]: EnemyType } = {}
for name: EnemyType, def: EnemyDef in definitions do
	typeById[def.typeId] = name
end
EnemyRegistry.TypeById = typeById

return EnemyRegistry