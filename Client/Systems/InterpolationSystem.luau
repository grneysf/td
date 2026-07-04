--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS  = require(ReplicatedStorage.Shared.ECS.World)
local Paths = require(ReplicatedStorage.Shared.Path.Paths)

local Interpolation = {}

function Interpolation.step(world: ECS.ClientWorld, now: number): ()
	world:forEachAlive(function(enemy)
		local pathLen = Paths.length(enemy.pathId) 
		local elapsed = now - enemy.syncTime
		enemy.renderProgress = math.clamp(
			enemy.syncProgress + enemy.speed * elapsed / pathLen,
			0, 1
		)
	end)
end

return Interpolation
