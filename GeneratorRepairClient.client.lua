-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GeneratorRepairRemote")
local gui
local markerConnection
local activeAttemptId
local barPeriod
local startedAt
local resultLocked = false

local COLORS = {
	Worst = Color3.fromRGB(235, 75, 75),
	Bad = Color3.fromRGB(235, 170, 65),
	Good = Color3.fromRGB(95, 205, 115),
	Perfect = Color3.fromRGB(70, 185, 235),
}

local function removeGui()
	if markerConnection then
		markerConnection:Disconnect()
		markerConnection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	activeAttemptId = nil
	resultLocked = false
end

local function makeLabel(parent, text, size, position, color, fontSize)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = false
	label.TextSize = fontSize
	label.Font = Enum.Font.GothamBold
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function showResult(result, progress, message)
	if not gui then
		return
	end
	resultLocked = true
	local resultLabel = gui:FindFirstChild("Result", true)
	local progressLabel = gui:FindFirstChild("Progress", true)
	if resultLabel then
		resultLabel.Text = result .. "!"
		resultLabel.TextColor3 = COLORS[result] or Color3.new(1, 1, 1)
	end
	if progressLabel then
		progressLabel.Text = message .. "  (" .. tostring(progress) .. "%)"
	end
	task.delay(1.25, removeGui)
end

local function createGui(progress)
	removeGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "GeneratorRepairGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.72)
	panel.Size = UDim2.fromOffset(560, 150)
	panel.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	makeLabel(panel, "REPAIR GENERATOR", UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.04), Color3.fromRGB(245, 245, 245), 20)
	local progressLabel = makeLabel(panel, "Progress: " .. tostring(progress) .. "%", UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.78), Color3.fromRGB(190, 198, 210), 14)
	progressLabel.Name = "Progress"
	local resultLabel = makeLabel(panel, "Press SPACE or click when the marker is in a zone", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.22), Color3.fromRGB(220, 225, 235), 14)
	resultLabel.Name = "Result"

	local bar = Instance.new("Frame")
	bar.Name = "TimingBar"
	bar.Position = UDim2.fromScale(0.05, 0.47)
	bar.Size = UDim2.fromScale(0.9, 0.2)
	bar.BackgroundColor3 = COLORS.Worst
	bar.BorderSizePixel = 0
	bar.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 5)
	barCorner.Parent = bar

	local zones = {
		{0, 0.16, "Worst"}, {0.16, 0.15, "Bad"}, {0.31, 0.16, "Good"},
		{0.47, 0.06, "Perfect"}, {0.53, 0.16, "Good"}, {0.69, 0.15, "Bad"}, {0.84, 0.16, "Worst"},
	}
	for _, zoneData in ipairs(zones) do
		local zone = Instance.new("Frame")
		zone.Position = UDim2.fromScale(zoneData[1], 0)
		zone.Size = UDim2.fromScale(zoneData[2], 1)
		zone.BackgroundColor3 = COLORS[zoneData[3]]
		zone.BorderSizePixel = 0
		zone.Parent = bar
	end

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.new(0, 5, 1.8, 0)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.BorderSizePixel = 0
	marker.ZIndex = 3
	marker.Parent = bar
	return marker
end

local function hit()
	if activeAttemptId and not resultLocked then
		remote:FireServer("Hit", activeAttemptId)
	end
end

local function startAttempt(serverStartedAt, serverPeriod, attemptId, progress)
	local marker = createGui(progress)
	startedAt = serverStartedAt
	barPeriod = serverPeriod
	activeAttemptId = attemptId
	markerConnection = RunService.RenderStepped:Connect(function()
		if not marker.Parent then
			return
		end
		local elapsed = workspace:GetServerTimeNow() - startedAt
		local cycle = (elapsed % barPeriod) / barPeriod
		local position = cycle <= 0.5 and cycle * 2 or 2 - cycle * 2
		marker.Position = UDim2.fromScale(position, 0.5)
	end)
end

remote.OnClientEvent:Connect(function(action, a, b, c, d, e)
	if action == "Start" then
		startAttempt(b, c, d, e)
	elseif action == "Result" then
		showResult(a, b, c)
	elseif action == "Cancelled" then
		removeGui()
	end
end)

local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Space then
		hit()
	end
end)

local function createButton()
	if not gui then
		return
	end
	local button = Instance.new("TextButton")
	button.Name = "HitButton"
	button.Text = "HIT"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.93)
	button.Size = UDim2.fromOffset(100, 28)
	button.BackgroundColor3 = Color3.fromRGB(55, 65, 85)
	button.Parent = gui
	button.Activated:Connect(hit)
end

remote.OnClientEvent:Connect(function(action)
	if action == "Start" then
		task.defer(createButton)
	end
end)

player.CharacterRemoving:Connect(removeGui)
