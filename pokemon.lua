-- LocalScript: Auto Boss + Patrol + Auto Fly + Auto Heal (check 3 pet trong workspace.ClientPets)

local Players                  = game:GetService("Players")
local RS                       = game:GetService("ReplicatedStorage")
local player                   = Players.LocalPlayer

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------

-- Vị trí map 1 để đi tuần / check boss
local POS_MAP1                 = Vector3.new(569.3123168945312, 3477.900146484375, -226.80519104003906)
-- Vị trí map 2 để đi tuần / check boss
local POS_MAP2                 = Vector3.new(-2303.7392578125, 39.43812942504883, -1366.6573486328125)
-- Vị trí hồi máu
local POS_HEAL                 = Vector3.new(-2234.548828125, -114.75332641601562, -957.3690185546875)
local HEAL_DURATION            = 10 -- giây đứng heal

-- Thời gian đứng mỗi map khi đi tuần nếu chưa thấy boss
local PATROL_INTERVAL          = 10 -- giây
-- Độ trễ vòng lặp chính
local MAIN_LOOP_DELAY          = 0.2 -- giây

-- Offset cao hơn mặt đất khi teleport vị trí
local TELEPORT_HEIGHT_OFFSET   = 5
-- Offset cao hơn boss khi bám boss
local BOSS_HEIGHT_OFFSET       = 4

-- AUTO HATCH EGG
getgenv().AUTO_EGG_HATCH       = true  -- bật/tắt auto ấp
getgenv().AUTO_EGG_HATCH_DELAY = 2     -- mỗi 2 giây lặp 1 lần
getgenv().AUTO_EGG_ID          = 1     -- id trứng (tham số thứ 2)
getgenv().AUTO_EGG_BATCH       = 9     -- số lượng ấp mỗi lần (tham số thứ 3)

--------------------------------------------------------------------
-- C0 MẪU CỦA BOSS (Motor6D_yao.C0)
--------------------------------------------------------------------

local ClientMonsters           = workspace:WaitForChild("ClientMonsters")
local ClientPetsFolder         = workspace:WaitForChild("ClientPets")

local BOSS_C0                  = {
    -- Boss 1
    Boss1 = CFrame.new(0.010848999, -3.76977253, -7.88153172, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    -- Boss 2
    Boss2 = CFrame.new(1.29150391, -5.08804512, -4.68080807, 1, 0, 0, 0, 1, 0, 0, 0, 1),
}

local EXPECTED_PET_COUNT       = 3

--------------------------------------------------------------------
-- REMOTE TELEPORT MAP 2
--------------------------------------------------------------------

local CommonLib                = RS:WaitForChild("CommonLibrary")
local Tool                     = CommonLib:WaitForChild("Tool")
local RemoteManager            = Tool:WaitForChild("RemoteManager")
local Funcs                    = RemoteManager:WaitForChild("Funcs")
local DataPullFunc             = Funcs:WaitForChild("DataPullFunc")

local function teleportToMap2ByRemote()
    local args = {
        "AreaTeleportToRegionChannel",
        3
    }

    pcall(function()
        DataPullFunc:InvokeServer(unpack(args))
    end)

    print("[AI] Teleport map 2 bằng remote AreaTeleportToRegionChannel, 3")
end

--------------------------------------------------------------------
-- HỖ TRỢ CƠ BẢN
--------------------------------------------------------------------

local function getChar()
    return player.Character or player.CharacterAdded:Wait()
end

local function getHRP()
    local char = getChar()
    return char:WaitForChild("HumanoidRootPart")
end

-- Teleport cao hơn mặt đất 1 chút
local function teleportTo(pos)
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(pos.X, pos.Y + TELEPORT_HEIGHT_OFFSET, pos.Z)
    end
end

--------------------------------------------------------------------
-- AUTO FLY (chống rớt)
--------------------------------------------------------------------

local function enableAutoFly()
    local hrp = getHRP()
    if not hrp then return end

    -- Xoá BodyVelocity cũ nếu có
    local old = hrp:FindFirstChild("AutoFlyBV")
    if old then
        old:Destroy()
    end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "AutoFlyBV"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = hrp

    print("[Fly] AutoFly bật (BodyVelocity giữ bạn lơ lửng, không rớt)")
end

-- Bật fly ngay khi script chạy + khi respawn
task.spawn(function()
    getChar()
    enableAutoFly()
    player.CharacterAdded:Connect(function()
        task.wait(1)
        enableAutoFly()
    end)
end)

--------------------------------------------------------------------
-- AUTO HEAL: nếu 1 trong 3 pet (ClientPets.Pet_1/2/3) bị mất thì đi heal
--------------------------------------------------------------------

local function needHeal()
    -- Đếm số lượng pet hiện có trong workspace.ClientPets
    local count = #ClientPetsFolder:GetChildren()

    if count < EXPECTED_PET_COUNT then
        print(string.format("[Heal] ClientPets còn %d/%d pet → cần hồi máu", count, EXPECTED_PET_COUNT))
        return true
    end

    return false
end


local function doHeal()
    print("[Heal] Tele về vị trí hồi máu...")
    teleportTo(POS_HEAL)

    local t = 0
    while t < HEAL_DURATION do
        task.wait(1)
        t += 1
    end

    print("[Heal] Hồi máu xong, tiếp tục vòng lặp")
end

--------------------------------------------------------------------
-- BOSS: NHẬN DIỆN THEO Motor6D_yao.C0
--------------------------------------------------------------------

local function getMonsterC0(monster)
    if not monster then return nil end

    local shower = monster:FindFirstChild("Shower")
    if not shower then return nil end

    local yao = shower:FindFirstChild("yao")
    if not yao then return nil end

    local motor = yao:FindFirstChild("Motor6D_yao")
    if not motor or not motor:IsA("Motor6D") then return nil end

    return motor.C0
end

local function approx(a, b)
    return math.abs(a - b) < 0.0001
end

local function sameC0(a, b)
    if not a or not b then return false end

    local pa, pb = a.Position, b.Position
    return approx(pa.X, pb.X)
        and approx(pa.Y, pb.Y)
        and approx(pa.Z, pb.Z)
end

local function findMonsterByC0(targetC0)
    if not targetC0 then return nil end

    for _, monster in ipairs(ClientMonsters:GetChildren()) do
        local c0 = getMonsterC0(monster)
        if c0 and sameC0(c0, targetC0) then
            return monster
        end
    end

    return nil
end

local function getBoss1()
    return findMonsterByC0(BOSS_C0.Boss1)
end

local function getBoss2()
    return findMonsterByC0(BOSS_C0.Boss2)
end

local function isBossAlive(boss)
    if not boss or boss.Parent == nil then return false end
    local hum = boss:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health > 0
    end
    return true
end

--------------------------------------------------------------------
-- ĐÁNH BOSS: TELE LẠI GẦN & ĐỢI ĐẾN KHI BOSS CHẾT HOẶC CẦN HEAL
--------------------------------------------------------------------

local function fightBoss(boss, label)
    if not boss then return "NO_BOSS" end
    label = label or "Boss"

    print("[AI] Bắt đầu đánh", label, "model:", boss.Name)

    while isBossAlive(boss) do
        -- nếu thiếu 1 trong 3 pet → dừng đánh, về heal
        if needHeal() then
            print("[AI]", label, "→ thiếu pet, dừng đánh để hồi máu")
            return "NEED_HEAL"
        end

        local hrp  = getHRP()
        local root = boss:FindFirstChild("HumanoidRootPart") or boss.PrimaryPart

        if hrp and root then
            -- Đứng cách boss 3 stud phía sau, và cao hơn BOSS_HEIGHT_OFFSET
            local base = root.CFrame * CFrame.new(0, 0, 3)
            hrp.CFrame = base * CFrame.new(0, BOSS_HEIGHT_OFFSET, 0)
        end

        task.wait(0.3)
    end

    print("[AI]", label, "đã chết")
    return "BOSS_DEAD"
end

--------------------------------------------------------------------
-- ĐI TUẦN 2 MAP KHI CẢ 2 BOSS ĐỀU CHẾT
-- Map 1 = teleportTo (Vector3)
-- Map 2 = teleportToMap2ByRemote (Remote)
--------------------------------------------------------------------

local function patrolTwoMaps()
    -- Đi map 1
    print("[AI] Đi tuần map 1 để check boss")
    teleportTo(POS_MAP1)

    local t = 0
    while t < PATROL_INTERVAL do
        -- nếu thiếu pet → về heal luôn
        if needHeal() then
            doHeal()
            return
        end

        local b1 = getBoss1()
        local b2 = getBoss2()
        if isBossAlive(b1) or isBossAlive(b2) then
            print("[AI] Phát hiện boss spawn khi đang ở map 1")
            return
        end
        task.wait(0.5)
        t = t + 0.5
    end

    -- Đi map 2 bằng vị trí
    print("[AI] Đi tuần map 2 để check boss")
    teleportTo(POS_MAP2)

    t = 0
    while t < PATROL_INTERVAL do
        if needHeal() then
            doHeal()
            return
        end

        local b1 = getBoss1()
        local b2 = getBoss2()
        if isBossAlive(b1) or isBossAlive(b2) then
            print("[AI] Phát hiện boss spawn khi đang ở map 2")
            return
        end
        task.wait(0.5)
        t = t + 0.5
    end
end

--------------------------------------------------------------------
-- VÒNG LẶP CHÍNH
-- Ưu tiên: HEAL → Boss1 → Boss2 → Patrol 2 map
--------------------------------------------------------------------

task.spawn(function()
    while true do
        -- 1. Ưu tiên heal nếu thiếu 1 trong 3 pet
        if needHeal() then
            doHeal()
        end

        local boss1 = getBoss1()
        local boss2 = getBoss2()

        if isBossAlive(boss1) then
            local result = fightBoss(boss1, "Boss1")
            if result == "NEED_HEAL" then
                doHeal()
            elseif result == "BOSS_DEAD" then
                -- nghỉ 2 giây sau khi giết boss 1
                task.wait(2)
            end
        elseif isBossAlive(boss2) then
            local result = fightBoss(boss2, "Boss2")
            if result == "NEED_HEAL" then
                doHeal()
            elseif result == "BOSS_DEAD" then
                -- nghỉ 2 giây sau khi giết boss 2
                task.wait(2)
            end
        else
            patrolTwoMaps()
        end


        task.wait(MAIN_LOOP_DELAY)
    end
end)

--------------------------------------------------------------------
-- AUTO HATCH EGG (EggHatchStartChannel + EggHatchTakenChannel)
-- Mỗi ~2 giây ấp 1 lần, vòng lặp vô tận khi AUTO_EGG_HATCH = true
--------------------------------------------------------------------

--------------------------------------------------------------------
-- AUTO HATCH EGG (2 slot)
-- Mỗi ~2 giây ấp cả slot 1 và slot 2, vòng lặp vô tận khi AUTO_EGG_HATCH = true
--------------------------------------------------------------------

task.spawn(function()
    if not getgenv().AUTO_EGG_HATCH then
        return
    end

    while getgenv().AUTO_EGG_HATCH do
        local eggId1     = getgenv().AUTO_EGG_ID or 1 -- slot 1
        local amount1    = getgenv().AUTO_EGG_BATCH or 9 -- slot 1
        local eggId2     = 2                          -- slot 2 cố định là 2
        local amount2    = 9                          -- slot 2 luôn 9
        local delay      = getgenv().AUTO_EGG_HATCH_DELAY or 2

        -- ==== SLOT 1 ====
        local argsStart1 = {
            "EggHatchStartChannel",
            eggId1,
            amount1
        }

        pcall(function()
            DataPullFunc:InvokeServer(unpack(argsStart1))
        end)
        print(string.format("[Egg] Slot1 HatchStart: eggId=%d, amount=%d", eggId1, amount1))

        task.wait(0.5)

        local argsTake1 = {
            "EggHatchTakenChannel",
            eggId1
        }

        pcall(function()
            DataPullFunc:InvokeServer(unpack(argsTake1))
        end)
        print(string.format("[Egg] Slot1 HatchTaken: eggId=%d", eggId1))

        -- ==== SLOT 2 ====
        local argsStart2 = {
            "EggHatchStartChannel",
            eggId2,
            amount2
        }

        pcall(function()
            DataPullFunc:InvokeServer(unpack(argsStart2))
        end)
        print(string.format("[Egg] Slot2 HatchStart: eggId=%d, amount=%d", eggId2, amount2))

        task.wait(0.5)

        local argsTake2 = {
            "EggHatchTakenChannel",
            eggId2
        }

        pcall(function()
            DataPullFunc:InvokeServer(unpack(argsTake2))
        end)
        print(string.format("[Egg] Slot2 HatchTaken: eggId=%d", eggId2))

        -- Chờ delay trước khi ấp lượt tiếp theo
        task.wait(delay)
    end
end)

--------------------------------------------------------------------
-- ANTI-AFK: mỗi 60 giây tự nhảy 1 lần
--------------------------------------------------------------------

task.spawn(function()
    while true do
        task.wait(60)  -- 60 giây

        local char = getChar()
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Jump = true
                print("[AntiAFK] Jump 1 cái chống AFK")
            end
        end
    end
end)
