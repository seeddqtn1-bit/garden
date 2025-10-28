    --// ===== Auto Rafflesia (flow mới: Lawnmower -> Rafflesia -> bán Rafflesia @ 9900) =====
    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local workspace         = game:GetService("Workspace")

    ----------------------------------------------------------------
    -- Wait for player / character / stats
    ----------------------------------------------------------------
    local player
    repeat player = Players.LocalPlayer; task.wait() until player

    if not player.Character or not player.Character.Parent then
        player.CharacterAdded:Wait()
    end

    local character   = player.Character
    local humanoid    = character:WaitForChild("Humanoid")
    local backpack    = player:WaitForChild("Backpack")
    local leaderstats = player:WaitForChild("leaderstats", 10)
    local cash        = leaderstats:WaitForChild("Cash", 10)

    ----------------------------------------------------------------
    -- Remotes / Map (chỉ chạy khi có Entities)
    ----------------------------------------------------------------
    local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 10)
    local PlaceUnit       = RemoteFunctions:WaitForChild("PlaceUnit", 10)
    local UpgradeUnit     = RemoteFunctions:WaitForChild("UpgradeUnit", 10) -- (không dùng, để sẵn)
    local SellUnit        = RemoteFunctions:WaitForChild("SellUnit", 10)

    local map = workspace:FindFirstChild("Map")
    if not map or not map:FindFirstChild("Entities") then
        return
    end
    local Entities = map:WaitForChild("Entities", 10)

    ----------------------------------------------------------------
    -- Config (flow mới theo yêu cầu)
    ----------------------------------------------------------------
    -- Tool/Unit names
    local raffToolName   = "Rafflesia"
    local raffUnitName   = "unit_rafflesia"

    local lawnToolName   = "Lawnmower"
    local lawnUnitName   = "unit_lawnmower"

    -- Vị trí đứng
    local STAND_POS       = Vector3.new(-335.41595458984375, 61.93030548095703, -840.5299072265625)
    local STAND_JITTER    = 1.0
    local APPROACH_RADIUS = 35
    local RETURN_TO_STAND = true

    -- Chi phí
    local lawnPlaceCost = 700
    local raffPlaceCost = 1250

    -- Cooldown đặt
    local PLACEMENT_COOLDOWN = 1.0

    -- Bán Rafflesia mới khi Cash >= 9400
    local SELL_RAFF_NEW_THRESHOLD = 9400

    -- Lawnmower placement (theo tọa độ bạn cung cấp)
    local LAWN_POS  = Vector3.new(-335.41595458984375, 61.93030548095703, -840.5299072265625)
    local LAWN_PATH = 1
    local LAWN_DIST = 235.79849886894226
    local LAWN_CF   = CFrame.new(
        -335.41595458984375, 61.93030548095703, -840.5299072265625,
        -1, 0, -0,
        -0, 1, -0,
        -0, 0, -1
    )
    local LAWN_ROT  = 180

    -- Rafflesia placement (theo tọa độ bạn cung cấp)
    local NEW_RAFF_POS  = Vector3.new(-324.64892578125, 61.93030548095703, -778.1752319335938)
    local NEW_RAFF_PATH = 1
    local NEW_RAFF_DIST = 159.7854104641804
    local NEW_RAFF_CF   = CFrame.new(
        -324.64892578125, 61.93030548095703, -778.1752319335938,
        -0.6757246851921082, 0, 0.7371541857719421,
        0, 1.0000001192092896, -0,
        -0.7371541857719421, 0, -0.6757246851921082
    )
    local NEW_RAFF_ROT  = 180

    ----------------------------------------------------------------
    -- State
    ----------------------------------------------------------------
    local busy, standingHere = false, false
    local lastPlaceTime = 0
    local standSpot = STAND_POS

    -- Flow: 1 = đặt Lawnmower, 2 = đặt Rafflesia, 3 = xong phần đặt
    local flowIndex = 1
    local awaitingPlaceIndex = nil -- 1 = lawn, 2 = raff
    local newRaffUnitId = nil
    local soldNewRaff = false

    ----------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------
    local function parseCash(v)
        if typeof(v) == "number" then return v end
        if typeof(v) == "string" then
            local s = v:gsub("[^%d%.-]", "")
            return tonumber(s) or 0
        end
        return 0
    end

    local function getCash()
        return parseCash(cash and cash.Value or 0)
    end

    local function getToolByName(name)
        return backpack:FindFirstChild(name) or character:FindFirstChild(name)
    end

    local function dist(a, b)
        return (a - b).Magnitude
    end

    local function moveTo(pos)
        humanoid:MoveTo(pos)
        humanoid.MoveToFinished:Wait()
    end

    local function jitterAround(v, r)
        local ox = (math.random()-0.5) * 2 * r
        local oz = (math.random()-0.5) * 2 * r
        return Vector3.new(v.X + ox, v.Y, v.Z + oz)
    end

    local function goStandOnce()
        if standingHere then return end
        standSpot = jitterAround(STAND_POS, STAND_JITTER)
        moveTo(standSpot)
        standingHere = true
    end

    local function resetFlow()
        busy, standingHere = false, false
        lastPlaceTime = 0
        flowIndex = 1
        awaitingPlaceIndex = nil
        newRaffUnitId = nil
        soldNewRaff = false
        task.defer(goStandOnce)
    end

    ----------------------------------------------------------------
    -- Bắt ID unit sau khi đặt (đủ để bán Rafflesia vừa đặt)
    ----------------------------------------------------------------
    Entities.ChildAdded:Connect(function(child)
        if awaitingPlaceIndex == 2 and child.Name == raffUnitName then
            local idValue = child:GetAttribute("ID")
            if idValue then newRaffUnitId = idValue end
        end
    end)

    -- Reset khi map sạch Entities
    Entities.ChildRemoved:Connect(function()
        task.delay(1, function()
            if #Entities:GetChildren() == 0 then resetFlow() end
        end)
    end)

    ----------------------------------------------------------------
    -- Đặt theo trình tự mới: 1) Lawnmower -> 2) Rafflesia
    ----------------------------------------------------------------
    local function placeNext()
        if busy then return end
        if (os.clock() - lastPlaceTime) < PLACEMENT_COOLDOWN then return end

        -- Bước 1: đặt Lawnmower
        if flowIndex == 1 then
            if getCash() < lawnPlaceCost then return end

            goStandOnce()

            local tool = getToolByName(lawnToolName)
            if not tool then return end

            local here = character.PrimaryPart and character.PrimaryPart.Position or standSpot
            local needApproach = (dist(here, LAWN_POS) > APPROACH_RADIUS)
            local cameCloser = false
            if needApproach then
                moveTo(jitterAround(LAWN_POS, 1.0))
                cameCloser = true
            end

            busy = true
            humanoid:EquipTool(tool)
            task.wait(0.05)

            awaitingPlaceIndex = 1
            local args = {
                lawnUnitName,
                {
                    Valid = true,
                    PathIndex = LAWN_PATH,
                    Position = LAWN_POS,
                    DistanceAlongPath = LAWN_DIST,
                    CF = LAWN_CF,
                    Rotation = LAWN_ROT
                }
            }

            local ok = pcall(function()
                return PlaceUnit:InvokeServer(unpack(args))
            end)

            pcall(function() humanoid:UnequipTools() end)

            if ok then
                lastPlaceTime = os.clock()
                flowIndex = 2
                task.wait(PLACEMENT_COOLDOWN)
            end

            if cameCloser and RETURN_TO_STAND then
                moveTo(standSpot)
            end

            awaitingPlaceIndex = nil
            busy = false
            return
        end

        -- Bước 2: đặt Rafflesia
        if flowIndex == 2 then
            if getCash() < raffPlaceCost then return end

            goStandOnce()

            local tool = getToolByName(raffToolName)
            if not tool then return end

            local here = character.PrimaryPart and character.PrimaryPart.Position or standSpot
            local needApproach = (dist(here, NEW_RAFF_POS) > APPROACH_RADIUS)
            local cameCloser = false
            if needApproach then
                moveTo(jitterAround(NEW_RAFF_POS, 1.0))
                cameCloser = true
            end

            busy = true
            humanoid:EquipTool(tool)
            task.wait(0.05)

            awaitingPlaceIndex = 2 -- để bắt ID Rafflesia
            local args = {
                raffUnitName,
                {
                    Valid = true,
                    PathIndex = NEW_RAFF_PATH,
                    Position = NEW_RAFF_POS,
                    DistanceAlongPath = NEW_RAFF_DIST,
                    CF = NEW_RAFF_CF,
                    Rotation = NEW_RAFF_ROT
                }
            }

            local ok = pcall(function()
                return PlaceUnit:InvokeServer(unpack(args))
            end)

            pcall(function() humanoid:UnequipTools() end)

            if ok then
                lastPlaceTime = os.clock()
                flowIndex = 3 -- xong phần đặt
                task.wait(PLACEMENT_COOLDOWN)
            end

            if cameCloser and RETURN_TO_STAND then
                moveTo(standSpot)
            end

            awaitingPlaceIndex = nil
            busy = false
            return
        end
    end

    ----------------------------------------------------------------
    -- Bán Rafflesia vừa đặt khi tiền >= 9900
    ----------------------------------------------------------------
    local function trySellNewRaff()
        if soldNewRaff then return end
        if flowIndex < 3 then return end
        if getCash() < SELL_RAFF_NEW_THRESHOLD then return end
        if busy then return end
        if not newRaffUnitId then return end

        busy = true
        local ok = pcall(function()
            return SellUnit:InvokeServer(newRaffUnitId)
        end)
        if ok then
            soldNewRaff = true
        end
        busy = false
    end

    ----------------------------------------------------------------
    -- Anti-AFK
    ----------------------------------------------------------------
    task.spawn(function()
        local VIM = game:GetService("VirtualInputManager")
        while true do
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            task.wait(60)
        end
    end)

    ----------------------------------------------------------------
    -- Driver
    ----------------------------------------------------------------
    local function drive()
        placeNext()       -- 1) Lawnmower -> 2) Rafflesia
        trySellNewRaff()  -- 3) Bán Rafflesia khi >= 9900
    end

    goStandOnce()
    task.spawn(function()
        while true do
            drive()
            task.wait(0.6)
        end
    end)
    cash:GetPropertyChangedSignal("Value"):Connect(drive)
    drive()
