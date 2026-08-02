
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local BRUTE_FORCE = true
local BRUTE_FORCE_MAGIC_NUMBER = 1000
local VISIBLE = false

local staticOffsetsR6 = {
    ["Head"] = Vector3.new(0, 1.5, 0),
    ["Left Arm"] = Vector3.new(-1.5, 0, 0),
    ["Right Arm"] = Vector3.new(1.5, 0, 0),
    ["Left Leg"] = Vector3.new(-0.5, -2, 0),
    ["Right Leg"] = Vector3.new(0.5, -2, 0),
}

local staticOffsetsR15 = {
    ["Head"] = Vector3.new(0, 1.5, 0),
    ["UpperTorso"] = Vector3.new(0, 1, 0),
    ["LowerTorso"] = Vector3.new(0, 0, 0),
    ["LeftUpperArm"] = Vector3.new(-0.5, 1, 0),
    ["LeftLowerArm"] = Vector3.new(-0.75, 0.25, 0),
    ["LeftHand"] = Vector3.new(-1, -0.5, 0),
    ["RightUpperArm"] = Vector3.new(0.5, 1, 0),
    ["RightLowerArm"] = Vector3.new(0.75, 0.25, 0),
    ["RightHand"] = Vector3.new(1, -0.5, 0),
    ["LeftUpperLeg"] = Vector3.new(-0.5, -1, 0),
    ["LeftLowerLeg"] = Vector3.new(-0.5, -2, 0),
    ["LeftFoot"] = Vector3.new(-0.5, -3, 0),
    ["RightUpperLeg"] = Vector3.new(0.5, -1, 0),
    ["RightLowerLeg"] = Vector3.new(0.5, -2, 0),
    ["RightFoot"] = Vector3.new(0.5, -3, 0),
}

local function calcCOM(model, offsets)
    local rootPart = model:FindFirstChild("HumanoidRootPart")
        or (model:FindFirstChildOfClass("Humanoid") and model:FindFirstChildOfClass("Humanoid").RootPart)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")

    if not rootPart then return Vector3.zero, 0 end

    local weightedSum = Vector3.zero
    local totalMass = 0

    local rootMass = rootPart:GetMass()
    weightedSum += rootPart.Position * rootMass
    totalMass += rootMass

    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if torso then
        local m = torso:GetMass()
        weightedSum += torso.Position * m
        totalMass += m
    end

    for partName, offset in pairs(offsets) do
        local part = model:FindFirstChild(partName)
        if part then
            local bp = torso or rootPart
            local pos = (bp.CFrame * CFrame.new(offset)).Position
            local m = part:GetMass()
            weightedSum += pos * m
            totalMass += m
        end
    end

    for _, tool in pairs(model:GetChildren()) do
        if tool:IsA("Tool") then
            for _, p in pairs(tool:GetDescendants()) do
                if p:IsA("BasePart") then
                    local m = p:GetMass()
                    weightedSum += p.Position * m
                    totalMass += m
                end
            end
        end
    end

    if totalMass == 0 then return Vector3.zero, 0 end
    return weightedSum / totalMass, totalMass
end

shared.com_balancer_objs = shared.com_balancer_objs or {}

local function setCOM(model, visible, brute_force)
    if not model or not model:IsA("Model") then return end

    if shared.com_balancer_objs[model] then
        shared.com_balancer_objs[model]:Destroy()
        shared.com_balancer_objs[model] = nil
    end

    local root = model:FindFirstChild("HumanoidRootPart")
        or (model:FindFirstChildOfClass("Humanoid") and model:FindFirstChildOfClass("Humanoid").RootPart)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")

    if not root then return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rigType = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
    local offsets = (rigType == "R15") and staticOffsetsR15 or staticOffsetsR6

    for _, part in pairs(model:GetChildren()) do
        if part:IsA("BasePart") then part.Massless = false end
    end

    root.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.Plastic)
    local COM, totalMass = calcCOM(model, offsets)
    local robloxCOM = root.AssemblyCenterOfMass
    if (COM - robloxCOM).Magnitude < 0.11 then return end

    for _, part in pairs(model:GetChildren()) do
        if part:IsA("BasePart") and part ~= root and part.Name ~= "COM_BALANCER" then
            part.Massless = true
        end
    end

    local p = Instance.new("Part")
    shared.com_balancer_objs[model] = p
    p.Name = "COM_BALANCER"
    p.Size = Vector3.one
    p.CustomPhysicalProperties = PhysicalProperties.new(totalMass * (brute_force and BRUTE_FORCE_MAGIC_NUMBER or 1), 0, 0)
    p.CanCollide = false
    p.Anchored = false
    p.Transparency = visible and 0.3 or 1
    p.Parent = model

    root.CustomPhysicalProperties = PhysicalProperties.new(0.0001, root.CurrentPhysicalProperties.Friction, root.CurrentPhysicalProperties.Elasticity)

    local w = Instance.new("Weld")
    w.Part0 = p
    w.Part1 = root
    w.Parent = p
    p.Position = COM
end

local function setupCharacter(char)
    if not char then return end
    task.wait(1)
    setCOM(char, VISIBLE, BRUTE_FORCE)

    char.ChildAdded:Connect(function(c)
        if c.Name ~= "COM_BALANCER" then
            task.wait()
            setCOM(char, VISIBLE, BRUTE_FORCE)
        end
    end)

    char.ChildRemoved:Connect(function(c)
        if c.Name ~= "COM_BALANCER" then
            task.wait()
            setCOM(char, VISIBLE, BRUTE_FORCE)
        end
    end)
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(function(char)
    setupCharacter(char)
end)
