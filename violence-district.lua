local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerESP = {}
local connections = {}

local oldFolder = player:FindFirstChild("ESPController")
if oldFolder then oldFolder:Destroy() end
Instance.new("Folder", player).Name = "ESPController"

local healRemote
do
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local healing = remotes and remotes:FindFirstChild("Healing")
    healRemote = healing and healing:FindFirstChild("HealEvent")
end

local BODY_MOVERS = {
    BodyVelocity = true, BodyPosition = true, BodyGyro = true, BodyForce = true,
}

local COLORS = {
    Killer = Color3.fromRGB(255, 0, 0),
    KillerCovered = Color3.fromRGB(180, 90, 90),
    PlayerNeon = Color3.fromRGB(0, 255, 0),
    PlayerNeonCovered = Color3.fromRGB(120, 200, 120),
    Generator = Color3.fromRGB(225, 225, 225),
    Pallet = Color3.fromRGB(255, 220, 80),
    PalletCovered = Color3.fromRGB(200, 185, 140),
    Nearest = Color3.fromRGB(80, 255, 120),
}

local KILLER_NAMES = {
    ["Stalker"]="The Stalker",["Killer"]="The Killer",["Hidden"]="The Hidden",
    ["Abysswalker"]="The Abysswalker",["Veil"]="The Veil",["Slasher"]="The Slasher",
    ["Masked"]="The Masked",["Cure"]="The Cure",["Butcher"]="The Butcher",
}

-- ==========================================
-- FEATURE STATE
-- ==========================================
local Features = {
    PlayerESP = true,
    GeneratorESP = true,
    PalletESP = true,
    KillerOverlay = true,
    VisualEnhancement = true,
    AutoHeal = true,
    CoreGuiFix = true,
}

-- ==========================================
-- VISUAL ENHANCEMENT
-- ==========================================
local visualEnhanced = false
local originalLighting = {}
local originalAtmospheres = {}
local originalEffects = {}
local disabledParticles = {}

local function ApplyVisualEnhancement()
    originalLighting = {
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
        Brightness = Lighting.Brightness,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
    Lighting.FogEnd = 1e6
    Lighting.FogStart = 1e6
    Lighting.FogColor = Color3.fromRGB(200, 200, 200)
    Lighting.GlobalShadows = false
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            if obj.Enabled then
                disabledParticles[obj] = true
                obj.Enabled = false
            end
        end
    end

    originalAtmospheres = {}
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            originalAtmospheres[obj] = { Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare }
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
        end
    end

    originalEffects = {}
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
            originalEffects[obj] = obj.Parent
            obj.Parent = nil
        end
    end
end

local function RemoveVisualEnhancement()
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.FogStart = originalLighting.FogStart
    Lighting.FogColor = originalLighting.FogColor
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.Brightness = originalLighting.Brightness
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient

    for obj in pairs(disabledParticles) do
        if obj and obj.Parent then obj.Enabled = true end
    end
    disabledParticles = {}

    for obj, data in pairs(originalAtmospheres) do
        if obj and obj.Parent then
            obj.Density = data.Density
            obj.Haze = data.Haze
            obj.Glare = data.Glare
        end
    end
    originalAtmospheres = {}

    for obj, parent in pairs(originalEffects) do
        if obj and parent then obj.Parent = parent end
    end
    originalEffects = {}
end

local function SetVisualEnhancement(on)
    if on == visualEnhanced then return end
    visualEnhanced = on
    if on then ApplyVisualEnhancement() else RemoveVisualEnhancement() end
end

SetVisualEnhancement(true)

workspace.DescendantAdded:Connect(function(obj)
    if visualEnhanced and (obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")) then
        disabledParticles[obj] = true
        obj.Enabled = false
    end
end)

-- ==========================================
-- ESP CREATION
-- ==========================================
local function CreateESP(adornee, visibleColor, coveredColor, name, isPlayer)
    local visible = Instance.new("Highlight")
    visible.Name = name
    visible.Adornee = adornee
    visible.DepthMode = Enum.HighlightDepthMode.Occluded
    visible.FillTransparency = 1
    visible.OutlineTransparency = isPlayer and 0 or 0.3
    visible.OutlineColor = visibleColor
    visible.Parent = adornee

    local hidden = Instance.new("Highlight")
    hidden.Name = name
    hidden.Adornee = adornee
    hidden.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hidden.FillColor = coveredColor
    hidden.FillTransparency = isPlayer and 0.45 or 0.92
    hidden.OutlineTransparency = isPlayer and 0.35 or 0.6
    hidden.OutlineColor = coveredColor
    hidden.Parent = adornee

    local esp = { Alive = true }

    function esp:SetColor(c, cc)
        visible.OutlineColor = c
        if cc then
            hidden.OutlineColor = cc
            hidden.FillColor = cc
        else
            hidden.OutlineColor = c
            hidden.FillColor = c
        end
    end

    function esp:SetVisible(on)
        visible.Enabled = on
        hidden.Enabled = on
    end

    function esp:Destroy()
        self.Alive = false
        if visible then visible:Destroy() end
        if hidden then hidden:Destroy() end
    end

    return esp
end

local function CleanupPlayer(targetPlayer)
    local h = playerESP[targetPlayer]
    if h then h:Destroy() end
    playerESP[targetPlayer] = nil
    local c = connections[targetPlayer]
    if c then
        for _, conn in ipairs(c) do
            if conn.Connected then conn:Disconnect() end
        end
        connections[targetPlayer] = nil
    end
end

-- ==========================================
-- KILLER OVERLAY (self-healing)
-- ==========================================
local PlayerGui = player:WaitForChild("PlayerGui")
local killUI, killText

local function EnsureOverlay()
    local pg = player:FindFirstChild("PlayerGui")
    if pg then PlayerGui = pg end

    if not killUI or not killUI.Parent then
        local existing = PlayerGui:FindFirstChild("KillerTextOverlay")
        if existing then existing:Destroy() end
        killUI = Instance.new("ScreenGui")
        killUI.Name = "KillerTextOverlay"
        killUI.ResetOnSpawn = false
        killUI.IgnoreGuiInset = true
        killUI.DisplayOrder = 999
        killUI.Parent = PlayerGui
    end

    if not killText or not killText.Parent then
        killText = Instance.new("TextLabel")
        killText.Name = "KillerText"
        killText.Size = UDim2.new(0, 500, 0, 50)
        killText.Position = UDim2.new(1, -520, 0, 20)
        killText.BackgroundTransparency = 1
        killText.Text = "Next Killer: scanning..."
        killText.TextColor3 = Color3.fromRGB(255, 50, 50)
        killText.Font = Enum.Font.GothamBold
        killText.TextSize = 20
        killText.TextXAlignment = Enum.TextXAlignment.Right
        killText.TextYAlignment = Enum.TextYAlignment.Top
        killText.Parent = killUI
    end

    killText.Visible = Features.KillerOverlay
end

EnsureOverlay()

local function getValue(obj, name)
    if not obj then return nil end
    local value = obj:GetAttribute(name)
    if value ~= nil then return value end
    local child = obj:FindFirstChild(name)
    if child then
        local ok, result = pcall(function() return child.Value end)
        if ok then return result end
    end
    return nil
end

local function isKiller(p)
    local t = p.Team and p.Team.Name:lower() or ""
    return t:find("killer", 1, true) ~= nil or t:find("murderer", 1, true) ~= nil
end

local function updateDisplay()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isKiller(p) then
            local char = p.Character
            local kt = char and char:GetAttribute("MorphedKiller")
            if kt then
                local dn = KILLER_NAMES[tostring(kt)] or tostring(kt)
                local m = char:GetAttribute("Mask")
                local ms = m and (" (" .. tostring(m) .. ")") or ""
                return "Killer: @" .. p.Name .. " — " .. dn .. ms
            end
            return "Killer: @" .. p.Name
        end
    end

    local candidate, bestAllowed
    local bestChance, bestAllowedChance = -math.huge, -math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        local chance = tonumber(getValue(p, "KillerChance")) or 0
        if getValue(p, "AllowKiller") == true then
            if not bestAllowed or chance > bestAllowedChance then
                bestAllowed = p; bestAllowedChance = chance
            end
        elseif not candidate or chance > bestChance then
            candidate = p; bestChance = chance
        end
    end
    candidate = bestAllowed or candidate

    if candidate then
        local chance = tonumber(getValue(candidate, "KillerChance"))
        local selected = getValue(candidate, "SelectedKiller")
        local un = candidate == player and "YOU (@" .. player.Name .. ")" or "@" .. candidate.Name
        if selected and tostring(selected) ~= "" then
            local dn = KILLER_NAMES[tostring(selected)] or tostring(selected)
            return "Next Killer: " .. un .. " — " .. dn
        elseif chance and chance > 0 then
            return "Next Killer: " .. un
        end
    end
    return "Next Killer: scanning..."
end

task.spawn(function()
    while true do
        EnsureOverlay()
        if Features.KillerOverlay then
            local ok, text = pcall(updateDisplay)
            if ok and killText and killText.Parent then
                killText.Text = text
            end
        end
        task.wait(1)
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(1)
    EnsureOverlay()
end)

-- ==========================================
-- PLAYER ESP
-- ==========================================
local function AddPlayerESP(targetPlayer)
    if targetPlayer == player then return end
    CleanupPlayer(targetPlayer)
    local conns = {}
    connections[targetPlayer] = conns

    local function getColors()
        if isKiller(targetPlayer) then
            return COLORS.Killer, COLORS.KillerCovered
        else
            return COLORS.PlayerNeon, COLORS.PlayerNeonCovered
        end
    end

    local function ApplyESP(character)
        if not character or not character.Parent then return end
        if playerESP[targetPlayer] then
            playerESP[targetPlayer]:Destroy()
            playerESP[targetPlayer] = nil
        end
        local vc, cc = getColors()
        local esp = CreateESP(character, vc, cc, "PlayerESP", true)
        esp:SetVisible(Features.PlayerESP)
        playerESP[targetPlayer] = esp
    end

    if targetPlayer.Character then ApplyESP(targetPlayer.Character) end

    table.insert(conns, targetPlayer.CharacterAdded:Connect(function(c)
        task.wait(0.1)
        ApplyESP(c)
    end))

    table.insert(conns, targetPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        local h = playerESP[targetPlayer]
        if h and h.Alive then
            local vc, cc = getColors()
            h:SetColor(vc, cc)
        end
    end))
end

for _, p in ipairs(Players:GetPlayers()) do AddPlayerESP(p) end
Players.PlayerAdded:Connect(AddPlayerESP)
Players.PlayerRemoving:Connect(CleanupPlayer)

-- ==========================================
-- GENERATOR ESP
-- ==========================================
local generatorESP = {}

local function CreateGeneratorESP(gen)
    if generatorESP[gen] then return end

    local progress = gen:GetAttribute("RepairProgress") or 0
    if progress >= 100 then return end

    local visible = Instance.new("Highlight")
    visible.Name = "GeneratorESP"; visible.Adornee = gen
    visible.DepthMode = Enum.HighlightDepthMode.Occluded
    visible.FillTransparency = 1; visible.OutlineTransparency = 0.3
    visible.OutlineColor = COLORS.Generator; visible.Parent = gen

    local hidden = Instance.new("Highlight")
    hidden.Name = "GeneratorESP"; hidden.Adornee = gen
    hidden.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hidden.FillColor = COLORS.Generator; hidden.FillTransparency = 0.92
    hidden.OutlineTransparency = 0.6; hidden.OutlineColor = COLORS.Generator
    hidden.Parent = gen

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GenProgressLabel"; billboard.Adornee = gen
    billboard.Size = UDim2.new(0, 60, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true; billboard.Parent = gen

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0); text.BackgroundTransparency = 1
    text.Text = tostring(progress) .. "%"
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextStrokeTransparency = 0.3; text.TextScaled = true
    text.Font = Enum.Font.GothamBold; text.Parent = billboard

    local esp = { Alive = true }
    function esp:SetVisible(on)
        visible.Enabled = on; hidden.Enabled = on; billboard.Enabled = on
    end
    function esp:Destroy()
        self.Alive = false
        visible:Destroy(); hidden:Destroy(); billboard:Destroy()
    end
    esp:SetVisible(Features.GeneratorESP)
    generatorESP[gen] = esp

    task.spawn(function()
        while esp.Alive and gen.Parent do
            local cp = gen:GetAttribute("RepairProgress")
            if cp then
                text.Text = string.format("%.0f%%", cp)
                if cp > 0 then
                    text.TextColor3 = Color3.fromRGB(80, 255, 120)
                else
                    text.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
                if cp >= 100 then
                    esp:Destroy(); generatorESP[gen] = nil; break
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ==========================================
-- PALLET ESP
-- ==========================================
local palletESP = {}

local function GetModelPos(model)
    if model:IsA("Model") then
        local p = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        return p and p.Position
    elseif model:IsA("BasePart") then
        return model.Position
    end
    return nil
end

local function AddPalletESP(pallet)
    if palletESP[pallet] then return end
    local esp = CreateESP(pallet, COLORS.Pallet, COLORS.PalletCovered, "PalletESP", false)
    esp:SetVisible(Features.PalletESP)
    palletESP[pallet] = esp
end

-- ==========================================
-- SCANNING
-- ==========================================
local function ScanModel(obj)
    if obj.Name == "PalletPoint" then
        local pm = obj.Parent and obj.Parent.Parent
        if pm and pm.Name == "Newpallet" then AddPalletESP(pm) end
    end
    local lower = string.lower(obj.Name or "")
    if obj:IsA("Model") and string.find(lower, "generator", 1, true) then
        CreateGeneratorESP(obj)
    end
end

local function ScanEverything()
    local map = workspace:FindFirstChild("Map") or workspace
    for _, obj in ipairs(map:GetDescendants()) do ScanModel(obj) end
end

task.wait(1)
ScanEverything()

workspace.ChildAdded:Connect(function(child)
    if child.Name == "Map" then task.wait(2); ScanEverything() end
end)

workspace.ChildRemoved:Connect(function(child)
    if child.Name == "Map" then task.wait(2); ScanEverything() end
end)

task.spawn(function()
    local map = workspace:FindFirstChild("Map") or workspace
    map.DescendantAdded:Connect(function(obj)
        task.wait(0.1)
        ScanModel(obj)
    end)
end)

-- ==========================================
-- PALLET NEAREST UPDATE LOOP
-- ==========================================
local nearestPallet

task.spawn(function()
    while true do
        task.wait(0.1)
        if Features.PalletESP then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local myPos = root.Position
                local nextNearest, nearestDistance = nil, math.huge

                for pallet, esp in pairs(palletESP) do
                    if not pallet.Parent or not esp.Alive then
                        palletESP[pallet] = nil
                        esp:Destroy()
                    else
                        local pos = GetModelPos(pallet)
                        if pos then
                            local d = (pos - myPos).Magnitude
                            if d < nearestDistance then
                                nearestDistance = d; nextNearest = pallet
                            end
                        end
                    end
                end

                if nextNearest ~= nearestPallet then
                    local prev = nearestPallet and palletESP[nearestPallet]
                    if prev and prev.Alive then
                        prev:SetColor(COLORS.Pallet, COLORS.PalletCovered)
                    end
                    nearestPallet = nextNearest
                    local curr = nearestPallet and palletESP[nearestPallet]
                    if curr and curr.Alive then
                        curr:SetColor(COLORS.Nearest, COLORS.Nearest)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- HEAL
-- ==========================================
local function Heal()
    if not Features.AutoHeal then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    hum.PlatformStand = false
    hum.WalkSpeed = 16
    hum.JumpPower = 50
    hum.Health = hum.MaxHealth
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    if rootPart then rootPart.CanCollide = true end
    for _, object in ipairs(char:GetDescendants()) do
        if BODY_MOVERS[object.ClassName] then object:Destroy() end
    end
    if healRemote then
        pcall(function()
            healRemote:FireServer(rootPart or char:WaitForChild("HumanoidRootPart"), true)
        end)
    end
end

-- ==========================================
-- CORE GUI FIX
-- ==========================================
local function ApplyCoreGuiSettings()
    if not Features.CoreGuiFix then return end
    for _ = 1, 10 do
        local ok = pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        end)
        if ok then break end
        task.wait(0.5)
    end
end

ApplyCoreGuiSettings()

player.CharacterAdded:Connect(function()
    task.wait(1)
    ApplyCoreGuiSettings()
end)

task.spawn(function()
    while true do
        task.wait(2)
        if Features.CoreGuiFix then
            pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
            end)
        end
    end
end)

-- ==========================================
-- TOGGLE HELPERS (used by the UI)
-- ==========================================
local function SetAllPlayerESP(on)
    Features.PlayerESP = on
    for _, esp in pairs(playerESP) do
        if esp.Alive then esp:SetVisible(on) end
    end
end

local function SetAllGeneratorESP(on)
    Features.GeneratorESP = on
    for _, esp in pairs(generatorESP) do
        if esp.Alive then esp:SetVisible(on) end
    end
end

local function SetAllPalletESP(on)
    Features.PalletESP = on
    for _, esp in pairs(palletESP) do
        if esp.Alive then esp:SetVisible(on) end
    end
end

local function SetKillerOverlay(on)
    Features.KillerOverlay = on
    if killText then killText.Visible = on end
end

local function SetVisual(on)
    Features.VisualEnhancement = on
    SetVisualEnhancement(on)
end

local function SetAutoHeal(on)
    Features.AutoHeal = on
end

local function SetCoreGuiFix(on)
    Features.CoreGuiFix = on
    if on then
        ApplyCoreGuiSettings()
    else
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        end)
    end
end

-- ==========================================
-- KEYBINDS (respect GUI toggles)
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        Heal()
    elseif input.KeyCode == Enum.KeyCode.P then
        SetVisual(not Features.VisualEnhancement)
    end
end)

-- ⬇⬇⬇  PASTE THE CYBERPUNK UI BLOCK DIRECTLY BELOW THIS LINE  ⬇⬇⬇
-- ==========================================
-- CYBERPUNK UI
-- ==========================================
local TweenService = game:GetService("TweenService")

local Theme = {
    BG      = Color3.fromRGB(8, 6, 16),
    BG2     = Color3.fromRGB(14, 10, 28),
    Stroke  = Color3.fromRGB(0, 220, 255),
    Accent  = Color3.fromRGB(0, 240, 255),
    Accent2 = Color3.fromRGB(255, 0, 200),
    Text    = Color3.fromRGB(220, 235, 255),
    Sub     = Color3.fromRGB(120, 150, 180),
    Off     = Color3.fromRGB(40, 40, 60),
}

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function gradient(parent, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 0
    g.Parent = parent
    return g
end

do
    local PlayerGui = player:WaitForChild("PlayerGui")
    local old = PlayerGui:FindFirstChild("VDControlPanel")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "VDControlPanel"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    gui.Parent = PlayerGui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 300, 0, 480)
    main.Position = UDim2.new(0, 22, 0.5, -240)
    main.BackgroundColor3 = Theme.BG
    main.BackgroundTransparency = 0.05
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Active = true
    main.Parent = gui
    corner(main, 14)
    stroke(main, Theme.Stroke, 1.5, 0.15)
    gradient(main, Theme.BG, Theme.BG2, 90)

    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(0, 3, 1, -20)
    glow.Position = UDim2.new(0, 0, 0, 10)
    glow.BackgroundColor3 = Theme.Accent
    glow.BorderSizePixel = 0
    glow.Parent = main
    gradient(glow, Theme.Accent, Theme.Accent2, 90)

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 56)
    titleBar.BackgroundColor3 = Theme.BG2
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 0, 24)
    title.Position = UDim2.new(0, 18, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "VIOLENCE // DISTRICT"
    title.TextColor3 = Theme.Accent
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -80, 0, 14)
    sub.Position = UDim2.new(0, 18, 0, 32)
    sub.BackgroundTransparency = 1
    sub.Text = "// NEURAL INTERFACE v2.4"
    sub.TextColor3 = Theme.Sub
    sub.Font = Enum.Font.Code
    sub.TextSize = 11
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = titleBar

    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, -24, 0, 1)
    div.Position = UDim2.new(0, 12, 0, 56)
    div.BackgroundColor3 = Theme.Stroke
    div.BackgroundTransparency = 0.5
    div.BorderSizePixel = 0
    div.Parent = main

    local min = Instance.new("TextButton")
    min.Size = UDim2.new(0, 28, 0, 28)
    min.Position = UDim2.new(1, -38, 0, 14)
    min.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    min.Text = "–"
    min.TextColor3 = Theme.Accent
    min.Font = Enum.Font.GothamBold
    min.TextSize = 18
    min.AutoButtonColor = false
    min.BorderSizePixel = 0
    min.Parent = titleBar
    corner(min, 6)
    stroke(min, Theme.Stroke, 1, 0.4)

    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -78)
    content.Position = UDim2.new(0, 10, 0, 68)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Theme.Accent
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = content

    local function MakeToggle(labelText, hint, initial, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 52)
        row.BackgroundColor3 = Theme.BG2
        row.BackgroundTransparency = 0.25
        row.BorderSizePixel = 0
        row.Parent = content
        corner(row, 8)
        stroke(row, Color3.fromRGB(35, 45, 65), 1, 0)

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 2, 1, -16)
        accent.Position = UDim2.new(0, 6, 0, 8)
        accent.BackgroundColor3 = Theme.Accent
        accent.BorderSizePixel = 0
        accent.Parent = row
        gradient(accent, Theme.Accent, Theme.Accent2, 90)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -100, 0, 20)
        label.Position = UDim2.new(0, 16, 0, 8)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Theme.Text
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local hintL = Instance.new("TextLabel")
        hintL.Size = UDim2.new(1, -100, 0, 14)
        hintL.Position = UDim2.new(0, 16, 0, 28)
        hintL.BackgroundTransparency = 1
        hintL.Text = hint or ""
        hintL.TextColor3 = Theme.Sub
        hintL.Font = Enum.Font.Code
        hintL.TextSize = 10
        hintL.TextXAlignment = Enum.TextXAlignment.Left
        hintL.Parent = row

        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0, 46, 0, 24)
        sw.Position = UDim2.new(1, -58, 0.5, -12)
        sw.BackgroundColor3 = Theme.Off
        sw.BorderSizePixel = 0
        sw.Parent = row
        corner(sw, 12)
        local swStroke = stroke(sw, Color3.fromRGB(60, 70, 90), 1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = UDim2.new(0, 3, 0.5, -9)
        knob.BackgroundColor3 = Color3.fromRGB(180, 190, 210)
        knob.BorderSizePixel = 0
        knob.Parent = sw
        corner(knob, 9)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = row

        local state = initial
        local function render(anim)
            local tc = state and Color3.fromRGB(0, 230, 200) or Theme.Off
            local tp = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            local sc = state and Theme.Accent or Color3.fromRGB(60, 70, 90)
            if anim then
                TweenService:Create(sw, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundColor3 = tc }):Play()
                TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = tp }):Play()
                TweenService:Create(swStroke, TweenInfo.new(0.18), { Color = sc, Transparency = state and 0.2 or 0 }):Play()
            else
                sw.BackgroundColor3 = tc
                knob.Position = tp
                swStroke.Color = sc
                swStroke.Transparency = state and 0.2 or 0
            end
        end
        render(false)

        btn.MouseButton1Click:Connect(function()
            state = not state
            render(true)
            pcall(callback, state)
        end)
        return row
    end

    MakeToggle("PLAYER ESP", "Highlight all players", Features.PlayerESP, SetAllPlayerESP)
    MakeToggle("GENERATOR ESP", "Generators + progress %", Features.GeneratorESP, SetAllGeneratorESP)
    MakeToggle("PALLET ESP", "Pallets / nearest marker", Features.PalletESP, SetAllPalletESP)
    MakeToggle("KILLER OVERLAY", "Top-right killer readout", Features.KillerOverlay, SetKillerOverlay)
    MakeToggle("VISUAL ENHANCE", "Clean lighting  [P]", Features.VisualEnhancement, SetVisual)
    MakeToggle("AUTO HEAL", "Health restore  [F]", Features.AutoHeal, SetAutoHeal)

    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, -6, 0, 18)
    footer.BackgroundTransparency = 1
    footer.Text = "F = HEAL   •   P = VISUALS   •   DRAG TITLE BAR"
    footer.TextColor3 = Theme.Sub
    footer.Font = Enum.Font.Code
    footer.TextSize = 10
    footer.Parent = content

    -- Minimize behavior
    local minimized = false
    min.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            Size = minimized and UDim2.new(0, 300, 0, 56) or UDim2.new(0, 300, 0, 480),
        }):Play()
    end)

    -- Draggable via title bar
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end
