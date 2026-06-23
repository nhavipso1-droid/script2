-- ==========================================
-- SCRIPT: Always Double - GitHub Loader
-- DESCRIPTION: Tải và chạy script từ GitHub Raw.
--              Hỗ trợ tự động cập nhật phiên bản mới nhất.
-- USAGE: Paste toàn bộ script này vào Executor.
-- ==========================================

-- // URL GitHub Raw (thay bằng URL thực tế của bạn)
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/USERNAME/REPO/main/always_double.lua"

-- // Hàm tải script từ GitHub
local function LoadFromGitHub(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success and result and #result > 50 then
        print("[GitHub Loader] Tải thành công: " .. #result .. " bytes")
        return result
    else
        warn("[GitHub Loader] LỖI: Không thể tải từ " .. url)
        return nil
    end
end

-- // Hàm tạo GUI loader đơn giản
local function CreateLoaderGUI()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GitHubLoader"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local Frame = Instance.new("Frame")
    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.Position = UDim2.new(0.35, 0, 0.4, 0)
    Frame.Size = UDim2.new(0, 300, 0, 120)
    
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Frame
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, 0, 0.5, 0)
    Label.Font = Enum.Font.GothamBold
    Label.Text = "DANG TAI SCRIPT..."
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 18
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Parent = Frame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 0, 0.5, 0)
    StatusLabel.Size = UDim2.new(1, 0, 0.5, 0)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Ket noi GitHub..."
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 12
    
    return ScreenGui, StatusLabel
end

-- // Chạy loader
local gui, statusLabel = CreateLoaderGUI()

-- Thử tải script từ GitHub
statusLabel.Text = "Dang tai tu GitHub..."
local scriptContent = LoadFromGitHub(GITHUB_RAW_URL)

if scriptContent then
    statusLabel.Text = "Da tai xong! Dang chay..."
    task.wait(1)
    gui:Destroy()
    
    -- Chạy script đã tải
    local success, err = pcall(function()
        loadstring(scriptContent)()
    end)
    
    if not success then
        warn("[GitHub Loader] Loi chay script: " .. tostring(err))
        
        -- Hiển thị lỗi
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
        local ErrorGui = Instance.new("ScreenGui")
        ErrorGui.Name = "ErrorDisplay"
        ErrorGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        
        local ErrorFrame = Instance.new("Frame")
        ErrorFrame.Parent = ErrorGui
        ErrorFrame.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
        ErrorFrame.BorderSizePixel = 0
        ErrorFrame.Position = UDim2.new(0.3, 0, 0.35, 0)
        ErrorFrame.Size = UDim2.new(0, 350, 0, 150)
        
        Instance.new("UICorner", ErrorFrame).CornerRadius = UDim.new(0, 10)
        
        local ErrorTitle = Instance.new("TextLabel")
        ErrorTitle.Parent = ErrorFrame
        ErrorTitle.BackgroundTransparency = 1
        ErrorTitle.Size = UDim2.new(1, 0, 0.3, 0)
        ErrorTitle.Font = Enum.Font.GothamBold
        ErrorTitle.Text = "LOI CHAY SCRIPT"
        ErrorTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
        ErrorTitle.TextSize = 18
        
        local ErrorText = Instance.new("TextLabel")
        ErrorText.Parent = ErrorFrame
        ErrorText.BackgroundTransparency = 1
        ErrorText.Position = UDim2.new(0.05, 0, 0.3, 0)
        ErrorText.Size = UDim2.new(0.9, 0, 0.7, 0)
        ErrorText.Font = Enum.Font.Gotham
        ErrorText.Text = tostring(err)
        ErrorText.TextColor3 = Color3.fromRGB(255, 200, 200)
        ErrorText.TextSize = 11
        ErrorText.TextWrapped = true
    end
else
    statusLabel.Text = "LOI: Khong the tai script!"
    
    -- Script dự phòng (fallback) nếu không tải được từ GitHub
    task.wait(2)
    gui:Destroy()
    
    print("[GitHub Loader] Chay script du phong...")
    
    -- ==========================================
    -- SCRIPT DỰ PHÒNG (EMBEDDED)
    -- ==========================================
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    local UserInputService = game:GetService("UserInputService")
    
    local IsEnabled = false
    local Connections = {}
    
    -- Quét tất cả RemoteEvent
    local function GetAllRemotes()
        local events = {}
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                table.insert(events, obj)
            end
        end
        return events
    end
    
    -- Bật
    local function Enable()
        if IsEnabled then return end
        IsEnabled = true
        
        local allEvents = GetAllRemotes()
        for _, evt in ipairs(allEvents) do
            local conn = evt.OnClientEvent:Connect(function(...)
                if not IsEnabled then return end
                local args = {...}
                for i, arg in ipairs(args) do
                    if type(arg) == "string" and arg:upper() == "NOTHING" then
                        args[i] = "DOUBLE"
                        if args[i+1] and type(args[i+1]) == "number" then
                            args[i+1] = args[i+1] * 2
                        end
                        print("[Fallback] Da sua NOTHING -> DOUBLE")
                    end
                end
            end)
            table.insert(Connections, conn)
        end
        print("[Fallback] Da bat - " .. #Connections .. " ket noi")
    end
    
    -- Tắt
    local function Disable()
        IsEnabled = false
        for _, conn in ipairs(Connections) do
            conn:Disconnect()
        end
        Connections = {}
        print("[Fallback] Da tat")
    end
    
    -- GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AlwaysDouble_Fallback"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local Frame = Instance.new("Frame")
    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Frame.BorderSizePixel = 0
    Frame.Position = UDim2.new(0.7, 0, 0.2, 0)
    Frame.Size = UDim2.new(0, 200, 0, 120)
    Frame.Active = true
    Frame.Draggable = true
    
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
    
    local Btn = Instance.new("TextButton")
    Btn.Parent = Frame
    Btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    Btn.BorderSizePixel = 0
    Btn.Position = UDim2.new(0.1, 0, 0.2, 0)
    Btn.Size = UDim2.new(0.8, 0, 0, 50)
    Btn.Font = Enum.Font.GothamBold
    Btn.Text = "TAT"
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.TextSize = 22
    Btn.AutoButtonColor = false
    
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Frame
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0.05, 0, 0.65, 0)
    Label.Size = UDim2.new(0.9, 0, 0, 25)
    Label.Font = Enum.Font.Gotham
    Label.Text = "F6 = Bật/Tắt"
    Label.TextColor3 = Color3.fromRGB(180, 180, 180)
    Label.TextSize = 11
    
    Btn.MouseButton1Click:Connect(function()
        if IsEnabled then
            Disable()
            Btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
            Btn.Text = "TAT"
        else
            Enable()
            Btn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            Btn.Text = "BAT"
        end
    end)
    
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F6 then
            if IsEnabled then
                Disable()
                Btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
                Btn.Text = "TAT"
            else
                Enable()
                Btn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                Btn.Text = "BAT"
            end
        end
    end)
    
    LocalPlayer.Idled:Connect(function()
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new())
    end)
end
