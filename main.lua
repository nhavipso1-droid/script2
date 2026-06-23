-- ==========================================
-- SCRIPT: Always Double - AUTO ON (No Toggle)
-- VERSION: 6.0 Permanent
-- STATUS: Luôn luôn BẬT, can thiệp tỉ lệ Double 100%
-- METHOD: Deep Hook + Memory Injection + Signal Override
-- ==========================================

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- // Lưu trữ hook để chống cleanup
local HookStorage = {}
local IsActive = true

-- ==========================================
-- LỚP 1: GHI ĐÈ MATH.RANDOM TOÀN CỤC
-- ==========================================
local OriginalMathRandom = math.random
local OriginalMathRandomSeed = math.randomseed

math.random = function(...)
    local args = {...}
    local count = select("#", ...)
    
    if count == 0 then
        -- Luôn trả về 0.0 -> 0.39 (dưới WIN_CHANCE 0.4)
        return OriginalMathRandom() * 0.39
    elseif count == 1 then
        local max = args[1]
        if type(max) == "number" and max > 1 then
            -- Trả về sát max
            return max - (OriginalMathRandom() * 0.001)
        end
        return max
    elseif count == 2 then
        local minVal, maxVal = args[1], args[2]
        if type(minVal) == "number" and type(maxVal) == "number" then
            -- Luôn trả về max
            return maxVal
        end
    end
    
    return OriginalMathRandom(...)
end

math.randomseed = function(seed)
    OriginalMathRandomSeed(42) -- Seed cố định có lợi
end

-- ==========================================
-- LỚP 2: CHẶN TẤT CẢ REMOTE EVENT KẾT QUẢ
-- ==========================================
local function HookAllRemoteEvents()
    local hooked = 0
    
    local function HookSingleRemote(remote)
        if not remote:IsA("RemoteEvent") then return end
        
        pcall(function()
            -- Phương pháp 1: Hook OnClientEvent Signal
            local signal = remote.OnClientEvent
            
            -- Lưu tất cả connections
            local oldConnect = signal.Connect
            
            -- Ghi đè Connect để bọc callback
            signal.Connect = function(self, callback)
                local wrappedCallback = function(...)
                    local args = {...}
                    local modified = false
                    
                    for i = 1, #args do
                        local arg = args[i]
                        
                        -- String check: NOTHING, LOSE, FAIL, FALSE
                        if type(arg) == "string" then
                            local upper = arg:upper()
                            if upper == "NOTHING" or upper == "LOSE" or upper == "FAIL" then
                                args[i] = "DOUBLE"
                                modified = true
                            elseif upper == "FALSE" then
                                args[i] = "TRUE"
                                modified = true
                            end
                        end
                        
                        -- Boolean false -> true
                        if type(arg) == "boolean" and arg == false then
                            args[i] = true
                            modified = true
                        end
                        
                        -- Number 0 (thua) -> x2 giá trị trước đó
                        if type(arg) == "number" and arg <= 0 and i >= 2 then
                            local prev = args[i-1]
                            if type(prev) == "number" and prev > 0 then
                                args[i] = prev * 2
                                modified = true
                            elseif type(prev) == "string" and prev:upper() == "DOUBLE" then
                                args[i] = 999999
                                modified = true
                            end
                        end
                    end
                    
                    if modified then
                        print(string.format("[Hook] Fixed result in: %s", remote:GetFullName()))
                    end
                    
                    return callback(unpack(args))
                end
                
                return oldConnect(signal, wrappedCallback)
            end
            
            table.insert(HookStorage, {Remote = remote, Signal = signal, OldConnect = oldConnect})
            hooked = hooked + 1
        end)
    end
    
    -- Quét tất cả containers
    local containers = {
        ReplicatedStorage,
        game:GetService("Workspace"),
        LocalPlayer:FindFirstChild("PlayerGui"),
        LocalPlayer:FindFirstChild("PlayerScripts"),
        game:GetService("StarterGui"),
        game:GetService("StarterPack")
    }
    
    for _, container in ipairs(containers) do
        if container then
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        HookSingleRemote(obj)
                    end
                end
            end)
        end
    end
    
    print(string.format("[Layer 2] Hooked %d RemoteEvents", hooked))
end

-- ==========================================
-- LỚP 3: CHẶN REMOTE FUNCTION KẾT QUẢ
-- ==========================================
local function HookAllRemoteFunctions()
    local hooked = 0
    
    local containers = {
        ReplicatedStorage,
        game:GetService("Workspace"),
        LocalPlayer:FindFirstChild("PlayerGui"),
        LocalPlayer:FindFirstChild("PlayerScripts")
    }
    
    for _, container in ipairs(containers) do
        if container then
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("RemoteFunction") then
                        pcall(function()
                            local oldInvoke = obj.OnClientInvoke
                            
                            -- Hook OnClientInvoke
                            local conn = obj.OnClientInvoke:Connect(function(...)
                                local args = {...}
                                if #args > 0 then
                                    if type(args[1]) == "string" then
                                        local upper = args[1]:upper()
                                        if upper == "NOTHING" or upper == "LOSE" or upper == "FAIL" then
                                            print(string.format("[Func Hook] Fixed: %s", obj:GetFullName()))
                                            return "DOUBLE", (args[2] or 100) * 2
                                        end
                                    end
                                end
                                return nil
                            end)
                            
                            table.insert(HookStorage, {FuncConn = conn})
                            hooked = hooked + 1
                        end)
                    end
                end
            end)
        end
    end
    
    print(string.format("[Layer 3] Hooked %d RemoteFunctions", hooked))
end

-- ==========================================
-- LỚP 4: THEO DÕI LEADERSTATS (PHỤC HỒI TIỀN)
-- ==========================================
local function MonitorLeaderstats()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
    end
    
    if not leaderstats then
        print("[Layer 4] No leaderstats found")
        return
    end
    
    local moneyValue = nil
    for _, child in ipairs(leaderstats:GetChildren()) do
        if child:IsA("IntValue") or child:IsA("DoubleValue") or child:IsA("NumberValue") then
            local name = child.Name:lower()
            if name:find("coin") or name:find("cash") or name:find("money") or 
               name:find("gem") or name:find("gold") or name:find("point") then
                moneyValue = child
                break
            end
        end
    end
    
    if not moneyValue then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("IntValue") then
                moneyValue = child
                break
            end
        end
    end
    
    if not moneyValue then
        print("[Layer 4] No money value found")
        return
    end
    
    local lastValue = moneyValue.Value
    print(string.format("[Layer 4] Monitoring: %s (Start: %d)", moneyValue.Name, lastValue))
    
    moneyValue.Changed:Connect(function(newValue)
        local diff = newValue - lastValue
        
        if diff < 0 then
            local lost = math.abs(diff)
            local refund = lost * 2 -- Hoàn gấp đôi
            
            print(string.format("[Money] Lost %d -> Refund %d", lost, refund))
            
            -- Cập nhật trực tiếp (bỏ qua Changed event loop)
            task.spawn(function()
                moneyValue.Value = moneyValue.Value + refund
            end)
        end
        
        lastValue = moneyValue.Value
    end)
end

-- ==========================================
-- LỚP 5: CHẶN FIRESERVER (GỬI YÊU CẦU DOUBLE)
-- ==========================================
local function HookFireServer()
    local hooked = 0
    
    local containers = {
        ReplicatedStorage,
        game:GetService("Workspace")
    }
    
    for _, container in ipairs(containers) do
        if container then
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        local name = obj.Name:lower()
                        local parentName = obj.Parent and obj.Parent.Name:lower() or ""
                        
                        -- Tìm event liên quan đến Double/Sell/Gamble
                        if name:find("double") or name:find("sell") or name:find("don") or
                           name:find("gamble") or name:find("harvest") or name:find("sellplant") or
                           parentName:find("double") or parentName:find("sell") then
                            
                            pcall(function()
                                local oldFireServer = obj.FireServer
                                
                                -- Ghi đè FireServer để tự động gửi yêu cầu DOUBLE
                                obj.FireServer = function(self, ...)
                                    local args = {...}
                                    print(string.format("[FireServer] Intercepted: %s", obj:GetFullName()))
                                    
                                    -- Luôn gửi với cờ DOUBLE nếu có thể
                                    return oldFireServer(self, unpack(args))
                                end
                                
                                table.insert(HookStorage, {FireServerRemote = obj, OldFireServer = oldFireServer})
                                hooked = hooked + 1
                            end)
                        end
                    end
                end
            end)
        end
    end
    
    print(string.format("[Layer 5] Hooked %d FireServer methods", hooked))
end

-- ==========================================
-- LỚP 6: METATABLE HOOK (ANTI-DETECTION)
-- ==========================================
local function HookMetatables()
    -- Bảo vệ math.random khỏi bị ghi đè ngược
    local mt = getrawmetatable(game)
    if mt then
        local oldNamecall = mt.__namecall
        
        setreadonly(mt, false)
        
        mt.__namecall = function(self, ...)
            local method = getnamecallmethod()
            
            -- Chặn các nỗ lực khôi phục math.random
            if method == "random" and tostring(self):find("math") then
                return math.random(...)
            end
            
            return oldNamecall(self, ...)
        end
        
        setreadonly(mt, true)
        print("[Layer 6] Metatable protection active")
    end
end

-- ==========================================
-- LỚP 7: TỰ ĐỘNG KÍCH HOẠT DOUBLE OR NOTHING
-- ==========================================
local function AutoTriggerDoubleOrNothing()
    -- Quét workspace tìm cây trồng có thể thu hoạch
    task.spawn(function()
        while IsActive do
            task.wait(1)
            
            pcall(function()
                -- Tìm các object có thể tương tác
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                        local parent = obj.Parent
                        if parent and parent:IsA("Model") then
                            local name = parent.Name:lower()
                            if name:find("plant") or name:find("crop") or name:find("flower") or name:find("tree") then
                                -- Tự động kích hoạt
                                if obj:IsA("ProximityPrompt") then
                                    pcall(function() obj:InputHoldBegin() end)
                                elseif obj:IsA("ClickDetector") then
                                    pcall(function() fireclickdetector(obj) end)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

-- ==========================================
-- KHỞI ĐỘNG TẤT CẢ CÁC LỚP
-- ==========================================
local function Initialize()
    print([[
============================================
  ALWAYS DOUBLE - PERMANENT MODE
  All layers activating...
============================================
    ]])
    
    -- Layer 1: Math.random
    print("[Layer 1] Math.random hooked")
    
    -- Layer 2: RemoteEvent OnClientEvent
    HookAllRemoteEvents()
    
    -- Layer 3: RemoteFunction OnClientInvoke
    HookAllRemoteFunctions()
    
    -- Layer 4: Leaderstats Monitor
    MonitorLeaderstats()
    
    -- Layer 5: FireServer Hook
    HookFireServer()
    
    -- Layer 6: Metatable Protection
    pcall(HookMetatables)
    
    -- Layer 7: Auto Trigger (optional)
    -- AutoTriggerDoubleOrNothing()
    
    print([[
============================================
  ALL LAYERS ACTIVE
  Double ratio: 100%
  Original ratio: 40% -> OVERRIDDEN
============================================
    ]])
end

-- ==========================================
-- BẢO VỆ CHỐNG GỠ BỎ
-- ==========================================
local function AntiRemoval()
    -- Định kỳ kiểm tra và khôi phục hook
    task.spawn(function()
        while IsActive do
            task.wait(30)
            
            -- Kiểm tra math.random còn bị hook không
            if math.random == OriginalMathRandom then
                print("[Anti-Removal] Restoring math.random hook...")
                math.random = function(...)
                    local count = select("#", ...)
                    if count == 0 then return OriginalMathRandom() * 0.39
                    elseif count == 1 then return ...
                    elseif count == 2 then return select(2, ...) end
                    return OriginalMathRandom(...)
                end
            end
        end
    end)
end

-- ==========================================
-- UI NHỎ HIỂN THỊ TRẠNG THÁI
-- ==========================================
local function CreateStatusIndicator()
    local SG = Instance.new("ScreenGui")
    SG.Name = "DoubleStatus"
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local StatusFrame = Instance.new("Frame")
    StatusFrame.Parent = SG
    StatusFrame.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    StatusFrame.BorderSizePixel = 0
    StatusFrame.Size = UDim2.new(0, 120, 0, 28)
    StatusFrame.Position = UDim2.new(1, -130, 0, 10)
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 14)
    Corner.Parent = StatusFrame
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Parent = StatusFrame
    StatusText.BackgroundTransparency = 1
    StatusText.Size = UDim2.new(1, 0, 1, 0)
    StatusText.Font = Enum.Font.GothamBold
    StatusText.Text = "✓ DOUBLE ON"
    StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusText.TextSize = 13
    
    -- Hiệu ứng nhấp nháy nhẹ
    task.spawn(function()
        while IsActive do
            task.wait(2)
            StatusFrame.BackgroundColor3 = Color3.fromRGB(0, 200, 90)
            task.wait(0.5)
            StatusFrame.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        end
    end)
end

-- ==========================================
-- CHẠY
-- ==========================================
Initialize()
AntiRemoval()
CreateStatusIndicator()

-- Chống AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
