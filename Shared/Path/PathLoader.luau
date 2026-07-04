--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Paths = require(ReplicatedStorage.Shared.Path.Paths)
local CatmullRom = require(ReplicatedStorage.Shared.Path.CatmullRom)

const containerName = "Paths"
const hideAtRuntime = true

type Entry = { order: number, position: Vector3, part: BasePart }

local function hideWaypoint(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CastShadow = false
end

local function loadPathFolder(folder: Folder): (number?, { Vector3 }?)
	local pathIdAttr = folder:GetAttribute("PathId")
	if typeof(pathIdAttr) ~= "number" then
		warn(string.format("Folder '%s' missing numeric pathId attr, skipped.", folder.Name))
		return nil, nil
	end
	local pathId: number = pathIdAttr

	local entries: { Entry } = {}

	for _, child in folder:GetChildren() do
		if not child:IsA("BasePart") then continue end
		local orderAttr = child:GetAttribute("Order")
		
		if typeof(orderAttr) ~= "number" then
			warn(string.format("Part '%s' in path %d missing order attr, skipped.", child.Name, pathId))
			continue
		end
		local order: number = orderAttr
		table.insert(entries, { order = order, position = child.Position, part = child })
	end

	if #entries < 2 then
		warn(string.format("Path %d has only %d waypoints; need >= 2  skipped.", pathId, #entries))
		return nil, nil
	end

	table.sort(entries, function(a: Entry, b: Entry) return a.order < b.order end)

	local waypoints: { Vector3 } = {}
	for _, entry in entries do
		table.insert(waypoints, entry.position)
		
		if hideAtRuntime then
			hideWaypoint(entry.part)
			
		end
	end

	return pathId, waypoints
end

local PathLoader = {}

function PathLoader.load(): Paths.WaypointMap
	local container = Workspace:FindFirstChild(containerName)
	if not container or not container:IsA("Folder") then
		warn(string.format("No Folder '%s' in Workspace.", containerName))
		return {}
	end

	local allWaypoints: Paths.WaypointMap = {}
	local loaded = 0

	for _, child in container:GetChildren() do
		if child:IsA("Folder") then
			local pathId, waypoints = loadPathFolder(child :: Folder)
			if pathId and waypoints then
				Paths.register(CatmullRom.create(pathId, waypoints))
				allWaypoints[pathId] = waypoints
				loaded += 1
			end
		end
	end

	print(string.format("%d spline paths loaded.", loaded))
	return allWaypoints
end

return PathLoader
