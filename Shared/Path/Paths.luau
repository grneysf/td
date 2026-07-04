--!strict

export type PathDefinition = {
	id:       number,
	length:   number,
	waypoints: { Vector3 },
	sample:   (progress: number) -> (Vector3, Vector3),
	samplePosition: (progress: number) -> Vector3,
}
export type WaypointMap = { [number]: { Vector3 } }

local Paths = {}

local registry: { [number]: PathDefinition } = {}

function Paths.register(path: PathDefinition)
	registry[path.id] = path
end

function Paths.get(pathId: number): PathDefinition?
	return registry[pathId]
end

function Paths.length(pathId: number): number
	local path = registry[pathId]
	return if path then path.length else 1
end

function Paths.getAll(): { PathDefinition }
	local result: { PathDefinition } = {}
	for _, path in registry do
		table.insert(result, path)
	end
	return result
end

function Paths.isRegistered(pathId: number): boolean
	return registry[pathId] ~= nil
end

function Paths.clear()
	table.clear(registry)
end

return Paths