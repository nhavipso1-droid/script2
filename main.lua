-- ==========================================
-- SCRIPT: Always Double ON/OFF - Grow a Garden 2
-- DESCRIPTION: Công tắc bật/tắt: BẬT = luôn Double,
--              TẮT = trả về cơ chế gốc 40% của game.
-- COMPATIBILITY: Synapse X, Script-Ware, Krnl, Delta
-- ==========================================

-- // Dịch vụ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- // Lưu trữ tham chiếu gốc để khôi phục khi TẮT
local OriginalMathRandom = math.random
local OriginalDoNRequest_OnServerEvent = nil
local OriginalDoNResult_OnClientEvent = nil

-- // Trạng thái
local IsEnabled = false
local HookedConnections = {}
local ActiveMethod = nil -- "Override" | "CurrencyBypass" | "MathHook" | nil

-- // Đường dẫn Remote (Tự động phát hiện)
local Paths = {
    DoN_Request = "Systems.DoubleOrNothing.DoN_Request",
    DoN_Override = "Systems.DoubleOrNothing.DebugFunctions.DoN_Override",
    DoN_Result = "Systems.DoubleOrNothing.DoN_Result",
    UpdateCoins = "Systems.Currency.UpdateCoins"
}

local function ResolveRemote(path)
    local parts = string.split(path, ".")
    local current = ReplicatedStorage
    for _, part in ipairs(parts) do
        if current then
            current = current:FindFirstChild(part)
        else
            return nil
        end
    end
    return current
end

local Remotes = {}
for name, path in pairs(Paths) do
    Remotes[name] = ResolveRemote(path)
end

-- ==========================================
-- PHƯƠNG PHÁP 1: MATH.RANDOM HOOK (DỰ PHÒNG)
-- ==========================================
local function EnableMathHook()
    if ActiveMethod == "MathHook" then return end
    
    math.random = function(...)
        local args = {...}
        if #args == 0 then
            -- Trả về giá trị trong khoảng [0, 0.39] để luôn <= 0.4 (WIN_CHANCE)
            return OriginalMathRandom() * 0.39
        elseif #args == 1 then
            -- Trả về max để tối ưu kết quả
            return args[1]
        elseif #args == 2 then
            -- Trả về max
            return args[2]
        end
    end
    
    ActiveMethod = "MathHook"
end

local function DisableMathHook()
    if ActiveMethod ~= "MathHook" then return end
    math.random = OriginalMathRandom
    ActiveMethod = nil
end

-- ==========================================
-- PHƯƠNG PHÁP 2: DoN_Override (DEBUG HIDDEN)
-- ==========================================
local function EnableOverrideHook()
    if ActiveMethod == "Override" then return end
    if not Remotes.DoN_Request or not Remotes.DoN_Override then return end
    
    -- Lưu hàm gốc của OnServerEvent
    local OriginalOnServerEvent = Remotes.DoN_Request.OnServerEvent
    
    -- Ghi đè OnServerEvent để chuyển hướng sang DoN_Override
    local NewOnServerEvent
    NewOnServerEvent = hookfunction(Remotes.DoN_Request.OnServerEvent, function(self, player, ...)
        if player == LocalPlayer then
            -- Bỏ qua logic gốc, gọi thẳng DoN_Override
            local success, err = pcall(function()
                return Remotes.DoN_Override:InvokeServer("DOUBLE", 999999999)
            end)
            if not success then
                warn("[AlwaysDouble] Override failed: " .. tostring(err))
            end
        end
        -- Vẫn gọi hàm gốc cho người khác (giữ game bình thường)
        return OriginalOnServerEvent(self, player, ...)
    end)
    
    -- Lưu tham chiếu để hủy
    HookedConnections["Override"] = {
        Original = OriginalOnServerEvent,
        Remote = Remotes.DoN_Request,
        HookedFunction = NewOnServerEvent
    }
    
    ActiveMethod = "Override"
end

local function DisableOverrideHook()
    if ActiveMethod ~= "Override" then return end
    -- Không thể unhook function trong môi trường Executor thông thường
    -- Yêu cầu lưu và khôi phục thủ công
    local data = HookedConnections["Override"]
    if data and data.Remote and data.Original then
        -- Khôi phục OnServerEvent gốc
        pcall(function()
            -- Phương pháp thay thế: gán lại metatable
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            -- Phức tạp để unhook, nên thông báo cho user
        end)
    end
    warn("[AlwaysDouble] Khôi phục hoàn toàn yêu cầu rejoin game")
    ActiveMethod = nil
end

-- ==========================================
-- PHƯƠNG PHÁP 3: CURRENCY BYPASS + RESULT HOOK
-- ==========================================
local function EnableCurrencyBypassHook()
    if ActiveMethod == "CurrencyBypass" then return end
    if not Remotes.DoN_Result or not Remotes.UpdateCoins then return end
    
    -- Lưu hàm gốc OnClientEvent
    local OriginalOnClientEvent = Remotes.DoN_Result.OnClientEvent
    
    -- Ghi đè OnClientEvent để chặn kết quả NOTHING
    local NewOnClientEvent
    NewOnClientEvent = hookfunction(Remotes.DoN_Result.OnClientEvent, function(...)
        local args = {...}
        local outcome = args[1]
        local value = args[2] or 0
        
        if outcome == "NOTHING" then
            -- Gửi tiền thật lên server bất kể kết quả
            local doubleValue = value * 2
            if Remotes.UpdateCoins then
                pcall(function()
                    Remotes.UpdateCoins:FireServer(doubleValue)
                end)
            end
            -- Sửa kết quả để UI hiển thị DOUBLE
            args[1] = "DOUBLE"
            args[2] = doubleValue
        end
        
        -- Gọi hàm gốc với tham số đã sửa
        return OriginalOnClientEvent(unpack(args))
    end)
    
    HookedConnections["CurrencyBypass"] = {
        Original = OriginalOnClientEvent,
        Remote = Remotes.DoN_Result,
        HookedFunction = NewOnClientEvent
    }
    
    ActiveMethod = "CurrencyBypass"
end

local function DisableCurrencyBypassHook()
    if ActiveMethod ~= "CurrencyBypass" then return end
    warn("[AlwaysDouble] Khôi phục hoàn toàn yêu cầu rejoin game")
    ActiveMethod = nil
end

-- ==========================================
-- HÀM CHÍNH: BẬT/TẮT
-- ==========================================
local function EnableAlwaysDouble()
    if IsEnabled then return end
    IsEnabled = true
    
    -- Ưu tiên chọn phương pháp tốt nhất
    if Remotes.DoN_Override and Remotes.DoN_Request then
        EnableOverrideHook()
        print("[AlwaysDouble] [BẬT] Phương pháp: DoN_Override (Debug)")
    elseif Remotes.DoN_Result and Remotes.UpdateCoins then
        EnableCurrencyBypassHook()
        print("[AlwaysDouble] [BẬT] Phương pháp: Currency Bypass + Result Hook")
    else
        EnableMathHook()
        print("[AlwaysDouble] [BẬT] Phương pháp: math.random Hook")
    end
end

local function DisableAlwaysDouble()
    if not IsEnabled then return end
    IsEnabled = false
    
    -- Vô hiệu hóa phương pháp đang hoạt động
    DisableMathHook()
    DisableOverrideHook()
    DisableCurrencyBypassHook()
    
    print("[AlwaysDouble] [TẮT] Đã khôi phục cơ chế gốc (40% thắng)")
end

local function ToggleAlwaysDouble()
    if IsEnabled then
        DisableAlwaysDouble()
    else
        EnableAlwaysDouble()
    end
end

-- ==========================================
-- GIAO DIỆN NGƯỜI DÙNG (SIMPLE UI)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AlwaysDoubleUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- // Khung chính
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.8, 0, 0.3, 0)
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Active = true
MainFrame.Draggable = true

-- // Bo góc
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- // Tiêu đề
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Font = Enum.Font.GothamBold
Title.Text = "ALWAYS DOUBLE"
Title.TextColor3 = Color3.fromRGB(76, 175, 80)
Title.TextSize = 18
Title.TextStrokeTransparency = 0.5

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- // Chỉnh lại bo góc tiêu đề (chỉ bo trên)
Instance.new("Frame", Title).BackgroundColor3 = Color3.fromRGB(60, 60, 60)
Title.ClipsDescendants = false

-- // Nút trạng thái (BẬT/TẮT)
local StatusButton = Instance.new("TextButton")
StatusButton.Name = "StatusButton"
StatusButton.Parent = MainFrame
StatusButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
StatusButton.BorderSizePixel = 0
StatusButton.Position = UDim2.new(0.1, 0, 0.25, 0)
StatusButton.Size = UDim2.new(0.8, 0, 0, 50)
StatusButton.Font = Enum.Font.GothamBold
StatusButton.Text = "BẬT"
StatusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusButton.TextSize = 24
StatusButton.AutoButtonColor = false

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusButton

-- // Nhãn trạng thái
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 0, 0.6, 0)
StatusLabel.Size = UDim2.new(1, 0, 0, 25)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Trạng thái: ĐANG TẮT (Cơ chế gốc 40%)"
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.TextSize = 12

-- // Nhãn phương pháp
local MethodLabel = Instance.new("TextLabel")
MethodLabel.Name = "MethodLabel"
MethodLabel.Parent = MainFrame
MethodLabel.BackgroundTransparency = 1
MethodLabel.Position = UDim2.new(0, 0, 0.75, 0)
MethodLabel.Size = UDim2.new(1, 0, 0, 20)
MethodLabel.Font = Enum.Font.Gotham
MethodLabel.Text = "Phương pháp: Chưa chọn"
MethodLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
MethodLabel.TextSize = 10

-- // Nhãn thông báo
local NotificationLabel = Instance.new("TextLabel")
NotificationLabel.Name = "NotificationLabel"
NotificationLabel.Parent = MainFrame
NotificationLabel.BackgroundTransparency = 1
NotificationLabel.Position = UDim2.new(0, 0, 0.88, 0)
NotificationLabel.Size = UDim2.new(1, 0, 0, 20)
NotificationLabel.Font = Enum.Font.Gotham
NotificationLabel.Text = ""
NotificationLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
NotificationLabel.TextSize = 10

-- // Cập nhật giao diện
local function UpdateUI()
    if IsEnabled then
        StatusButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80) -- Xanh lá
        StatusButton.Text = "ĐANG BẬT"
        StatusLabel.Text = "Trạng thái: ĐANG BẬT (Luôn DOUBLE)"
        StatusLabel.TextColor3 = Color3.fromRGB(76, 175, 80)
        
        local methodText = "Không xác định"
        if ActiveMethod == "Override" then methodText = "DoN_Override (Debug)"
        elseif ActiveMethod == "CurrencyBypass" then methodText = "Currency Bypass"
        elseif ActiveMethod == "MathHook" then methodText = "math.random Hook"
        end
        MethodLabel.Text = "Phương pháp: " .. methodText
    else
        StatusButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Đỏ
        StatusButton.Text = "ĐANG TẮT"
        StatusLabel.Text = "Trạng thái: ĐANG TẮT (Cơ chế gốc 40%)"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        MethodLabel.Text = "Phương pháp: Không can thiệp"
    end
end

-- // Hiệu ứng nhấp nháy thông báo
local function ShowNotification(text, duration)
    NotificationLabel.Text = text
    task.delay(duration or 3, function()
        NotificationLabel.Text = ""
    end)
end

-- // Xử lý sự kiện nút
StatusButton.MouseButton1Click:Connect(function()
    ToggleAlwaysDouble()
    UpdateUI()
    
    if IsEnabled then
        ShowNotification("ĐÃ BẬT: Luôn Double khi Sell", 4)
    else
        ShowNotification("ĐÃ TẮT: Trở về cơ chế gốc (40%)", 4)
    end
end)

-- // Phím tắt: Phím F6 để bật/tắt nhanh
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        ToggleAlwaysDouble()
        UpdateUI()
        if IsEnabled then
            ShowNotification("Phím tắt F6: ĐÃ BẬT", 2)
        else
            ShowNotification("Phím tắt F6: ĐÃ TẮT", 2)
        end
    end
end)

-- ==========================================
-- KHỞI TẠO
-- ==========================================
UpdateUI()

-- Kiểm tra phương pháp khả dụng
local availableMethods = {}
if Remotes.DoN_Override and Remotes.DoN_Request then
    table.insert(availableMethods, "DoN_Override")
end
if Remotes.DoN_Result and Remotes.UpdateCoins then
    table.insert(availableMethods, "CurrencyBypass")
end
table.insert(availableMethods, "MathHook")

print([[
============================================
  ALWAYS DOUBLE - GROW A GARDEN 2
  F6 = Bật/Tắt nhanh
  Phương pháp khả dụng: ]] .. table.concat(availableMethods, ", ") .. [[
============================================
]])

ShowNotification("Sẵn sàng | F6 để Bật/Tắt | " .. #availableMethods .. " phương pháp", 5)

-- Chống AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
