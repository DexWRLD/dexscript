-- DexWRLD Linkvertise Key System Loader
-- Users must complete Linkvertise ads to get a key

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "DexWRLD Linkvertise Auth",
   LoadingTitle = "Complete Linkvertise ads for key",
   LoadingSubtitle = "https://discord.gg/UNKmXcjytu",
   ConfigurationSaving = { Enabled = false },
   Discord = { Enabled = true, Invite = "UNKmXcjytu", RememberJoins = true },
   KeySystem = false
})

local Tab = Window:CreateTab("Key Auth", 4483362458)

Window:CreateParagraph({Title = "Get Your Key", Content = "1. Join Discord: https://discord.gg/UNKmXcjytu\n2. Get Linkvertise link from #keys channel\n3. Complete ALL ads/checkpoints\n4. Copy key from final page\n5. Paste below\n\nTIP: Disable adblock for faster completion!"})

local KeyInput = Window:CreateInput({
   Name = "Enter Key",
   PlaceholderText = "DEX-XXXXXXXX",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      local HttpService = game:GetService("HttpService")
      -- Replace with your Pastebin raw link containing valid keys (one per line)
      local KeyUrl = "https://raw.githubusercontent.com/DexWRLD/dexscript/refs/heads/main/keys.txt"      
      pcall(function()
         local KeyResponse = HttpService:GetAsync(KeyUrl)
         local Keys = KeyResponse:split("\n")
         
         for _, ValidKey in pairs(Keys) do
            if (Text:gsub("%s+", "")):lower() == ValidKey:gsub("%s+", ""):lower() then
               Rayfield:Notify({
                  Title = "Success!",
                  Content = "Valid key! Loading Dex...",
                  Duration = 3.0,
                  Image = 4483362458
               })
               Window:Destroy()
               -- Load your main script
               loadstring(game:HttpGet("https://raw.githubusercontent.com/DexWRLD/dexscript/refs/heads/main/dexscript.lua"))()
               return
            end
         end
         
         Rayfield:Notify({
            Title = "Invalid Key",
            Content = "Wrong key. Complete Linkvertise again.",
            Duration = 4.0
         })
      end)
   end
})
