--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Paths             = require(ReplicatedStorage.Shared.Path.Paths)

export type PathSelectorType = {
	_pathIds: { number },

	refresh: (PathSelectorType) -> (),
	count:   (PathSelectorType) -> number,
	ids:     (PathSelectorType) -> { number },
	pick:    (PathSelectorType) -> number,
}

local PathSelector = {}
PathSelector.__index = PathSelector

function PathSelector.new(): PathSelectorType
	local self = setmetatable({}, PathSelector) :: PathSelectorType
	self._pathIds = {}
	return self
end

function PathSelector:refresh()
	local ids = self._pathIds
	table.clear(ids)
	for _, path in Paths.getAll() do
		ids[#ids + 1] = path.id
	end
	if #ids == 0 then ids[1] = 1 end
end

function PathSelector:count(): number
	return #self._pathIds
end


function PathSelector:ids(): { number }
	return self._pathIds
end

function PathSelector:pick(): number
	local ids = self._pathIds
	return if #ids > 0 then ids[math.random(1, #ids)] else 1
end

return PathSelector
