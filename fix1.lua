local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function teleportToPart(part)
    if part and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local root = player.Character.HumanoidRootPart
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
        print("✅ Đã dịch chuyển đến:", part:GetFullName())
    else
        warn("❌ Không thể dịch chuyển – thiếu Part hoặc Character.")
    end
end

local function getSecondModelFromLevels()
    local levels = workspace:FindFirstChild("Levels")
    if not levels then return nil end

    local children = levels:GetChildren()
    table.sort(children, function(a, b) return a.Name < b.Name end)

    if #children >= 2 then
        return children[2]
    end
    return nil
end

-- Thử tìm Model trong Collectibles
local function tryGetCollectiblesTarget()
    local secondModel = getSecondModelFromLevels()
    if not secondModel then return nil end

    local map = secondModel:FindFirstChild("Map")
    if not map then return nil end

    local innerLevels = map:FindFirstChild("Levels")
    if not innerLevels then return nil end

    local model1 = innerLevels:FindFirstChild("1")
    if not model1 then return nil end

    local collectibles = model1:FindFirstChild("Collectibles")
    if not collectibles then return nil end

    local finalModel = collectibles:FindFirstChild("Model")
    if finalModel and finalModel:IsA("Model") then
        return finalModel.PrimaryPart or finalModel:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

-- Nếu không có, thử tìm Checkpoints > 3
local function tryGetCheckpointFallback()
    local secondModel = getSecondModelFromLevels()
    if not secondModel then return nil end

    local map = secondModel:FindFirstChild("Map")
    if not map then return nil end

    local innerLevels = map:FindFirstChild("Levels")
    if not innerLevels then return nil end

    local model1 = innerLevels:FindFirstChild("1")
    if not model1 then return nil end

    local checkpoints = model1:FindFirstChild("Checkpoints")
    if not checkpoints then return nil end

    local part3 = checkpoints:FindFirstChild("3")
    if part3 and part3:IsA("BasePart") then
        return part3
    end
    return nil
end

-- === Thực thi ===
local target = tryGetCollectiblesTarget()

if target then
    teleportToPart(target)
else
    print("⚠️ Không tìm thấy Collectibles/Model – thử dùng Checkpoints.")
    local fallback = tryGetCheckpointFallback()
    if fallback then
        teleportToPart(fallback)
    else
        warn("❌ Không tìm thấy cả hai vị trí để dịch chuyển.")
    end
end
