--!strict
local F16 = {}

local function floatToHalf(value: number): number
	if value ~= value then
		return 0x7E00
	end
	if value == math.huge then
		return 0x7C00
	end
	if value == -math.huge then
		return 0xFC00
	end

	local sign = 0
	if value < 0 then
		sign = 0x8000
		value = -value
	end

	if value == 0 then
		return sign
	end

	local mantissa, exponent = math.frexp(value)
	exponent += 14
	mantissa = mantissa * 2 - 1

	if exponent <= 0 then
		mantissa *= 2 ^ (exponent - 1)
		exponent = 0
	elseif exponent >= 31 then
		return sign + 0x7C00
	end

	return sign + bit32.lshift(exponent, 10) + bit32.band(math.floor(mantissa * 1024 + 0.5), 0x3FF)
end

local function halfToFloat(bits: number): number
	local sign = bit32.rshift(bits, 15)
	local exponent = bit32.band(bit32.rshift(bits, 10), 0x1F)
	local mantissa = bit32.band(bits, 0x3FF)

	if exponent == 0 then
		if mantissa == 0 then
			return if sign == 1 then -0 else 0
		end
		local value = mantissa / 1024 * 2 ^ -14
		return if sign == 1 then -value else value
	end

	if exponent == 31 then
		if mantissa == 0 then
			return if sign == 1 then -math.huge else math.huge
		end
		return 0 / 0
	end

	local value = (1 + mantissa / 1024) * 2 ^ (exponent - 15)
	return if sign == 1 then -value else value
end

function F16.encode(value: number): number
	return floatToHalf(math.clamp(value, 0, 1))
end

function F16.decode(bits: number): number
	return halfToFloat(bits)
end

function F16.encodeSpeed(value: number): number
	return floatToHalf(math.clamp(value, 0, 65504))
end

function F16.decodeSpeed(bits: number): number
	return halfToFloat(bits)
end

return F16
