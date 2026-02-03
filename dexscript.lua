local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()


--============================================================================
-- SERVICES & CONFIGURATION
--============================================================================


local Services = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    Players = game:GetService("Players"),
}


local LocalPlayer = Services.Players.LocalPlayer
local CardRemote = Services.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Card")
local CodesRemote = Services.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Codes")
local RemotesFolder = Services.ReplicatedStorage:FindFirstChild("Remotes")
local StockRemote = RemotesFolder and RemotesFolder:FindFirstChild("Stock")
local GetStockRemote = RemotesFolder and RemotesFolder:FindFirstChild("GetStock")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")


-- Global state
local State = {
    MyPlotID = nil,
    OwnedCardKeys = {},
    LastAutoOpenTime = 0,
    FlyActive = false,
    FlySpeed = 50,
    FlyConnection = nil,


    AutoCollectRunning = false,
    LastStockCheckTime = 0,
    -- GetStock doesn't update after a buy; we track effective stock client-side
    CardMarketEffectiveStock = {},
    CardMarketLastBuyPack = nil,
    CardMarketLastBuyTime = 0,
}


-- Auto collect config
local AutoCollect_PageCount = 8      -- total binder pages
local AutoCollect_MaxSlotIndex = 9   -- highest index you actually see (e.g. 1–9)


--============================================================================
-- UI SETUP
--============================================================================


local Window = Fluent:CreateWindow({
    Title = "Anime Card Collection | Helix Hub",
    SubTitle = "By Dex v1.5",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})


local Tabs = {
    AutoBuy    = Window:AddTab({ Title = "Auto Buy",    Icon = "shopping-cart" }),
    AutoPlace  = Window:AddTab({ Title = "Auto Place",  Icon = "mouse-pointer-2" }),
    AutoOpen   = Window:AddTab({ Title = "Auto Open",   Icon = "box" }),
    AutoCollect= Window:AddTab({ Title = "Auto Collect",Icon = "banknote" }),
    AutoUpgrade= Window:AddTab({ Title = "Auto Upgrade",Icon = "arrow-up" }),
    Codes      = Window:AddTab({ Title = "Codes",       Icon = "ticket" }),
    Speed      = Window:AddTab({ Title = "Speed Hacks", Icon = "arrow-big-right" }),
    Settings   = Window:AddTab({ Title = "Settings",    Icon = "settings" })
}


local Options = Fluent.Options


--============================================================================
-- UTILITY FUNCTIONS
--============================================================================


local function ParseValue(val)
    if type(val) == "number" then return val end
    if type(val) ~= "string" then return 0 end


    local clean = val:lower():gsub("[^%d%.%a]", "")
    local numStr = clean:match("^[%d%.]+") or "0"
    local suffix = clean:match("[%a]+$")
    local number = tonumber(numStr) or 0


    local multipliers = {
        k = 1e3, m = 1e6, b = 1e9, t = 1e12,
        q = 1e15, qa = 1e15, qi = 1e18,
        sx = 1e21, sp = 1e24
    }


    return number * (multipliers[suffix] or 1)
end


local function AutoDetectPlotId()
    local player = LocalPlayer
    local locations = {
        Workspace:FindFirstChild("Tycoons"),
        Workspace:FindFirstChild("Plots"),
        Workspace:FindFirstChild("Bases")
    }
    for _, folder in pairs(locations) do
        if folder then
            for _, plot in pairs(folder:GetChildren()) do
                local owner = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
                if tostring(owner) == player.Name then
                    local id = plot.Name:match("%d+") or plot.Name
                    return id
                end
            end
        end
    end
    return nil
end


local function AutoDetectPlotInstance()
    local id = State.MyPlotID
    if not id then return nil end


    local plots = Services.Workspace:FindFirstChild("Plots")
    return plots and plots:FindFirstChild(tostring(id)) or nil
end


local function GetPlayerCash()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return 0 end


    local hud = gui:FindFirstChild("HUD")
    if not hud then return 0 end


    local cashLabel = hud:FindFirstChild("Cash", true)
    if cashLabel and cashLabel:IsA("TextLabel") then
        return ParseValue(cashLabel.Text)
    end
    return 0
end


--============================================================================
-- INVENTORY MANAGEMENT
--============================================================================


local function RefreshInventory()
    table.clear(State.OwnedCardKeys)


    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end


    local backpack = pg:FindFirstChild("Backpack")
    if not backpack then return end


    local frame = backpack:FindFirstChild("Frame")
    if not frame then return end


    local packFrame = frame:FindFirstChild("PackFrame")
    if not packFrame then return end


    for _, child in ipairs(packFrame:GetChildren()) do
        if child.Name ~= "Template"
            and (child:IsA("Frame") or child:IsA("ImageButton") or child:IsA("TextButton")) then
            table.insert(State.OwnedCardKeys, child.Name)
        end
    end
end


local function GetBestCard()
    if #State.OwnedCardKeys == 0 then return nil end


    table.sort(State.OwnedCardKeys, function(a, b)
        local aHasMod = a:find("-") and 1 or 0
        local bHasMod = b:find("-") and 1 or 0
        if aHasMod ~= bHasMod then return aHasMod > bHasMod end
        return a < b
    end)


    return State.OwnedCardKeys[1]
end


--============================================================================
-- UI CONFIGURATION
--============================================================================


-- AUTO BUY TAB
local AutoBuySection = Tabs.AutoBuy:AddSection("Auto Buy")


Tabs.AutoBuy:AddToggle("Toggle_AutoBuy", {
    Title = "Enable Auto Buy",
    Description = "Purchase packs from the shop",
    Default = false
})


Tabs.AutoBuy:AddDropdown("Dropdown_Mode", {
    Title = "Buy Mode",
    Values = {"Normal", "Smart"},
    Default = "Smart",
    Description = "Smart: Prioritizes most expensive packs"
})

-- Pack names (used in multi-select dropdown and filter logic)
local PackNames = {"Pirate", "Ninja", "Soul", "Slayer", "Sorcerer", "Dragon", "Fire", "Hero", "Hunter", "Solo", "Titan", "Chainsaw", "Flight", "Ego", "Clover", "Ghoul"}
local PackDropdownValues = {"Select All"}
for _, p in ipairs(PackNames) do
    table.insert(PackDropdownValues, p)
end

Tabs.AutoBuy:AddDropdown("Dropdown_PackSelect", {
    Title = "Packs to buy",
    Description = "Select All = buy any pack. Uncheck Select All and pick specific packs to buy only those.",
    Values = PackDropdownValues,
    Multi = true,
    Default = {"Select All"}
})

Tabs.AutoBuy:AddInput("Input_MinPrice", {
    Title = "Minimum Price ($)",
    Default = "0",
    Numeric = true
})

-- AUTO CARD MARKET (stock market)
Tabs.AutoBuy:AddSection("Auto Card Market")
Tabs.AutoBuy:AddToggle("Toggle_AutoCardShop", {
    Title = "Enable Auto Card Market",
    Description = "Buy all packs from the card market (in stock, within price). Does not use Packs to buy dropdown.",
    Default = false
})
Tabs.AutoBuy:AddInput("Input_StockCheckInterval", {
    Title = "Delay between market cycles (seconds)",
    Default = "5",
    Numeric = true,
    Description = "Wait this long after a cycle (when nothing left to buy) before checking again. Stock is re-checked after every buy, not on a timer."
})


-- AUTO PLACE TAB
local AutoPlaceSection = Tabs.AutoPlace:AddSection("Auto Place")


Tabs.AutoPlace:AddToggle("Toggle_AutoPlace", {
    Title = "Enable Auto Place",
    Description = "Auto-equip and place packs on floor",
    Default = false
})


-- AUTO OPEN TAB
local AutoOpenSection = Tabs.AutoOpen:AddSection("Auto Open")


Tabs.AutoOpen:AddToggle("Toggle_AutoOpen", {
    Title = "Enable Auto Open",
    Description = "Auto-open ready packs with fireproximityprompt",
    Default = false
})


-- AUTO COLLECT TAB
local AutoCollectSection = Tabs.AutoCollect:AddSection("Auto Collect")


Tabs.AutoCollect:AddToggle("Toggle_AutoCollect", {
    Title = "Enable Auto Collect",
    Description = "Collect cash from binder pages",
    Default = false
})


-- AUTO UPGRADE TAB
local AutoUpgradeSection = Tabs.AutoUpgrade:AddSection("Auto Upgrade")


Tabs.AutoUpgrade:AddToggle("Toggle_AutoUpgrade", {
    Title = "Enable Auto Upgrade",
    Description = "Prioritize Luck, Hatch, Mutation, WalkSpeed",
    Default = false
})




-- SPEED TAB
Tabs.Speed:AddSection("Movement")


Tabs.Speed:AddSlider("Slider_WalkSpeed", {
    Title = "Walk Speed",
    Description = "Default is 16",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end
})


Tabs.Speed:AddSlider("Slider_JumpPower", {
    Title = "Jump Power",
    Description = "Default is 50",
    Default = 50,
    Min = 50,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = value
        end
    end
})


Tabs.Speed:AddSection("Advanced Movement")


Tabs.Speed:AddToggle("Toggle_Fly", {
    Title = "Enable Fly",
    Description = "SPACE up, LeftShift down",
    Default = false,
    Callback = function(value)
        State.FlyActive = value


        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChild("Humanoid")


        if value then
            if not root or not humanoid then return end


            if State.FlyConnection then
                State.FlyConnection:Disconnect()
                State.FlyConnection = nil
            end
            local oldBV = root:FindFirstChildOfClass("BodyVelocity")
            if oldBV then oldBV:Destroy() end


            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)


            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Name = "FlyBodyVelocity"
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Parent = root


            State.FlyConnection = RunService.RenderStepped:Connect(function()
                if not State.FlyActive or not root or not root.Parent then
                    if State.FlyConnection then
                        State.FlyConnection:Disconnect()
                        State.FlyConnection = nil
                    end
                    if bodyVelocity and bodyVelocity.Parent then
                        bodyVelocity:Destroy()
                    end
                    if humanoid then
                        humanoid.PlatformStand = false
                        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    end
                    return
                end


                local moveDirection = Vector3.new()


                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDirection += root.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection -= root.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDirection -= root.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection += root.CFrame.RightVector
                end


                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDirection += Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection -= Vector3.new(0, 1, 0)
                end


                if moveDirection.Magnitude > 0 then
                    moveDirection = moveDirection.Unit
                    bodyVelocity.Velocity = moveDirection * State.FlySpeed
                else
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)


            Fluent:Notify({
                Title = "Fly Enabled",
                Content = "Use WASD to move, SPACE up, LeftShift down",
                Duration = 2
            })
        else
            if State.FlyConnection then
                State.FlyConnection:Disconnect()
                State.FlyConnection = nil
            end


            if root then
                local bv = root:FindFirstChild("FlyBodyVelocity") or root:FindFirstChildOfClass("BodyVelocity")
                if bv then bv:Destroy() end
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end


            if humanoid then
                humanoid.PlatformStand = false
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            end


            Fluent:Notify({
                Title = "Fly Disabled",
                Content = "Fly mode turned off",
                Duration = 2
            })
        end
    end
})


Tabs.Speed:AddSlider("Slider_FlySpeed", {
    Title = "Fly Speed",
    Description = "How fast you fly",
    Default = 50,
    Min = 10,
    Max = 150,
    Rounding = 1,
    Callback = function(value)
        State.FlySpeed = value
    end
})


--============================================================================
-- UI CONFIGURATION - CODES TAB
--============================================================================


local CodesSection = Tabs.Codes:AddSection("Codes")


local AllCodes = {
    "FirstCode",
    "SecondCode",
    "ThirdCode",
    "FourthCode",
    "FifthCode",
    "SixthCode"
}


Tabs.Codes:AddButton({
    Title = "Claim All Codes",
    Description = "Redeem all available codes once",
    Callback = function()
        task.spawn(function()
            for _, code in ipairs(AllCodes) do
                local ok, err = pcall(function()
                    CodesRemote:FireServer(code)
                end)
                if not ok then
                    warn("[Codes] Failed to redeem:", code, err)
                else
                    print("[Codes] Redeemed:", code)
                end
                task.wait(0.2)
            end
        end)
    end
})


--============================================================================
-- CORE FUNCTIONS (PLACE / OPEN)
--============================================================================


local function GetRandomFloorPoint()
    local plot = AutoDetectPlotInstance()
    if not plot then return nil end

    local misc = plot:FindFirstChild("Misc")
    if not misc then return nil end

    local floor = misc:FindFirstChild("Floor")
    if not floor or not floor:IsA("BasePart") then return nil end

    local packs = plot:FindFirstChild("Packs")
    if not packs then return nil end

    local cf = floor.CFrame
    local size = floor.Size

    -- Get positions of objects to avoid (misc objects)
    local avoidPositions = {}
    for _, child in misc:GetChildren() do
        if child:IsA("Model") and child.Name ~= "Floor" and child.Name ~= "Spawn" then
            local primaryPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                table.insert(avoidPositions, primaryPart.Position)
            end
        end
    end

    -- Get positions of existing packs to avoid
    local packPositions = {}
    for _, packModel in ipairs(packs:GetChildren()) do
        local primaryPart = packModel.PrimaryPart or packModel:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            table.insert(packPositions, primaryPart.Position)
        end
    end

    local maxAttempts = 50
    local safeDistanceFromObjects = 10 -- Stay 10 studs away from misc objects
    local safeDistanceFromPacks = 8 -- Stay 8 studs away from existing packs

    for attempt = 1, maxAttempts do
        local edgeBuffer = 0.6
        local offset = CFrame.new(
            (math.random() - 0.5) * size.X * edgeBuffer,
            size.Y * 0.5 + 3,
            (math.random() - 0.5) * size.Z * edgeBuffer
        )

        local candidatePos = (cf * offset).Position

        -- Check if position is safe from misc objects
        local isSafeFromObjects = true
        for _, avoidPos in ipairs(avoidPositions) do
            if (candidatePos - avoidPos).Magnitude < safeDistanceFromObjects then
                isSafeFromObjects = false
                break
            end
        end

        -- Check if position is safe from existing packs
        local isSafeFromPacks = true
        if isSafeFromObjects then
            for _, packPos in ipairs(packPositions) do
                if (candidatePos - packPos).Magnitude < safeDistanceFromPacks then
                    isSafeFromPacks = false
                    break
                end
            end
        end

        if isSafeFromObjects and isSafeFromPacks then
            return candidatePos
        end
    end

    -- Fallback to center if no safe position found
    return (cf * CFrame.new(0, size.Y * 0.5 + 3, 0)).Position
end


local function IsPackBelow(root)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {root.Parent}


    local result = Services.Workspace:Raycast(root.Position, Vector3.new(0, -10, 0), params)
    if not result then return false end


    local parent = result.Instance
    while parent and parent ~= Services.Workspace do
        if parent.Name == "Packs" and parent.Parent == Services.Workspace then
            return true
        end
        parent = parent.Parent
    end
    return false
end


local function CountGroundPacks()
    local plot = AutoDetectPlotInstance()
    if not plot then return 0 end


    local packs = plot:FindFirstChild("Packs")
    if not packs then return 0 end


    return #packs:GetChildren()
end


local function IsPackLimitReached()
    return CountGroundPacks() >= 16
end


local function AutoPlacePacks()
    if IsPackLimitReached() then
        return
    end


    if not Options.Toggle_AutoPlace.Value then return end


    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end


    local pos = GetRandomFloorPoint()
    if not pos then return end


    RefreshInventory()
    local card = GetBestCard()
    if not card then return end


    CardRemote:FireServer("Equip", card)
    task.wait(0.25)


    root.CFrame = CFrame.new(pos)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    task.wait(0.2)


    if IsPackBelow(root) then
        return
    end


    CardRemote:FireServer("Place", card)
    CardRemote:FireServer("Unequip", card)
    task.wait(1)
end


local function GetReadyPacks()
    local ready = {}
    local plot = AutoDetectPlotInstance()
    if not plot then return ready end


    local packs = plot:FindFirstChild("Packs")
    if not packs then return ready end


    for _, packModel in ipairs(packs:GetChildren()) do
        -- Iterate through all children of the pack model
        for _, inner in ipairs(packModel:GetChildren()) do
            local timerGui = inner:FindFirstChild("PackTimer")
            if timerGui and timerGui:IsA("BillboardGui") then
                local label = timerGui:FindFirstChild("Timer") or timerGui:FindFirstChildWhichIsA("TextLabel", true)
                if label and label.Text == "Ready!" then
                    table.insert(ready, {
                        model = packModel,
                        name = packModel.Name,
                        inner = inner, -- Store the actual inner part
                    })
                end
            end
        end
    end


    return ready
end


local function AutoOpenPacks()
    if not Options.Toggle_AutoOpen.Value then return end

    if tick() - State.LastAutoOpenTime < 1.5 then return end

    local packs = GetReadyPacks()
    if #packs == 0 then return end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for _, info in ipairs(packs) do
        if not Options.Toggle_AutoOpen.Value then return end

        -- Use the stored inner part instead of looking for it by name
        local prompt = info.inner:FindFirstChild("ProximityPrompt")
        if prompt and fireproximityprompt then
            root.CFrame = CFrame.new(info.inner.Position + Vector3.new(0, 3, 0))
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            task.wait(0.3)

            pcall(function()
                fireproximityprompt(prompt)
                print("[AutoOpen] ✓ " .. info.name .. " (" .. CountGroundPacks() .. "/16)")
                State.LastAutoOpenTime = tick()
            end)

            task.wait(0.5)
        end
    end
end


--============================================================================
-- AUTO GRADE: NAME TABLE & HELPERS
--============================================================================


local Names = {
    Luffy = "Straw Hat",
    Nami = "Cat Burglar",
    Chopper = "Candy Doc",
    Usopp = "Brave Sniper",
    ["Nico Robin"] = "Demon Scholar",
    Franky = "Iron Cyborg",
    Jimbe = "Knight of the Sea",
    Sanji = "Black Leg",
    Zoro = "Three-Blade Demon",
    Naruto = "Ninetails Hero",
    Sakura = "Cherry Fist",
    Shikamaru = "Shadow Strategist",
    Hinato = "White Eye Princess",
    ["Rock Lee"] = "Green Hurricane",
    Gaara = "Desert Guardian",
    Sasuke = "Clan Avenger",
    Kakashi = "Copy Ninja",
    Minato = "Yellow Flash",
    Ichigo = "Soul Reaper",
    Kon = "Soul Doll",
    Orihime = "Gentle Healer",
    Sado = "Iron Giant",
    Ishida = "Spirit Archer",
    Rukia = "Frost Reaper",
    Renji = "Crimson Fang",
    Kenpachi = "Battle Demon",
    Kisuke = "Hidden Genius",
    Tanjiro = "Brother Slayer",
    Nezuko = "Demon Sister",
    Inosuke = "Boar King",
    Zenitsu = "Thunder Cry",
    Rengoku = "Flame Pillar",
    Mitsuri = "Love Pillar",
    Giyu = "Water Pillar",
    Obani = "Serpent Pillar",
    Sanemi = "Wind Pillar",
    Itadori = "Cursed Vessel",
    Nobara = "Voodoo Queen",
    Megumi = "Shadow Summoner",
    Toge = "Cursed Voice",
    Maki = "Heavenly Breaker",
    Todo = "Boogie Brawler",
    Yuta = "Bound Prodigy",
    Gojo = "Strongest Sorcerer",
    Sakuna = "King of Curses",
    Goku = "Earth's Hero",
    Vegeta = "Pride Prince",
    Krillin = "Mini Monk",
    Piccolo = "Green Alien",
    Trunks = "Time Traveler",
    Gohan = "Hidden Potential",
    ["Super Saiyan Rose"] = "Divine Rose",
    Broly = "Legendary Warrior",
    Beerus = "God of Destruction",
    Shinra = "Devil's Footprints",
    Iris = "Holy Flame",
    Tamaki = "Fire Kitten",
    Obi = "Iron Captain",
    Hibana = "Fire Princess",
    ["Mage Maki"] = "Witch Queen",
    Arthur = "Knight King",
    Sho = "White Angel",
    Benimaru = "The Destruction King",
    Saitama = "One-Punch Hero",
    King = "Ultimate Bluff",
    Fubuki = "Blizzard Queen",
    Sonic = "Speed Assassin",
    ["Child Emperor"] = "Genius Tactician",
    Genos = "Demon Cyborg",
    ["Silver Fang"] = "Flowing Fists",
    Kamikaze = "Atomic Blade",
    Tatsumaki = "Tornado Terror",
    Gon = "Wild Child",
    Leorio = "Aspiring Doctor",
    Shizuku = "Phantom Cleanser",
    Kurapika = "Chain Avenger",
    Kite = "Hunter Teacher",
    Killua = "Lightning Assassin",
    Hisoka = "Jester",
    Neferpitou = "Royal Predator",
    Netero = "Chairman Buddah",
    Jinwoo = "Shadow Monarch",
    ["Chae In"] = "Blade Dancer",
    Tank = "Shadow Bear",
    Yoonho = "White Tiger",
    ["Jong In"] = "Ultimate Soldier",
    Tusk = "Dread Shaman",
    Gunhee = "National Authority",
    Beru = "Shadow Ant",
    Igris = "Crimson Knight",
    Eren = "Founding Titan",
    Mikasa = "Fierce Soldier",
    Armin = "Colossal Titan",
    Sasha = "Potato Girl",
    Reiner = "Armored Titan",
    Annie = "Female Titan",
    Hange = "Titan Researcher",
    Levi = "Strongest Soldier",
    Historia = "Royal Queen",
    Denji = "Chainsaw Hybrid",
    Kobeni = "Nervous Wreck",
    Himeno = "Chaotic Senpai",
    Aki = "Topknot",
    Power = "Blood Fiend",
    Galgali = "Violence Fiend",
    Angel = "Angel",
    Reze = "Bomb Girl",
    Makima = "Boss Lady",
    -- Ego Pack
    Isagi = "Zone Player",
    Bachira = "Dribbler Genius",
    Chigiri = "Speed Star",
    Kunigami = "Burning Beast",
    Nagi = "Lazy Prodigy",
    ["King Soccer"] = "Monster",
    Shidou = "Mad Dog",
    Rin = "Genius Brother",
    Sae = "Midfield Prodigy",
    -- Clover Pack
    Asta = "Magicless Knight",
    Yuno = "Prodigy Mage",
    Noelle = "Water Princess",
    Luck = "Battle Maniac",
    William = "Noble Knight",
    Nacht = "Shadow Captain",
    Mereoleona = "Lioness",
    Yami = "Dark Magic User",
    Julius = "Time Mage",
    -- Ghoul Pack
    Kaneki = "One-Eyed Ghoul",
    Touka = "Rabbit Ghoul",
    Hinami = "Gentle Ghoul",
    Tsukiyama = "Gourmet",
    Suzuya = "Jason Junior",
    Amon = "Dove",
    Rize = "Binge Eater",
    Eto = "Owl",
    Arima = "CCG Reaper"
}


--============================================================================
-- AUTO UPGRADE
--============================================================================


local function TryUpgrade(statKey)
    local ok, err = pcall(function()
        CardRemote:FireServer("Upgrade", statKey)
    end)
    if not ok then
        warn("[AutoUpgrade] failed for", statKey, err)
    end
end


local UpgradeOrder = {
    "CardChance",
    "HatchTime",
    "MutationChance",
    "Walkspeed"
}


local function AutoUpgrade()
    if not Options.Toggle_AutoUpgrade.Value then return end


    for _, key in ipairs(UpgradeOrder) do
        if not Options.Toggle_AutoUpgrade.Value then return end
        TryUpgrade(key)
        task.wait(0.15)
    end
end


--============================================================================
-- AUTO COLLECT
--============================================================================


local function CollectCardSlot(slotIndex, side)
    local plot = AutoDetectPlotInstance()
    if not plot then return end


    local ok, err = pcall(function()
        local display = plot:WaitForChild("Map"):WaitForChild("Display")
        local sideFolder = display:WaitForChild(side)
        local cardSlot = sideFolder:FindFirstChild(tostring(slotIndex))
        if not cardSlot then return end
        CardRemote:FireServer("Collect", cardSlot)
        task.wait(0.1)
    end)


    if not ok then
        warn("[AutoCollect] Failed slot", side, slotIndex, err)
    end
end


local function GoPage(direction)
    pcall(function()
        CardRemote:FireServer("Page", direction)
    end)
end


local function AutoCollectOnceFullCycle()
    for _ = 1, AutoCollect_PageCount + 1 do
        if not Options.Toggle_AutoCollect.Value then return end
        GoPage("LeftArrow")
        task.wait(0.2)
    end


    for page = 1, AutoCollect_PageCount do
        if not Options.Toggle_AutoCollect.Value then return end


        for slot = 1, AutoCollect_MaxSlotIndex do
            if not Options.Toggle_AutoCollect.Value then return end
            CollectCardSlot(slot, "Left")
            CollectCardSlot(slot, "Right")
        end


        if page < AutoCollect_PageCount then
            GoPage("RightArrow")
            task.wait(0.25)
        end
    end
end


local function GetPackFolder()
    local ws = Services.Workspace
    if ws:FindFirstChild("Client") then
        local client = ws:FindFirstChild("Client")
        return client and client:FindFirstChild("Packs") or nil
    end
    return ws:FindFirstChild("Packs")
end


-- Shared: build currentStock + stockAmounts from GetStock result (two-table or single-table format)
local function buildStockTables(result)
    if type(result) ~= "table" then return nil, nil end
    if type(result[1]) == "table" and type(result[2]) == "table" then
        return result[1], result[2]
    end
    local currentStock = result
    local stockAmounts = {}
    for packName, packData in pairs(result) do
        if type(packData) == "table" and packData.Amount ~= nil then
            stockAmounts[packName] = packData.Amount
        end
    end
    return currentStock, stockAmounts
end

-- Shared: get stock amount for packName (exact key or base name; base name matches "PackName-Suffix")
local function getStockAmount(currentStock, stockAmounts, packName)
    if not currentStock or not stockAmounts then return 0 end
    for stockKey, _ in pairs(currentStock) do
        local sk = type(stockKey) == "string" and stockKey or tostring(stockKey)
        if sk == packName or string.find(sk, packName .. "-") then
            return stockAmounts[sk] or 0
        end
    end
    return 0
end

-- Real stock from Stock UI: PlayerGui.Stock.Frame.ScrollingFrame.<Layout>.Stock (Text = "Stock: xN")
local function getRealStockFromUI(layoutNumber)
    local gui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Stock")
    if not gui then return nil end
    local frame = gui:FindFirstChild("Frame")
    local scroll = frame and frame:FindFirstChild("ScrollingFrame")
    if not scroll then return nil end
    local slot = layoutNumber and scroll:FindFirstChild(tostring(layoutNumber))
    if not slot then return nil end
    local stockLabel = slot:FindFirstChild("Stock")
    if not stockLabel or not stockLabel:IsA("TextLabel") then return nil end
    local text = stockLabel.Text or ""
    local n = text:match("Stock: x(%d+)")
    return n and tonumber(n) or nil
end

-- Auto Card Market: buy all packs from stock market (does not use Packs to buy dropdown)
-- GetStock returns cached data and does NOT update after a buy; we track effective stock client-side.
local function AutoCardShopOnce()
    if not StockRemote or not GetStockRemote then return end

    local function fetchStockRaw()
        local ok, result = pcall(function()
            return GetStockRemote:InvokeServer()
        end)
        if not ok or not result or type(result) ~= "table" then return nil end
        return result
    end

    local rawResult = fetchStockRaw()
    if not rawResult then return end
    local currentStock, stockAmounts = buildStockTables(rawResult)
    if not currentStock or not stockAmounts then return end

    local cash = GetPlayerCash()
    local minPrice = tonumber(Options.Input_MinPrice.Value) or 0
    local now = tick()
    local recentBuyWindow = 30 -- seconds: don't overwrite our decrement with stale server data for this long after buying a pack

    for packName, packData in pairs(currentStock) do
        if type(packData) ~= "table" then continue end
        local serverAmount = stockAmounts[packName] or packData.Amount or 0
        -- Prefer real stock from Stock UI (PlayerGui.Stock.Frame.ScrollingFrame.<Layout>.Stock "Stock: xN")
        local realUI = getRealStockFromUI(packData.Layout)
        if realUI ~= nil then
            serverAmount = realUI
        end
        -- Use client-tracked effective stock (GetStock is cached; UI = real source when available)
        local effectiveStock
        if State.CardMarketEffectiveStock[packName] ~= nil and State.CardMarketEffectiveStock[packName] <= 0 then
            effectiveStock = 0
        else
            effectiveStock = serverAmount
            if State.CardMarketEffectiveStock[packName] ~= nil then
                effectiveStock = math.min(effectiveStock, State.CardMarketEffectiveStock[packName])
            end
            if State.CardMarketEffectiveStock[packName] == nil or State.CardMarketEffectiveStock[packName] > 0 then
                State.CardMarketEffectiveStock[packName] = serverAmount
            end
        end
        if effectiveStock <= 0 then continue end

        local price = packData.Price
        if not price then
            local success, cardConfig = pcall(function()
                return require(Services.ReplicatedStorage.Modules.Config.Core.CardConfig)
            end)
            if success and cardConfig and cardConfig.Packs and cardConfig.Packs[packName] then
                price = cardConfig.Packs[packName].Price
            end
        end

        local canBuy = false
        if not price then
            canBuy = cash > 0
        else
            canBuy = price >= minPrice and cash >= price
        end

        if canBuy then
            -- Right before buying: skip if real UI stock says 0 (PlayerGui.Stock.Frame.ScrollingFrame.<Layout>.Stock)
            local realUINow = getRealStockFromUI(packData.Layout)
            if realUINow ~= nil and realUINow <= 0 then
                continue
            end
            local success, err = pcall(function()
                StockRemote:FireServer("Buy", packName)
            end)
            if success then
                print(string.format("[Auto Card Market] Purchased %s", packName))
                State.CardMarketEffectiveStock[packName] = (State.CardMarketEffectiveStock[packName] or effectiveStock) - 1
                State.CardMarketLastBuyPack = packName
                State.CardMarketLastBuyTime = tick()
                local left = State.CardMarketEffectiveStock[packName]
                print(string.format("[Auto Card Market] Debug: %s left in stock = %s (tracked; GetStock is cached)", packName, tostring(math.max(0, left))))
            else
                warn(string.format("[Auto Card Market] Failed %s: %s", packName, tostring(err)))
            end
            cash = GetPlayerCash()
            task.wait(0.3)
        end
    end
end


--============================================================================
-- MAIN LOOP
--============================================================================


task.spawn(function()
    task.wait(1)


    State.MyPlotID = AutoDetectPlotId()
    if State.MyPlotID then
        Fluent:Notify({
            Title = "System Ready",
            Content = "Plot " .. State.MyPlotID .. " detected",
            Duration = 3
        })
    else
        Fluent:Notify({
            Title = "Warning",
            Content = "Could not find your plot",
            Duration = 5
        })
    end


    while true do
        task.wait(0.1)


        if not State.MyPlotID then
            State.MyPlotID = AutoDetectPlotId()
        end


        -- AUTO UPGRADE
        AutoUpgrade()


        -- AUTO BUY
        if Options.Toggle_AutoBuy.Value and State.MyPlotID then
            local cash = GetPlayerCash()
            local minPrice = tonumber(Options.Input_MinPrice.Value) or 0
            local mode = Options.Dropdown_Mode.Value

            -- Build "what's enabled" from the multi-select dropdown (handle any format Fluent uses)
            local packSel = (Options.Dropdown_PackSelect and Options.Dropdown_PackSelect.Value) or {}
            if type(packSel) ~= "table" then
                packSel = {}
            end

            local selectAll = false
            local enabledPackNames = {} -- set of selected pack name strings (lowercase)

            for key, val in pairs(packSel) do
                if type(key) == "string" then
                    if key == "Select All" and val then selectAll = true end
                    if key ~= "Select All" and val then
                        enabledPackNames[key:lower()] = true
                    end
                elseif type(key) == "number" and val and PackDropdownValues[key] then
                    local name = PackDropdownValues[key]
                    if name ~= "Select All" then
                        enabledPackNames[name:lower()] = true
                    end
                end
            end
            for i, key in ipairs(packSel) do
                if type(key) == "string" and key ~= "Select All" then
                    enabledPackNames[key:lower()] = true
                end
            end

            -- Belt pack matches if: Select All is on OR pack name is in enabled set
            local function packMatchesFilter(beltPackName)
                if selectAll then return true end
                local nameLower = (beltPackName or ""):lower()
                for enabledLower, _ in pairs(enabledPackNames) do
                    if nameLower == enabledLower or nameLower:find(enabledLower, 1, true) then
                        return true
                    end
                end
                return false
            end

            local packFolder = GetPackFolder()
            if packFolder then
                local candidates = {}


                for _, pack in ipairs(packFolder:GetChildren()) do
                    if pack.Name:match("%-" .. State.MyPlotID .. "$") then
                        local display = pack:FindFirstChild("ConveyorDisplay") or pack:FindFirstChild("Display")
                        if not display then
                            for _, child in ipairs(pack:GetChildren()) do
                                if child:IsA("BasePart") then
                                    local subDisplay = child:FindFirstChild("ConveyorDisplay")
                                    if subDisplay then
                                        display = subDisplay
                                        break
                                    end
                                end
                            end
                        end


                        if display then
                            local priceLabel = display:FindFirstChild("Price")
                            local price = priceLabel and ParseValue(priceLabel.Text) or 0


                            local nameLabel = display:FindFirstChild("PackName")
                            local packName = nameLabel and nameLabel.Text or ""


                            local matches = packMatchesFilter(packName)


                            if matches and price >= minPrice and cash >= price then
                                if mode == "Normal" then
                                    CardRemote:FireServer("BuyPack", pack.Name)
                                    task.wait(0.5)
                                    break
                                else
                                    table.insert(candidates, {pack = pack, price = price})
                                end
                            end
                        end
                    end
                end


                if mode == "Smart" and #candidates > 0 then
                    table.sort(candidates, function(a, b) return a.price > b.price end)
                    CardRemote:FireServer("BuyPack", candidates[1].pack.Name)
                    task.wait(0.5)
                end
            end
        end

        -- AUTO CARD MARKET: stock is checked after each buy inside AutoCardShopOnce; delay between cycles uses Input_StockCheckInterval
        if Options.Toggle_AutoCardShop and Options.Toggle_AutoCardShop.Value and StockRemote and GetStockRemote then
            local cycleDelay = tonumber(Options.Input_StockCheckInterval.Value) or 5
            if (tick() - State.LastStockCheckTime) >= cycleDelay then
                State.LastStockCheckTime = tick()
                AutoCardShopOnce()
            end
        end

        -- AUTO PLACE
        AutoPlacePacks()


        -- AUTO OPEN
        AutoOpenPacks()


        -- AUTO COLLECT
        if Options.Toggle_AutoCollect.Value and not State.AutoCollectRunning then
            State.AutoCollectRunning = true
            task.spawn(function()
                while Options.Toggle_AutoCollect.Value do
                    AutoCollectOnceFullCycle()
                    task.wait(1.5)
                end
                State.AutoCollectRunning = false
            end)
        end
    end
end)


-- Update walk speed/jump when character respawns
LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.1)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = Options.Slider_WalkSpeed.Value or 16
        humanoid.JumpPower = Options.Slider_JumpPower.Value or 50
    end
end)


--============================================================================
-- FINALIZATION
--============================================================================


SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)


Window:SelectTab(1)
