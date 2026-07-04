--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Paths = require(ReplicatedStorage.Shared.Path.Paths)

local PathSampler = {}

function PathSampler.sample(pathId: number, progress: number): (Vector3, Vector3)
	local path = Paths.get(pathId)
	if not path then
		return Vector3.zero, Vector3.new(0, 0, -1)
	end
	return path.sample(progress)
end

function PathSampler.samplePosition(pathId: number, progress: number): Vector3
	local path = Paths.get(pathId)
	if not path then
		return Vector3.zero
	end
	return path.samplePosition(progress)
end

function PathSampler.length(pathId: number): number
	local path = Paths.get(pathId)
	return if path then path.length else 1
end

return PathSampler