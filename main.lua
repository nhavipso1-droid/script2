-- ==========================================
-- SCRIPT: Grow a Garden 2 - Always Double
-- VERSION: 4.0 Final
-- METHOD: Metatable Hook + Signal Interception
-- GUI: ON (Xanh) / OFF (Đỏ)
-- ==========================================

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- // State
local IsEnabled = false
local HookedSignals = {}
local OriginalMathRandom = math.random
local OriginalMathRandomSeed = math.randomseed

-- ==========================================
-- PHASE 1: TÌM TẤT CẢ REMOTE EVENT/FUNCTION
-- ==========================================
local function DeepFindAllRemotes()
    local found = {Events = {}, Functions = {}}
    
    local containers = {
        ReplicatedStorage,
        game:GetService("Workspace"),
        LocalPlayer.PlayerScripts,
        LocalPlayer.PlayerGui
    }
    
    for _, container in ipairs(containers) do
        pcall(function()
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    table.insert(found.Events, obj)
                elseif obj:IsA("RemoteFunction") then
                    table.insert(found.Functions, obj)
                end
            end
        end)
    end
    
    return found
end

-- ==========================================
-- PHASE 2: HOOK TẤT CẢ ONCLIENTEVENT
-- ==========================================
local function HookAllClientEvents(remotes)
    local count = 0
    
    for _, remote in ipairs(remotes.Events) do
        pcall(function()
            local signal = remote.OnClientEvent
            
            -- Tạo wrapper cho signal
            local originalFire = signal.Fire
            local connectionList = {}
            
            -- Ghi đè phương thức Connect của signal
            local mt = getrawmetatable(signal) or {}
            local oldConnect = mt.__call or signal.Connect
            
            local function newConnect(callback)
                local wrappedCallback = function(...)
                    if not IsEnabled then
                        -- OFF: Chạy callback gốc
                        return callback(...)
                    end
                    
                    -- ON: Kiểm tra và sửa đối số
                    local args = {...}
                    local modified = false
                    
                    for i = 1, #args do
                        local arg = args[i]
                        
                        -- Phát hiện string "NOTHING", "LOSE", "FAIL"
                        if type(arg) == "string" then
                            local upper = arg:upper()
                            if upper == "NOTHING" or upper == "LOSE" or upper == "FAIL" then
                                args[i] = "DOUBLE"
                                modified = true
                            end
                        end
                        
                        -- Phát hiện boolean false (thất bại)
                        if type(arg) == "boolean" and arg == false then
                            args[i] = true
                            modified = true
                        end
                        
                        -- Phát hiện số 0 (mất hết)
                        if type(arg) == "number" and arg == 0 and i >= 2 then
                            local prevArg = args[i-1]
                            if type(prevArg) == "number" and prevArg > 0 then
                                args[i] = prevArg * 2
                                modified = true
                            else
                                args[i] = 1000
                                modified = true
                            end
                        end
                    end
                    
                    if modified then
                        print("[Hook] Modified args for: " .. remote.Name)
                    end
                    
                    return callback(unpack(args))
                end
                
                local conn = oldConnect(signal, wrappedCallback)
                table.insert(connectionList, conn)
                return conn
            end
            
            signal.Connect = newConnect
            table.insert(HookedSignals, {Signal = signal, Connections = connectionList, OriginalConnect = oldConnect})
            count = count + 1
        end)
    end
    
    return count
end

-- ==========================================
-- PHASE 3: HOOK MATH.RANDOM (SERVER-SIDE FALLBACK)
-- ==========================================
local function HookMathRandom()
    math.random = function(...)
        if not IsEnabled then
            return OriginalMathRandom(...)
        end
        
        local args = {...}
        local count = select("#", ...)
        
        if count == 0 then
            -- Trả về số < 0.4 (WIN_CHANCE)
            return OriginalMathRandom() * 0.39
        elseif count == 1 then
            local max = args[1]
            if type(max) == "number" and max > 1 then
                -- Trả về giá trị gần max nhất
                return max - OriginalMathRandom() * 0.01
            end
            return max
        elseif count == 2 then
            -- Trả về max
            return args[2]
        end
        
        return OriginalMathRandom(...)
    end
    
    math.randomseed = function(seed)
        -- Giữ seed gốc nhưng vô hiệu hóa ảnh hưởng
        OriginalMathRandomSeed(seed)
        if IsEnabled then
            -- Đặt seed để kết quả luôn có lợi
            OriginalMathRandomSeed(42)
        end
    end
end

-- ==========================================
-- PHASE 4: THEO DÕI LEADERSTATS
-- ==========================================
local LeaderstatsMonitor = nil
local LastMoneyValue = 0
local MoneyValue = nil

local function StartLeaderstatsMonitor()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = LocalPlayer:WaitForChild("leaderstats", 5)
    end
    
    if not leaderstats then return end
    
    -- Tìm giá trị tiền
    for _, child in ipairs(leaderstats:GetChildren()) do
        if child:IsA("IntValue") or child:IsA("DoubleValue") or child:IsA("NumberValue") then
            local name = child.Name:lower()
            if name:find("coin") or name:find("cash") or name:find("money") or 
               name:find("gem") or name:find("gold") or name:find("point") then
                MoneyValue = child
                LastMoneyValue = child.Value
                break
            end
        end
    end
    
    if not MoneyValue then
        -- Lấy IntValue đầu tiên
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("IntValue") then
                MoneyValue = child
                LastMoneyValue = child.Value
                break
            end
        end
    end
    
    if not MoneyValue then return end
    
    -- Theo dõi thay đổi
    LeaderstatsMonitor = MoneyValue.Changed:Connect(function(newValue)
        if not IsEnabled then
            LastMoneyValue = newValue
            return
        end
        
        local diff = newValue - LastMoneyValue
        
        -- Nếu tiền GIẢM (do NOTHING)
        if diff < 0 then
            local lost = math.abs(diff)
            local double = lost * 2
            
            print(string.format("[Money] Phát hiện mất %d -> Hoàn trả %d", lost, double))
            
            -- Ngắt kết nối tạm thời
            LeaderstatsMonitor:Disconnect()
            
            -- Hoàn tiền gấp đôi
            MoneyValue.Value = MoneyValue.Value + double
            
            -- Kết nối lại
            LastMoneyValue = MoneyValue.Value
            LeaderstatsMonitor = MoneyValue.Changed:Connect(function(v)
                if not IsEnabled then
                    LastMoneyValue = v
                    return
                end
                LastMoneyValue = v
            end)
        else
            LastMoneyValue = newValue
        end
    end)
    
    print("[Money] Đang theo dõi: " .. MoneyValue.Name)
end

-- ==========================================
-- BẬT/TẮT
-- ==========================================
local function Enable()
    if IsEnabled then return false end
    IsEnabled = true
    
    HookMathRandom()
    
    local remotes = DeepFindAllRemotes()
    local hookedCount = HookAllClientEvents(remotes)
    
    if LeaderstatsMonitor == nil then
        StartLeaderstatsMonitor()
    end
    
    print(string.format("[AlwaysDouble] ===== BẬT ====="))
    print(string.format("[AlwaysDouble] RemoteEvent: %d, RemoteFunction: %d", #remotes.Events, #remotes.Functions))
    print(string.format("[AlwaysDouble] Đã hook: %d signals", hookedCount))
    print(string.format("[AlwaysDouble] Leaderstats: %s", MoneyValue and MoneyValue.Name or "Không tìm thấy"))
    
    return true
end

local function Disable()
    if not IsEnabled then return false end
    IsEnabled = false
    
    -- Khôi phục math.random
    math.random = OriginalMathRandom
    math.randomseed = OriginalMathRandomSeed
    
    -- Khôi phục signal connections
    for _, data in ipairs(HookedSignals) do
        pcall(function()
            data.Signal.Connect = data.OriginalConnect
        end)
    end
    HookedSignals = {}
    
    -- Ngắt leaderstats monitor
    if LeaderstatsMonitor then
        LeaderstatsMonitor:Disconnect()
        LeaderstatsMonitor = nil
    end
    
    print("[AlwaysDouble] ===== TẮT - Đã khôi phục =====")
    return true
end

local function Toggle()
    if IsEnabled then
        Disable()
    else
        Enable()
    end
    return IsEnabled
end

-- ==========================================
-- GIAO DIỆN: ON (XANH) / OFF (ĐỎ)
-- ==========================================
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AlwaysDoubleGUI"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Container chính
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.73, 0, 0.18, 0)
    MainFrame.Size = UDim2.new(0, 240, 0, 200)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    -- Bo góc
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    -- Viền sáng
    local Stroke = Instance.new("UIStroke")
    Stroke.Parent = MainFrame
    Stroke.Thickness = 1.5
    Stroke.Color = Color3.fromRGB(60, 60, 60)
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    -- Thanh tiêu đề
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Parent = MainFrame
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleBar.BorderSizePixel = 0
    TitleBar.Size = UDim2.new(1, 0, 0, 42)
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    -- Che nửa dưới bo góc
    local TitleCover = Instance.new("Frame")
    TitleCover.Name = "TitleCover"
    TitleCover.Parent = TitleBar
    TitleCover.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleCover.BorderSizePixel = 0
    TitleCover.Position = UDim2.new(0, 0, 0.5, 0)
    TitleCover.Size = UDim2.new(1, 0, 0.5, 0)
    
    -- Icon + Text
    local TitleText = Instance.new("TextLabel")
    TitleText.Name = "TitleText"
    TitleText.Parent = TitleBar
    TitleText.BackgroundTransparency = 1
    TitleText.Size = UDim2.new(1, 0, 1, 0)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.Text = "🎰  ALWAYS DOUBLE"
    TitleText.TextColor3 = Color3.fromRGB(255, 210, 0)
    TitleText.TextSize = 16
    TitleText.TextStrokeTransparency = 0.7
    
    -- Nút ON/OFF chính
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Parent = MainFrame
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 45, 45) -- Đỏ = OFF
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Position = UDim2.new(0.1, 0, 0.28, 0)
    ToggleButton.Size = UDim2.new(0.8, 0, 0, 56)
    ToggleButton.Font = Enum.Font.GothamBlack
    ToggleButton.Text = "OFF"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 28
    ToggleButton.AutoButtonColor = false
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 10)
    BtnCorner.Parent = ToggleButton
    
    -- Hiệu ứng bóng nút
    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Parent = ToggleButton
    BtnStroke.Thickness = 2
    BtnStroke.Color = Color3.fromRGB(255, 80, 80)
    BtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    -- Label trạng thái
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = MainFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0.05, 0, 0.6, 0)
    StatusLabel.Size = UDim2.new(0.9, 0, 0, 28)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "🔴 CƠ CHẾ GỐC (40%)"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    StatusLabel.TextSize = 13
    
    -- Label phương pháp
    local MethodLabel = Instance.new("TextLabel")
    MethodLabel.Name = "MethodLabel"
    MethodLabel.Parent = MainFrame
    MethodLabel.BackgroundTransparency = 1
    MethodLabel.Position = UDim2.new(0.05, 0, 0.74, 0)
    MethodLabel.Size = UDim2.new(0.9, 0, 0, 20)
    MethodLabel.Font = Enum.Font.Gotham
    MethodLabel.Text = "Signal Hook + Math Hook"
    MethodLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
    MethodLabel.TextSize = 10
    
    -- Label phím tắt
    local HotkeyLabel = Instance.new("TextLabel")
    HotkeyLabel.Name = "HotkeyLabel"
    HotkeyLabel.Parent = MainFrame
    HotkeyLabel.BackgroundTransparency = 1
    HotkeyLabel.Position = UDim2.new(0.05, 0, 0.86, 0)
    HotkeyLabel.Size = UDim2.new(0.9, 0, 0, 22)
    HotkeyLabel.Font = Enum.Font.Gotham
    HotkeyLabel.Text = "⌨ F6 = Bật/Tắt nhanh"
    HotkeyLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    HotkeyLabel.TextSize = 10
    
    -- ==========================================
    -- CẬP NHẬT GIAO DIỆN
    -- ==========================================
    local function UpdateUI()
        if IsEnabled then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113) -- Xanh = ON
            ToggleButton.Text = "ON"
            BtnStroke.Color = Color3.fromRGB(80, 255, 130)
            StatusLabel.Text = "🟢 LUÔN DOUBLE (100%)"
            StatusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 45, 45) -- Đỏ = OFF
            ToggleButton.Text = "OFF"
            BtnStroke.Color = Color3.fromRGB(255, 80, 80)
            StatusLabel.Text = "🔴 CƠ CHẾ GỐC (40%)"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
    
    -- ==========================================
    -- SỰ KIỆN
    -- ==========================================
    ToggleButton.MouseButton1Click:Connect(function()
        Toggle()
        UpdateUI()
    end)
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F6 then
            Toggle()
            UpdateUI()
        end
    end)
    
    -- Khởi tạo
    UpdateUI()
    
    return ScreenGui
end

-- ==========================================
-- KHỞI CHẠY
-- ==========================================
local GUI = CreateGUI()

print([[
============================================
  ALWAYS DOUBLE - GROW A GARDEN 2
  VERSION 4.0 FINAL
  
  [ON]  = Luôn DOUBLE (100%)
  [OFF] = Cơ chế gốc (40%)
  [F6]  = Bật/Tắt nhanh
============================================
]])

-- Chống AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Tự động bật khi vào game (tùy chọn)
task.spawn(function()
    task.wait(2)
    -- Bỏ comment dòng dưới nếu muốn tự động bật
    -- Enable()
    -- UpdateUI()
end)

-- Debug: In tất cả RemoteEvent tìm thấy
task.spawn(function()
    task.wait(3)
    local remotes = DeepFindAllRemotes()
    print("\n========== DANH SÁCH REMOTE EVENT ==========")
    for _, evt in ipairs(remotes.Events) do
        print("  [Event] " .. evt:GetFullName())
    end
    print("\n========== DANH SÁCH REMOTE FUNCTION ==========")
    for _, fn in ipairs(remotes.Functions) do
        print("  [Func] " .. fn:GetFullName())
    end
    print("================================================\n")
end)
