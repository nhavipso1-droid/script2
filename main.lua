-- ==========================================
-- SCRIPT: Always Double - AUTO-DETECT & DUMP
-- DESCRIPTION: Tự động quét toàn bộ game để tìm
--              cơ chế Double or Nothing thực tế.
--              Sau đó áp dụng phương pháp phù hợp.
-- ==========================================

-- // Dịch vụ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- // Biến toàn cục
local IsEnabled = false
local DetectedSystem = nil -- Lưu hệ thống đã phát hiện
local Connections = {}

-- ==========================================
-- BƯỚC 1: QUÉT TOÀN BỘ GAME TÌM CƠ CHẾ
-- ==========================================
local function DeepScan()
    local results = {
        RemoteEvents = {},
        RemoteFunctions = {},
        ModuleScripts = {},
        ScreenGuis = {},
        Leaderstats = {}
    }
    
    -- Quét ReplicatedStorage
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            table.insert(results.RemoteEvents, {
                Name = obj.Name,
                Path = obj:GetFullName(),
                Parent = obj.Parent and obj.Parent.Name or "Unknown"
            })
        elseif obj:IsA("RemoteFunction") then
            table.insert(results.RemoteFunctions, {
                Name = obj.Name,
                Path = obj:GetFullName(),
                Parent = obj.Parent and obj.Parent.Name or "Unknown"
            })
        elseif obj:IsA("ModuleScript") then
            table.insert(results.ModuleScripts, {
                Name = obj.Name,
                Path = obj:GetFullName(),
                Parent = obj.Parent and obj.Parent.Name or "Unknown"
            })
        end
    end
    
    -- Quét PlayerGui
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("ScreenGui") or obj:IsA("Frame") then
                local texts = {}
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        local text = child.Text:lower()
                        if text:find("double") or text:find("sell") or text:find("nothing") or text:find("gamble") then
                            table.insert(texts, child.Text)
                        end
                    end
                end
                if #texts > 0 then
                    table.insert(results.ScreenGuis, {
                        Name = obj.Name,
                        Path = obj:GetFullName(),
                        Texts = texts
                    })
                end
            end
        end
    end
    
    -- Quét leaderstats
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            table.insert(results.Leaderstats, {
                Name = child.Name,
                Class = child.ClassName,
                Value = child:IsA("IntValue") and child.Value or "N/A"
            })
        end
    end
    
    return results
end

-- ==========================================
-- BƯỚC 2: PHÂN TÍCH KẾT QUẢ QUÉT
-- ==========================================
local function AnalyzeResults(scanResults)
    local detected = {
        method = nil,
        remoteEvent = nil,
        remoteFunction = nil,
        currencyEvent = nil,
        uiFound = false
    }
    
    -- Tìm RemoteEvent liên quan đến Double/Sell
    for _, evt in ipairs(scanResults.RemoteEvents) do
        local name = evt.Name:lower()
        local path = evt.Path:lower()
        
        if name:find("double") or name:find("sell") or name:find("nothing") or
           name:find("don") or name:find("gamble") or name:find("result") or
           path:find("double") or path:find("sell") then
            detected.remoteEvent = evt
            detected.method = "RemoteEvent"
            break
        end
    end
    
    -- Tìm RemoteFunction liên quan
    for _, fn in ipairs(scanResults.RemoteFunctions) do
        local name = fn.Name:lower()
        local path = fn.Path:lower()
        
        if name:find("double") or name:find("sell") or name:find("nothing") or
           name:find("don") or name:find("override") or name:find("debug") then
            detected.remoteFunction = fn
            if not detected.method then
                detected.method = "RemoteFunction"
            end
            break
        end
    end
    
    -- Tìm sự kiện tiền tệ
    for _, evt in ipairs(scanResults.RemoteEvents) do
        local name = evt.Name:lower()
        if name:find("coin") or name:find("cash") or name:find("money") or 
           name:find("currency") or name:find("update") or name:find("add") then
            detected.currencyEvent = evt
            break
        end
    end
    
    -- Kiểm tra UI
    detected.uiFound = #scanResults.ScreenGuis > 0
    
    return detected
end

-- ==========================================
-- BƯỚC 3: THỬ KÍCH HOẠT DOUBLE OR NOTHING
-- ==========================================
local function TryTriggerDoN()
    -- Quét tất cả RemoteEvent và gửi thử
    local scanResults = DeepScan()
    
    for _, evt in ipairs(scanResults.RemoteEvents) do
        local name = evt.Name:lower()
        if name:find("double") or name:find("don") or name:find("sell") or name:find("gamble") then
            local remote = ReplicatedStorage:FindFirstChild(evt.Path:gsub("ReplicatedStorage%.", ""), true)
            if remote then
                print("[Scanner] Đang thử kích hoạt: " .. evt.Path)
                pcall(function()
                    -- Thử gửi với tham số rỗng hoặc mặc định
                    remote:FireServer()
                end)
                pcall(function()
                    -- Thử gửi với tham số là Player
                    remote:FireServer(LocalPlayer)
                end)
                pcall(function()
                    -- Thử gửi với tham số string
                    remote:FireServer("DOUBLE", 1000)
                end)
            end
        end
    end
end

-- ==========================================
-- BƯỚC 4: PHƯƠNG PHÁP CAN THIỆP PHỔ QUÁT
-- ==========================================
local function EnableUniversalHook()
    if #Connections > 0 then return true end
    
    local scanResults = DeepScan()
    local hookedCount = 0
    
    -- Kết nối vào TẤT CẢ RemoteEvent.OnClientEvent
    for _, evt in ipairs(scanResults.RemoteEvents) do
        local remote = nil
        pcall(function()
            remote = ReplicatedStorage:FindFirstChild(evt.Path:gsub("ReplicatedStorage%.", ""), true)
        end)
        
        if remote and remote:IsA("RemoteEvent") then
            local conn = remote.OnClientEvent:Connect(function(...)
                if not IsEnabled then return end
                
                local args = {...}
                local modified = false
                
                -- Kiểm tra từng tham số
                for i, arg in ipairs(args) do
                    -- Tìm string "NOTHING" hoặc tương tự
                    if type(arg) == "string" then
                        local upper = arg:upper()
                        if upper == "NOTHING" or upper == "LOSE" or upper == "FAIL" or upper == "FALSE" then
                            args[i] = "DOUBLE"
                            modified = true
                            print("[Hook] Đã sửa NOTHING -> DOUBLE trong: " .. evt.Name)
                        end
                    end
                    -- Tìm number = 0 (mất hết)
                    if type(arg) == "number" and arg == 0 and i > 1 then
                        -- Có thể là giá trị 0 (nothing)
                        args[i] = (args[i-1] or 100) * 2
                        modified = true
                        print("[Hook] Đã sửa giá trị 0 -> x2 trong: " .. evt.Name)
                    end
                end
                
                if modified then
                    -- Cố gắng gửi lại tiền qua currency event
                    if DetectedSystem and DetectedSystem.currencyEvent then
                        local currRemote = nil
                        pcall(function()
                            currRemote = ReplicatedStorage:FindFirstChild(
                                DetectedSystem.currencyEvent.Path:gsub("ReplicatedStorage%.", ""), true
                            )
                        end)
                        if currRemote then
                            task.spawn(function()
                                pcall(function()
                                    currRemote:FireServer(args[2] or 1000)
                                end)
                            end)
                        end
                    end
                end
            end)
            
            table.insert(Connections, conn)
            hookedCount = hookedCount + 1
        end
    end
    
    -- Kết nối vào TẤT CẢ RemoteFunction.OnClientInvoke
    for _, fn in ipairs(scanResults.RemoteFunctions) do
        local remote = nil
        pcall(function()
            remote = ReplicatedStorage:FindFirstChild(fn.Path:gsub("ReplicatedStorage%.", ""), true)
        end)
        
        if remote and remote:IsA("RemoteFunction") then
            -- Hook OnClientInvoke
            local conn = remote.OnClientInvoke:Connect(function(...)
                if not IsEnabled then return nil end
                
                local args = {...}
                if #args > 0 and type(args[1]) == "string" then
                    if args[1]:upper() == "NOTHING" then
                        print("[Hook] Sửa RemoteFunction NOTHING -> DOUBLE: " .. fn.Name)
                        return "DOUBLE", (args[2] or 100) * 2
                    end
                end
                return nil -- Không thay đổi
            end)
            
            table.insert(Connections, conn)
            hookedCount = hookedCount + 1
        end
    end
    
    print("[Hook] Đã kết nối " .. hookedCount .. " sự kiện/hàm")
    return hookedCount > 0
end

local function DisableUniversalHook()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}
    print("[Hook] Đã ngắt tất cả kết nối")
end

-- ==========================================
-- BƯỚC 5: PHƯƠNG PHÁP LEADERSTATS TRỰC TIẾP
-- ==========================================
local LeaderstatsConnection = nil

local function EnableLeaderstatsMonitor()
    if LeaderstatsConnection then return true end
    
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then
        -- Đợi leaderstats xuất hiện
        leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
    end
    
    if not leaderstats then return false end
    
    -- Tìm IntValue tiền tệ
    local moneyValue = nil
    for _, child in ipairs(leaderstats:GetChildren()) do
        if child:IsA("IntValue") or child:IsA("NumberValue") then
            local name = child.Name:lower()
            if name:find("coin") or name:find("cash") or name:find("money") or name:find("gem") then
                moneyValue = child
                break
            end
        end
    end
    
    if not moneyValue then
        -- Lấy IntValue đầu tiên
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("IntValue") then
                moneyValue = child
                break
            end
        end
    end
    
    if not moneyValue then return false end
    
    -- Theo dõi thay đổi giá trị
    local lastValue = moneyValue.Value
    
    LeaderstatsConnection = moneyValue.Changed:Connect(function(newValue)
        if not IsEnabled then return end
        
        local diff = newValue - lastValue
        
        -- Nếu giá trị giảm (mất tiền do NOTHING), tự động cộng lại gấp đôi
        if diff < 0 then
            local doubleAmount = math.abs(diff) * 2
            print("[Leaderstats] Phát hiện mất " .. math.abs(diff) .. " -> Cộng lại " .. doubleAmount)
            
            -- Ngắt kết nối tạm thời để tránh vòng lặp
            LeaderstatsConnection:Disconnect()
            
            -- Cộng tiền
            moneyValue.Value = moneyValue.Value + doubleAmount
            
            -- Kết nối lại
            LeaderstatsConnection = moneyValue.Changed:Connect(function(v)
                if not IsEnabled then return end
                lastValue = v
            end)
        end
        
        lastValue = moneyValue.Value
    end)
    
    print("[Leaderstats] Đang theo dõi: " .. moneyValue.Name)
    return true
end

local function DisableLeaderstatsMonitor()
    if LeaderstatsConnection then
        LeaderstatsConnection:Disconnect()
        LeaderstatsConnection = nil
    end
end

-- ==========================================
-- BẬT/TẮT CHÍNH
-- ==========================================
local function EnableAlwaysDouble()
    if IsEnabled then return false end
    IsEnabled = true
    
    -- Quét game
    local scanResults = DeepScan()
    DetectedSystem = AnalyzeResults(scanResults)
    
    print("[AlwaysDouble] ===== KẾT QUẢ QUÉT =====")
    print("[AlwaysDouble] RemoteEvents: " .. #scanResults.RemoteEvents)
    print("[AlwaysDouble] RemoteFunctions: " .. #scanResults.RemoteFunctions)
    print("[AlwaysDouble] ModuleScripts: " .. #scanResults.ModuleScripts)
    print("[AlwaysDouble] UI Elements: " .. #scanResults.ScreenGuis)
    print("[AlwaysDouble] Phương pháp: " .. (DetectedSystem.method or "Universal"))
    print("[AlwaysDouble] ============================")
    
    -- Thử kích hoạt Double or Nothing
    TryTriggerDoN()
    
    -- Bật phương pháp phổ quát
    local success = EnableUniversalHook()
    
    -- Bật theo dõi leaderstats
    EnableLeaderstatsMonitor()
    
    if success then
        print("[AlwaysDouble] ĐÃ BẬT THÀNH CÔNG")
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
    
    DisableUniversalHook()
    DisableLeaderstatsMonitor()
    
    print("[AlwaysDouble] ĐÃ TẮT - Trở về cơ chế gốc")
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
-- GIAO DIỆN TỐI GIẢN
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AlwaysDouble_Universal"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.7, 0, 0.15, 0)
MainFrame.Size = UDim2.new(0, 260, 0, 250)
MainFrame.Active = true
MainFrame.Draggable = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Tiêu đề
local TitleBar = Instance.new("Frame")
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 45)

Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)
local TitleCover = Instance.new("Frame")
TitleCover.Parent = TitleBar
TitleCover.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleCover.BorderSizePixel = 0
TitleCover.Position = UDim2.new(0, 0, 0.5, 0)
TitleCover.Size = UDim2.new(1, 0, 0.5, 0)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TitleBar
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size = UDim2.new(1, 0, 1, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "🎰 ALWAYS DOUBLE"
TitleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
TitleLabel.TextSize = 18

-- Nút BẬT/TẮT
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = MainFrame
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Position = UDim2.new(0.08, 0, 0.23, 0)
ToggleBtn.Size = UDim2.new(0.84, 0, 0, 60)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.Text = "TẮT"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 26
ToggleBtn.AutoButtonColor = false

Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

-- Thông tin
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Parent = MainFrame
InfoLabel.BackgroundTransparency = 1
InfoLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
InfoLabel.Size = UDim2.new(0.9, 0, 0, 60)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.Text = "Nhấn nút hoặc F6 để bật/tắt"
InfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoLabel.TextSize = 12
InfoLabel.TextWrapped = true
InfoLabel.TextYAlignment = Enum.TextYAlignment.Top

-- Nhãn phụ
local SubLabel = Instance.new("TextLabel")
SubLabel.Parent = MainFrame
SubLabel.BackgroundTransparency = 1
SubLabel.Position = UDim2.new(0.05, 0, 0.78, 0)
SubLabel.Size = UDim2.new(0.9, 0, 0, 20)
SubLabel.Font = Enum.Font.Gotham
SubLabel.Text = ""
SubLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
SubLabel.TextSize = 10

-- Cập nhật UI
local function UpdateUI()
    if IsEnabled then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        ToggleBtn.Text = "BẬT"
        InfoLabel.Text = "🟢 LUÔN DOUBLE\nTất cả kết quả NOTHING sẽ bị chặn"
        InfoLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        ToggleBtn.Text = "TẮT"
        InfoLabel.Text = "🔴 CƠ CHẾ GỐC\nGame hoạt động bình thường (40%)"
        InfoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end

-- Sự kiện
ToggleBtn.MouseButton1Click:Connect(function()
    ToggleAlwaysDouble()
    UpdateUI()
    local scanResults = DeepScan()
    SubLabel.Text = string.format("Đã quét: %d RemoteEvent, %d RemoteFunc", 
        #scanResults.RemoteEvents, #scanResults.RemoteFunctions)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        ToggleAlwaysDouble()
        UpdateUI()
    end
end)

-- Khởi tạo
UpdateUI()

-- Tự động quét và hiển thị kết quả
task.spawn(function()
    task.wait(3)
    local scanResults = DeepScan()
    SubLabel.Text = string.format("Đã quét: %d RemoteEvent, %d RemoteFunc", 
        #scanResults.RemoteEvents, #scanResults.RemoteFunctions)
    
    -- In kết quả quét ra console
    print("\n========== KẾT QUẢ QUÉT GAME ==========")
    print("REMOTE EVENTS:")
    for _, evt in ipairs(scanResults.RemoteEvents) do
        print("  - " .. evt.Path)
    end
    print("\nREMOTE FUNCTIONS:")
    for _, fn in ipairs(scanResults.RemoteFunctions) do
        print("  - " .. fn.Path)
    end
    print("\nUI ELEMENTS (Double/Sell):")
    for _, ui in ipairs(scanResults.ScreenGuis) do
        print("  - " .. ui.Name .. ": " .. table.concat(ui.Texts, ", "))
    end
    print("\nLEADERSTATS:")
    for _, stat in ipairs(scanResults.Leaderstats) do
        print("  - " .. stat.Name .. " (" .. stat.Class .. ") = " .. tostring(stat.Value))
    end
    print("=========================================\n")
end)

-- Chống AFK
LocalPlayer.Idled:Connect(function()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)
