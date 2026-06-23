-- ==========================================
-- SCRIPT: Always Double - Mobile Toggle UI
-- VERSION: 5.0 Mobile Edition
-- GUI: Công tắc trượt (Switch Toggle) kiểu điện thoại
-- ==========================================

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- // State
local IsEnabled = false
local HookedSignals = {}
local LeaderstatsMonitor = nil
local MoneyValue = nil
local LastMoneyValue = 0
local OriginalMathRandom = math.random

-- ==========================================
-- CORE: TÌM REMOTE EVENT
-- ==========================================
local function GetAllRemotes()
    local events = {}
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                table.insert(events, obj)
            end
        end
    end)
    return events
end

-- ==========================================
-- CORE: HOOK ONCLIENTEVENT
-- ==========================================
local function HookEvents(remotes)
    local count = 0
    for _, remote in ipairs(remotes) do
        pcall(function()
            local conn = remote.OnClientEvent:Connect(function(...)
                if not IsEnabled then return end
                local args = {...}
                local changed = false
                
                for i, arg in ipairs(args) do
                    if type(arg) == "string" then
                        local u = arg:upper()
                        if u == "NOTHING" or u == "LOSE" or u == "FAIL" then
                            args[i] = "DOUBLE"
                            changed = true
                        end
                    elseif type(arg) == "boolean" and arg == false then
                        args[i] = true
                        changed = true
                    elseif type(arg) == "number" and arg == 0 and i >= 2 then
                        if type(args[i-1]) == "number" and args[i-1] > 0 then
                            args[i] = args[i-1] * 2
                            changed = true
                        end
                    end
                end
                
                if changed then
                    print("[Signal] Fixed: " .. remote.Name)
                end
            end)
            table.insert(HookedSignals, conn)
            count = count + 1
        end)
    end
    return count
end

-- ==========================================
-- CORE: HOOK MATH.RANDOM
-- ==========================================
local function EnableMathHook()
    math.random = function(...)
        if not IsEnabled then return OriginalMathRandom(...) end
        local n = select("#", ...)
        if n == 0 then return OriginalMathRandom() * 0.39
        elseif n == 1 then return ...
        elseif n == 2 then return select(2, ...) end
        return OriginalMathRandom(...)
    end
end

local function DisableMathHook()
    math.random = OriginalMathRandom
end

-- ==========================================
-- CORE: LEADERSTATS MONITOR
-- ==========================================
local function StartMoneyMonitor()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then ls = LocalPlayer:WaitForChild("leaderstats", 5) end
    if not ls then return end
    
    for _, c in ipairs(ls:GetChildren()) do
        if c:IsA("IntValue") then
            local n = c.Name:lower()
            if n:find("coin") or n:find("cash") or n:find("money") or n:find("gem") then
                MoneyValue = c
                LastMoneyValue = c.Value
                break
            end
        end
    end
    if not MoneyValue then
        for _, c in ipairs(ls:GetChildren()) do
            if c:IsA("IntValue") then MoneyValue = c; LastMoneyValue = c.Value; break end
        end
    end
    if not MoneyValue then return end
    
    LeaderstatsMonitor = MoneyValue.Changed:Connect(function(v)
        if not IsEnabled then LastMoneyValue = v; return end
        local diff = v - LastMoneyValue
        if diff < 0 then
            local add = math.abs(diff) * 2
            LeaderstatsMonitor:Disconnect()
            MoneyValue.Value = MoneyValue.Value + add
            LastMoneyValue = MoneyValue.Value
            LeaderstatsMonitor = MoneyValue.Changed:Connect(function(v2)
                if not IsEnabled then LastMoneyValue = v2; return end
                LastMoneyValue = v2
            end)
        else
            LastMoneyValue = v
        end
    end)
end

-- ==========================================
-- BẬT / TẮT
-- ==========================================
local function Enable()
    if IsEnabled then return end
    IsEnabled = true
    EnableMathHook()
    local remotes = GetAllRemotes()
    HookEvents(remotes)
    if not LeaderstatsMonitor then StartMoneyMonitor() end
    print("[ON] Always Double Activated")
end

local function Disable()
    if not IsEnabled then return end
    IsEnabled = false
    DisableMathHook()
    for _, c in ipairs(HookedSignals) do pcall(function() c:Disconnect() end) end
    HookedSignals = {}
    if LeaderstatsMonitor then LeaderstatsMonitor:Disconnect(); LeaderstatsMonitor = nil end
    print("[OFF] Restored Original")
end

local function Toggle()
    if IsEnabled then Disable() else Enable() end
end

-- ==========================================
-- GIAO DIỆN SWITCH KIỂU ĐIỆN THOẠI
-- ==========================================
local function CreateMobileSwitchUI()
    local SG = Instance.new("ScreenGui")
    SG.Name = "MobileSwitch"
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.IgnoreGuiInset = true
    
    -- Kích thước dựa trên màn hình điện thoại
    local ViewSize = workspace.CurrentCamera.ViewportSize
    
    -- Panel container
    local Panel = Instance.new("Frame")
    Panel.Name = "Panel"
    Panel.Parent = SG
    Panel.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
    Panel.BorderSizePixel = 0
    Panel.Size = UDim2.new(0, 280, 0, 140)
    Panel.Position = UDim2.new(0.5, -140, 0.08, 0)
    Panel.Active = true
    Panel.Draggable = true
    
    local PanelCorner = Instance.new("UICorner")
    PanelCorner.CornerRadius = UDim.new(0, 20)
    PanelCorner.Parent = Panel
    
    local PanelStroke = Instance.new("UIStroke")
    PanelStroke.Parent = Panel
    PanelStroke.Thickness = 1
    PanelStroke.Color = Color3.fromRGB(50, 50, 55)
    PanelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    -- Tiêu đề
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = Panel
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Position = UDim2.new(0, 0, 0, 10)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🎰 Always Double"
    Title.TextColor3 = Color3.fromRGB(255, 210, 50)
    Title.TextSize = 16
    
    -- ==========================================
    -- SWITCH CONTAINER (KIỂU iOS/ANDROID)
    -- ==========================================
    local SwitchContainer = Instance.new("Frame")
    SwitchContainer.Name = "SwitchContainer"
    SwitchContainer.Parent = Panel
    SwitchContainer.BackgroundTransparency = 1
    SwitchContainer.Size = UDim2.new(0, 70, 0, 36)
    SwitchContainer.Position = UDim2.new(1, -85, 0, 50)
    
    -- Background Switch (Track)
    local SwitchTrack = Instance.new("Frame")
    SwitchTrack.Name = "SwitchTrack"
    SwitchTrack.Parent = SwitchContainer
    SwitchTrack.BackgroundColor3 = Color3.fromRGB(70, 70, 75) -- Xám (OFF)
    SwitchTrack.BorderSizePixel = 0
    SwitchTrack.Size = UDim2.new(1, 0, 1, 0)
    
    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = SwitchTrack
    
    -- Nút tròn (Thumb)
    local SwitchThumb = Instance.new("Frame")
    SwitchThumb.Name = "SwitchThumb"
    SwitchThumb.Parent = SwitchTrack
    SwitchThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SwitchThumb.BorderSizePixel = 0
    SwitchThumb.Size = UDim2.new(0, 30, 0, 30)
    SwitchThumb.Position = UDim2.new(0, 3, 0.5, -15) -- Bên trái = OFF
    
    local ThumbCorner = Instance.new("UICorner")
    ThumbCorner.CornerRadius = UDim.new(1, 0)
    ThumbCorner.Parent = SwitchThumb
    
    -- Bóng cho nút tròn
    local ThumbShadow = Instance.new("ImageLabel")
    ThumbShadow.Name = "Shadow"
    ThumbShadow.Parent = SwitchThumb
    ThumbShadow.BackgroundTransparency = 1
    ThumbShadow.Size = UDim2.new(1.2, 0, 1.2, 0)
    ThumbShadow.Position = UDim2.new(-0.1, 0, -0.1, 0)
    ThumbShadow.Image = "rbxassetid://6015897843"
    ThumbShadow.ImageTransparency = 0.6
    ThumbShadow.ScaleType = Enum.ScaleType.Slice
    ThumbShadow.SliceCenter = Rect.new(8, 8, 8, 8)
    
    -- Nhãn trạng thái
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = Panel
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Size = UDim2.new(0, 120, 0, 28)
    StatusLabel.Position = UDim2.new(0, 20, 0, 52)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "OFF"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    StatusLabel.TextSize = 18
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Nhãn mô tả
    local DescLabel = Instance.new("TextLabel")
    DescLabel.Name = "DescLabel"
    DescLabel.Parent = Panel
    DescLabel.BackgroundTransparency = 1
    DescLabel.Size = UDim2.new(1, -40, 0, 22)
    DescLabel.Position = UDim2.new(0, 20, 0, 100)
    DescLabel.Font = Enum.Font.Gotham
    DescLabel.Text = "Nhấn công tắc để bật/tắt"
    DescLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
    DescLabel.TextSize = 11
    DescLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- ==========================================
    -- ANIMATION SWITCH
    -- ==========================================
    local SwitchTween = nil
    
    local function AnimateSwitch(on)
        local thumbGoal
        local trackColor
        local statusText
        local statusColor
        
        if on then
            thumbGoal = UDim2.new(1, -33, 0.5, -15) -- Phải = ON
            trackColor = Color3.fromRGB(52, 199, 89)  -- Xanh iOS
            statusText = "ON"
            statusColor = Color3.fromRGB(52, 199, 89)
        else
            thumbGoal = UDim2.new(0, 3, 0.5, -15)    -- Trái = OFF
            trackColor = Color3.fromRGB(70, 70, 75)   -- Xám
            statusText = "OFF"
            statusColor = Color3.fromRGB(255, 100, 100)
        end
        
        -- Hủy tween cũ
        if SwitchTween then SwitchTween:Cancel() end
        
        -- Tween thumb
        local thumbInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        SwitchTween = TweenService:Create(SwitchThumb, thumbInfo, {Position = thumbGoal})
        SwitchTween:Play()
        
        -- Tween track color
        local trackInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
        TweenService:Create(SwitchTrack, trackInfo, {BackgroundColor3 = trackColor}):Play()
        
        -- Cập nhật text
        StatusLabel.Text = statusText
        StatusLabel.TextColor3 = statusColor
    end
    
    -- ==========================================
    -- SỰ KIỆN NHẤN
    -- ==========================================
    local ClickDetector = Instance.new("TextButton")
    ClickDetector.Name = "ClickDetector"
    ClickDetector.Parent = SwitchContainer
    ClickDetector.BackgroundTransparency = 1
    ClickDetector.Size = UDim2.new(1.5, 0, 1.5, 0)
    ClickDetector.Position = UDim2.new(-0.25, 0, -0.25, 0)
    ClickDetector.Text = ""
    
    ClickDetector.MouseButton1Click:Connect(function()
        Toggle()
        AnimateSwitch(IsEnabled)
    end)
    
    -- Hỗ trợ chạm (mobile)
    ClickDetector.TouchTap:Connect(function()
        Toggle()
        AnimateSwitch(IsEnabled)
    end)
    
    -- ==========================================
    -- NÚT ẨN/HIỆN PANEL
    -- ==========================================
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Name = "MinimizeBtn"
    MinimizeBtn.Parent = Panel
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    MinimizeBtn.BorderSizePixel = 0
    MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
    MinimizeBtn.Position = UDim2.new(1, -30, 0, 8)
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.Text = "−"
    MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinimizeBtn.TextSize = 16
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(1, 0)
    BtnCorner.Parent = MinimizeBtn
    
    local isMinimized = false
    
    MinimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            Panel.Size = UDim2.new(0, 280, 0, 50)
            MinimizeBtn.Text = "+"
        else
            Panel.Size = UDim2.new(0, 280, 0, 140)
            MinimizeBtn.Text = "−"
        end
    end)
    
    -- Khởi tạo
    AnimateSwitch(false)
    
    return SG
end

-- ==========================================
-- KHỞI CHẠY
-- ==========================================
local GUI = CreateMobileSwitchUI()

print([[
============================================
  ALWAYS DOUBLE - MOBILE EDITION
  [ON]  = Luôn DOUBLE
  [OFF] = Cơ chế gốc 40%
  Nhấn công tắc để bật/tắt
============================================
]])

-- Chống AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
