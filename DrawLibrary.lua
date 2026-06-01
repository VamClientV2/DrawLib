local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Draw = {}

-- Private: ensure a shared ScreenGui exists in CoreGui
local function getScreenGui()
	local gui = CoreGui:FindFirstChild("DrawLibrary")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "DrawLibrary"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = CoreGui
	end
	return gui
end

-- Private: generate unique render step names
local idCounter = 0
local function uniqueId()
	idCounter = idCounter + 1
	return "Draw_" .. idCounter .. "_" .. tick()
end

function Draw.Circle(type, sides, size)
	local screenGui = getScreenGui()
	local radius = size
	local frames = {}
	local renderName = uniqueId()
	local alive = true

	for i = 1, sides do
		local frame = Instance.new("Frame")
		frame.Name = "DrawCircle_" .. i
		frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)

		local angle = math.rad((i - 1) * (360 / sides))
		local nextAngle = math.rad(i * (360 / sides))
		local midAngle = (angle + nextAngle) / 2
		local midX = math.cos(midAngle) * radius
		local midY = math.sin(midAngle) * radius

		local x1 = math.cos(angle) * radius
		local y1 = math.sin(angle) * radius
		local x2 = math.cos(nextAngle) * radius
		local y2 = math.sin(nextAngle) * radius
		local sideLength = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)

		local rotationDeg = math.deg(midAngle) + 90

		frame.Size = UDim2.new(0, sideLength, 0, 1)
		frame.Rotation = rotationDeg
		frame.Position = UDim2.new(0, 0, 0, 0)
		frame.Parent = screenGui

		table.insert(frames, {
			frame = frame,
			midX = midX,
			midY = midY,
		})
	end

	if type == "FromMouse" then
		RunService:BindToRenderStep(renderName, 1, function()
			if not alive then return end
			local mouseLocation = UserInputService:GetMouseLocation()
			if mouseLocation then
				for _, data in frames do
					data.frame.Position = UDim2.new(
						0, mouseLocation.X + data.midX,
						0, mouseLocation.Y + data.midY
					)
				end
			end
		end)
	end

	local circle = {}

	function circle:Destroy()
		alive = false
		RunService:UnbindFromRenderStep(renderName)
		for _, data in frames do
			data.frame.Parent = nil
		end
		frames = {}
	end

	return circle
end

function Draw.Line(type, destination)
	local screenGui = getScreenGui()
	local Camera = game:GetService("Workspace").CurrentCamera
	local lineFrames = {}
	local renderName = uniqueId()
	local alive = true
	local targets = {}

	-- Normalize destination: single BasePart or table of BaseParts
	if typeof(destination) == "Instance" then
		if destination:IsA("BasePart") then
			targets = {destination}
		end
	elseif typeof(destination) == "table" then
		for _, v in destination do
			if typeof(v) == "Instance" and v:IsA("BasePart") then
				table.insert(targets, v)
			end
		end
	end

	-- Dynamically grow the line frame pool as needed
	local function ensureFrameCount(count)
		while #lineFrames < count do
			local frame = Instance.new("Frame")
			frame.Name = "DrawLine_" .. (#lineFrames + 1)
			frame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			frame.BorderSizePixel = 0
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Size = UDim2.new(0, 0, 0, 1)
			frame.Visible = false
			frame.Parent = screenGui
			table.insert(lineFrames, frame)
		end
	end

	if type == "FromMouse" then
		RunService:BindToRenderStep(renderName, 2, function()
			if not alive then return end
			local mouseLocation = UserInputService:GetMouseLocation()
			if not mouseLocation then
				for _, frame in lineFrames do
					frame.Visible = false
				end
				return
			end

			-- Project valid targets to screen coordinates
			local screenTargets = {}
			for _, target in targets do
				if target and target.Parent then
					local screenPos, onScreen = Camera:WorldToScreenPoint(target.Position)
					if onScreen then
						table.insert(screenTargets, Vector2.new(screenPos.X, screenPos.Y))
					end
				end
			end

			ensureFrameCount(#screenTargets)

			for i, frame in lineFrames do
				if i <= #screenTargets then
					local target = screenTargets[i]
					local mouseVec = Vector2.new(mouseLocation.X, mouseLocation.Y)
					local midpoint = (mouseVec + target) / 2
					local distance = (target - mouseVec).Magnitude
					local angle = math.deg(math.atan2(target.Y - mouseLocation.Y, target.X - mouseLocation.X))

					frame.Position = UDim2.new(0, midpoint.X, 0, midpoint.Y)
					frame.Size = UDim2.new(0, distance, 0, 1)
					frame.Rotation = angle
					frame.Visible = true
				else
					frame.Visible = false
				end
			end
		end)
	end

	local line = {}

	function line:Add(part)
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			table.insert(targets, part)
		elseif typeof(part) == "table" then
			for _, p in part do
				if typeof(p) == "Instance" and p:IsA("BasePart") then
					table.insert(targets, p)
				end
			end
		end
	end

	function line:Remove(part)
		for i, t in targets do
			if t == part then
				table.remove(targets, i)
				return
			end
		end
	end

	function line:Destroy()
		alive = false
		RunService:UnbindFromRenderStep(renderName)
		for _, frame in lineFrames do
			frame.Parent = nil
		end
		lineFrames = {}
	end

	return line
end

return Draw
