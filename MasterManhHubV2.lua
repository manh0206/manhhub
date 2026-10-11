-- LocalScript đặt trong StarterPlayer > StarterPlayerScripts
-- Dành cho game do bạn phát triển hoặc kiểm thử trong Studio
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== Cấu hình =====
local CONFIG = {
	HubName = "MasterManhHub",
	WalkSpeed = { min = 16, max = 250, default = 16 },
	JumpHeight = { min = 16, max = 250, default = 16 },
	NoclipKey = Enum.KeyCode.N,
	FlyKey = Enum.KeyCode.F,
	ToggleGuiKey = Enum.KeyCode.M,
	PanelWidth = 280,
	HeaderHeight = 36,
	BodyHeight = 230,
	Colors = {
		Panel = Color3.fromRGB(28, 28, 36),
		Header = Color3.fromRGB(38, 38, 48),
		Track = Color3.fromRGB(65, 65, 78),
		On = Color3.fromRGB(60, 190, 110),
		Off = Color3.fromRGB(150, 60, 60),
		Text = Color3.fromRGB(240, 240, 245),
		SubText = Color3.fromRGB(180, 180, 192),
		Stroke = Color3.fromRGB(70, 70, 88),
	},
}

local NAMETAG = {
	MaxDistance = 1e6,
	StudsOffset = Vector3.new(0, 2.5, 0),
	UpdateInterval = 0.2,
	TextSize = 14,
}

-- ===== Trạng thái =====
local values = {
	WalkSpeed = CONFIG.WalkSpeed.default,
	JumpHeight = CONFIG.JumpHeight.default,
}

local noclipOn = false
local noclipConnection
local originalCollide = setmetatable({}, { __mode = "k" })

local flyOn = false
local flyConnection
local flyForce
local flyAttachment

local nametagOn = false
local nametagTags = {}      -- [Player] = { gui, label }
local nametagConns = {}     -- [Player] = { connections }
local nametagUpdateConn
local nametagPlayerAddedConn
local nametagPlayerRemovingConn
local nametagAccumulator = 0

local panelVisible = true
local activeDrag = nil

local refreshNoclipButton
local refreshFlyButton
local refreshNametagButton

-- ===== Tiện ích nhân vật =====
local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Dùng JumpHeight thay vì JumpPower để kết quả không phụ thuộc trọng lực Workspace
local function applyMovement(humanoid)
	if not humanoid then return end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = values.WalkSpeed
	humanoid.JumpHeight = values.JumpHeight
end

-- ===== Xuyên tường =====
local function applyNoclip(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			originalCollide[part] = true
			part.CanCollide = false
		end
	end
end

local function restoreCollision()
	for part in pairs(originalCollide) do
		if part.Parent then
			part.CanCollide = true
		end
		originalCollide[part] = nil
	end
end

local function setNoclip(state)
	if noclipOn == state then return end
	noclipOn = state

	if state then
		-- Stepped chạy trước physics mỗi frame nên va chạm luôn bị tắt kịp thời
		noclipConnection = RunService.Stepped:Connect(function()
			local character = player.Character
			if character then
				applyNoclip(character)
			end
		end)
	else
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
		restoreCollision()
	end

	refreshNoclipButton()
end

-- ===== Bay =====
local function clearFlyObjects()
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	if flyForce then
		flyForce:Destroy()
		flyForce = nil
	end
	if flyAttachment then
		flyAttachment:Destroy()
		flyAttachment = nil
	end
end

local function stopFly()
	if not flyOn then return end
	flyOn = false
	clearFlyObjects()

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.PlatformStand = false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	refreshFlyButton()
end

local function keyValue(keyCode)
	return UserInputService:IsKeyDown(keyCode) and 1 or 0
end

local function startFly()
	if flyOn then return end
	local humanoid = getHumanoid()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end

	flyOn = true
	humanoid.PlatformStand = true

	-- VectorForce cân bằng trọng lực nên nhân vật lơ lửng khi không có input
	flyAttachment = Instance.new("Attachment")
	flyAttachment.Parent = root

	flyForce = Instance.new("VectorForce")
	flyForce.Attachment0 = flyAttachment
	flyForce.RelativeTo = Enum.ActuatorRelativeTo.World
	flyForce.ApplyAtCenterOfMass = true
	flyForce.Parent = root

	-- PreSimulation chạy ngay trước physics nên lực và vận tốc có hiệu lực ngay frame đó
	flyConnection = RunService.PreSimulation:Connect(function()
		local character = player.Character
		local currentRoot = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not currentRoot or not hum then
			stopFly()
			return
		end

		local camera = workspace.CurrentCamera
		if not camera then return end

		hum.PlatformStand = true
		flyForce.Force = Vector3.new(0, currentRoot.AssemblyMass * workspace.Gravity, 0)

		local forward = keyValue(Enum.KeyCode.W) - keyValue(Enum.KeyCode.S)
		local strafe = keyValue(Enum.KeyCode.D) - keyValue(Enum.KeyCode.A)
		local vertical = keyValue(Enum.KeyCode.Space) - keyValue(Enum.KeyCode.LeftShift)

		local direction = camera.CFrame.LookVector * forward
			+ camera.CFrame.RightVector * strafe
			+ Vector3.new(0, vertical, 0)

		if direction.Magnitude > 0 then
			currentRoot.AssemblyLinearVelocity = direction.Unit * values.WalkSpeed
		else
			-- Không có input thì dừng hẳn, không để quán tính trôi đi
			currentRoot.AssemblyLinearVelocity = Vector3.zero
		end
	end)

	refreshFlyButton()
end

local function setFly(state)
	if state then
		startFly()
	else
		stopFly()
	end
end

-- ===== Nametag =====
local function removeNametag(otherPlayer)
	local tag = nametagTags[otherPlayer]
	if tag then
		tag.gui:Destroy()
		nametagTags[otherPlayer] = nil
	end
end

local function createNametag(otherPlayer, character)
	if not nametagOn then return end
	removeNametag(otherPlayer)

	local head = character:WaitForChild("Head", 10)
	if not head or not nametagOn then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = NAMETAG.StudsOffset
	billboard.AlwaysOnTop = true -- Tường vẫn che nametag
	billboard.MaxDistance = NAMETAG.MaxDistance
	billboard.Adornee = head
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = CONFIG.Colors.Panel
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.TextSize = NAMETAG.TextSize
	label.TextColor3 = CONFIG.Colors.Text
	label.Text = otherPlayer.Name
	label.Parent = billboard

	nametagTags[otherPlayer] = { gui = billboard, label = label }
end

local function watchPlayer(otherPlayer)
	if otherPlayer == player or nametagConns[otherPlayer] then return end

	nametagConns[otherPlayer] = {
		otherPlayer.CharacterAdded:Connect(function(character)
			createNametag(otherPlayer, character)
		end),
		otherPlayer.CharacterRemoving:Connect(function()
			removeNametag(otherPlayer)
		end),
	}

	if otherPlayer.Character then
		task.spawn(createNametag, otherPlayer, otherPlayer.Character)
	end
end

local function unwatchPlayer(otherPlayer)
	local conns = nametagConns[otherPlayer]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
	end
	nametagConns[otherPlayer] = nil
	removeNametag(otherPlayer)
end

local function setNametag(state)
	if nametagOn == state then return end
	nametagOn = state

	if state then
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			watchPlayer(otherPlayer)
		end
		nametagPlayerAddedConn = Players.PlayerAdded:Connect(watchPlayer)
		nametagPlayerRemovingConn = Players.PlayerRemoving:Connect(unwatchPlayer)

		-- Throttle: chỉ cập nhật chữ theo khoảng cách mỗi UpdateInterval giây
		nametagUpdateConn = RunService.RenderStepped:Connect(function(dt)
			nametagAccumulator += dt
			if nametagAccumulator < NAMETAG.UpdateInterval then return end
			nametagAccumulator = 0

			local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not localRoot then return end

			for otherPlayer, tag in pairs(nametagTags) do
				local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
				if otherRoot then
					local distance = (otherRoot.Position - localRoot.Position).Magnitude
					tag.label.Text = string.format("%s  [%d m]", otherPlayer.Name, math.floor(distance + 0.5))
				end
			end
		end)
	else
		if nametagUpdateConn then
			nametagUpdateConn:Disconnect()
			nametagUpdateConn = nil
		end
		if nametagPlayerAddedConn then
			nametagPlayerAddedConn:Disconnect()
			nametagPlayerAddedConn = nil
		end
		if nametagPlayerRemovingConn then
			nametagPlayerRemovingConn:Disconnect()
			nametagPlayerRemovingConn = nil
		end
		for otherPlayer in pairs(nametagConns) do
			unwatchPlayer(otherPlayer)
		end
	end

	refreshNametagButton()
end

-- ===== Respawn: tắt noclip và bay =====
player.CharacterAdded:Connect(function(character)
	clearFlyObjects()
	flyOn = false

	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	noclipOn = false
	originalCollide = setmetatable({}, { __mode = "k" })

	refreshNoclipButton()
	refreshFlyButton()

	local humanoid = character:WaitForChild("Humanoid", 10)
	applyMovement(humanoid)
end)

if player.Character then
	task.spawn(function()
		applyMovement(getHumanoid())
	end)
end

-- ===== Giao diện: khung chính =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MovementGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(CONFIG.PanelWidth, CONFIG.HeaderHeight + CONFIG.BodyHeight)
panel.Position = UDim2.fromOffset(20, 120)
panel.BackgroundColor3 = CONFIG.Colors.Panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = CONFIG.Colors.Stroke
stroke.Thickness = 1
stroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, CONFIG.HeaderHeight)
header.BackgroundColor3 = CONFIG.Colors.Header
header.BorderSizePixel = 0
header.Parent = panel

local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -60, 1, 0)
headerLabel.Position = UDim2.fromOffset(12, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextSize = 15
headerLabel.TextColor3 = CONFIG.Colors.Text
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Text = CONFIG.HubName .. "  🗿"
headerLabel.Parent = header

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.fromOffset(26, 26)
minimizeButton.AnchorPoint = Vector2.new(1, 0.5)
minimizeButton.Position = UDim2.new(1, -8, 0.5, 0)
minimizeButton.BackgroundColor3 = CONFIG.Colors.Track
minimizeButton.BorderSizePixel = 0
minimizeButton.AutoButtonColor = false
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 16
minimizeButton.TextColor3 = CONFIG.Colors.Text
minimizeButton.Text = "–"
minimizeButton.Parent = header
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 6)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 0, CONFIG.BodyHeight)
body.Position = UDim2.fromOffset(0, CONFIG.HeaderHeight)
body.BackgroundTransparency = 1
body.Parent = panel

-- ===== Thành phần: nút bật/tắt =====
local function makeToggle(y)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -24, 0, 30)
	button.Position = UDim2.fromOffset(12, y)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = CONFIG.Colors.Text
	button.Parent = body
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	return button
end

local noclipButton = makeToggle(10)
refreshNoclipButton = function()
	noclipButton.BackgroundColor3 = noclipOn and CONFIG.Colors.On or CONFIG.Colors.Off
	noclipButton.Text = "Xuyên tường: " .. (noclipOn and "BẬT" or "TẮT") .. "  (N)"
end
noclipButton.Activated:Connect(function()
	setNoclip(not noclipOn)
end)

local flyButton = makeToggle(48)
refreshFlyButton = function()
	flyButton.BackgroundColor3 = flyOn and CONFIG.Colors.On or CONFIG.Colors.Off
	flyButton.Text = "Bay: " .. (flyOn and "BẬT" or "TẮT") .. "  (F)"
end
flyButton.Activated:Connect(function()
	setFly(not flyOn)
end)

local nametagButton = makeToggle(86)
refreshNametagButton = function()
	nametagButton.BackgroundColor3 = nametagOn and CONFIG.Colors.On or CONFIG.Colors.Off
	nametagButton.Text = "Nametag: " .. (nametagOn and "BẬT" or "TẮT")
end
nametagButton.Activated:Connect(function()
	setNametag(not nametagOn)
end)

-- ===== Thành phần: thanh trượt =====
local function makeSlider(y, labelText, key)
	local config = CONFIG[key]

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, 0, 0, 18)
	label.Position = UDim2.fromOffset(12, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = CONFIG.Colors.SubText
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = body

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.35, -12, 0, 18)
	valueLabel.Position = UDim2.new(0.65, 0, 0, y)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = CONFIG.Colors.On
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = body

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 6)
	track.Position = UDim2.fromOffset(12, y + 28)
	track.BackgroundColor3 = CONFIG.Colors.Track
	track.BorderSizePixel = 0
	track.Parent = body
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = CONFIG.Colors.On
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.AutoButtonColor = false
	knob.Text = ""
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function render()
		local alpha = (values[key] - config.min) / (config.max - config.min)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = string.format("%.1f", values[key])
	end

	-- Chuyển vị trí X thành giá trị, làm tròn về bước 0.5
	local function setFromX(screenX)
		local relative = math.clamp((screenX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local raw = config.min + relative * (config.max - config.min)
		values[key] = math.floor(raw * 2 + 0.5) / 2
		render()
		applyMovement(getHumanoid())
	end

	local function beginDrag(input)
		setFromX(input.Position.X)
		activeDrag = function(pos)
			setFromX(pos.X)
		end
	end

	for _, target in ipairs({ track, knob }) do
		target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end)
	end

	render()
end

makeSlider(10 + 130, "Tốc độ đi (WalkSpeed)", "WalkSpeed")
makeSlider(10 + 130 + 40, "Độ cao nhảy (JumpHeight)", "JumpHeight")

refreshNoclipButton()
refreshFlyButton()
refreshNametagButton()

-- ===== Kéo thả panel =====
header.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local startMouse = Vector2.new(input.Position.X, input.Position.Y)
	local startX = panel.Position.X.Offset
	local startY = panel.Position.Y.Offset

	activeDrag = function(pos)
		local delta = Vector2.new(pos.X, pos.Y) - startMouse
		local screen = screenGui.AbsoluteSize
		local x = math.clamp(startX + delta.X, 0, screen.X - CONFIG.PanelWidth)
		local y = math.clamp(startY + delta.Y, 0, screen.Y - panel.AbsoluteSize.Y)
		panel.Position = UDim2.fromOffset(x, y)
	end
end)

-- ===== Thu gọn / mở rộng =====
local function setPanelVisible(state)
	panelVisible = state
	body.Visible = state
	panel.Size = UDim2.fromOffset(
		CONFIG.PanelWidth,
		state and (CONFIG.HeaderHeight + CONFIG.BodyHeight) or CONFIG.HeaderHeight
	)
	minimizeButton.Text = state and "–" or "+"
end

minimizeButton.Activated:Connect(function()
	setPanelVisible(not panelVisible)
end)

-- ===== Luồng nhập liệu chung =====
UserInputService.InputChanged:Connect(function(input)
	if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		activeDrag(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		activeDrag = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == CONFIG.NoclipKey then
		setNoclip(not noclipOn)
	elseif input.KeyCode == CONFIG.FlyKey then
		setFly(not flyOn)
	elseif input.KeyCode == CONFIG.ToggleGuiKey then
		setPanelVisible(not panelVisible)
	end
end)
