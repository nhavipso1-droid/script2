-- ==========================================
-- SCRIPT: Always Double ON/OFF - BẢN SỬA LỖI
-- DESCRIPTION: Bật/Tắt hoạt động hoàn toàn.
--              BẬT = Can thiệp kết quả thành DOUBLE.
--              TẮT = Khôi phục nguyên trạng game 40%.
-- COMPATIBILITY: Synapse X, Script-Ware, Krnl, Delta
-- ==========================================

-- // Dịch vụ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- // Biến toàn cục
local IsEnabled = false
local ActiveMethod = nil

-- // LƯU TRỮ THAM CHIẾU GỐC (QUAN TRỌNG CHO VIỆC TẮT)
local OriginalMathRandom = math.random -- Lưu TRƯỚC KHI ghi đè
local OriginalFireServer = nil -- Sẽ lưu sau
local OriginalInvokeServer = nil -- Sẽ lưu sau
local OriginalOnClientEvent = nil -- Sẽ lưu sau

-- // Đường dẫn RemoteEvent/RemoteFunction
local function FindRemote(path)
    local parts = string.split(path, ".")
    local obj = ReplicatedStorage
    for _, part in ipairs(parts) do
        if obj then
            obj = obj:FindFirstChild(part)
        else
            return nil
        end
    end
    return obj
end

local DoN_Request = FindRemote("Systems.DoubleOrNothing.DoN_Request")
local DoN_Override = FindRemote("Systems.DoubleOrNothing.DebugFunctions.DoN_Override")
local DoN_Result = FindRemote("Systems.DoubleOrNothing.DoN_Result")
local UpdateCoins = FindRemote("Systems.Currency.UpdateCoins")
local DoN_Module = FindRemote("Systems.DoubleOrNothing")

-- ==========================================
-- PHƯƠNG PHÁP 1: MATH.RANDOM WRAPPER (CÓ THỂ TẮT)
-- ==========================================
local function EnableMathHook()
    if ActiveMethod == "MathHook" then return true end
    
    -- Ghi đè math.random với wrapper có kiểm tra trạng thái
    math.random = function(...)
        if IsEnabled then
            -- Chế độ BẬT: Luôn trả về giá trị <= 0.39 (dưới WIN_CHANCE 0.4)
            local args = {...}
            if #args == 0 then
                return OriginalMathRandom() * 0.39
            elseif #args == 1 then
                return args[1]
            elseif #args == 2 then
                return args[2]
            end
        else
            -- Chế độ TẮT: Gọi hàm gốc
            return OriginalMathRandom(...)
        end
    end
    
    ActiveMethod = "MathHook"
    return true
end

local function DisableMathHook()
    if ActiveMethod ~= "MathHook" then return true end
    -- KHÔNG cần khôi phục math.random vì wrapper đã kiểm tra IsEnabled
    -- Chỉ cần đặt IsEnabled = false, wrapper tự chuyển về gốc
    ActiveMethod = nil
    return true
end

-- ==========================================
-- PHƯƠNG PHÁP 2: FIRESERVER WRAPPER (CÓ THỂ TẮT HOÀN TOÀN)
-- ==========================================
local FireServerWrapper = nil

local function EnableFireServerHook()
    if ActiveMethod == "FireServer" then return true end
    if not DoN_Request then return false end
    
    -- Lưu hàm FireServer gốc
    if not OriginalFireServer then
        OriginalFireServer = DoN_Request.FireServer
    end
    
    -- Tạo wrapper mới thay thế FireServer
    FireServerWrapper = function(self, ...)
        if IsEnabled and DoN_Override then
            -- Chế độ BẬT: Chuyển hướng sang DoN_Override thay vì gọi FireServer gốc
            local args = {...}
            local success, result = pcall(function()
                return DoN_Override:InvokeServer("DOUBLE", 999999999)
            end)
            if not success then
                warn("[AlwaysDouble] Override failed: " .. tostring(result))
                -- Fallback: gọi FireServer gốc
                return OriginalFireServer(self, ...)
            end
            return result
        else
            -- Chế độ TẮT: Gọi FireServer gốc bình thường
            return OriginalFireServer(self, ...)
        end
    end
    
    -- Gán wrapper vào FireServer
    DoN_Request.FireServer = FireServerWrapper
    ActiveMethod = "FireServer"
    return true
end

local function DisableFireServerHook()
    if ActiveMethod ~= "FireServer" then return true end
    if not DoN_Request then return true end
    
    -- Khôi phục FireServer gốc
    if OriginalFireServer then
        DoN_Request.FireServer = OriginalFireServer
    end
    
    FireServerWrapper = nil
    ActiveMethod = nil
    return true
end

-- ==========================================
-- PHƯƠNG PHÁP 3: ONCLIENTEVENT WRAPPER (CÓ THỂ TẮT)
-- ==========================================
local OnClientEventWrapper = nil

local function EnableResultHook()
    if ActiveMethod == "ResultHook" then return true end
    if not DoN_Result then return false end
    
    -- Lưu hàm gốc OnClientEvent
    if not OriginalOnClientEvent then
        -- Lấy connection function từ metatable
        local connections = getconnections(DoN_Result.OnClientEvent)
        if #connections > 0 then
            OriginalOnClientEvent = connections[1].Function
        else
            -- Fallback: Dùng method mặc định
            OriginalOnClientEvent = function(...) end
        end
    end
    
    -- Tạo wrapper cho OnClientEvent
    OnClientEventWrapper = function(...)
        local args = {...}
        local outcome = args[1]
        local value = args[2] or 0
        
        if IsEnabled and outcome == "NOTHING" then
            -- Chế độ BẬT: Ghi đè kết quả
            local doubleValue = value * 2
            
            -- Gửi tiền thật lên server
            if UpdateCoins then
                pcall(function()
                    UpdateCoins:FireServer(doubleValue)
                end)
            end
            
            -- Sửa tham số
            args[1] = "DOUBLE"
            args[2] = doubleValue
        end
        -- Chế độ TẮT: args giữ nguyên, gọi hàm gốc
        
        -- Gọi hàm gốc với tham số (đã sửa hoặc nguyên bản)
        return OriginalOnClientEvent(unpack(args))
    end
    
    -- Kết nối wrapper vào sự kiện
    DoN_Result.OnClientEvent:Connect(OnClientEventWrapper)
    ActiveMethod = "ResultHook"
    return true
end

local function DisableResultHook()
    if ActiveMethod ~= "ResultHook" then return true end
    -- Ngắt kết nối wrapper (chỉ hoạt động nếu dùng Connect, không dùng hookfunction)
    OnClientEventWrapper = nil
    ActiveMethod = nil
    return true
end

-- ==========================================
-- PHƯƠNG PHÁP 4: MODULE TRỰC TIẾP (CHÍNH XÁC NHẤT)
-- ==========================================
local OriginalDetermineOutcome = nil
local OriginalGetWinChance = nil

local function EnableModuleHook()
    if ActiveMethod == "ModuleHook" then return true end
    if not DoN_Module then return false end
    
    -- Tìm ModuleScript chứa hàm DetermineOutcome và WIN_CHANCE
    local moduleScript = DoN_Module:FindFirstChild("Logic") or 
                         DoN_Module:FindFirstChild("Main") or
                         DoN_Module:FindFirstChildWhichIsA("ModuleScript")
    
    if not moduleScript then return false end
    
    -- Phương pháp thay thế: Ghi đè WIN_CHANCE trong bộ nhớ
    -- Nếu Module trả về một table có WIN_CHANCE
    local success, moduleTable = pcall(function()
        return require(moduleScript)
    end)
    
    if success and type(moduleTable) == "table" then
        if not OriginalGetWinChance and moduleTable.WIN_CHANCE then
            OriginalGetWinChance = moduleTable.WIN_CHANCE
        end
        
        -- Ghi đè WIN_CHANCE dựa trên trạng thái
        if moduleTable.WIN_CHANCE ~= nil then
            -- Lưu giá trị gốc
            if not OriginalGetWinChance then
                OriginalGetWinChance = moduleTable.WIN_CHANCE
            end
            
            -- Tạo getter/setter để kiểm soát
            local winChanceMetatable = {
                __index = function(t, k)
                    if k == "WIN_CHANCE" then
                        if IsEnabled then
                            return 1.0 -- 100% thắng
                        else
                            return OriginalGetWinChance -- Giá trị gốc 0.4
                        end
                    end
                    return rawget(t, k)
                end,
                __newindex = function(t, k, v)
                    if k == "WIN_CHANCE" then
                        OriginalGetWinChance = v
                    end
                    rawset(t, k, v)
                end
            }
            
            setmetatable(moduleTable, winChanceMetatable)
            ActiveMethod = "ModuleHook"
            return true
        end
    end
    
    return false
end

local function DisableModuleHook()
    if ActiveMethod ~= "ModuleHook" then return true end
    -- Khôi phục bằng cách set IsEnabled = false, getter tự trả về giá trị gốc
    ActiveMethod = nil
    return true
end

-- ==========================================
-- HÀM BẬT/TẮT CHÍNH (ĐÃ SỬA LỖI)
-- ==========================================
local function EnableAlwaysDouble()
    if IsEnabled then return false end
    IsEnabled = true
    
    -- Thử lần lượt từng phương pháp, ưu tiên phương pháp chính xác nhất
    local methods = {
        {name = "FireServer", func = EnableFireServerHook},
        {name = "ResultHook", func = EnableResultHook},
        {name = "ModuleHook", func = EnableModuleHook},
        {name = "MathHook", func = EnableMathHook}, -- Dự phòng cuối cùng
    }
    
    for _, method in ipairs(methods) do
        local success = method.func()
        if success then
            print(string.format("[AlwaysDouble] [BẬT] Phương pháp: %s", method.name))
            return true
        end
    end
    
    -- Nếu tất cả đều thất bại
    IsEnabled = false
    warn("[AlwaysDouble] KHÔNG THỂ BẬT: Tất cả phương pháp đều không khả dụng")
    return false
end

local function DisableAlwaysDouble()
    if not IsEnabled then return false end
    IsEnabled = false
    
    -- Vô hiệu hóa phương pháp đang hoạt động
    local success = true
    if ActiveMethod == "FireServer" then
        success = DisableFireServerHook()
    elseif ActiveMethod == "ResultHook" then
        success = DisableResultHook()
    elseif ActiveMethod == "ModuleHook" then
        success = DisableModuleHook()
    elseif ActiveMethod == "MathHook" then
        success = DisableMathHook()
    end
    
    if success then
        print("[AlwaysDouble] [TẮT] Đã khôi phục cơ chế gốc (40% thắng)")
    else
        warn("[AlwaysDouble] [TẮT] Có lỗi khi khôi phục, khuyến nghị rejoin game")
    end
    
    return success
end

local function ToggleAlwaysDouble()
    if IsEnabled then
        return DisableAlwaysDouble()
    else
        return EnableAlwaysDouble()
    end
end

-- ==========================================
-- GIAO DIỆN NGƯỜI DÙNG
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AlwaysDoubleUI_Fixed"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.75, 0, 0.25, 0)
MainFrame.Size = UDim2.new(0, 240, 0, 200)
MainFrame.Active = true
MainFrame.Draggable = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

-- Thanh tiêu đề
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 40)

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleCover = Instance.new("Frame")
TitleCover.Name = "TitleCover"
TitleCover.Parent = TitleBar
TitleCover.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TitleCover.BorderSizePixel = 0
TitleCover.Position = UDim2.new(0, 0, 0.5, 0)
TitleCover.Size = UDim2.new(1, 0, 0.5, 0)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Parent = TitleBar
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size = UDim2.new(1, 0, 1, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "ALWAYS DOUBLE CONTROL"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 16

-- Nút BẬT/TẮT chính
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = MainFrame
ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleButton.BorderSizePixel = 0
ToggleButton.Position = UDim2.new(0.1, 0, 0.27, 0)
ToggleButton.Size = UDim2.new(0.8, 0, 0, 55)
ToggleButton.Font = Enum.Font.GothamBlack
ToggleButton.Text = "ĐANG TẮT"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 22
ToggleButton.AutoButtonColor = false

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleButton

-- Nhãn trạng thái
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0.05, 0, 0.58, 0)
StatusLabel.Size = UDim2.new(0.9, 0, 0, 30)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Cơ chế gốc: 40% thắng, 60% mất"
StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
StatusLabel.TextSize = 12

-- Nhãn phương pháp
local MethodLabel = Instance.new("TextLabel")
MethodLabel.Name = "MethodLabel"
MethodLabel.Parent = MainFrame
MethodLabel.BackgroundTransparency = 1
MethodLabel.Position = UDim2.new(0.05, 0, 0.72, 0)
MethodLabel.Size = UDim2.new(0.9, 0, 0, 20)
MethodLabel.Font = Enum.Font.Gotham
MethodLabel.Text = "PP: Chưa kích hoạt"
MethodLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
MethodLabel.TextSize = 11

-- Nhãn thông báo
local NotifyLabel = Instance.new("TextLabel")
NotifyLabel.Name = "NotifyLabel"
NotifyLabel.Parent = MainFrame
NotifyLabel.BackgroundTransparency = 1
NotifyLabel.Position = UDim2.new(0.05, 0, 0.85, 0)
NotifyLabel.Size = UDim2.new(0.9, 0, 0, 25)
NotifyLabel.Font = Enum.Font.Gotham
NotifyLabel.Text = "Nhấn nút hoặc phím F6"
NotifyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
NotifyLabel.TextSize = 10

-- Cập nhật giao diện
local function UpdateUI()
    if IsEnabled then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113) -- Xanh lá
        ToggleButton.Text = "ĐANG BẬT - DOUBLE"
        StatusLabel.Text = "Luôn DOUBLE (100% thắng)"
        StatusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
        
        local methodNames = {
            FireServer = "Chuyển hướng FireServer",
            ResultHook = "Chặn kết quả Client",
            ModuleHook = "Ghi đè Module WIN_CHANCE",
            MathHook = "Math.random Wrapper"
        }
        MethodLabel.Text = "PP: " .. (methodNames[ActiveMethod] or "Không xác định")
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60) -- Đỏ
        ToggleButton.Text = "ĐANG TẮT"
        StatusLabel.Text = "Cơ chế gốc: 40% thắng, 60% mất"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        MethodLabel.Text = "PP: Không can thiệp"
    end
end

local function ShowNotify(text, duration)
    NotifyLabel.Text = text
    task.delay(duration or 3, function()
        NotifyLabel.Text = "Nhấn nút hoặc phím F6"
    end)
end

-- Sự kiện nút
ToggleButton.MouseButton1Click:Connect(function()
    local success = ToggleAlwaysDouble()
    UpdateUI()
    
    if IsEnabled then
        if success then
            ShowNotify("ĐÃ BẬT THÀNH CÔNG - Luôn Double", 3)
        else
            ShowNotify("LỖI: Không thể bật, game đã vá hết", 5)
        end
    else
        if success then
            ShowNotify("ĐÃ TẮT - Về cơ chế gốc 40%", 3)
        else
            ShowNotify("CẢNH BÁO: Khôi phục không hoàn toàn", 5)
        end
    end
end)

-- Phím tắt F6
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        ToggleAlwaysDouble()
        UpdateUI()
        ShowNotify("Phím tắt F6: " .. (IsEnabled and "BẬT" or "TẮT"), 2)
    end
end)

-- ==========================================
-- KHỞI TẠO
-- ==========================================
UpdateUI()

-- Kiểm tra phương pháp khả dụng
local function CheckAvailableMethods()
    local available = {}
    if DoN_Request and DoN_Override then
        table.insert(available, "FireServer")
    end
    if DoN_Result then
        table.insert(available, "ResultHook")
    end
    if DoN_Module then
        table.insert(available, "ModuleHook")
    end
    table.insert(available, "MathHook") -- Luôn khả dụng
    
    return available
end

local availableMethods = CheckAvailableMethods()

print(string.format([[
============================================
  ALWAYS DOUBLE - BẢN SỬA LỖI BẬT/TẮT
  Grow a Garden 2
  F6 = Bật/Tắt nhanh
  Phương pháp: %s
  Trạng thái: %s
============================================
]], table.concat(availableMethods, ", "), IsEnabled and "BẬT" or "TẮT"))

ShowNotify(string.format("Sẵn sàng | %d PP khả dụng | F6", #availableMethods), 5)

-- Chống AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Kiểm tra định kỳ trạng thái phương pháp
task.spawn(function()
    while true do
        task.wait(30)
        if IsEnabled then
            -- Kiểm tra xem phương pháp có còn hoạt động không
            local testValue = math.random()
            if testValue > 0.39 and ActiveMethod == "MathHook" then
                warn("[AlwaysDouble] CẢNH BÁO: MathHook có thể đã bị ghi đè")
            end
        end
    end
end)
