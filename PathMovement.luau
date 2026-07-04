--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS  = require(ReplicatedStorage.Shared.ECS.World)
local Paths = require(ReplicatedStorage.Shared.Path.Paths)

local PathMovement = {}

function PathMovement.step(world: ECS.World, dt: number, now: number): { ECS.Entity }
	local finished: { ECS.Entity } = {}

	world:forEachAlive(function(enemy)
		local pathLen = Paths.length(enemy.pathId)
		world:advanceProgress(enemy, dt, pathLen, now)
		if enemy.progress >= 1 then
			finished[#finished + 1] = enemy.id
		end
	end)

	return finished
end

return PathMovement