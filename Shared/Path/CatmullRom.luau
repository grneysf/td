--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Paths = require(ReplicatedStorage.Shared.Path.Paths)

type PathDefinition = Paths.PathDefinition

local CatmullRom = {}

const SPLINE_STEPS = 128
const TENSION      = 0.5

local function crPointOnly(
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number
): Vector3
	local t2 = t * t
	local t3 = t2 * t
	local m0 = (p2 - p0) * TENSION
	local m1 = (p3 - p1) * TENSION
	return (2*t3 - 3*t2 + 1) * p1
		+  (t3 - 2*t2 + t)   * m0
		+  (-2*t3 + 3*t2)    * p2
		+  (t3 - t2)         * m1
end

local function crEval(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): (Vector3, Vector3)
	local t2 = t * t
	local t3 = t2 * t
	local m0 = (p2 - p0) * TENSION
	local m1 = (p3 - p1) * TENSION

	local pos = (2*t3 - 3*t2 + 1) * p1
		+  (t3 - 2*t2 + t)   * m0
		+  (-2*t3 + 3*t2)    * p2
		+  (t3 - t2)         * m1

	local tan = (6*t2 - 6*t)     * p1
		+ (3*t2 - 4*t + 1)       * m0
		+  (-6*t2 + 6*t)         * p2
		+   (3*t2 - 2*t)         * m1

	return pos, tan
end

local function buildArcLengthTable(wps: { Vector3 }): ({ number }, { number }, number)
	local segs    = #wps - 1
	local n       = segs * SPLINE_STEPS + 1
	local arcLens = table.create(n, 0)
	local gTs     = table.create(n, 0)
	local total = 0
	local idx   = 1
	for seg = 1, segs do
		local p0   = wps[math.max(1,    seg - 1)]
		local p1   = wps[seg]
		local p2   = wps[math.min(#wps, seg + 1)]
		local p3   = wps[math.min(#wps, seg + 2)]
		local prev = p1
		for step = 1, SPLINE_STEPS do
			local lt   = step / SPLINE_STEPS
			local curr = crPointOnly(p0, p1, p2, p3, lt)
			total     += (curr - prev).Magnitude
			prev       = curr
			idx       += 1
			arcLens[idx] = total
			gTs[idx]     = (seg - 1) + lt
		end
	end
	return arcLens, gTs, total
end

function CatmullRom.create(id: number, waypoints: { Vector3 }): PathDefinition
	assert(#waypoints >= 2,
		string.format("Path %d needs ? 2 waypoints", id))

	local arcLens, gTs, totalLength = buildArcLengthTable(waypoints)
	local tableSize = #arcLens
	local nWps      = #waypoints
	local segs      = nWps - 1

	local segments = table.create(segs)
	for seg = 1, segs do
		segments[seg] = {
			p0 = waypoints[math.max(1,    seg - 1)],
			p1 = waypoints[seg],
			p2 = waypoints[math.min(nWps, seg + 1)],
			p3 = waypoints[math.min(nWps, seg + 2)],
		}
	end

	local function resolve(progress: number): (number, number)
		if totalLength <= 0 then
			return 1, 0
		end

		local target = math.clamp(progress, 0, 1) * totalLength
		local lo, hi = 1, tableSize
		while lo < hi do
			local mid = (lo + hi) // 2
			if arcLens[mid] < target then lo = mid + 1 else hi = mid end
		end

		local globalT: number
		if lo <= 1 then
			globalT = 0
		else
			local a    = arcLens[lo - 1]
			local b    = arcLens[lo]
			local span = b - a
			local frac = if span > 0 then (target - a) / span else 0
			globalT = gTs[lo - 1] + frac * (gTs[lo] - gTs[lo - 1])
		end

		local seg    = math.clamp(math.floor(globalT) + 1, 1, segs)
		local localT = globalT - (seg - 1)
		return seg, localT
	end

	local function sample(progress: number): (Vector3, Vector3)
		if totalLength <= 0 then
			return waypoints[1], Vector3.zAxis
		end

		local seg, localT = resolve(progress)
		local s = segments[seg]

		local pos, tan = crEval(s.p0, s.p1, s.p2, s.p3, localT)
		local fwd = if tan.Magnitude > 1e-4 then tan.Unit else Vector3.zAxis
		return pos, fwd
	end

	local function samplePosition(progress: number): Vector3
		if totalLength <= 0 then
			return waypoints[1]
		end

		local seg, localT = resolve(progress)
		local s = segments[seg]

		return crPointOnly(s.p0, s.p1, s.p2, s.p3, localT)
	end

	return {
		id            = id,
		length        = totalLength,
		waypoints     = waypoints,
		sample        = sample,
		samplePosition = samplePosition,
	}
end

return CatmullRom