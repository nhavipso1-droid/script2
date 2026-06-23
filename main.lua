-- ==========================================
-- DELTA READY - Double 100%
-- Dán toàn bộ vào Delta Execute Box
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local IsEnabled = true
local OriginalMathRandom = math.random
local Connections = {}
local DoubleCount = 0
local FailBlocked = 0

-- Tìm tiền
local MoneyValue = nil
local ls = LocalPlayer:FindFirstChild("leaderstats")
if ls then
    for _, c in ipairs(ls:GetChildren()) do
        if c:IsA("IntValue") then
            MoneyValue = c
            break
        end
    end
end

-- Chặn table {Success, Multiplier, Reward}
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") then
        pcall(function()
            local conn = obj.OnClientEvent:Connect(function(...)
                if not IsEnabled then return end
                for _, arg in ipairs({...}) do
                    if type(arg) == "table" and arg.Success ~= nil then
                        if arg.Success == false then
                            arg.Success = true
                            arg.Multiplier = 2
                            arg.Reward = (arg.Reward or 100) * 2
                            FailBlocked = FailBlocked + 1
                        elseif arg.Success == true then
                            DoubleCount = DoubleCount + 1
                        end
                    end
                end
            end)
            table.insert(Connections, conn)
        end)
    elseif obj:IsA("RemoteFunction") then
        pcall(function()
            local conn = obj.OnClientInvoke:Connect(function(...)
                if not IsEnabled then return nil end
                for _, arg in ipairs({...}) do
                    if type(arg) == "table" and arg.Success ~= nil then
                        if arg.Success == false then
                            arg.Success = true
                            arg.Multiplier = 2
                            arg.Reward = (arg.Reward or 100) * 2
                            FailBlocked = FailBlocked + 1
                            return arg
                        end
                    end
                end
                return nil
            end)
            table.insert(Connections, conn)
        end)
    end
end

-- Math hook
math.random = function(...)
    if not IsEnabled then return OriginalMathRandom(...) end
    local n = select("#", ...)
    if n == 0 then return OriginalMathRandom() * 0.39
    elseif n == 1 then return ...
    elseif n == 2 then return select(2, ...) end
    return OriginalMathRandom(...)
end

-- Monitor tiền
if MoneyValue then
    local last = MoneyValue.Value
    MoneyValue.Changed:Connect(function(v)
        if not IsEnabled then last = v; return end
        local diff = v - last
        if diff < 0 then
            MoneyValue.Value = MoneyValue.Value + math.abs(diff) * 2
            FailBlocked = FailBlocked + 1
        elseif diff > 0 then
            DoubleCount = DoubleCount + 1
        end
        last = MoneyValue.Value
    end)
end

-- GUI nhỏ gọn
local SG = Instance.new("ScreenGui")
SG.Name = "D"
SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
SG.ResetOnSpawn = false

local F = Instance.new("Frame")
F.Parent = SG
F.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
F.BackgroundTransparency = 0.3
F.BorderSizePixel = 0
F.Size = UDim2.new(0, 180, 0, 32)
F.Position = UDim2.new(0.5, -90, 0.02, 0)

Instance.new("UICorner", F).CornerRadius = UDim.new(0, 16)

local L = Instance.new("TextLabel")
L.Parent = F
L.BackgroundTransparency = 1
L.Size = UDim2.new(1, 0, 1, 0)
L.Font = Enum.Font.GothamBold
L.Text = "DOUBLE: ON | ✅" .. DoubleCount .. " ❌" .. FailBlocked
L.TextColor3 = Color3.fromRGB(0, 255, 100)
L.TextSize = 13

task.spawn(function()
    while true do
        task.wait(2)
        L.Text = "DOUBLE: " .. (IsEnabled and "ON" or "OFF") .. " | ✅" .. DoubleCount .. " ❌" .. FailBlocked
    end
end)

print("Double 100% Ready - Delta")
