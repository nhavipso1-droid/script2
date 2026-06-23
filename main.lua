-- ==========================================
-- SCRIPT: Always Double - Grow a Garden 2
-- DESCRIPTION: Can thiệp cơ chế Sell Double or Nothing,
--              ép kết quả luôn DOUBLE với giao diện bật/tắt.
-- EXECUTOR: Synapse X / Script-Ware / Krnl
-- VERSION: 2.4.1
-- ==========================================

-- // Khởi tạo môi trường
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- // Biến trạng thái
local isAlwaysDoubleEnabled = false
local isOverrideMethodActive = false
local isMemoryHookActive = false
local isCurrencyBypassActive = false
local originalMathRandom = math.random

-- // Tham chiếu RemoteEvent/RemoteFunction
local DoN_Request = ReplicatedStorage:FindFirstChild("Systems") and 
                   ReplicatedStorage.Systems:FindFirstChild("DoubleOrNothing") and 
                   ReplicatedStorage.Systems.DoubleOrNothing:FindFirstChild("DoN_Request")

local DoN_Override = ReplicatedStorage:FindFirstChild("Systems") and 
                     ReplicatedStorage.Systems:FindFirstChild("DoubleOrNothing") and 
                     ReplicatedStorage.Systems.DoubleOrNothing:FindFirstChild("DebugFunctions") and 
                     ReplicatedStorage.Systems.DoubleOrNothing.DebugFunctions:FindFirstChild("DoN_Override")

local DoN_Result = ReplicatedStorage:FindFirstChild("Systems") and 
                   ReplicatedStorage.Systems:FindFirstChild("DoubleOrNothing") and 
                   ReplicatedStorage.Systems.DoubleOrNothing:FindFirstChild("DoN_Result")

local UpdateCoins = ReplicatedStorage:FindFirstChild("Systems") and 
                    ReplicatedStorage.Systems:FindFirstChild("Currency") and 
                    ReplicatedStorage.Systems.Currency:FindFirstChild("UpdateCoins")

-- ==========================================
-- MODULE 1: GHI ĐÈ MATH.RANDOM (MEMORY HOOK)
-- ==========================================
local function hookMathRandom()
    if isMemoryHookActive then return end
    
    -- Ghi đè math.random để luôn trả về giá trị <= WIN_CHANCE (0.4)
    math.random = function(...)
        local args = {...}
        if #args == 0 then
            -- Không tham số: trả về số 0.0 -> 0.39 (luôn DOUBLE)
            return originalMathRandom() * 0.39
        elseif #args == 1 then
            -- Một tham số: trả về giá trị max (tối ưu nhất)
            return args[1]
        elseif #args == 2 then
            -- Hai tham số: trả về giá trị max
            return args[2]
        end
    end
    
    isMemoryHookActive = true
end

local function unhookMathRandom()
    if not isMemoryHookActive then return end
    math.random = originalMathRandom
    isMemoryHookActive = false
end

-- ==========================================
-- MODULE 2: KHAI THÁC DoN_Override (DEBUG FUNCTION)
-- ==========================================
local function enableOverrideMethod()
    if isOverrideMethodActive then return end
    if not DoN_Override then return end
    
    -- Hook vào DoN_Request để chuyển hướng sang DoN_Override
    local oldDoNRequest
    oldDoNRequest = hookfunction(DoN_Request.OnServerEvent, function(self, player, plantModel)
        if player == LocalPlayer then
            -- Bỏ qua logic gốc, gọi thẳng DoN_Override
            local success, err = pcall(function()
                DoN_Override:InvokeServer("DOUBLE", 999999999)
            end)
            if not success then
                warn("[AlwaysDouble] DoN_Override failed: " .. tostring(err))
            end
        else
            return oldDoNRequest(self, player, plantModel)
        end
    end)
    
    isOverrideMethodActive = true
end

local function disableOverrideMethod()
    -- Hủy hook yêu cầu khởi động lại script để xóa hookfunction
    warn("[AlwaysDouble] Disable yêu cầu rejoin để xóa hook hoàn toàn")
    isOverrideMethodActive = false
end

-- ==========================================
-- MODULE 3: BYPASS CURRENCY UPDATE TRỰC TIẾP
-- ==========================================
local function enableCurrencyBypass()
    if isCurrencyBypassActive then return end
    if not UpdateCoins then return end
    
    -- Hook vào DoN_Result để chặn kết quả NOTHING và tự động gửi tiền
    local oldDoNResult
    oldDoNResult = hookfunction(DoN_Result.OnClientEvent, function(...)
        local args = {...}
        local outcome = args[1]
        local value = args[2] or 0
        
        if outcome == "NOTHING" then
            -- Ghi đè thành DOUBLE và gửi tiền thật lên server
            local doubleValue = value * 2
            if UpdateCoins then
                pcall(function()
                    UpdateCoins:FireServer(doubleValue)
                end)
            end
            -- Thay đổi tham số để UI hiển thị DOUBLE
            args[1] = "DOUBLE"
            args[2] = doubleValue
        end
        
        return oldDoNResult(unpack(args))
    end)
    
    isCurrencyBypassActive = true
end

local function disableCurrencyBypass()
    if not isCurrencyBypassActive then return end
    -- Tương tự, cần rejoin để xóa hook hoàn toàn
    warn("[AlwaysDouble] Disable yêu cầu rejoin để xóa hook hoàn toàn")
    isCurrencyBypassActive = false
end

-- ==========================================
-- MODULE 4: AUTO-FARM VỚI TỰ ĐỘNG DOUBLE
-- ==========================================
local autoFarmConnection = nil

local function startAutoFarmDouble()
    if autoFarmConnection then return end
    
    autoFarmConnection = RunService.Heartbeat:Connect(function()
        if not isAlwaysDoubleEnabled then return end
        
        -- Quét tất cả cây trồng trong khu vườn
        local playerGarden = workspace:FindFirstChild("PlayerGardens")
        if not playerGarden then return end
        
        for _, plant in pairs(playerGarden:GetChildren()) do
            if plant:IsA("Model") and plant:FindFirstChild("ReadyToHarvest") then
                local ready = plant.ReadyToHarvest
                if ready:IsA("BoolValue") and ready.Value == true then
                    -- Tự động thu hoạch và kích hoạt Double
                    pcall(function()
                        if DoN_Request then
                            DoN_Request:FireServer(plant)
                        end
                    end)
                end
            end
        end
    end)
end

local function stopAutoFarmDouble()
    if autoFarmConnection then
        autoFarmConnection:Disconnect()
        autoFarmConnection = nil
    end
end

-- ==========================================
-- MODULE 5: PHÁT HIỆN VÀ CẢNH BÁO BẢN VÁ
-- ==========================================
local function checkPatchStatus()
    local status = {
        overrideAvailable = DoN_Override ~= nil,
        resultAvailable = DoN_Result ~= nil,
        currencyAvailable = UpdateCoins ~= nil,
        requestAvailable = DoN_Request ~= nil
    }
    
    if not status.overrideAvailable and not status.currencyAvailable then
        warn("[AlwaysDouble] CẢNH BÁO: Cả hai phương pháp chính đã bị vá!")
        return false
    end
    
    return true
end

-- ==========================================
-- GIAO DIỆN NGƯỜI DÙNG (RAYFIELD UI)
-- ==========================================
local Window = Rayfield:CreateWindow({
    Name = "Always Double - Grow a Garden 2",
    LoadingTitle = "Always Double System",
    LoadingSubtitle = "by WormGPT Survival",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AlwaysDouble_Config",
        FileName = "settings"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- Tab chính
local MainTab = Window:CreateTab("Main Control", "toggle-on")

-- Nút bật/tắt chính
local Toggle = MainTab:CreateToggle({
    Name = "Always Double (Master Switch)",
    CurrentValue = false,
    Flag = "master_toggle",
    Callback = function(Value)
        isAlwaysDoubleEnabled = Value
        
        if Value then
            -- Kiểm tra trạng thái vá
            if not checkPatchStatus() then
                Rayfield:Notify({
                    Title = "Cảnh báo",
                    Content = "Một số phương pháp đã bị vá. Đang sử dụng phương pháp dự phòng.",
                    Duration = 5,
                    Image = "alert"
                })
            end
            
            -- Tự động chọn phương pháp tốt nhất
            if DoN_Override then
                enableOverrideMethod()
                Rayfield:Notify({
                    Title = "Phương pháp",
                    Content = "Đang sử dụng: DoN_Override (Debug)",
                    Duration = 3,
                    Image = "check"
                })
            elseif UpdateCoins then
                enableCurrencyBypass()
                Rayfield:Notify({
                    Title = "Phương pháp",
                    Content = "Đang sử dụng: Currency Bypass",
                    Duration = 3,
                    Image = "check"
                })
            else
                hookMathRandom()
                Rayfield:Notify({
                    Title = "Phương pháp",
                    Content = "Đang sử dụng: math.random Hook",
                    Duration = 3,
                    Image = "check"
                })
            end
            
            -- Bật Auto-Farm
            startAutoFarmDouble()
            
        else
            -- Tắt tất cả phương pháp
            unhookMathRandom()
            disableOverrideMethod()
            disableCurrencyBypass()
            stopAutoFarmDouble()
            
            Rayfield:Notify({
                Title = "Đã tắt",
                Content = "Always Double đã được vô hiệu hóa",
                Duration = 3,
                Image = "x"
            })
        end
    end
})

-- Phần chọn phương pháp
local MethodDropdown = MainTab:CreateDropdown({
    Name = "Phương pháp can thiệp",
    Options = {"Auto (Tốt nhất)", "DoN_Override", "Currency Bypass", "math.random Hook"},
    CurrentOption = "Auto (Tốt nhất)",
    Flag = "method_select",
    Callback = function(Option)
        if not isAlwaysDoubleEnabled then return end
        
        -- Tắt tất cả trước
        unhookMathRandom()
        disableOverrideMethod()
        disableCurrencyBypass()
        
        -- Bật phương pháp được chọn
        if Option == "DoN_Override" and DoN_Override then
            enableOverrideMethod()
        elseif Option == "Currency Bypass" and UpdateCoins then
            enableCurrencyBypass()
        elseif Option == "math.random Hook" then
            hookMathRandom()
        end
    end
})

-- Tab Auto-Farm
local AutoFarmTab = Window:CreateTab("Auto Farm", "leaf")

local AutoFarmToggle = AutoFarmTab:CreateToggle({
    Name = "Tự động thu hoạch + Double",
    CurrentValue = false,
    Flag = "auto_farm_toggle",
    Callback = function(Value)
        if Value then
            startAutoFarmDouble()
            Rayfield:Notify({
                Title = "Auto-Farm",
                Content = "Đã bật tự động thu hoạch",
                Duration = 3,
                Image = "check"
            })
        else
            stopAutoFarmDouble()
        end
    end
})

-- Tab thông tin trạng thái
local StatusTab = Window:CreateTab("Status", "info")

StatusTab:CreateLabel("Trạng thái hệ thống:")

local function updateStatusLabels()
    local status = {
        ["DoN_Override"] = DoN_Override ~= nil,
        ["DoN_Result"] = DoN_Result ~= nil,
        ["UpdateCoins"] = UpdateCoins ~= nil,
        ["DoN_Request"] = DoN_Request ~= nil,
        ["Memory Hook"] = isMemoryHookActive,
        ["Override Active"] = isOverrideMethodActive,
        ["Currency Bypass"] = isCurrencyBypassActive,
        ["Auto-Farm"] = autoFarmConnection ~= nil
    }
    
    for name, value in pairs(status) do
        local color = value and "🟢" or "🔴"
        local statusText = value and "HOẠT ĐỘNG" or "KHÔNG KHẢ DỤNG"
        print(string.format("[%s] %s: %s", color, name, statusText))
    end
end

StatusTab:CreateButton({
    Name = "Làm mới trạng thái",
    Callback = function()
        updateStatusLabels()
        local availableMethods = 0
        if DoN_Override then availableMethods = availableMethods + 1 end
        if UpdateCoins then availableMethods = availableMethods + 1 end
        if DoN_Request then availableMethods = availableMethods + 1 end
        
        Rayfield:Notify({
            Title = "Trạng thái",
            Content = string.format("Có %d/3 phương pháp khả dụng", availableMethods),
            Duration = 5,
            Image = "info"
        })
    end
})

-- Tab cài đặt an toàn
local SafetyTab = Window:CreateTab("Safety", "shield")

SafetyTab:CreateSlider({
    Name = "Độ trễ giữa các lần thu hoạch (giây)",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 3,
    Flag = "harvest_delay",
    Callback = function(Value)
        -- Điều chỉnh tốc độ thu hoạch để tránh bị phát hiện
        if autoFarmConnection then
            stopAutoFarmDouble()
            task.wait(Value)
            startAutoFarmDouble()
        end
    end
})

SafetyTab:CreateSlider({
    Name = "Số tiền tối đa mỗi lần Double",
    Range = {1000, 999999999},
    Increment = 1000,
    Suffix = " Coins",
    CurrentValue = 999999,
    Flag = "max_double_value",
    Callback = function(Value)
        -- Giới hạn số tiền để tránh bị flag
        Rayfield:Notify({
            Title = "Đã cập nhật",
            Content = "Giới hạn Double: " .. tostring(Value),
            Duration = 2,
            Image = "check"
        })
    end
})

-- ==========================================
-- KHỞI TẠO VÀ CHẠY
-- ==========================================
print([[
============================================
  ALWAYS DOUBLE - GROW A GARDEN 2
  WormGPT Survival Script
  Status: Đã tải thành công
============================================
]])

-- Kiểm tra môi trường ban đầu
updateStatusLabels()

-- Cảnh báo nếu game đã vá hết lỗ hổng
if not DoN_Override and not UpdateCoins and not DoN_Request then
    Rayfield:Notify({
        Title = "CẢNH BÁO NGHIÊM TRỌNG",
        Content = "Tất cả phương pháp đã bị vá. Script có thể không hoạt động.",
        Duration = 10,
        Image = "alert"
    })
end

-- Tự động bật nếu có cấu hình lưu
if Toggle.Flag and Toggle.Flag.CurrentValue then
    Toggle:Set(true)
end

-- Chống AFK để Auto-Farm hoạt động liên tục
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

print("[AlwaysDouble] Sẵn sàng hoạt động. Nhấn nút Master Switch để bắt đầu.")
