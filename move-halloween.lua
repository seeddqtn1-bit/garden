local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')

----------------------------------------------------------------
-- Chờ LocalPlayer + Character
----------------------------------------------------------------
local player = Players.LocalPlayer
while not player do task.wait() end
if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end
local character = player.Character
local hrp = character:WaitForChild('HumanoidRootPart')

----------------------------------------------------------------
-- Giảm đồ họa + ẩn quái
----------------------------------------------------------------
local function hideCharacter(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA('BasePart') then
            part.LocalTransparencyModifier = 1
        elseif part:IsA('Decal') then
            part.Transparency = 1
        end
    end
end

local function hideEntities()
    local EntitiesFolder = workspace:FindFirstChild('Map')
        and workspace.Map:FindFirstChild('Entities')
    if not EntitiesFolder then return end
    local function processEntity(entity)
        for _, obj in ipairs(entity:GetDescendants()) do
            if obj:IsA('BasePart') then
                obj.LocalTransparencyModifier = 1
                obj.CanCollide = false
            elseif obj:IsA('Decal') or obj:IsA('Texture') then
                obj.Transparency = 1
            end
        end
        local anchor = entity:FindFirstChild('Anchor')
        if anchor and anchor:FindFirstChild('HPHolder') then
            for _, obj in ipairs(anchor.HPHolder:GetDescendants()) do
                if obj:IsA('BasePart') then
                    obj.LocalTransparencyModifier = 1
                elseif obj:IsA('Decal') or obj:IsA('Texture') then
                    obj.Transparency = 1
                elseif obj:IsA('BillboardGui') or obj:IsA('SurfaceGui') then
                    obj.Enabled = false
                end
            end
        end
    end
    for _, entity in ipairs(EntitiesFolder:GetChildren()) do processEntity(entity) end
    EntitiesFolder.ChildAdded:Connect(function(child)
        task.wait(0.2)
        processEntity(child)
    end)
end

local function enableLow()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e6
    Lighting.Brightness = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.EnvironmentDiffuseScale = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA('ParticleEmitter') or v:IsA('Trail') or v:IsA('Beam')
            or v:IsA('Fire') or v:IsA('Smoke') or v:IsA('Sparkles') then
            v.Enabled = false
        elseif v:IsA('Decal') or v:IsA('Texture') then
            v.Transparency = 1
        elseif v:IsA('BasePart') then
            v.Material = Enum.Material.SmoothPlastic
        elseif v:IsA('SpecialMesh') then
            v.VertexColor = Vector3.new(0,0,0)
        end
    end
    local char = player.Character or player.CharacterAdded:Wait()
    hideCharacter(char)
    hideEntities()
end

enableLow()
player.CharacterAdded:Connect(function(char)
    char:WaitForChild('HumanoidRootPart')
    task.wait(1)
    hideCharacter(char)
end)

----------------------------------------------------------------
-- Hàm hỗ trợ
----------------------------------------------------------------
local function SafeTeleport(targetPos, duration)
    local tweenInfo = TweenInfo.new(duration or 1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local goal = { CFrame = CFrame.new(targetPos) }
    local tween = TweenService:Create(hrp, tweenInfo, goal)
    tween:Play()
    tween.Completed:Wait()
end

local function IsInLobby()
    local Map = workspace:FindFirstChild('Map')
    return Map and Map:FindFirstChild('Garden') ~= nil
end
local function IsInFarm() return not IsInLobby() end

----------------------------------------------------------------
-- Lobby actions
----------------------------------------------------------------
local function DoLobbyActions()
    local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions')
 --   local LobbySetMap = RemoteFunctions:FindFirstChild('LobbySetMap_9')
    local LobbySetMaxPlayers = RemoteFunctions:FindFirstChild('LobbySetMaxPlayers_21')
    local waypoints = {
        Vector3.new(103.1913, 65.7766, 851.7170),
        Vector3.new(184.1986, 66.9051, 803.2827),
    }

    local function getCharacter()
        local char = player.Character or player.CharacterAdded:Wait()
        local humanoid = char:WaitForChild('Humanoid', 10)
        local root = char:WaitForChild('HumanoidRootPart', 10)
        return humanoid, root
    end

    local function reachedTarget(pos, target, range)
        return (pos - target).Magnitude <= (range or 3)
    end

    local function moveThroughWaypoints()
        local humanoid, root = getCharacter()
        for _, wp in ipairs(waypoints) do
            local arrived = false
            repeat
                if not ScriptEnabled then return end
                humanoid:MoveTo(wp)
                task.wait(0.15)
                if reachedTarget(root.Position, wp, 3) then
                    arrived = true
                end
            until arrived or not ScriptEnabled
        end
    end

    local function invokeRemotes()
        if LobbySetMap then
            for i=1,3 do
                if not ScriptEnabled then return end
                pcall(function() LobbySetMap:InvokeServer('map_back_garden') end)
                task.wait(1)
            end
        end
        if LobbySetMaxPlayers then
            for i=1,3 do
                if not ScriptEnabled then return end
                pcall(function() LobbySetMaxPlayers:InvokeServer(1) end)
                task.wait(1)
            end
        end
    end

    while IsInLobby() and ScriptEnabled do
        moveThroughWaypoints()
        if not ScriptEnabled then break end
        invokeRemotes()
        local t=0
        repeat task.wait(1); t+=1 until not IsInLobby() or t>=10 or not ScriptEnabled
    end
end

----------------------------------------------------------------
-- Farm actions
----------------------------------------------------------------
local function DoFarmActions()
    local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions')
    local ChangeTickSpeed = RemoteFunctions:WaitForChild('ChangeTickSpeed')
    local SkipWave = RemoteFunctions:WaitForChild('SkipWave')
    local PlaceDifficultyVote = RemoteFunctions:WaitForChild('PlaceDifficultyVote')

    pcall(function() ChangeTickSpeed:InvokeServer(2) end)

    task.spawn(function()
        local guiPath = nil
        pcall(function()
            guiPath = player.PlayerGui:WaitForChild('GameGui',10)
                :WaitForChild('Screen',10)
                :WaitForChild('Middle',10)
                :WaitForChild('DifficultyVote',10)
        end)
        if guiPath then
            while IsInFarm() and ScriptEnabled do
                pcall(function() PlaceDifficultyVote:InvokeServer('dif_impossible') end)
                task.wait(2)
            end
        end
    end)

    while IsInFarm() and ScriptEnabled do
        task.wait(0.5)
        pcall(function() SkipWave:InvokeServer('y') end)
    end
end

----------------------------------------------------------------
-- RestartGame spam
----------------------------------------------------------------
task.spawn(function()
    local RestartGame = ReplicatedStorage:WaitForChild('RemoteFunctions'):WaitForChild('RestartGame')
    while true do
        if ScriptEnabled then
            pcall(function() RestartGame:InvokeServer() end)
        end
        task.wait(2)
    end
end)

----------------------------------------------------------------
-- Overlay info
----------------------------------------------------------------
local PlayerGui = player:WaitForChild('PlayerGui')
local screenGui = Instance.new('ScreenGui')
screenGui.Name = 'FullGameOverlay'
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local background = Instance.new('Frame')
background.Size = UDim2.new(1,0,1,0)
background.BackgroundColor3 = Color3.fromRGB(0,0,0)
background.BackgroundTransparency = 0.7
background.BorderSizePixel = 0
background.Parent = screenGui

local infoFrame = Instance.new('Frame')
infoFrame.Size = UDim2.new(0.4,0,0.2,0)
infoFrame.AnchorPoint = Vector2.new(0.5,0.5)
infoFrame.Position = UDim2.new(0.5,0,0.5,0)
infoFrame.BackgroundTransparency = 1
infoFrame.Parent = background

local nameLabel = Instance.new('TextLabel')
nameLabel.Size = UDim2.new(1,0,0.6,0)
nameLabel.Text = player.Name
nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
nameLabel.BackgroundTransparency = 1
nameLabel.TextScaled = true
nameLabel.Font = Enum.Font.GothamBlack
nameLabel.TextStrokeTransparency = 0
nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
nameLabel.Parent = infoFrame

local seedLabel = Instance.new('TextLabel')
seedLabel.Size = UDim2.new(1,0,0.4,0)
seedLabel.Position = UDim2.new(0,0,0.6,0)
seedLabel.Text = 'Seeds: 0'
seedLabel.TextColor3 = Color3.fromRGB(0,255,128)
seedLabel.BackgroundTransparency = 1
seedLabel.TextScaled = true
seedLabel.Font = Enum.Font.GothamBold
seedLabel.TextStrokeTransparency = 0
seedLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
seedLabel.Parent = infoFrame

local leaderstats = player:WaitForChild('leaderstats')
local seeds = leaderstats:WaitForChild('Seeds')
seeds.Changed:Connect(function(v) seedLabel.Text = 'Seeds: '..v end)
seedLabel.Text = 'Seeds: '..seeds.Value

----------------------------------------------------------------
-- Toggle ON/OFF Button
----------------------------------------------------------------
local toggleGui = Instance.new('ScreenGui')
toggleGui.Name = 'ToggleGui'
toggleGui.ResetOnSpawn = false
toggleGui.Parent = PlayerGui

local toggleButton = Instance.new('TextButton')
toggleButton.Size = UDim2.new(0, 80, 0, 40)
toggleButton.Position = UDim2.new(1, -90, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(40,120,40)
toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 20
toggleButton.Text = "ON"
toggleButton.Parent = toggleGui

ScriptEnabled = true

toggleButton.MouseButton1Click:Connect(function()
    ScriptEnabled = not ScriptEnabled
    if ScriptEnabled then
        toggleButton.Text = "ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(40,120,40)
        screenGui.Enabled = true
        print("[Toggle] Script BẬT lại")
    else
        toggleButton.Text = "OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(120,40,40)
        screenGui.Enabled = false
        print("[Toggle] Script TẮT + Ẩn overlay")
    end
end)

----------------------------------------------------------------
-- Main loop
----------------------------------------------------------------
while true do
    if ScriptEnabled then
        if IsInLobby() then
            DoLobbyActions()
        elseif IsInFarm() then
            DoFarmActions()
        end
    end
    task.wait(1)
end
