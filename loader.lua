-- DexWRLD Custom Key System (No External UI Dependencies)
-- Made by DexWRLD | discord.gg/UNKmXcjytu

local KeySystemActive = true
local ValidKeys = {}
local KeyUrl = "https://raw.githubusercontent.com/DexWRLD/dexscript/refs/heads/main/keys.txt"
local MainScript = "https://raw.githubusercontent.com/DexWRLD/dexscript/refs/heads/main/dexscript.lua"

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

-- Fetch valid keys from GitHub
local function LoadKeys()
    local success, result = pcall(function()
        return game:HttpGet(KeyUrl)    end)
    
    if success then
        for key in result:gmatch("[^\n]+") do
            table.insert(ValidKeys, (key:gsub("%s+", "")))    else
                    end
                return true
        warn("Failed to load keys: " .. tostring(result))
        return false
    end
end

-- Create GUI
local function CreateKeyGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DexKeySystem"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    if syn then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    else
        ScreenGui.Parent = CoreGui
    end

    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 450, 0, 300)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    -- Corner
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = MainFrame

    -- Shadow Effect
    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.BackgroundTransparency = 1
    Shadow.Position = UDim2.new(0, -15, 0, -15)
    Shadow.Size = UDim2.new(1, 30, 1, 30)
    Shadow.ZIndex = 0
    Shadow.Image = "rbxassetid://6014261993"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.5
    Shadow.Parent = MainFrame

    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar

    -- Title Text
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -20, 1, 0)
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🔑 DexWRLD Key System"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "Close"
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -40, 0, 10)
    CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    CloseButton.BorderSizePixel = 0
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    CloseButton.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)

    -- Info Text
    local InfoText = Instance.new("TextLabel")
    InfoText.Name = "Info"
    InfoText.Size = UDim2.new(1, -40, 0, 80)
    InfoText.Position = UDim2.new(0, 20, 0, 65)
    InfoText.BackgroundTransparency = 1
    InfoText.Font = Enum.Font.Gotham
    InfoText.Text = "📌 Get your key from Discord:\ndiscord.gg/UNKmXcjytu\n\n💡 Complete Linkvertise ads in #keys"
    InfoText.TextColor3 = Color3.fromRGB(200, 200, 200)
    InfoText.TextSize = 13
    InfoText.TextWrapped = true
    InfoText.TextYAlignment = Enum.TextYAlignment.Top
    InfoText.Parent = MainFrame

    -- Key Input Box
    local KeyBox = Instance.new("TextBox")
    KeyBox.Name = "KeyBox"
    KeyBox.Size = UDim2.new(1, -40, 0, 45)
    KeyBox.Position = UDim2.new(0, 20, 0, 160)
    KeyBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    KeyBox.BorderSizePixel = 0
    KeyBox.Font = Enum.Font.Gotham
    KeyBox.PlaceholderText = "Enter key here..."
    KeyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    KeyBox.Text = ""
    KeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyBox.TextSize = 14
    KeyBox.ClearTextOnFocus = false
    KeyBox.Parent = MainFrame

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 8)
    BoxCorner.Parent = KeyBox

    -- Submit Button
    local SubmitButton = Instance.new("TextButton")
    SubmitButton.Name = "Submit"
    SubmitButton.Size = UDim2.new(1, -40, 0, 45)
    SubmitButton.Position = UDim2.new(0, 20, 0, 220)
    SubmitButton.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
    SubmitButton.BorderSizePixel = 0
    SubmitButton.Font = Enum.Font.GothamBold
    SubmitButton.Text = "✓ Verify Key"
    SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SubmitButton.TextSize = 16
    SubmitButton.Parent = MainFrame

    local SubmitCorner = Instance.new("UICorner")
    SubmitCorner.CornerRadius = UDim.new(0, 8)
    SubmitCorner.Parent = SubmitButton

    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.Size = UDim2.new(1, -40, 0, 20)
    StatusLabel.Position = UDim2.new(0, 20, 1, -30)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Waiting for key..."
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    StatusLabel.TextSize = 11
    StatusLabel.Parent = MainFrame

    -- Dragging
    local dragging, dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)

    -- Verify Key Function
    local function VerifyKey()
        local enteredKey = KeyBox.Text:gsub("%s+", "")
        
        if enteredKey == "" then
            StatusLabel.Text = "⚠️ Please enter a key!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
            return
        end

        SubmitButton.Text = "⏳ Checking..."
        SubmitButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        StatusLabel.Text = "Verifying key..."
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        
        wait(0.5)
        
        for _, validKey in ipairs(ValidKeys) do
            if enteredKey:lower() == validKey:lower() then
                -- Valid key!
                StatusLabel.Text = "✓ Key Valid! Loading script..."
                StatusLabel.TextColor3 = Color3.fromRGB(50, 255, 100)
                SubmitButton.Text = "✓ Success!"
                SubmitButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
                
                wait(1)
                ScreenGui:Destroy()
                
                -- Load main script
                local success, err = pcall(function()
                    loadstring(game:HttpGet(MainScript))()
                end)
                
                if not success then
                    warn("Failed to load main script: " .. tostring(err))
                end
                return
            end
        end
        
        -- Invalid key
        StatusLabel.Text = "❌ Invalid Key! Get key from Discord."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        SubmitButton.Text = "✕ Invalid Key"
        SubmitButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        
        wait(2)
        SubmitButton.Text = "✓ Verify Key"
        SubmitButton.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
        StatusLabel.Text = "Try again..."
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end

    SubmitButton.MouseButton1Click:Connect(VerifyKey)
    
    KeyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            VerifyKey()
        end
    end)
end

-- Main Execution
print("[DexWRLD] Loading key system...")

if LoadKeys() then
    print("[DexWRLD] Keys loaded successfully! (" .. #ValidKeys .. " keys)")
    CreateKeyGUI()
else
    warn("[DexWRLD] Failed to load keys! Check your connection.")
end
