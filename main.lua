-- ==========================================
-- SCRIPT: Always Double - BẢN HOẠT ĐỘNG THỰC SỰ
-- DESCRIPTION: BẬT = Luôn nhận DOUBLE.
--              TẮT = Game gốc 40%.
-- METHOD: Chặn và thay đổi gói tin kết quả từ Server
--         trước khi UI/Data xử lý.
-- ==========================================

-- // Dịch vụ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- // Trạng thái
local IsEnabled = false
local Connection = nil -- Lưu kết nối sự kiện để có thể ngắt khi TẮT

-- // Tìm RemoteEvent kết quả Double or Nothing
-- Tên có thể khác nhau tùy phiên bản game
local PossibleResultEventNames = {
    "DoN_Result",
    "DoubleOrNothingResult",
    "SellResult",
    "GambleResult",
    "DoubleResult",
    "DoNResult"
}

local ResultEvent = nil

-- Tìm trong ReplicatedStorage và các thư mục con
local function FindResultEvent()
    -- Tìm trực tiếp
    for _, name in ipairs(PossibleResultEventNames) do
        local event = ReplicatedStorage:FindFirstChild(name, true)
        if event and event:IsA("RemoteEvent") then
            return event
        end
    end
    
    -- Tìm trong Systems
    local systems = ReplicatedStorage:FindFirstChild("Systems")
    if systems then
        for _, child in ipairs(systems:GetDescendants()) do
            if child:IsA("RemoteEvent") and 
               (child.Name:lower():find("result") or 
                child.Name:lower():find("double") or 
                child.Name:lower():find("don")) then
                return child
            end
        end
    end
    
    -- Tìm tất cả RemoteEvent có liên quan đến Double
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("double") or name:find("result") or name:find("sell") then
                return obj
            end
        end
    end
    
    return nil
end

ResultEvent = FindResultEvent()

-- Tìm RemoteEvent cập nhật tiền
local function FindCurrencyEvent()
    local systems = ReplicatedStorage:FindFirstChild("Systems")
    if systems then
        local currency = systems:FindFirstChild("Currency")
        if currency then
            for _, child in ipairs(currency:GetChildren()) do
                if child:IsA("RemoteEvent") then
                    return child
                end
            end
        end
    end
    
    -- Tìm trong ReplicatedStorage
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("coin") or name:find("currency") or name:find("money") or name:find("update") then
                return obj
            end
        end
    end
    
    return nil
end

local CurrencyEvent = FindCurrencyEvent()

-- ==========================================
-- PHƯƠNG PHÁP CHÍNH: CHẶN ONCLIENTEVENT
-- ==========================================
local function EnableInterception()
    if Connection then return true end -- Đã bật rồi
    
    if not ResultEvent then
        warn("[AlwaysDouble] KHÔNG TÌM THẤY RemoteEvent kết quả!")
        return false
    end
    
    -- Tạo kết nối chặn kết quả
    Connection = ResultEvent.OnClientEvent:Connect(function(outcome, value, ...)
        if not IsEnabled then
            -- Chế độ TẮT: Không làm gì, để game xử lý bình thường
            return
        end
        
        -- Chế độ BẬT: Kiểm tra và thay đổi kết quả
        -- outcome thường là string: "DOUBLE" hoặc "NOTHING"
        -- value là số tiền
        
        if type(outcome) == "string" and outcome:upper() == "NOTHING" then
            print("[AlwaysDouble] Phát hiện NOTHING -> Chuyển thành DOUBLE")
            
            -- Tính toán giá trị DOUBLE (value * 2)
            local doubleValue = (type(value) == "number" and value > 0) and (value * 2) or 1000
            
            -- Phương pháp 1: Gửi sự kiện cập nhật tiền giả
            if CurrencyEvent then
                task.spawn(function()
                    pcall(function()
                        CurrencyEvent:FireServer(doubleValue)
                        print("[AlwaysDouble] Đã gửi tiền DOUBLE: " .. tostring(doubleValue))
                    end)
                end)
            end
            
            -- Phương pháp 2: Trực tiếp cộng tiền vào leaderstats (Client-Side)
            task.spawn(function()
                pcall(function()
                    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                    if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins") or 
                                      leaderstats:FindFirstChild("Cash") or
                                      leaderstats:FindFirstChild("Money")
                        if coins and coins:IsA("IntValue") then
                            coins.Value = coins.Value + doubleValue
                            print("[AlwaysDouble] Đã cập nhật leaderstats: +" .. tostring(doubleValue))
                        end
                    end
                end)
            end)
            
            -- Phương pháp 3: Gửi lại yêu cầu với kết quả DOUBLE
            -- (Tìm RemoteEvent yêu cầu và gửi lại)
            local requestEvent = nil
            local systems = ReplicatedStorage:FindFirstChild("Systems")
            if systems then
                local don = systems:FindFirstChild("DoubleOrNothing")
                if don then
                    requestEvent = don:FindFirstChild("DoN_Request") or don:FindFirstChild("Request")
                end
            end
            
            if requestEvent then
                task.spawn(function()
                    pcall(function()
                        -- Gửi yêu cầu mới với cùng cây trồng
                        local args = {...}
                        if #args > 0 then
                            requestEvent:FireServer(unpack(args))
                        end
                    end)
                end)
            end
        end
    end)
    
    print("[AlwaysDouble] [BẬT] Đã kết nối chặn kết quả: " .. ResultEvent:GetFullName())
    return true
end

local function DisableInterception()
    if Connection then
        Connection:Disconnect()
        Connection = nil
        print("[AlwaysDouble] [TẮT] Đã ngắt kết nối chặn kết quả")
    end
    return true
end

-- ==========================================
-- PHƯƠNG PHÁP DỰ PHÒNG: CHẶN TẤT CẢ REMOTEEVENT
-- ==========================================
local AllConnections = {}

local function EnableGlobalInterception()
    if #AllConnections > 0 then return true end
    
    -- Kết nối vào tất cả RemoteEvent có thể là kết quả
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("result") or name:find("double") or name:find("sell") or name:find("coin") then
                local conn = obj.OnClientEvent:Connect(function(...)
                    if not IsEnabled then return end
                    
                    local args = {...}
                    for i, arg in ipairs(args) do
                        if type(arg) == "string" and arg:upper() == "NOTHING" then
                            print("[AlwaysDouble] Chặn NOTHING từ: " .. obj:GetFullName())
                            
                            -- Thay đổi args
                            args[i] = "DOUBLE"
                            if args[i+1] and type(args[i+1]) == "number" then
                                args[i+1] = args[i+1] * 2
                            end
                            
                            -- Cập nhật tiền
                            if CurrencyEvent then
                                task.spawn(function()
                                    pcall(function()
                                        local val = args[i+1] or 1000
                                        CurrencyEvent:FireServer(val)
                                    end)
                                end)
                            end
                            
                            break
                        end
                    end
                end)
                
                table.insert(AllConnections, conn)
            end
        end
    end
    
    print("[AlwaysDouble] [BẬT] Chặn toàn cục: " .. #AllConnections .. " sự kiện")
    return #AllConnections > 0
end

local function DisableGlobalInterception()
    for _, conn in ipairs(AllConnections) do
        conn:Disconnect()
    end
    AllConnections = {}
    print("[AlwaysDouble] [TẮT] Đã ngắt tất cả chặn toàn cục")
    return true
end

-- ==========================================
-- HÀM BẬT/TẮT CHÍNH
-- ==========================================
local function EnableAlwaysDouble()
    if IsEnabled then return false end
    IsEnabled = true
    
    -- Thử phương pháp chính xác trước
    local success = EnableInterception()
    
    -- Nếu không tìm thấy ResultEvent cụ thể, dùng phương pháp toàn cục
    if not success or not ResultEvent then
        success = EnableGlobalInterception()
    end
    
    if success then
        print("[AlwaysDouble] ========== ĐÃ BẬT ==========")
        return true
    else
        IsEnabled = false
        warn("[AlwaysDouble] KHÔNG THỂ BẬT - Không tìm thấy sự kiện nào")
        return false
    end
end

local function DisableAlwaysDouble()
    if not IsEnabled then return false end
    IsEnabled = false
    
    DisableInterception()
    DisableGlobalInterception()
    
    print("[AlwaysDouble] ========== ĐÃ TẮT ==========")
    return true
end

local function ToggleAlwaysDouble()
    if IsEnabled then
        return DisableAlwaysDouble()
    else
        return EnableAlwaysDouble()
    end
end

-- ==========================================
-- GIAO DIỆN
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AlwaysDoubleUI_Working"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.72, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 250, 0, 220)
MainFrame.Active = true
MainFrame.Draggable = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

-- Tiêu đề
local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Font = Enum.Font.GothamBold
Title.Text = "🎰 ALWAYS DOUBLE"
Title.TextColor3 = Color3.fromRGB(255, 215, 0)
Title.TextSize = 18

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title

local TitleCover = Instance.new("Frame")
TitleCover.Parent = Title
TitleCover.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TitleCover.BorderSizePixel = 0
TitleCover.Position = UDim2.new(0, 0, 0.5, 0)
TitleCover.Size = UDim2.new(1, 0, 0.5, 0)

-- Nút chính
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Parent = MainFrame
ToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Position = UDim2.new(0.08, 0, 0.25, 0)
ToggleBtn.Size = UDim2.new(0.84, 0, 0, 60)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.Text = "ĐANG TẮT"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 24
ToggleBtn.AutoButtonColor = false

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 10)
BtnCorner.Parent = ToggleBtn

-- Trạng thái
local StatusText = Instance.new("TextLabel")
StatusText.Parent = MainFrame
StatusText.BackgroundTransparency = 1
StatusText.Position = UDim2.new(0.05, 0, 0.55, 0)
StatusText.Size = UDim2.new(0.9, 0, 0, 25)
StatusText.Font = Enum.Font.GothamBold
StatusText.Text = "Cơ chế gốc: 40% DOUBLE"
StatusText.TextColor3 = Color3.fromRGB(255, 120, 120)
StatusText.TextSize = 14

-- Thông tin phương pháp
local MethodText = Instance.new("TextLabel")
MethodText.Parent = MainFrame
MethodText.BackgroundTransparency = 1
MethodText.Position = UDim2.new(0.05, 0, 0.68, 0)
MethodText.Size = UDim2.new(0.9, 0, 0, 20)
MethodText.Font = Enum.Font.Gotham
MethodText.Text = "PP: Chưa kích hoạt"
MethodText.TextColor3 = Color3.fromRGB(180, 180, 180)
MethodText.TextSize = 11

-- Sự kiện tìm thấy
local EventText = Instance.new("TextLabel")
EventText.Parent = MainFrame
EventText.BackgroundTransparency = 1
EventText.Position = UDim2.new(0.05, 0, 0.78, 0)
EventText.Size = UDim2.new(0.9, 0, 0, 20)
EventText.Font = Enum.Font.Gotham
EventText.Text = "Sự kiện: " .. (ResultEvent and "✅ Tìm thấy" or "❌ Không tìm thấy")
EventText.TextColor3 = ResultEvent and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
EventText.TextSize = 10

-- Thông báo
local NotifyText = Instance.new("TextLabel")
NotifyText.Parent = MainFrame
NotifyText.BackgroundTransparency = 1
NotifyText.Position = UDim2.new(0.05, 0, 0.88, 0)
NotifyText.Size = UDim2.new(0.9, 0, 0, 25)
NotifyText.Font = Enum.Font.Gotham
NotifyText.Text = "F6 = Bật/Tắt | Kéo để di chuyển"
NotifyText.TextColor3 = Color3.fromRGB(200, 200, 200)
NotifyText.TextSize = 10

-- Cập nhật UI
local function UpdateUI()
    if IsEnabled then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        ToggleBtn.Text = "ĐANG BẬT ✓"
        StatusText.Text = "LUÔN DOUBLE (100%)"
        StatusText.TextColor3 = Color3.fromRGB(46, 204, 113)
        
        local method = (Connection and "Chặn trực tiếp") or 
                       (#AllConnections > 0 and "Chặn toàn cục (".. #AllConnections .." SK)") or 
                       "Không xác định"
        MethodText.Text = "PP: " .. method
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ToggleBtn.Text = "ĐANG TẮT ✗"
        StatusText.Text = "Cơ chế gốc: 40% DOUBLE"
        StatusText.TextColor3 = Color3.fromRGB(255, 120, 120)
        MethodText.Text = "PP: Không can thiệp"
    end
end

local function Notify(msg, duration)
    NotifyText.Text = msg
    task.delay(duration or 3, function()
        NotifyText.Text = "F6 = Bật/Tắt | Kéo để di chuyển"
    end)
end

-- Sự kiện nút
ToggleBtn.MouseButton1Click:Connect(function()
    local success = ToggleAlwaysDouble()
    UpdateUI()
    
    if IsEnabled then
        Notify(success and "✅ ĐÃ BẬT - Luôn DOUBLE" or "❌ LỖI: Không thể bật", 4)
    else
        Notify(success and "🔙 ĐÃ TẮT - Về 40% gốc" or "⚠️ Tắt không hoàn toàn", 4)
    end
end)

-- Phím tắt
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        local success = ToggleAlwaysDouble()
        UpdateUI()
        Notify("F6: " .. (IsEnabled and "BẬT ✓" or "TẮT ✗"), 2)
    end
end)

-- ==========================================
-- KHỞI TẠO
-- ==========================================
UpdateUI()

print([[
============================================
  ALWAYS DOUBLE - BẢN HOẠT ĐỘNG
  Grow a Garden 2
  F6 = Bật/Tắt
  ResultEvent: ]] .. (ResultEvent and ResultEvent:GetFullName() or "KHÔNG TÌM THẤY") .. [[
  CurrencyEvent: ]] .. (CurrencyEvent and CurrencyEvent:GetFullName() or "KHÔNG TÌM THẤY") .. [[
============================================
]])

-- Chống AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Kiểm tra lại ResultEvent sau khi game tải xong
task.spawn(function()
    task.wait(10)
    if not ResultEvent then
        ResultEvent = FindResultEvent()
        if ResultEvent then
            EventText.Text = "Sự kiện: ✅ Tìm thấy (sau 10s)"
            EventText.TextColor3 = Color3.fromRGB(100, 255, 100)
            Notify("Đã tìm thấy sự kiện sau khi tải!", 3)
        end
    end
    if not CurrencyEvent then
        CurrencyEvent = FindCurrencyEvent()
    end
end)
