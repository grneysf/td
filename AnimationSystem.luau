--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathSampler = require(ReplicatedStorage.Shared.Path.PathSampler)
local ECS = require(ReplicatedStorage.Shared.ECS.World)
local EnemyRegistry = require(ReplicatedStorage.Shared.EnemyRegistry)
local ModelPool = require(script.Parent.ModelPool)

const SMOOTH = 12
const RUN_SPEED_THRESHOLD = 9

type AnimType = "walk" | "run"

local _runAnim: Animation? = ReplicatedStorage.Animations:FindFirstChild("Running")
if _runAnim and not _runAnim:IsA("Animation") then _runAnim = nil end

local _tracks:    { [Model]: AnimationTrack } = {}
local _animType:  { [Model]: AnimType }         = {}
local _lastSpeed: { [Model]: number }         = {}

local _models: { [number]: Model } = {}

local function playAnimation(model: Model, speed: number): ()
	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then return end

	local useRun   = speed >= RUN_SPEED_THRESHOLD
	local animType: AnimType = useRun and "run" or "walk"
	if _animType[model] == animType then return end 

	local anim: Animation?
	if useRun and _runAnim then
		anim = _runAnim
	else
		local walkAnim = controller:FindFirstChild("Walk")
		if walkAnim and walkAnim:IsA("Animation") then
			anim = walkAnim
		end
	end
	if not anim then return end

	local animator = controller:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
		_tracks[model] = nil
	end

	animator            = Instance.new("Animator")
	animator.Parent     = controller

	local track         = animator:LoadAnimation(anim)
	_tracks[model]      = track
	_animType[model]    = animType
	_lastSpeed[model]   = nil
	track:Play()
	if useRun then return end
	track:AdjustSpeed(0.6)
end

local function stopAndClean(model: Model): ()
	local track = _tracks[model]
	if track then track:Stop() end
	_tracks[model]    = nil
	_animType[model]  = nil
	_lastSpeed[model] = nil
end

local function adjustSpeed(model: Model, speed: number, typeName: EnemyRegistry.EnemyType): ()
	local track = _tracks[model]
	if not track then return end

	local def   = EnemyRegistry.Definitions[typeName]
	local base  = def and def.baseSpeed or 1
	local ratio = if base > 0 then speed / base else 1

	if _lastSpeed[model] ~= ratio then
		track:AdjustSpeed(ratio)
		_lastSpeed[model] = ratio
	end
end

local AnimationSystem = {}

function AnimationSystem.step(world: ECS.ClientWorld, dt: number): ()
	local toRelease: { number } = {}
	for id in _models do
		if not world:get(id) then
			toRelease[#toRelease + 1] = id
		end
	end
	for _, id in toRelease do
		stopAndClean(_models[id])
		ModelPool.releaseById(id)
		_models[id] = nil
	end

	world:forEachAlive(function(enemy)
		if not _models[enemy.id] then
			local model = ModelPool.acquireById(enemy.id, enemy.type)
			if not model then return end
			_models[enemy.id] = model
			enemy.model       = model
		end

		local model = _models[enemy.id]
		if not model then return end

		playAnimation(model, enemy.speed)

		local position, direction = PathSampler.sample(enemy.pathId, enemy.renderProgress)

		if direction.Magnitude < 0.001 then
			direction = Vector3.new(0, 0, -1)
		end

		local targetCFrame = CFrame.lookAt(position, position + direction)

		local current = model:GetPivot()
		local alpha = 1 - math.exp(-SMOOTH * dt)

		local newRotation = current.Rotation:Lerp(targetCFrame.Rotation, alpha)
		model:PivotTo(CFrame.new(position) * newRotation)
	end)

	ModelPool.releaseMissing(world)
end

function AnimationSystem.cleanup(world: ECS.ClientWorld): ()
	world:forEachAlive(function(enemy: ECS.ClientEnemyRecord)
		local model = _models[enemy.id]
		if model then
			stopAndClean(model)
			ModelPool.releaseById(enemy.id)
			_models[enemy.id] = nil
			enemy.model       = nil
		end
	end)
	for id, model in _models do
		stopAndClean(model)
		ModelPool.releaseById(id)
		_models[id] = nil
	end
end

return AnimationSystem
