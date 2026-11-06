-- Place this Script in ServerScriptService.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local REMOTE_NAME = "GeneratorRepairRemote"
local GENERATOR_TAG = "Generator"
local GENERATOR_FOLDER_NAME = "Generators"
local PROMPT_NAME = "RepairPrompt"
local MAX_PROGRESS = 100
local FAILURE_PENALTY = 15
local REPAIR_DISTANCE = 14
local ATTEMPT_TIMEOUT = 12
local BAR_PERIOD = 2.4

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

local activeByPlayer = {}
local playerByGenerator = {}
local attemptSerial = 0

local function getGeneratorPart(generator)
	if generator:IsA("BasePart") then
		return generator
	end
	if generator:IsA("Model") then
		return generator.PrimaryPart or generator:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getProgress(generator)
	local value = generator:GetAttribute("RepairProgress")
	if typeof(value) ~= "number" then
		value = 0
	end
	return math.clamp(value, 0, MAX_PROGRESS)
end

local function setProgress(generator, value)
	generator:SetAttribute("RepairProgress", math.clamp(value, 0, MAX_PROGRESS))
end

local function getGeneratorFromPrompt(prompt)
	local current = prompt.Parent
	while current and current ~= Workspace do
		if current:GetAttribute("IsGenerator") == true or CollectionService:HasTag(current, GENERATOR_TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isNearGenerator(player, generator)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = getGeneratorPart(generator)
	return root ~= nil and part ~= nil and (root.Position - part.Position).Magnitude <= REPAIR_DISTANCE
end

local function clearPlayerAttempt(player)
	local attempt = activeByPlayer[player]
	if attempt then
		if playerByGenerator[attempt.generator] == player then
			playerByGenerator[attempt.generator] = nil
		end
		activeByPlayer[player] = nil
	end
end

local function ensurePrompt(generator)
	if not (generator:IsA("Model") or generator:IsA("BasePart")) then
		return
	end
	local part = getGeneratorPart(generator)
	if not part then
		return
	end
	generator:SetAttribute("IsGenerator", true)
	if generator:GetAttribute("RepairProgress") == nil then
		setProgress(generator, 0)
	end

	local prompt = part:FindFirstChild(PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = "Repair Generator"
		prompt.ObjectText = generator.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = REPAIR_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if prompt:GetAttribute("RepairConnected") then
		return
	end
	prompt:SetAttribute("RepairConnected", true)
	prompt.Triggered:Connect(function(player)
		if getProgress(generator) >= MAX_PROGRESS then
			return
		end
		if activeByPlayer[player] or playerByGenerator[generator] or not isNearGenerator(player, generator) then
			return
		end
		attemptSerial += 1
		local attemptId = tostring(attemptSerial) .. "-" .. tostring(math.random(1000, 9999))
		activeByPlayer[player] = {
			generator = generator,
			startedAt = Workspace:GetServerTimeNow(),
			attemptId = attemptId,
		}
		playerByGenerator[generator] = player
		remote:FireClient(player, "Start", generator, activeByPlayer[player].startedAt, BAR_PERIOD, attemptId, getProgress(generator))
	end)
end

local function classifyPosition(position)
	if position < 0.16 or position > 0.84 then
		return "Worst", 0
	elseif position < 0.31 or position > 0.69 then
		return "Bad", 6
	elseif position < 0.47 or position > 0.53 then
		return "Good", 10
	else
		return "Perfect", 15
	end
end

remote.OnServerEvent:Connect(function(player, action, attemptId)
	if action ~= "Hit" then
		return
	end
	local attempt = activeByPlayer[player]
	if not attempt or attempt.attemptId ~= attemptId then
		return
	end
	local generator = attempt.generator
	if not generator.Parent or not isNearGenerator(player, generator) or Workspace:GetServerTimeNow() - attempt.startedAt > ATTEMPT_TIMEOUT then
		clearPlayerAttempt(player)
		remote:FireClient(player, "Cancelled", "The repair attempt expired.")
		return
	end

	local elapsed = Workspace:GetServerTimeNow() - attempt.startedAt
	local cycle = (elapsed % BAR_PERIOD) / BAR_PERIOD
	local position = cycle <= 0.5 and cycle * 2 or 2 - cycle * 2
	local result, reward = classifyPosition(position)
	local progress = getProgress(generator)
	if result == "Worst" then
		setProgress(generator, progress - FAILURE_PENALTY)
		clearPlayerAttempt(player)
		remote:FireClient(player, "Result", result, getProgress(generator), "The generator shorted out. Try again.")
		return
	end

	local newProgress = math.min(MAX_PROGRESS, progress + reward)
	setProgress(generator, newProgress)
	clearPlayerAttempt(player)
	if newProgress >= MAX_PROGRESS then
		remote:FireClient(player, "Result", result, newProgress, "Generator repaired!")
	else
		remote:FireClient(player, "Result", result, newProgress, string.format("Repair progress: %d%%", newProgress))
	end
end)

local function registerGenerator(instance)
	ensurePrompt(instance)
end

for _, instance in ipairs(CollectionService:GetTagged(GENERATOR_TAG)) do
	registerGenerator(instance)
end
CollectionService:GetInstanceAddedSignal(GENERATOR_TAG):Connect(registerGenerator)

local generatorFolder = Workspace:FindFirstChild(GENERATOR_FOLDER_NAME)
if generatorFolder then
	for _, instance in ipairs(generatorFolder:GetChildren()) do
		registerGenerator(instance)
	end
	generatorFolder.ChildAdded:Connect(registerGenerator)
end

Players.PlayerRemoving:Connect(clearPlayerAttempt)
