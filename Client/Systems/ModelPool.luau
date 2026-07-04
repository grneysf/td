--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local EnemyRegistry = require(ReplicatedStorage.Shared.EnemyRegistry)
local ECS = require(ReplicatedStorage.Shared.ECS.World)

type EnemyType = EnemyRegistry.EnemyType

const POOL_CAP = 30

local _enemyFolder: Folder
local _active: { [number]: Model }     = {}
local _free:   { [EnemyType]: { Model } } = {}
local _typeOf: { [Model]: EnemyType }     = {}

local function ensureFolder()
	if _enemyFolder then return end
	_enemyFolder        = Instance.new("Folder")
	_enemyFolder.Name   = "ActiveEnemies"
	_enemyFolder.Parent = Workspace
end

local function cloneTemplate(typeName: EnemyType): Model?
	local def = EnemyRegistry.Definitions[typeName]
	if not def then
		warn("Unknown enemy type:", typeName)
		return nil
	end
	local template = ReplicatedStorage.Enemies:FindFirstChild(def.model)
	if not template then
		warn("Missing template:", def.model)
		return nil
	end
	return (template :: Model):Clone()
end

local ModelPool = {}

function ModelPool.acquireById(id: number, typeName: EnemyType): Model?
	ensureFolder()

	local existing = _active[id]
	if existing then return existing end

	local model: Model?
	local freeList = _free[typeName]

	if freeList and #freeList > 0 then
		model = table.remove(freeList) :: Model
		model.Parent = _enemyFolder
	else
		model = cloneTemplate(typeName)
		if not model then return nil end
		_typeOf[model :: Model] = typeName
		model.Parent = _enemyFolder
	end

	_active[id] = model :: Model
	return model
end

function ModelPool.acquire(enemy: ECS.ClientEnemyRecord): Model?
	return ModelPool.acquireById(enemy.id, enemy.type)
end

function ModelPool.releaseById(id: number)
	local model = _active[id]
	if not model then return end
	_active[id] = nil

	local typeName = _typeOf[model]
	if not typeName then
		model:Destroy()
		return
	end

	local freeList = _free[typeName]
	if not freeList then
		freeList        = table.create(POOL_CAP)
		_free[typeName] = freeList
	end

	if #freeList < POOL_CAP then
		model.Parent = nil
		table.insert(freeList, model)
	else
		_typeOf[model] = nil
		model:Destroy()
	end
end

function ModelPool.releaseMissing(world: ECS.ClientWorld)
	local toRelease = {}
	for id in _active do
		local enemy = world:get(id)
		if not enemy or not enemy.alive then
			toRelease[#toRelease + 1] = id
		end
	end
	for _, id in toRelease do
		ModelPool.releaseById(id)
	end
end

function ModelPool.clearPool(): ()
	for typeName, freeList in _free do
		for _, model in freeList do
			_typeOf[model] = nil
			model:Destroy()
		end
		_free[typeName] = nil
	end
end

function ModelPool.prewarm(typeName: EnemyType, count: number): ()
	local freeList = _free[typeName] or table.create(count)
	_free[typeName] = freeList
	local needed = math.min(count, POOL_CAP) - #freeList
	for _ = 1, needed do
		local model = cloneTemplate(typeName)
		if not model then break end
		_typeOf[model] = typeName
		model.Parent   = nil
		table.insert(freeList, model)
	end
end

return ModelPool
