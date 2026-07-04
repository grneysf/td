--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Shared.ECS.World)

local VFXSystem = {}

local function ensureBillboard(model: Model): BillboardGui
	local root = model.PrimaryPart :: BasePart
	local existing = root:FindFirstChild("EntityBillboard")
	if existing and existing:IsA("BillboardGui") then
		return existing
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EntityBillboard"
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.Parent = billboard

	return billboard
end

function VFXSystem.step(world: ECS.ClientWorld): ()
	world:forEachAlive(function(enemy)
		local model = enemy.model
		if not model then
			return
		end

		local billboard = ensureBillboard(model)
		local label = billboard:FindFirstChild("Label") :: TextLabel?
		if not label then
			return
		end

		label.Text = ("Entity [%d]"):format(enemy.id)
	end)
end

return VFXSystem
