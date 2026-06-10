-- ======================
-- |        OzWare       |
-- |    V3 Dashboard     |
-- ======================

-- ======================
-- ANTI-CHEAT BYPASS
-- ======================
do
    -- Phase 1: Neutralise Heartbeat-based AC tick functions.
    -- Targets closures with exactly 3 upvalues whose first upvalue is a boolean —
    -- the known signature of the game's scheduler detection loop.
    local _RunService = game:GetService("RunService")
    local ok1, conns = pcall(getconnections, _RunService.Heartbeat)
    if ok1 and conns then
        for _, conn in ipairs(conns) do
            local fn = conn.Function
            if fn then
                local ok2, uvCount = pcall(function()
                    return #debug.getupvalues(fn)
                end)
                if ok2 and uvCount == 3 then
                    local ok3, uv1 = pcall(debug.getupvalue, fn, 1)
                    if ok3 and typeof(uv1) == "boolean" then
                        pcall(hookfunction, fn, function() end)
                    end
                end
            end
        end
    end

    -- Phase 2: Silently intercept xpcall to suppress AC error reporting.
    -- No prints inside the hook — xpcall fires thousands of times per second
    -- so any logging here causes lag. Cache capped at 200 to prevent memory bloat.
    local acCache = {}
    local acCount = 0
    local CACHE_CAP = 200
    local origXpcall
    pcall(function()
        origXpcall = hookfunction(xpcall, function(...)
            local fn = select(1, ...)
            if not acCache[fn] then
                if acCount < CACHE_CAP then
                    acCount = acCount + 1
                    acCache[fn] = { origXpcall(...) }
                else
                    return origXpcall(...)
                end
            end
            return table.unpack(acCache[fn])
        end)
    end)

    -- Phase 3: Scan GC for the AC update closure at bytecode offset 0x01AC.
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "table" and rawget(v, "update") then
                if islclosure(v.update) then
                    local uvs = debug.getupvalues(v.update)
                    if #uvs == 1 then
                        if debug.getinfo(v.update, "l") == 0x01AC then
                            hookfunction(v.update, function() end)
                        end
                    end
                end
            end
        end
    end)
end

task.defer(function()

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenSvc     = game:GetService("TweenService")
local RunSvc       = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")

local player    = Players.LocalPlayer
local ok, _gui  = pcall(function() return gethui() end)
local playerGui = ok and _gui or player:WaitForChild("PlayerGui")
local realGui   = player:WaitForChild("PlayerGui")

-- 2-second wait so game state fully loads before any function reads gamemode
task.wait(2)

local Net = RS:WaitForChild("Networking")

-- ======================
-- THEME (EzP Gui style — flat dark, pink accent)
-- ======================
local C = {
    BG       = Color3.fromRGB(25,  25,  25),         -- content background
    PANEL    = Color3.fromRGB(35,  35,  35),         -- hover / input bg
    CARD     = Color3.fromRGB(32,  32,  32),         -- subtle row alt
    BORDER   = Color3.fromRGB(52,  52,  58),         -- subtle dividers
    ACCENT   = Color3.fromRGB(220, 80,  150),        -- pink active/on
    ACCENT2  = Color3.fromRGB(240, 110, 170),        -- lighter pink
    GREEN    = Color3.fromRGB(80,  200, 140),
    RED      = Color3.fromRGB(220, 70,  100),
    YELLOW   = Color3.fromRGB(230, 180, 60),
    TEXT     = Color3.fromRGB(235, 235, 235),        -- near-white
    SUBTEXT  = Color3.fromRGB(130, 130, 140),        -- grey inactive
    DIM      = Color3.fromRGB(80,  80,  90),         -- very dim
    DISABLED = Color3.fromRGB(75,  75,  82),         -- off-circle (visible on dark bg)
    ACTIVE   = Color3.fromRGB(220, 80,  150),
}
local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.GothamSemibold
local FONT_REG  = Enum.Font.Gotham


local function getMapRoot()
    return workspace:FindFirstChild("Map")
        or workspace:FindFirstChild("MapHolder")
        or workspace:FindFirstChild("Maps")
        or workspace:FindFirstChild("Stage")
end

local _inGameCache = false
local _inGameStamp = 0
local function inGameMode()
    local now = os.clock()
    if now - _inGameStamp < 0.5 then return _inGameCache end
    _inGameStamp = now
    -- Only re-evaluate every 0.5s — avoids 20+ FindFirstChild per frame
    if getMapRoot() then _inGameCache = true; return true end
    local net = RS:FindFirstChild("Networking")
    local ody = net and net:FindFirstChild("Odyssey")
    local adv = ody and ody:FindFirstChild("Adventure")
    if adv and adv:FindFirstChild("VoteEvent") then _inGameCache = true; return true end
    for _, name in ipairs({
        "OdysseyRoom","AdventureRoom","Adventure","OdysseyMap","AdventureMap",
        "Odyssey","OdysseyStage","AdventureStage","OdysseyHolder","AdventureHolder",
        "GameMap","GameFolder","BattleMap","Match","MatchFolder",
    }) do
        if workspace:FindFirstChild(name) then _inGameCache = true; return true end
    end
    _inGameCache = false
    return false
end

-- ======================
-- HELPERS
-- ======================
local function tween(o, p, t) TweenSvc:Create(o, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad), p):Play() end
local function corner(p, r)   local c=Instance.new("UICorner");  c.CornerRadius=UDim.new(0,r or 8); c.Parent=p; return c end
local function stroke(p, col, th) local s=Instance.new("UIStroke"); s.Color=col or C.BORDER; s.Thickness=th or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s end
local function gradient(p, a, b, rot)
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,a), ColorSequenceKeypoint.new(1,b or a)})
    g.Rotation=rot or 90; g.Parent=p; return g
end
local function padding(p, all, t, b, l, r)
    local pd=Instance.new("UIPadding")
    pd.PaddingTop=UDim.new(0,t or all or 0); pd.PaddingBottom=UDim.new(0,b or all or 0)
    pd.PaddingLeft=UDim.new(0,l or all or 0); pd.PaddingRight=UDim.new(0,r or all or 0)
    pd.Parent=p; return pd
end
local function listLayout(p, dir, pad, align)
    local l=Instance.new("UIListLayout")
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0, pad or 6)
    l.HorizontalAlignment=align or Enum.HorizontalAlignment.Left
    l.Parent=p; return l
end

-- ======================
-- ROOT
-- ======================
if playerGui:FindFirstChild("OzWare") then playerGui.OzWare:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name="OzWare"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
-- Keep OzWare below game GUIs so it never intercepts their clicks.
-- Game ScreenGuis typically use DisplayOrder 0–10; we stay at -1 so
-- only our own explicit interactive elements (win, floatBtn) receive input.
gui.DisplayOrder = -1
gui.Parent=playerGui

local notifQueue = {}
local function notify(msg, ok)
    local color = ok and C.GREEN or C.RED
    local f=Instance.new("Frame")
    f.Size=UDim2.new(0,300,0,40); f.Position=UDim2.new(0.5,-150,1,20)
    f.BackgroundColor3=C.PANEL; f.ZIndex=100; f.Parent=gui
    corner(f,10); stroke(f,color,1)
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(0,3,1,-12)
    accent.Position=UDim2.new(0,8,0,6); accent.BackgroundColor3=color
    accent.ZIndex=101; accent.Parent=f; corner(accent,2)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-22,1,0)
    lbl.Position=UDim2.new(0,20,0,0); lbl.BackgroundTransparency=1
    lbl.Text=(ok and "+ " or "x ")..msg; lbl.TextColor3=C.TEXT
    lbl.TextSize=12; lbl.Font=FONT_SEMI; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=101; lbl.Parent=f
    local targetY = 1 - (0.06 * (#notifQueue + 1))
    table.insert(notifQueue, f)
    tween(f, {Position=UDim2.new(0.5,-150,targetY,-50)}, 0.3)
    task.delay(3, function()
        tween(f,{Position=UDim2.new(0.5,-150,1,20), BackgroundTransparency=1},0.25)
        tween(lbl,{TextTransparency=1},0.25)
        task.wait(0.3)
        local i=table.find(notifQueue,f); if i then table.remove(notifQueue,i) end
        f:Destroy()
    end)
end
local function safeCall(fn, okMsg, failPrefix)
    local ok, err = pcall(fn)
    if okMsg or not ok then notify(ok and okMsg or ((failPrefix or "Error")..": "..tostring(err)), ok) end
    return ok
end

-- ======================
-- SETTINGS AUTOSAVE
-- ======================
local OZWARE_SAVE_FILE = "OzWare_Settings.json"
local OzSaved = { toggles = {}, characters = {}, selectedCharacter = nil }

local function canUseFiles()
    return typeof(readfile) == "function" and typeof(writefile) == "function"
end

local function loadOzSettings()
    if not canUseFiles() then return end
    local exists = false
    if typeof(isfile) == "function" then
        local ok, result = pcall(isfile, OZWARE_SAVE_FILE)
        exists = ok and result
    else
        exists = true
    end
    if not exists then return end
    local okRead, raw = pcall(readfile, OZWARE_SAVE_FILE)
    if not okRead or type(raw) ~= "string" or raw == "" then return end
    local okDecode, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if okDecode and typeof(decoded) == "table" then
        OzSaved = decoded
        OzSaved.toggles = OzSaved.toggles or {}
        OzSaved.characters = OzSaved.characters or {}
    end
end

local function saveOzSettings()
    if not canUseFiles() then return end
    pcall(function()
        writefile(OZWARE_SAVE_FILE, HttpService:JSONEncode(OzSaved))
    end)
end

local function getSavedToggle(key, default)
    OzSaved.toggles = OzSaved.toggles or {}
    local saved = OzSaved.toggles[key]
    if typeof(saved) == "boolean" then return saved end
    return default and true or false
end

local function setSavedToggle(key, value)
    OzSaved.toggles = OzSaved.toggles or {}
    OzSaved.toggles[key] = value and true or false
    saveOzSettings()
end

loadOzSettings()

-- ======================
-- WINDOW  (premium redesign)
-- Logo image: upload OzWare logo to Roblox, replace LOGO_ASSET_ID below
-- ======================
local LOGO_ASSET = "rbxassetid://109657187781033"
local WIN_W, WIN_H = 720, 440
local SIDEBAR_W    = 152

-- ── Window frame ─────────────────────────────────────────────────
local win = Instance.new("Frame")
win.Name             = "Window"
win.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
win.AnchorPoint      = Vector2.new(0.5, 0.5)
win.Position         = UDim2.new(0.5, 0, 0.5, 0)
win.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
win.BorderSizePixel  = 0
win.ClipsDescendants = true
win.Active           = false  -- true would dim screen on mobile touch
win.Visible          = false

-- ── Open/close animation (top-level so accessible at boot) ────────
local isOpen = false

local function openWindow()
    isOpen = true
    win.Visible = true
    win.Size    = UDim2.new(0, WIN_W * 0.55, 0, WIN_H * 0.55)
    win.AnchorPoint = Vector2.new(0.5, 0.5)
    win.Position    = UDim2.new(0.5, 0, 0.5, 0)
    TweenSvc:Create(win, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, WIN_W, 0, WIN_H)
    }):Play()
end

local function closeWindow()
    isOpen = false
    local t = TweenSvc:Create(win, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, WIN_W * 0.55, 0, WIN_H * 0.55)
    })
    t:Play()
    t.Completed:Connect(function()
        win.Visible = false
        win.Size    = UDim2.new(0, WIN_W, 0, WIN_H)
    end)
end

win.ZIndex = 10
win.Parent = gui

-- Rounded corners
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)

-- Outer border — 4px white, bulky
local winStroke = Instance.new("UIStroke", win)
winStroke.Color     = Color3.fromRGB(55, 55, 60)
winStroke.Thickness = 1
winStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Flat dark background
do
    local bg=Instance.new("Frame",win); bg.Size=UDim2.new(1,0,1,0)
    bg.BackgroundColor3=Color3.fromRGB(25,25,25); bg.BorderSizePixel=0; bg.ZIndex=0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
end

-- Texture layers removed for flat style





-- ── Sidebar (full height) ────────────────────────────────────────
local sidebar=Instance.new("Frame",win)
sidebar.Size=UDim2.new(0,SIDEBAR_W,1,0); sidebar.Position=UDim2.new(0,0,0,0)
sidebar.BackgroundColor3=Color3.fromRGB(22,22,22); sidebar.BorderSizePixel=0; sidebar.ZIndex=11
Instance.new("UICorner",sidebar).CornerRadius=UDim.new(0,8)
local sideDiv=Instance.new("Frame",sidebar)
sideDiv.Size=UDim2.new(0,1,1,0); sideDiv.Position=UDim2.new(1,-1,0,0)
sideDiv.BackgroundColor3=Color3.fromRGB(48,48,52); sideDiv.BorderSizePixel=0; sideDiv.ZIndex=12

-- ── Branding (top of sidebar) ─────────────────────────────────────
local brandArea=Instance.new("Frame",sidebar)
brandArea.Size=UDim2.new(1,0,0,60); brandArea.Position=UDim2.new(0,0,0,0)
brandArea.BackgroundTransparency=1; brandArea.BorderSizePixel=0; brandArea.ZIndex=13; brandArea.Active=true
local brandDiv=Instance.new("Frame",brandArea)
brandDiv.Size=UDim2.new(1,0,0,1); brandDiv.Position=UDim2.new(0,0,1,-1)
brandDiv.BackgroundColor3=Color3.fromRGB(48,48,52); brandDiv.BorderSizePixel=0; brandDiv.ZIndex=14
local logoImg=Instance.new("ImageLabel",brandArea)
logoImg.Size=UDim2.new(0,38,0,38); logoImg.AnchorPoint=Vector2.new(0,0.5)
logoImg.Position=UDim2.new(0,8,0.5,0); logoImg.BackgroundTransparency=1
logoImg.BorderSizePixel=0; logoImg.Image=LOGO_ASSET; logoImg.ScaleType=Enum.ScaleType.Fit; logoImg.ZIndex=14
Instance.new("UICorner",logoImg).CornerRadius=UDim.new(0,19)
local logoFallback=Instance.new("TextLabel",brandArea)
logoFallback.Size=UDim2.new(0,88,0,18); logoFallback.Position=UDim2.new(0,52,0,10)
logoFallback.BackgroundTransparency=1; logoFallback.Text="OzWare"
logoFallback.TextColor3=C.TEXT; logoFallback.TextSize=14; logoFallback.Font=FONT_BOLD
logoFallback.TextXAlignment=Enum.TextXAlignment.Left; logoFallback.ZIndex=15
local gameLabel=Instance.new("TextLabel",brandArea)
gameLabel.Size=UDim2.new(1,-14,0,13); gameLabel.Position=UDim2.new(0,52,0,32)
gameLabel.BackgroundTransparency=1; gameLabel.Text="Anime Vanguards"
gameLabel.TextColor3=C.DIM; gameLabel.TextSize=10; gameLabel.Font=FONT_REG
gameLabel.TextXAlignment=Enum.TextXAlignment.Left; gameLabel.ZIndex=15

local dragging,dragStart,winStart=false,nil,nil
brandArea.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; winStart=win.Position
    end
end)
brandArea.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        win.Position=UDim2.new(winStart.X.Scale,winStart.X.Offset+d.X,winStart.Y.Scale,winStart.Y.Offset+d.Y)
    end
end)

local tabList=Instance.new("Frame",sidebar)
tabList.Size=UDim2.new(1,0,1,-60); tabList.Position=UDim2.new(0,0,0,60)
tabList.BackgroundTransparency=1; tabList.ZIndex=12
listLayout(tabList,nil,4,Enum.HorizontalAlignment.Center)

-- ── Content area ──────────────────────────────────────────────────
local contentArea=Instance.new("Frame",win)
contentArea.Size=UDim2.new(1,-SIDEBAR_W,1,0); contentArea.Position=UDim2.new(0,SIDEBAR_W,0,0)
contentArea.BackgroundTransparency=1; contentArea.ClipsDescendants=true; contentArea.ZIndex=11

-- ── Tab system ────────────────────────────────────────────────────
local tabButtons,tabLabels,tabIcons,tabPages,activeTab={},{},{},{},nil
local TAB_NAMES={"Lobby","Joiner","Game","Odyssey","SpringLTM","Macro"}

local function makePage()
    local p=Instance.new("ScrollingFrame")
    p.Size=UDim2.new(1,0,1,0); p.BackgroundTransparency=1; p.BorderSizePixel=0
    p.ScrollBarThickness=2; p.ScrollBarImageColor3=C.ACCENT
    p.CanvasSize=UDim2.new(0,0,0,0); p.AutomaticCanvasSize=Enum.AutomaticSize.Y
    p.Visible=false; p.ZIndex=12; p.Parent=contentArea
    listLayout(p,nil,8); padding(p,nil,8,8,8,8)
    return p
end

local function switchTab(name)
    for n,_ in pairs(tabPages) do
        tabPages[n].Visible=false
        if tabButtons[n] then
            tween(tabButtons[n],{BackgroundColor3=Color3.fromRGB(22,22,22)},0.1)
            if tabLabels[n] then tabLabels[n].TextColor3=C.SUBTEXT end
        end
    end
    tabPages[name].Visible=true
    tween(tabButtons[name],{BackgroundColor3=C.ACCENT},0.1)
    tabLabels[name].TextColor3=Color3.fromRGB(255,255,255)
    activeTab=name
end

for i,name in ipairs(TAB_NAMES) do
    local b=Instance.new("TextButton",tabList)
    b.Size=UDim2.new(1,-10,0,32); b.BackgroundColor3=Color3.fromRGB(22,22,22)
    b.BackgroundTransparency=0; b.Text=""; b.AutoButtonColor=false
    b.BorderSizePixel=0; b.LayoutOrder=i; b.ZIndex=13
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    local lbl=Instance.new("TextLabel",b)
    lbl.Size=UDim2.new(1,-16,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=name
    lbl.TextColor3=C.SUBTEXT; lbl.TextSize=13; lbl.Font=FONT_REG
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=14
    local ico=Instance.new("TextLabel",b); ico.Size=UDim2.new(0,0,0,0)
    ico.BackgroundTransparency=1; ico.Text=""; ico.ZIndex=0
    tabButtons[name]=b; tabLabels[name]=lbl; tabIcons[name]=ico
    tabPages[name]=makePage()
    b.MouseButton1Click:Connect(function() switchTab(name) end)
    b.MouseEnter:Connect(function()
        if activeTab~=name then tween(b,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end
    end)
    b.MouseLeave:Connect(function()
        if activeTab~=name then tween(b,{BackgroundColor3=Color3.fromRGB(22,22,22)},0.08) end
    end)
end


-- ======================
-- COMPONENTS
-- ======================
local function section(page, title, order)
    -- Flat section: just a small centered text header, no card box
    if title and title ~= "" then
        local hdr=Instance.new("TextLabel",page)
        hdr.Size=UDim2.new(1,0,0,26); hdr.BackgroundTransparency=1
        hdr.Text=title; hdr.TextColor3=C.DIM
        hdr.TextSize=10; hdr.Font=FONT_BOLD
        hdr.TextXAlignment=Enum.TextXAlignment.Center
        hdr.LayoutOrder=(order or 1)*2-1; hdr.ZIndex=3
    end
    local card=Instance.new("Frame",page)
    card.Size=UDim2.new(1,0,0,0); card.AutomaticSize=Enum.AutomaticSize.Y
    card.BackgroundColor3=Color3.fromRGB(30,30,30); card.BackgroundTransparency=0; card.BorderSizePixel=0
    card.LayoutOrder=(order or 1)*2; card.ClipsDescendants=true; card.ZIndex=2
    corner(card,8); listLayout(card,nil,0)
    return card
end

local function btn(parent, label, color, order)
    color = color or C.ACCENT
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(1,-24,0,34); b.BackgroundColor3=color
    b.Text=label; b.TextColor3=Color3.fromRGB(255,255,255); b.TextSize=13; b.Font=FONT_SEMI
    b.BorderSizePixel=0; b.LayoutOrder=order or 99; b.ZIndex=3
    corner(b,6)
    b.MouseEnter:Connect(function() tween(b,{BackgroundColor3=color:Lerp(Color3.new(1,1,1),0.1)},0.08) end)
    b.MouseLeave:Connect(function() tween(b,{BackgroundColor3=color},0.08) end)
    return b
end

local function label(parent, text, order)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(1,0,0,16); l.BackgroundTransparency=1
    l.Text=text; l.TextColor3=C.DIM; l.TextSize=10; l.Font=FONT_REG
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.LayoutOrder=order or 99; l.ZIndex=3
    padding(l,nil,0,0,14,0)
    return l
end

local function input(parent, placeholder, order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,-24,0,30); f.BackgroundColor3=C.PANEL; f.BorderSizePixel=0
    f.LayoutOrder=order or 99; f.ZIndex=3
    corner(f,5)
    local tb=Instance.new("TextBox",f)
    tb.Size=UDim2.new(1,-16,1,0); tb.Position=UDim2.new(0,8,0,0)
    tb.BackgroundTransparency=1; tb.Text=""
    tb.PlaceholderText=placeholder; tb.PlaceholderColor3=C.DIM
    tb.TextColor3=C.TEXT; tb.TextSize=12; tb.Font=FONT_REG
    tb.TextXAlignment=Enum.TextXAlignment.Left; tb.ZIndex=4
    return tb
end

local function toggle(parent, text, order, default, saveKey)
    saveKey = saveKey or ("toggle:"..text)

    -- Flat row: label left, circle right
    local row=Instance.new("TextButton",parent)
    row.Size=UDim2.new(1,0,0,38); row.AutoButtonColor=false
    row.BackgroundColor3=Color3.fromRGB(30,30,30); row.BackgroundTransparency=0
    row.BorderSizePixel=0; row.Text=""
    row.LayoutOrder=order or 99; row.ZIndex=3
    -- Subtle bottom separator
    local sep=Instance.new("Frame",row)
    sep.Size=UDim2.new(1,-20,0,1); sep.Position=UDim2.new(0,10,1,-1)
    sep.BackgroundColor3=Color3.fromRGB(40,40,45); sep.BorderSizePixel=0; sep.ZIndex=4
    -- Label
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-44,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=C.SUBTEXT; lbl.TextSize=13; lbl.Font=FONT_REG
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4
    -- Circle indicator
    local circle=Instance.new("Frame",row)
    circle.Size=UDim2.new(0,16,0,16); circle.Position=UDim2.new(1,-28,0.5,-8)
    circle.BackgroundColor3=C.DISABLED; circle.BorderSizePixel=0; circle.ZIndex=5
    corner(circle,8)

    local enabled=getSavedToggle(saveKey,default)
    local function apply()
        if enabled then
            tween(circle,{BackgroundColor3=C.ACCENT},0.15)
            lbl.TextColor3=C.TEXT
        else
            tween(circle,{BackgroundColor3=C.DISABLED},0.15)
            lbl.TextColor3=C.SUBTEXT
        end
    end
    apply()

    row.MouseEnter:Connect(function()
        tween(row,{BackgroundColor3=Color3.fromRGB(40,40,40)},0.08)
    end)
    row.MouseLeave:Connect(function()
        tween(row,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08)
    end)

    local callbacks={}
    row.MouseButton1Click:Connect(function()
        enabled=not enabled; setSavedToggle(saveKey,enabled); apply()
        for _,cb in ipairs(callbacks) do task.spawn(cb,enabled) end
    end)
    return row, function() return enabled end, function(cb)
        table.insert(callbacks,cb)
        if enabled then task.spawn(cb,true) end
    end
end

-- Smooth collapsible
local function makeCollapsible(btn, list, labelText)
    local open=false
    local clip=Instance.new("Frame")
    clip.BackgroundTransparency=1; clip.BorderSizePixel=0
    clip.ClipsDescendants=true; clip.Size=UDim2.new(1,0,0,0)
    clip.LayoutOrder=list.LayoutOrder; clip.ZIndex=list.ZIndex
    clip.Parent=list.Parent
    list.Parent=clip; list.LayoutOrder=0; list.Visible=true
    local ll=list:FindFirstChildOfClass("UIListLayout")
    local function contentH()
        return ll and ll.AbsoluteContentSize.Y or list.AbsoluteSize.Y
    end
    if ll then
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if open then clip.Size=UDim2.new(1,0,0,contentH()) end
        end)
    end
    local function doToggle()
        open=not open
        btn.Text=(open and "▼" or "▶").."  "..labelText
        if open then
            local h=contentH()
            if h<4 then task.defer(function() tween(clip,{Size=UDim2.new(1,0,0,contentH())},0.25) end)
            else tween(clip,{Size=UDim2.new(1,0,0,h)},0.25) end
        else tween(clip,{Size=UDim2.new(1,0,0,0)},0.2) end
    end
    btn.MouseButton1Click:Connect(doToggle)
    return doToggle, function() return open end
end


local function chip(parent, text, selected, onClick)
    local c=Instance.new("TextButton")
    c.AutomaticSize=Enum.AutomaticSize.X
    c.Size=UDim2.new(0,0,1,-6)
    c.BackgroundColor3=selected and C.ACCENT or C.PANEL
    c.Text=text; c.TextColor3=selected and C.TEXT or C.SUBTEXT
    c.TextSize=12; c.Font=FONT_SEMI; c.BorderSizePixel=0
    c.ZIndex=4; c.Parent=parent; corner(c,6); padding(c,nil,0,0,10,10)
    c.MouseButton1Click:Connect(onClick)
    return c
end

local function hScroll(parent, h, order)
    local s=Instance.new("ScrollingFrame")
    s.Size=UDim2.new(1,0,0,h); s.BackgroundTransparency=1; s.BorderSizePixel=0
    s.ScrollBarThickness=0; s.CanvasSize=UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize=Enum.AutomaticSize.X
    s.ScrollingDirection=Enum.ScrollingDirection.X
    s.LayoutOrder=order or 99; s.ZIndex=3; s.Parent=parent
    listLayout(s,Enum.FillDirection.Horizontal,6); padding(s,nil,3,3,0,0)
    return s
end

-- ======================
-- LOBBY TAB - AUTO SUMMON TOGGLES
-- ======================
do
local lobbyPage = tabPages["Lobby"]

local sumSec = section(lobbyPage, "Auto Summoner", 1)

-- Collapsible toggle list
local sumColBtn = Instance.new("TextButton", sumSec)
sumColBtn.Size=UDim2.new(1,0,0,30); sumColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
sumColBtn.BorderSizePixel=0; sumColBtn.LayoutOrder=1
sumColBtn.Text="▶  Summoner"; sumColBtn.TextColor3=C.SUBTEXT
sumColBtn.TextSize=12; sumColBtn.Font=FONT_SEMI
sumColBtn.AutoButtonColor=false; sumColBtn.ZIndex=3
corner(sumColBtn,6)

local sumListFrame = Instance.new("Frame", sumSec)
sumListFrame.Size=UDim2.new(1,0,0,0); sumListFrame.AutomaticSize=Enum.AutomaticSize.Y
sumListFrame.BackgroundTransparency=1; sumListFrame.BorderSizePixel=0
sumListFrame.LayoutOrder=2; sumListFrame.Visible=false
listLayout(sumListFrame, nil, 4)

makeCollapsible(sumColBtn, sumListFrame, "Summoner")

-- Logger-confirmed signature (UPD 12.5):
--   ALL banners use ONE remote: Networking.Units.SummonEvent
--   SummonEvent:FireServer("SummonMany", bannerId, amount)
--   amount = 50 for all banners — game uses max-pull and deducts from currency.
--
--   bannerId confirmed from live captures:
--     Selection       "Selection"
--     Special         "Special"
--     StandardMemoria "StandardMemoria"
--     Spring26        "Spring26"
--     Spring26Memoria "Spring26Memoria"

-- Lazy-resolved so a slow RS replication doesn't silently return nil at load time
local function getSummonRemote()
    local units = Net:FindFirstChild("Units")
    return units and units:FindFirstChild("SummonEvent")
end

local function fireBanner(bannerId)
    local remote = getSummonRemote()
    if not remote then
        notify("SummonEvent not found", false)
        return false
    end
    -- amount=50: game accepts 50 as the max-pull value and deducts the correct
    -- currency automatically, same as clicking the 10x/50x button manually.
    return pcall(function()
        remote:FireServer("SummonMany", bannerId, 50)
    end)
end

local BANNERS = {
    { name = "Selection",        id = "Selection"        },
    { name = "Special",          id = "Special"          },
    { name = "Standard Memoria", id = "StandardMemoria"  },
    { name = "Spring Banner",    id = "Spring26"         },
    { name = "Spring Memoria",   id = "Spring26Memoria"  },
}

for i, b in ipairs(BANNERS) do
    local _, getOn = toggle(sumListFrame, "Auto: "..b.name, i, false, "summon-v7:"..b.id)
    task.spawn(function()
        while true do
            if getOn() and not inGameMode() then
                fireBanner(b.id)
            end
            task.wait(1.25)
        end
    end)
end

-- Claimers: collapsible selector, each toggle auto-loops every 5s in lobby
local claimSec = section(lobbyPage, "Claimer", 2)

local clmColBtn = Instance.new("TextButton", claimSec)
clmColBtn.Size=UDim2.new(1,0,0,30); clmColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
clmColBtn.BorderSizePixel=0; clmColBtn.LayoutOrder=1
clmColBtn.Text="▶  Claimers"; clmColBtn.TextColor3=C.SUBTEXT
clmColBtn.TextSize=12; clmColBtn.Font=FONT_SEMI
clmColBtn.AutoButtonColor=false; clmColBtn.ZIndex=3
corner(clmColBtn,6)

local clmListFrame = Instance.new("Frame", claimSec)
clmListFrame.Size=UDim2.new(1,0,0,0); clmListFrame.AutomaticSize=Enum.AutomaticSize.Y
clmListFrame.BackgroundTransparency=1; clmListFrame.BorderSizePixel=0
clmListFrame.LayoutOrder=2; clmListFrame.Visible=false
listLayout(clmListFrame, nil, 4)

makeCollapsible(clmColBtn, clmListFrame, "Claimers")

local CLAIMERS = {
    { name="Claim All Quests",     key="claim.quests",     fn=function() Net.Quests.ClaimQuest:FireServer("ClaimAll") end },
    { name="Claim All Milestones", key="claim.milestones", fn=function()
        for _,m in ipairs({10,25,50,70,100,150,200,250,300,400,500,750,1000}) do
            Net.Milestones.MilestonesEvent:FireServer("Claim", m); task.wait(0.08)
        end
    end},
    { name="Claim Daily Reward",   key="claim.daily",      fn=function()
        for day=1,7 do Net.DailyRewardEvent:FireServer("Claim",{[1]="Special",[2]=day}); task.wait(0.08) end
    end},
    { name="Claim Battle Pass",    key="claim.battlepass", fn=function() Net.BattlepassEvent:FireServer("ClaimAll") end},
}
local claimGetters = {}
for i,c in ipairs(CLAIMERS) do
    local _, getter = toggle(clmListFrame, c.name, i, false, c.key)
    claimGetters[i] = getter
end
-- Loop: fires each enabled claimer every 5s in lobby
do
    local loopClock = 0
    RunSvc.Heartbeat:Connect(function()
        if os.clock() - loopClock < 5 then return end
        loopClock = os.clock()
        if inGameMode() then return end
        for i, c in ipairs(CLAIMERS) do
            if claimGetters[i] and claimGetters[i]() then
                task.spawn(function() pcall(c.fn) end)
            end
        end
    end)
end
end



-- ── Cancel popup: watch Visible signal — far more reliable than polling ────
task.spawn(function()
    local popupScreen = pg:WaitForChild("PopupScreen", 30)
    if not popupScreen then return end
    local function tryCancel()
        if not popupScreen.Visible then return end
        task.wait(0.15)  -- brief delay so children are fully ready
        pcall(function()
            local btn = safePath(popupScreen,
                "BaseCancelFrame","Main","Buttons","Cancel","Button")
            if btn then btn.MouseButton1Click:Fire() end
        end)
    end
    popupScreen:GetPropertyChangedSignal("Visible"):Connect(tryCancel)
    tryCancel()  -- handle if already visible on inject
end)

-- ── Auto-retry (exact path watchers) ────────────────────────────────────────
task.spawn(function()
    local pg = player.PlayerGui

    local function safePath(root, ...)
        local cur = root
        for _, key in ipairs({...}) do
            if not cur then return nil end
            cur = cur:FindFirstChild(key)
        end
        return cur
    end

    while task.wait(0.5) do
        -- (cancel button handled via Visible signal — see setup below)

        -- Auto-retry end screen (exact path + remote)
        -- Auto Next / Auto Retry — Next takes priority when available
        pcall(function()
            local endEv   = Net:FindFirstChild("EndScreen") and Net.EndScreen:FindFirstChild("VoteEvent")
            local nextBtn  = safePath(pg,"EndScreen","Holder","Buttons","Next","Button")
            local retryBtn = safePath(pg,"EndScreen","Holder","Buttons","Retry","Button")
            if getAutoNext and getAutoNext() and nextBtn and nextBtn.Visible then
                if endEv then endEv:FireServer("Next") end
                nextBtn.MouseButton1Click:Fire()
            elseif getAutoRetry and getAutoRetry() and retryBtn and retryBtn.Visible then
                if endEv then endEv:FireServer("Retry") end
                retryBtn.MouseButton1Click:Fire()
            end
        end)
    end
end)


-- ======================
-- JOINER TAB
-- ======================
do
local joinerPage = tabPages["Joiner"]

-- Helper: build act lists of length n
local function acts(n) local t={}; for i=1,n do t[i]="Act"..i end; return t end

local STAGES = {
    Story        = (function() local t={}; for i=1,12 do t["Stage"..i]=acts(6) end; return t end)(),
    LegendStage  = (function() local t={}; for i=1,12 do t["Stage"..i]=acts(3) end; return t end)(),
    Dungeon      = { Stage1={"Act1","Act2","Act3","OccultHunt"}, Stage2={"AntIsland"}, Stage3={"FrozenVolcano"}, Stage4=acts(9), Stage5={"Underworld"} },
    Raid         = { Stage1=acts(4), Stage2=acts(5), Stage3=acts(2) },
    Challenge    = { Stage1={"ChallengeAct"}, Stage2={"ChallengeAct"}, Stage3={"ChallengeAct"} },
    BossEvent    = { IgrosEvent={"Act1","Act1Elite"}, SukonoEvent={"Act1"} },
}

local selType, selStage, selAct = "Story","Stage1","Act1"

local joinSec = section(joinerPage, "Stage Joiner", 1)
label(joinSec, "Stage Type", 1)
local typeScroll = hScroll(joinSec, 32, 2)
label(joinSec, "Stage", 3)
local stageScroll = hScroll(joinSec, 32, 4)
label(joinSec, "Act", 5)
local actScroll = hScroll(joinSec, 32, 6)

local function refreshActs()
    for _,c in ipairs(actScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local list = STAGES[selType] and STAGES[selType][selStage] or {}
    selAct = list[1] or selAct
    for _,a in ipairs(list) do
        chip(actScroll, a, a==selAct, function()
            selAct=a
            for _,ch in ipairs(actScroll:GetChildren()) do
                if ch:IsA("TextButton") then
                    tween(ch,{BackgroundColor3 = ch.Text==selAct and C.ACCENT or C.PANEL})
                    ch.TextColor3 = ch.Text==selAct and C.TEXT or C.SUBTEXT
                end
            end
        end)
    end
end

local function refreshStages()
    for _,c in ipairs(stageScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local stages = STAGES[selType] or {}
    local keys = {}
    for k in pairs(stages) do table.insert(keys,k) end
    table.sort(keys)
    selStage = keys[1] or selStage
    for _,sName in ipairs(keys) do
        chip(stageScroll, sName, sName==selStage, function()
            selStage = sName
            for _,ch in ipairs(stageScroll:GetChildren()) do
                if ch:IsA("TextButton") then
                    tween(ch,{BackgroundColor3 = ch.Text==selStage and C.ACCENT or C.PANEL})
                    ch.TextColor3 = ch.Text==selStage and C.TEXT or C.SUBTEXT
                end
            end
            refreshActs()
        end)
    end
    refreshActs()
end

local typeKeys = {}
for k in pairs(STAGES) do table.insert(typeKeys,k) end
table.sort(typeKeys)
for _,tName in ipairs(typeKeys) do
    chip(typeScroll, tName, tName==selType, function()
        selType=tName
        for _,ch in ipairs(typeScroll:GetChildren()) do
            if ch:IsA("TextButton") then
                tween(ch,{BackgroundColor3 = ch.Text==selType and C.ACCENT or C.PANEL})
                ch.TextColor3 = ch.Text==selType and C.TEXT or C.SUBTEXT
            end
        end
        refreshStages()
    end)
end
refreshStages()

local optSec = section(joinerPage, "Options", 2)
local _, getNightmare  = toggle(optSec, "Nightmare Mode", 1)
local _, getFriendsOnly= toggle(optSec, "Friends Only", 2)
local _, getAutoStart  = toggle(optSec, "Auto-Start Match (actually enter)", 3, true)

local joinBtnSec = section(joinerPage, "", 3)
local joinBtn = btn(joinBtnSec, "Join Match", C.GREEN, 1)
joinBtn.MouseButton1Click:Connect(function()
    safeCall(function()
        local friendsOnly = getFriendsOnly()
        local payload = {
            Difficulty  = getNightmare() and "Nightmare" or "Normal",
            Act         = selAct,
            StageType   = selType,
            Stage       = selStage,
            FriendsOnly = friendsOnly,
        }

        -- Search direct children of Networking only — no recursive search.
        -- Recursive FindFirstChild can match unrelated remotes deeper in the tree.
        -- AddMatch/CreateMatch excluded — those strings crash SummonButtonsHandler.
        local joinRemoteNames = {"JoinMatch", "MatchEvent", "LobbyMatchEvent"}
        local fired = false
        for _, name in ipairs(joinRemoteNames) do
            local r = Net:FindFirstChild(name)  -- direct children only
            if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
                local ok = pcall(function()
                    if r:IsA("RemoteFunction") then
                        r:InvokeServer(friendsOnly, payload)
                    else
                        r:FireServer(friendsOnly, payload)
                    end
                end)
                if ok then fired = true; break end
            end
        end
        if not fired then error("No join remote found") end

        if getAutoStart() then
            task.wait(0.5)
            local sm = Net:FindFirstChild("StartMatch", true) or Net:FindFirstChild("PlayMatch", true)
            if sm and (sm:IsA("RemoteEvent") or sm:IsA("RemoteFunction")) then
                pcall(function()
                    if sm:IsA("RemoteFunction") then sm:InvokeServer(friendsOnly)
                    else sm:FireServer(friendsOnly) end
                end)
            end
        end
    end, "Joining "..selType.." "..selStage.." "..selAct, "Join failed")
end)
end

-- ======================
-- GAME TAB
-- ======================
do
local gamePage = tabPages["Game"]

-- Track current wave — tries WavesAmount label AND WaveInfoEvent as backup
local currentWave = 0
do
    local waveConn = nil

    local function parseWave(txt)
        if type(txt) ~= "string" then return nil end
        return tonumber(txt:match("(%d+)"))
    end

    local function readTextFrom(obj)
        -- obj might be a TextLabel directly, or a Frame containing one
        if not obj then return nil end
        local ok, txt = pcall(function() return obj.Text end)
        if ok and txt then return parseWave(txt) end
        -- Try first TextLabel child
        for _, c in ipairs(obj:GetChildren()) do
            local ok2, t2 = pcall(function() return c.Text end)
            if ok2 and t2 then
                local n = parseWave(t2)
                if n then return n end
            end
        end
        return nil
    end

    local function connectWaveLabel()
        local hud      = realGui:FindFirstChild("HUD")
        local map      = hud and hud:FindFirstChild("Map")
        -- Confirmed path from Dex: Map.WaveInfo (Frame) > Wave (TextLabel)
        local waveInfo = map and map:FindFirstChild("WaveInfo")
        local obj      = waveInfo and waveInfo:FindFirstChild("Wave")
        if not obj then return false end
        local n = readTextFrom(obj)
        if n then currentWave = n end
        if waveConn then waveConn:Disconnect() end
        -- Watch text changes — works for both TextLabel and Frame > TextLabel
        local target = obj
        local ok = pcall(function() local _ = obj.Text end)
        if not ok then
            -- It's a Frame; watch the first TextLabel child
            for _, c in ipairs(obj:GetChildren()) do
                local hasText = pcall(function() local _ = c.Text end)
                if hasText then target = c; break end
            end
        end
        -- Connect signal — wrapped in pcall in case target has no Text property
        pcall(function()
            waveConn = target:GetPropertyChangedSignal("Text"):Connect(function()
                local v = readTextFrom(obj)
                if v then currentWave = v end
            end)
        end)
        return true
    end

    -- Backup: WaveInfoEvent fires whenever wave changes
    local waveEv = Net:FindFirstChild("WaveInfoEvent")
    if waveEv then
        waveEv.OnClientEvent:Connect(function(...)
            for _, v in ipairs({...}) do
                if type(v) == "number" and v > 0 then
                    currentWave = v; return
                elseif type(v) == "table" then
                    local n = tonumber(v.Wave or v.Current or v.WaveNumber or v[1])
                    if n and n > 0 then currentWave = n; return end
                end
            end
        end)
    end

    local connected = false
    RunSvc.Heartbeat:Connect(function()
        if not inGameMode() then
            currentWave = 0; connected = false; return
        end
        if not connected then
            connected = connectWaveLabel()
        end
    end)
end

local matchSec = section(gamePage, "Match Controls", 1)

-- ── Gameplay collapsible ──────────────────────────────────────────────────
local gpSelBtn = Instance.new("TextButton", matchSec)
gpSelBtn.Size=UDim2.new(1,0,0,38); gpSelBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
gpSelBtn.BackgroundTransparency=0; gpSelBtn.BorderSizePixel=0; gpSelBtn.LayoutOrder=1; gpSelBtn.ZIndex=3
gpSelBtn.Text="▶  Gameplay"; gpSelBtn.TextColor3=C.SUBTEXT; gpSelBtn.TextSize=12; gpSelBtn.Font=FONT_SEMI
gpSelBtn.AutoButtonColor=false
do local d=Instance.new("Frame",gpSelBtn); d.Size=UDim2.new(1,-20,0,1); d.Position=UDim2.new(0,10,0,0); d.BackgroundColor3=Color3.fromRGB(40,40,45); d.BorderSizePixel=0; d.ZIndex=4 end
gpSelBtn.MouseEnter:Connect(function() tween(gpSelBtn,{BackgroundColor3=Color3.fromRGB(40,40,40)},0.08) end)
gpSelBtn.MouseLeave:Connect(function() tween(gpSelBtn,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end)

local gpList = Instance.new("Frame", matchSec)
gpList.Size=UDim2.new(1,0,0,0); gpList.AutomaticSize=Enum.AutomaticSize.Y
gpList.BackgroundColor3=Color3.fromRGB(30,30,30); gpList.BorderSizePixel=0
gpList.LayoutOrder=1; gpList.ZIndex=3
listLayout(gpList,nil,0)
makeCollapsible(gpSelBtn, gpList, "Gameplay")

-- Auto Vote Start
local _, getAutoSkipStart, onAutoSkipStart = toggle(gpList, "Auto Vote Start", 1, false, "game.autoskipstart")
do
    local settingsEv = Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent")
    onAutoSkipStart(function()
        local ev = settingsEv or (Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent"))
        if ev then pcall(function() ev:FireServer("Toggle", "AutoSkipStart") end) end
    end)
end
-- Auto Next
local _, getAutoNext = toggle(gpList, "Auto Next", 2, false, "game.autonext")
-- Auto Retry
local _, getAutoRetry = toggle(gpList, "Auto Retry", 3, false, "game.autoretry")
-- Auto Skip Wave
local _, getSkipWave, onSkipWave = toggle(gpList, "Auto Skip Wave", 4, false, "game.skipwave")
do
    local settingsEv = Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent")
    onSkipWave(function()
        local ev = settingsEv or (Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent"))
        if ev then pcall(function() ev:FireServer("Toggle", "AutoSkipWaves") end) end
    end)
end
-- Auto Restart
local _, getRestartOnWave, onRestartOnWave = toggle(gpList, "Auto Restart", 5, false, "game.restartonwave")
label(gpList, "Votes to restart when wave number is reached", 6)

-- On Wave: keyboard-editable TextBox (same style as modifier boxes)
do
    local WAVE_SAVE = "OzWare_settings.json"
    local settings  = {}
    pcall(function()
        if isfile and isfile(WAVE_SAVE) then
            local t = game:GetService("HttpService"):JSONDecode(readfile(WAVE_SAVE))
            if type(t) == "table" then settings = t end
        end
    end)
    local function saveSettings()
        pcall(function()
            writefile(WAVE_SAVE, game:GetService("HttpService"):JSONEncode(settings))
        end)
    end

    local targetWave = tonumber(settings.restartWave) or 15

    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,40); row.BackgroundColor3=Color3.fromRGB(30,30,30)
    row.BorderSizePixel=0; row.LayoutOrder=7; row.ZIndex=3
    row.Parent=gpList
    do local d=Instance.new("Frame",row); d.Size=UDim2.new(1,-20,0,1); d.Position=UDim2.new(0,10,0,0); d.BackgroundColor3=Color3.fromRGB(40,40,45); d.BorderSizePixel=0; d.ZIndex=4 end

    local waveLbl = Instance.new("TextLabel", row)
    waveLbl.Size=UDim2.new(1,-80,1,0); waveLbl.BackgroundTransparency=1
    waveLbl.Text="On Wave:"; waveLbl.TextColor3=C.TEXT
    waveLbl.TextSize=13; waveLbl.Font=FONT_REG
    waveLbl.TextXAlignment=Enum.TextXAlignment.Left
    waveLbl.Position=UDim2.new(0,14,0,0); waveLbl.ZIndex=4

    local waveBox=Instance.new("TextBox", row)
    waveBox.Size=UDim2.new(0,52,0,26); waveBox.AnchorPoint=Vector2.new(1,0.5)
    waveBox.Position=UDim2.new(1,-10,0.5,0)
    waveBox.BackgroundColor3=Color3.fromRGB(40,40,45); waveBox.BorderSizePixel=0
    waveBox.Text=tostring(targetWave)
    waveBox.PlaceholderText="1-999"; waveBox.PlaceholderColor3=C.DIM
    waveBox.TextColor3=C.TEXT; waveBox.TextSize=13; waveBox.Font=FONT_BOLD
    waveBox.TextXAlignment=Enum.TextXAlignment.Center; waveBox.ZIndex=4
    corner(waveBox,5)

    local restartFired = false

    local function setWave(n)
        local newTarget = math.clamp(n, 1, 999)
        -- Only reset fired flag if new target is beyond current wave
        -- (prevents immediate re-fire when lowering the target)
        if currentWave < newTarget then
            restartFired = false
        end
        targetWave           = newTarget
        waveBox.Text         = tostring(targetWave)
        settings.restartWave = targetWave
        saveSettings()
    end

    waveBox.FocusLost:Connect(function()
        local n = tonumber(waveBox.Text)
        if n then setWave(n) else waveBox.Text = tostring(targetWave) end
    end)

    -- Read wave directly from label path every 0.25s
    -- (avoids stale currentWave when HUD connection dies on restart)
    local function readWaveDirect()
        local cur = 0
        pcall(function()
            local hud = realGui:FindFirstChild("HUD")
            local map = hud and hud:FindFirstChild("Map")
            local wi  = map and map:FindFirstChild("WaveInfo")
            local wo  = wi  and wi:FindFirstChild("Wave")
            if not wo then return end
            local ok, txt = pcall(function() return wo.Text end)
            if not ok then
                local c = wo:FindFirstChildOfClass("TextLabel")
                ok, txt = pcall(function() return c.Text end)
            end
            cur = tonumber((txt or ""):match("(%d+)")) or 0
        end)
        return cur
    end

    task.spawn(function()
        while task.wait(0.25) do
            if not getRestartOnWave() then restartFired = false; continue end
            if not inGameMode()       then restartFired = false; continue end
            local cur = readWaveDirect()
            if cur == 0 then
                restartFired = false
            elseif cur >= targetWave and not restartFired then
                restartFired = true
                local ev = Net:FindFirstChild("MatchRestartSettingEvent")
                if ev then pcall(function() ev:FireServer("Vote") end) end
            elseif cur < targetWave then
                restartFired = false
            end
        end
    end)

    -- Also hook MatchRestarted signal as extra safety net
    pcall(function()
        local gh = require(game.ReplicatedStorage.Modules.Gameplay.GameHandler)
        if gh and gh.MatchRestarted then
            gh.MatchRestarted:Connect(function() restartFired = false end)
        end
    end)
end

-- UTILITY
-- ======================
local utilSec = section(gamePage, "Utility", 2)

local BASE_KEYWORDS = {"base","spawn","path","road","floor","ground","terrain","plate"}
local function isBasePart(name)
    local n = name:lower()
    for _, kw in ipairs(BASE_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end


-- ── Delete Map Structures ─────────────────────────────────────────
local mapDeleted = false
local _, getDeleteMap, onDeleteMap = toggle(utilSec, "Delete Map Structures", 2, false, "util.deletemap")
onDeleteMap(function(on)
    if not on then mapDeleted = false; return end
    if mapDeleted then return end
    -- Wait for game to be ready (handles both click and saved-state load)
    local waited = 0
    while not inGameMode() and waited < 60 do task.wait(0.5); waited = waited + 0.5 end
    if not inGameMode() then notify("Must be in a match", false); return end
    mapDeleted = true

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local pY  = hrp and hrp.Position.Y or 0
    local count = 0

    -- Platform = large flat BasePart within 8 studs of player Y — keep visible + collidable
    local function isPlatform(p)
        return (p.Size.X > 50 or p.Size.Z > 50) and math.abs(p.Position.Y - pY) <= 8
    end

    local charSet = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then charSet[pl.Character] = true end
    end

    local SKIP = {Entities=true, Ignore=true, Camera=true}
    for _, child in ipairs(workspace:GetChildren()) do
        if SKIP[child.Name] or child.ClassName == "Terrain" or charSet[child] then continue end
        for _, p in ipairs(child:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    if not isPlatform(p) then
                        p.Transparency = 1
                        p.CanCollide   = false
                        p.CastShadow   = false
                    end
                end)
                count = count + 1
            elseif p:IsA("Decal") or p:IsA("Texture") then
                pcall(function() p.Transparency = 1 end)
            end
        end
        if child:IsA("BasePart") then
            pcall(function()
                if not isPlatform(child) then
                    child.Transparency = 1
                    child.CanCollide   = false
                end
            end)
        end
    end
    notify(("Map: hid %d parts"):format(count), true)
end)


-- ── Delete Enemies ────────────────────────────────────────────────
-- CONFIRMED: enemies live in workspace.Entities folder as numbered Models (1,2,3...)
local _, getDeleteEnemies, onDeleteEnemies = toggle(utilSec, "Delete Enemies", 3, false, "util.deletenemies")
local destroyedEnemies = {}
onDeleteEnemies(function(on)
    if not on then destroyedEnemies = {} end
end)
task.spawn(function()
    while true do
        task.wait(0.2)
        if not getDeleteEnemies() or not inGameMode() then continue end
        local entities = workspace:FindFirstChild("Entities")
        if not entities then continue end
        for _, model in ipairs(entities:GetChildren()) do
            if destroyedEnemies[model] then continue end
            if model:IsA("Model") or model:IsA("BasePart") then
                destroyedEnemies[model] = true
                pcall(function() model:Destroy() end)
            end
        end
    end
end)
-- Also watch for new enemies spawning
workspace.ChildAdded:Connect(function(child)
    if child.Name ~= "Entities" then return end
    child.ChildAdded:Connect(function(model)
        if not getDeleteEnemies() then return end
        task.wait(0.05)
        pcall(function() model:Destroy() end)
    end)
end)
do
    local entities = workspace:FindFirstChild("Entities")
    if entities then
        entities.ChildAdded:Connect(function(model)
            if not getDeleteEnemies() then return end
            task.wait(0.05)
            pcall(function() model:Destroy() end)
        end)
    end
end

-- ── FPS Boost ─────────────────────────────────────────────────────
local fpsApplied = false
local function applyFPSBoost()
    if fpsApplied then return end
    fpsApplied = true
    local Lighting = game:GetService("Lighting")
    -- settings() is nil in some executor environments — guard it
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    for _, c in ipairs(Lighting:GetChildren()) do pcall(function() c:Destroy() end) end
    Lighting.GlobalShadows=false; Lighting.FogEnd=9e9; Lighting.FogStart=9e9
    Lighting.Brightness=0; Lighting.Ambient=Color3.fromRGB(200,200,200)
    Lighting.OutdoorAmbient=Color3.fromRGB(200,200,200); Lighting.ClockTime=14
    Lighting.ExposureCompensation=0
    Lighting.ColorShift_Bottom=Color3.new(0,0,0); Lighting.ColorShift_Top=Color3.new(0,0,0)
    local Terrain = workspace.Terrain
    Terrain.WaterWaveSize=0; Terrain.WaterWaveSpeed=0
    Terrain.WaterReflectance=0; Terrain.WaterTransparency=1
    pcall(function() Terrain.Decoration=false end)
    for _, c in ipairs(Terrain:GetChildren()) do
        if c:IsA("Clouds") then pcall(function() c:Destroy() end) end
    end
    local function simplify(inst)
        if inst:IsA("BasePart") then
            pcall(function()
                inst.Material=Enum.Material.SmoothPlastic
                inst.CastShadow=false; inst.Reflectance=0
                inst.BrickColor=BrickColor.new("Medium stone grey")
            end)
        end
        local cls=inst.ClassName
        if cls=="ParticleEmitter" or cls=="Trail" or cls=="Beam"
        or cls=="Smoke" or cls=="Fire" or cls=="Sparkles"
        or cls=="SelectionBox" or cls=="Atmosphere" or cls=="Sky"
        or cls=="Clouds" or cls=="PointLight" or cls=="SpotLight"
        or cls=="SurfaceLight" then
            pcall(function() inst:Destroy() end)
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            pcall(function() inst.Transparency=1 end)
        elseif inst:IsA("SpecialMesh") then
            pcall(function() inst.MeshType=Enum.MeshType.Block end)
        end
    end
    for _, inst in ipairs(workspace:GetDescendants()) do simplify(inst) end
    notify("FPS Boost ON", true)
end

local _, getBoostFPS, onBoostFPS = toggle(utilSec, "Boost FPS", 4, false, "util.fpsbst")
onBoostFPS(function(on)
    if on then
        -- Only apply during a match, not in lobby
        if inGameMode() then
            applyFPSBoost()
        else
            task.spawn(function()
                local w = 0
                while not inGameMode() and w < 120 do task.wait(1); w=w+1 end
                if inGameMode() and getBoostFPS() then applyFPSBoost() end
            end)
        end
    elseif not on and fpsApplied then
        fpsApplied = false
        notify("FPS Boost OFF — rejoin to fully restore", true)
    end
end)

-- ── Modifier Selector ─────────────────────────────────────────────
do
local HttpSvc      = game:GetService("HttpService")
local AUTO_SAVE    = "OzWare_mod_auto.json"
local RESTART_SAVE = "OzWare_mod_restart.json"

-- Two separate priority tables
local autoPri    = {}  -- for Auto Pick (all modifiers)
local restartPri = {}  -- for Restart Modifier (starting only)
pcall(function()
    if isfile and isfile(AUTO_SAVE) then
        local t = HttpSvc:JSONDecode(readfile(AUTO_SAVE))
        if type(t) == "table" then autoPri = t end
    end
end)
pcall(function()
    if isfile and isfile(RESTART_SAVE) then
        local t = HttpSvc:JSONDecode(readfile(RESTART_SAVE))
        if type(t) == "table" then restartPri = t end
    end
end)
local function saveAuto()    pcall(function() writefile(AUTO_SAVE,    HttpSvc:JSONEncode(autoPri))    end) end
local function saveRestart() pcall(function() writefile(RESTART_SAVE, HttpSvc:JSONEncode(restartPri)) end) end

local modSec = section(gamePage, "Modifier Selector", 3)

-- ── AUTO PICK MODIFIER ────────────────────────────────────────────
local _, getAutoMod = toggle(modSec, "Auto Pick Modifier", 1, false, "game.auto_modifier")
label(modSec, "Picks highest-priority modifier when offered", 2)

-- Collapsible: ALL modifiers (Additive + Starting)
local allColBtn = Instance.new("TextButton", modSec)
allColBtn.Size=UDim2.new(1,0,0,30); allColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
allColBtn.BorderSizePixel=0; allColBtn.LayoutOrder=3
allColBtn.Text="▶  All Modifier Priorities"
allColBtn.TextColor3=C.SUBTEXT; allColBtn.TextSize=12; allColBtn.Font=FONT_SEMI
allColBtn.AutoButtonColor=false; allColBtn.ZIndex=3
corner(allColBtn,6)

local allListFrame = Instance.new("Frame", modSec)
allListFrame.Size=UDim2.new(1,0,0,0); allListFrame.AutomaticSize=Enum.AutomaticSize.Y
allListFrame.BackgroundTransparency=0; allListFrame.BackgroundColor3=Color3.fromRGB(30,30,30); allListFrame.BorderSizePixel=0
allListFrame.LayoutOrder=4; allListFrame.Visible=false
listLayout(allListFrame, nil, 0)

local allOpen = false
allColBtn.Text = "▶  All Modifier Priorities"
makeCollapsible(allColBtn, allListFrame, "All Modifier Priorities")

-- ── RESTART MODIFIER ──────────────────────────────────────────────
local _, getRestartMod = toggle(modSec, "Restart Modifier", 5, false, "game.restart_modifier")
label(modSec, "Restarts match until a priority starting modifier appears", 6)

-- Collapsible: Starting modifiers only
local rstColBtn = Instance.new("TextButton", modSec)
rstColBtn.Size=UDim2.new(1,0,0,30); rstColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
rstColBtn.BorderSizePixel=0; rstColBtn.LayoutOrder=7
rstColBtn.Text="▶  Starting Modifier Priorities"
rstColBtn.TextColor3=C.SUBTEXT; rstColBtn.TextSize=12; rstColBtn.Font=FONT_SEMI
rstColBtn.AutoButtonColor=false; rstColBtn.ZIndex=3
corner(rstColBtn,6)

local rstListFrame = Instance.new("Frame", modSec)
rstListFrame.Size=UDim2.new(1,0,0,0); rstListFrame.AutomaticSize=Enum.AutomaticSize.Y
rstListFrame.BackgroundTransparency=0; rstListFrame.BackgroundColor3=Color3.fromRGB(30,30,30); rstListFrame.BorderSizePixel=0
rstListFrame.LayoutOrder=8; rstListFrame.Visible=false
listLayout(rstListFrame, nil, 0)

local rstOpen = false
rstColBtn.Text = "▶  Starting Modifier Priorities"
makeCollapsible(rstColBtn, rstListFrame, "Starting Modifier Priorities")

-- Row builder
local function makeModRow(parent, name, priTable, saveFn, order)
    local row = Instance.new("Frame", parent)
    row.Size=UDim2.new(1,0,0,38); row.BackgroundColor3=Color3.fromRGB(30,30,30)
    row.BorderSizePixel=0; row.LayoutOrder=order or 999; row.ZIndex=3
    -- divider (skip on first row)
    if (order or 999) > 1 then
        local sep=Instance.new("Frame",row)
        sep.Size=UDim2.new(1,-20,0,1); sep.Position=UDim2.new(0,10,0,0)
        sep.BackgroundColor3=Color3.fromRGB(40,40,45); sep.BorderSizePixel=0; sep.ZIndex=4
    end
    local lbl = Instance.new("TextLabel", row)
    lbl.Size=UDim2.new(1,-66,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=name
    lbl.TextColor3=C.SUBTEXT; lbl.TextSize=13; lbl.Font=FONT_REG
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4
    lbl.TextTruncate=Enum.TextTruncate.AtEnd
    local box = Instance.new("TextBox", row)
    box.Size=UDim2.new(0,44,0,26); box.AnchorPoint=Vector2.new(1,0.5)
    box.Position=UDim2.new(1,-10,0.5,0)
    box.BackgroundColor3=Color3.fromRGB(40,40,45); box.BorderSizePixel=0
    box.Text=tostring(priTable[name] or 0)
    box.PlaceholderText="0"; box.PlaceholderColor3=C.DIM
    box.TextColor3=C.TEXT; box.TextSize=13; box.Font=FONT_BOLD
    box.TextXAlignment=Enum.TextXAlignment.Center; box.ZIndex=4
    corner(box,5)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text) or 0
        priTable[name] = n; box.Text = tostring(n); saveFn()
    end)
end

-- Group header helper
local function groupHdr(parent, text, order)
    local h = Instance.new("TextLabel", parent)
    h.Size=UDim2.new(1,0,0,24); h.BackgroundColor3=Color3.fromRGB(30,30,30)
    h.BackgroundTransparency=0; h.BorderSizePixel=0
    h.Text="─── "..text.." ───"
    h.TextColor3=C.DIM; h.TextSize=10; h.Font=FONT_BOLD
    h.TextXAlignment=Enum.TextXAlignment.Center
    h.ZIndex=3; h.LayoutOrder=order
end

-- Populate ALL list (Additive + Starting)
local ADDITIVE = {"Strong","Fast","Dodge","Damage","Cooldown","Range","Slayer",
    "Press It","Common Loot","Uncommon Loot","Champions","Precise Attack",
    "Planning Ahead","Harvest"}
local STARTING = {"Immunity","Exploding","Revitalize","Thrice","Quake","Regen",
    "Shielded","Drowsy","No Trait No Problem","Money Surge","King's Burden",
    "Lifeline","Exterminator","Warding off Evil","Fisticuffs","Limit Break",
    "Tyrant Destroyer","Sphere Finder","High Class","Tyrant Arrives"}

local o = 1
groupHdr(allListFrame, "Additive", o); o=o+1
for _, n in ipairs(ADDITIVE) do makeModRow(allListFrame, n, autoPri, saveAuto, o); o=o+1 end
groupHdr(allListFrame, "Starting", o); o=o+1
for _, n in ipairs(STARTING) do makeModRow(allListFrame, n, autoPri, saveAuto, o); o=o+1 end

-- Populate RESTART list (Starting only)
local r = 1
groupHdr(rstListFrame, "Starting", r); r=r+1
for _, n in ipairs(STARTING) do makeModRow(rstListFrame, n, restartPri, saveRestart, r); r=r+1 end

-- ── Event logic ──────────────────────────────────────────────────
local modPickFired = false

local function connectModifierEvent(modEv)
    modEv.OnClientEvent:Connect(function(action, mods)
        if action == "End" then modPickFired = false; return end
        if action ~= "Start" then return end
        modPickFired = false

        if not getAutoMod() and not getRestartMod() then return end
        if modPickFired then return end

        local offered = {}
        if type(mods) == "table" then
            for _, mod in ipairs(mods) do
                local n = type(mod) == "table" and mod.Name or tostring(mod)
                if n and n ~= "" then offered[n] = true end
            end
        end

        if getAutoMod() then
            local bestName, bestPri = nil, 0
            for n in pairs(offered) do
                local pri = autoPri[n] or 0
                if pri > bestPri then bestName=n; bestPri=pri end
            end
            if bestName and bestPri > 0 then
                modPickFired = true
                task.defer(function()
                    pcall(function() modEv:FireServer("Choose", bestName) end)
                end)
                return
            end
        end

        if getRestartMod() and not modPickFired then
            local found = false
            for n in pairs(offered) do
                if (restartPri[n] or 0) > 0 then found = true; break end
            end
            if not found then
                modPickFired = true
                local rev = Net:FindFirstChild("MatchRestartSettingEvent")
                if rev then pcall(function() rev:FireServer("Vote") end) end
            end
        end
    end)
end

-- ModifierEvent is directly under Networking, present in all game modes.
-- If injected in lobby it won't exist yet — watch for it to appear.
local modEv = Net:FindFirstChild("ModifierEvent")
if modEv then
    connectModifierEvent(modEv)
else
    Net.ChildAdded:Connect(function(child)
        if child.Name == "ModifierEvent" then
            connectModifierEvent(child)
        end
    end)
end
end -- close modifier do block

end -- close Game Tab do block

-- ======================
-- ODYSSEY TAB  (dynamic, no UUIDs)
-- ======================
do
local odysseyPage = tabPages["Odyssey"]
local autoSec = section(odysseyPage, "Adventure", 1)

-- Collapsible adventure toggles
local advColBtn = Instance.new("TextButton", autoSec)
advColBtn.Size=UDim2.new(1,0,0,30); advColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
advColBtn.BorderSizePixel=0; advColBtn.LayoutOrder=1
advColBtn.Text="▶  Adventure Settings"; advColBtn.TextColor3=C.SUBTEXT
advColBtn.TextSize=12; advColBtn.Font=FONT_SEMI
advColBtn.AutoButtonColor=false; advColBtn.ZIndex=3
corner(advColBtn,6)

local advListFrame = Instance.new("Frame", autoSec)
advListFrame.Size=UDim2.new(1,0,0,0); advListFrame.AutomaticSize=Enum.AutomaticSize.Y
advListFrame.BackgroundTransparency=1; advListFrame.BorderSizePixel=0
advListFrame.LayoutOrder=2; advListFrame.Visible=false
listLayout(advListFrame, nil, 4)

local advOpen = false
advColBtn.MouseButton1Click:Connect(function()
    advOpen = not advOpen
    advListFrame.Visible = advOpen
    advColBtn.Text = (advOpen and "▼" or "▶") .. "  Adventure Settings"
end)

local _, getAutoNextRoom      = toggle(advListFrame, "Auto Next Room",                    1, false, "odyssey.auto_next_room")
label(advListFrame, "Continues to the next room automatically", 2)
local _, getAutoPick          = toggle(advListFrame, "Auto Select Cards",                 3, true,  "odyssey.auto_select_cards")
label(advListFrame, "Picks highest rarity card when card screen appears", 4)
local _, getAutoRagnawCards   = toggle(advListFrame, "Auto Select Unit Cards (Ragnaw)",   5, false, "odyssey.auto_ragnaw_unit_cards")
label(advListFrame, "Prioritises Ragnaw unit cards when picking", 6)
local _, getAutoSkipShop      = toggle(advListFrame, "Auto Skip Shop",                    7, false, "odyssey.auto_skip_shop.v3")
label(advListFrame, "Closes Stiches' Shop automatically", 8)
local _, getAutoCollectChests = toggle(advListFrame, "Auto Collect Chests",               9, false, "odyssey.auto_collect_chest.v3")
label(advListFrame, "Opens all chests in Treasure Room", 10)
local _, getSkipUnitReward    = toggle(advListFrame, "Skip Unit Reward",                 11, false, "odyssey.skip_unit_reward")
label(advListFrame, "Skips unit reward panel after elite rooms", 12)

local ragnawPickedThisRun = {}
local ragnawPickCount     = 0

-- ======================
-- Confirmed remote locations (UPD 12.5):
--   Networking.Units.SummonEvent                          — summoning
--   Networking.Odyssey.Adventure.CardPickEvent            — card pick/skip
--   Networking.Odyssey.Adventure.ShopEvent                — shop close
--   Networking.Odyssey.Adventure.TreasureEvent            — chest open
--   Networking.Odyssey.Adventure.BossRewardEvent          — elite unit reward
--   Networking.Odyssey.Adventure.VoteEvent                — floor vote
--   Networking.Odyssey.Adventure.MapEvent                 — map snapshot
--   Networking.StageMechanics.OdysseyChest                — chest (backup)
-- ======================
local _odyFolder  = Net:FindFirstChild("Odyssey")
local _advFolder  = _odyFolder and _odyFolder:FindFirstChild("Adventure")
local _stageMech  = Net:FindFirstChild("StageMechanics")

local REMOTES = {}
local function refreshRemotes()
    _odyFolder = Net:FindFirstChild("Odyssey")
    _advFolder = _odyFolder and _odyFolder:FindFirstChild("Adventure")
    _stageMech = Net:FindFirstChild("StageMechanics")
    if _advFolder then
        -- All confirmed from Dex screenshot of Networking.Odyssey.Adventure:
        REMOTES.CardPickEvent    = _advFolder:FindFirstChild("CardPickEvent")
        REMOTES.ShopEvent        = _advFolder:FindFirstChild("ShopEvent")
            or (_odyFolder and _odyFolder:FindFirstChild("OdysseyShopEvent"))
        REMOTES.TreasureEvent    = _advFolder:FindFirstChild("TreasureEvent")
        REMOTES.UnitRewardEvent  = _advFolder:FindFirstChild("UnitRewardEvent")
        REMOTES.BossRewardEvent  = _advFolder:FindFirstChild("BossRewardEvent")
        REMOTES.VoteEvent        = _advFolder:FindFirstChild("VoteEvent")
        REMOTES.MapEvent         = _advFolder:FindFirstChild("MapEvent")
            or Net:FindFirstChild("MapEvent")
    end
    if _stageMech then
        REMOTES.OdysseyChest = _stageMech:FindFirstChild("OdysseyChest")
    end
    REMOTES.ModifierEvent = Net:FindFirstChild("ModifierEvent")
end
refreshRemotes()

-- Clear REMOTES cache on respawn/teleport so they re-resolve for the next run
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    -- Reset all one-shot flags so toggles work immediately in the new match
    for k in pairs(REMOTES) do REMOTES[k] = nil end
    mapDeleted       = false
    destroyedEnemies = {}
    fpsApplied       = false
    task.wait(3); refreshRemotes()
end)

local function getONet(name)
    if REMOTES[name] then return REMOTES[name] end
    refreshRemotes()
    return REMOTES[name]
end

-- Watch for Adventure folder appearing (happens when entering a run)
Net.ChildAdded:Connect(function(c)
    if c.Name == "Odyssey" then
        task.wait(0.5); refreshRemotes()
        c.ChildAdded:Connect(function() task.wait(0.2); refreshRemotes() end)
    end
    task.wait(0.2); refreshRemotes()
end)
do
    local odyF = Net:FindFirstChild("Odyssey")
    if odyF then
        odyF.ChildAdded:Connect(function() task.wait(0.2); refreshRemotes() end)
        local advF = odyF:FindFirstChild("Adventure")
        if advF then
            advF.ChildAdded:Connect(function() task.wait(0.1); refreshRemotes() end)
        end
    end
end

-- Rarity scoring from card text blob
local RARITY_SCORES = {secret=7, divine=7, celestial=6, mythic=5, legendary=4, epic=3, rare=2, uncommon=1, common=0}
local function rarityScore(text)
    if not text then return 0 end
    local t = text:lower()
    local best = 0
    for word, score in pairs(RARITY_SCORES) do
        if t:find(word, 1, true) and score > best then best = score end
    end
    return best
end

-- chooseCardIndex: picks the highest rarity card from text blobs
local function chooseCardIndex(opts)
    if not opts or #opts == 0 then return 1, "basic" end
    local bestIdx, bestScore = 1, -1
    for i, text in ipairs(opts) do
        local score = rarityScore(text)
        if score > bestScore then bestIdx = i; bestScore = score end
    end
    return bestIdx, "basic"
end


-- ── AdventureHUD helper ──────────────────────────────────────────
-- CONFIRMED: all panels live inside PlayerGui.AdventureHUD
-- AdventureHUD children:
--   ChooseCard              — card pick panel
--   Stiches' Shop_Export    — shop panel (note: Stiches, one t)
--   TreasurePanel           — treasure room panel
--   RunRewardsPanelRoot     — unit reward after elite room ("CLAIM YOUR REWARDS")
--   AdventureMapRoot        — map/vote UI

-- ── AdventureHUD helper ──────────────────────────────────────────
local function getAdventureHUD()
    return realGui:FindFirstChild("AdventureHUD")
end

-- All panels are direct children of AdventureHUD at runtime
-- (MatchPanels only exists in StarterPlayer source, not in PlayerGui)
local function findPanel(name)
    local hud = getAdventureHUD()
    if not hud then return nil end
    return hud:FindFirstChild(name)
end

-- A panel is "open" when Visible=true
-- CONFIRMED from debugger: game toggles Visible property, AbsoluteSize stays constant
local function isPanelOpen(panel)
    if not panel then return false end
    return panel.Visible == true
end

local function findAdventurePanel(name)
    local hud = getAdventureHUD()
    if not hud then return nil end
    local direct = hud:FindFirstChild(name)
    if direct then return direct end
    local matchPanels = hud:FindFirstChild("MatchPanels")
    if matchPanels then
        return matchPanels:FindFirstChild(name)
    end
    return nil
end

-- Click a close button using its exact confirmed path
local function clickClose(panel)
    if not panel then return end
    -- Confirmed path: panel.Content.TopFrame.RightFrame.RightFrame.Close
    local btn = panel:FindFirstChild("Content")
    if btn then
        btn = btn:FindFirstChild("TopFrame")
        if btn then
            btn = btn:FindFirstChild("RightFrame")
            if btn then
                btn = btn:FindFirstChild("RightFrame")
                if btn then
                    btn = btn:FindFirstChild("Close")
                end
            end
        end
    end
    if btn then
        pcall(function() btn.Activated:Fire() end)
        pcall(function() btn.MouseButton1Click:Fire() end)
    end
end

-- ── Card pick ────────────────────────────────────────────────────
-- CONFIRMED structure:
--   ChooseCard.Content.ListContainer
--     ImageButton (Frame) ← card 1 (leftmost)
--     ImageButton (Frame) ← card 2
--     ImageButton (Frame) ← card 3 (rightmost, usually highest rarity)
-- Card name/rarity: TextLabel (Description) inside each ImageButton
-- Pick by simulating MouseButton1Click on the ImageButton

local function getCardButtons()
    -- CONFIRMED: CardPickPanel under AdventureHUD.MatchPanels.Panels
    local cc = findPanel("CardPickPanel") or findPanel("ChooseCard")
    if not cc or not cc.Visible then return nil end

    -- Search for card buttons - try known path first, then search all descendants
    local sif = cc:FindFirstChild("Content")
    sif = sif and sif:FindFirstChild("ListContainer")
    sif = sif and sif:FindFirstChild("ScrollIndicatorFrame")

    -- If path not found, search entire panel for ImageButtons
    local searchRoot = sif or cc
    local cards = {}
    for _, child in ipairs(searchRoot:GetChildren()) do
        if child:IsA("ImageButton") then
            local text = ""
            for _, d in ipairs(child:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text and #d.Text > 1 then
                    text = text .. " " .. d.Text:lower()
                end
            end
            table.insert(cards, {
                btn  = child,
                text = text,
                x    = child.AbsolutePosition.X,
            })
        end
    end
    if #cards == 0 then return nil end
    table.sort(cards, function(a, b) return a.x < b.x end)
    return cards
end

local function clickButton(btn)
    -- Delta executor blocks :Fire() on signals
    -- We use the remote directly instead (see doCardPick and pickIndex)
    _ = btn -- unused but kept for API compatibility
end

-- Direct remote pick — works when called while ChooseCard is visible
-- The server accepts CardPickEvent only during an active card pick phase
local function pickIndex(opts, indexHint)
    local ev = getONet("CardPickEvent")
    if not ev then return false end
    local idx = indexHint or 1
    -- For character cards: first pick selects, second pick confirms
    pcall(function() ev:FireServer("Pick", idx) end)
    task.wait(0.3)
    pcall(function() ev:FireServer("Pick", idx) end)
    return true
end

local function skipCards()
    local ev = getONet("CardPickEvent")
    if ev then pcall(function() ev:FireServer("Skip", 0) end) end
end

local function readOpenCardOptions()
    local cards = getCardButtons()
    if not cards then return nil end
    -- Return text blobs for rarity scoring
    local opts = {}
    for _, c in ipairs(cards) do table.insert(opts, c.text) end
    return opts
end

-- ── Shop ─────────────────────────────────────────────────────────
-- CONFIRMED: Stiches' Shop_Export  341, 376 when open
local function isShopOpen()
    local hud = getAdventureHUD()
    if not hud then return false end
    local p = hud:FindFirstChild("Stiches' Shop_Export")
    return isPanelOpen(p)
end

local function closeShopGui()
    refreshRemotes()
    local shopEv = getONet("ShopEvent")
    if shopEv then pcall(function() shopEv:FireServer("Close") end) end
end

-- ── Treasure ─────────────────────────────────────────────────────
-- CONFIRMED: TreasurePanel  307, 239 when open
local function isTreasureOpen()
    local hud = getAdventureHUD()
    if not hud then return false end
    local p = hud:FindFirstChild("TreasurePanel")
    return isPanelOpen(p)
end

local openedChests = {}
local function collectAndCloseTreasure()
    refreshRemotes()
    local chestRemote = getONet("OdysseyChest")
    if not chestRemote then
        -- OdysseyChest is under StageMechanics
        local sm = Net:FindFirstChild("StageMechanics")
        chestRemote = sm and sm:FindFirstChild("OdysseyChest")
    end

    if chestRemote then
        -- CONFIRMED: chests are in workspace.Ignore named "OdysseyChest_<uuid>"
        local ignoreFolder = workspace:FindFirstChild("Ignore")
        if ignoreFolder then
            for _, model in ipairs(ignoreFolder:GetChildren()) do
                local name = model.Name
                -- Match OdysseyChest_<uuid> but NOT OdysseyChestPing_<uuid>
                if name:sub(1, 13) == "OdysseyChest_" and name:sub(1, 17) ~= "OdysseyChestPing_" then
                    local uuid = name:sub(14) -- strip "OdysseyChest_" prefix
                    if not openedChests[uuid] then
                        openedChests[uuid] = true
                        pcall(function() chestRemote:FireServer("OpenChest", uuid) end)
                        task.wait(0.08)
                    end
                end
            end
        end
    end

    -- Chest collection done; panel closes when server processes all chests
    local hud = realGui:FindFirstChild("AdventureHUD")
    if hud then
        local panel = hud:FindFirstChild("TreasurePanel")
        if panel then
            -- Fire close via remote if available
            local ev = getONet("TreasureEvent")
            if ev then pcall(function() ev:FireServer("Close") end) end
        end
    end
end

-- ── Unit Reward ───────────────────────────────────────────────────
-- Module name confirmed: BossRewardPickPanel
local function isUnitRewardOpen()
    local p = findAdventurePanel("BossRewardPickPanel")
           or findAdventurePanel("RunRewardsPanelRoot")
    return isPanelOpen(p)
end

local function skipUnitRewardPanel()
    refreshRemotes()
    local ev = getONet("UnitRewardEvent")
    if ev then pcall(function() ev:FireServer("Skip") end) end
end

-- ── requestNextRoom ───────────────────────────────────────────────
local function requestNextRoom()
    refreshRemotes()
    local mapEv = getONet("MapEvent")
    if mapEv then pcall(function() mapEv:FireServer("RequestSnapshot") end) end
    task.wait(0.2)
    local voteEv = getONet("VoteEvent")
    if not voteEv then return end
    for _, idx in ipairs({1, 2, 3, 4, 5}) do
        pcall(function() voteEv:FireServer("Vote", idx) end)
        task.wait(0.05)
    end
    local modEv = getONet("ModifierEvent")
    if modEv then pcall(function() modEv:FireServer("ClientReady") end) end
end

-- ── Odyssey automation: event-driven ────────────────────────────
-- All connections use WaitForChild so lobby injection works too.
do
    local currentOffer = nil  -- stored card offer data
    local openedChestIds = {}

    local function hookIgnore(folder)
        folder.ChildAdded:Connect(function(model)
            if not getAutoCollectChests() then return end
            local n = model.Name
            if n:sub(1,13) ~= "OdysseyChest_" then return end
            if n:sub(1,17) == "OdysseyChestPing_" then return end
            if openedChestIds[n] then return end
            openedChestIds[n] = true
            task.wait(0.1)
            local sm = Net:FindFirstChild("StageMechanics")
            local cr = sm and sm:FindFirstChild("OdysseyChest")
            if cr then pcall(function() cr:FireServer("OpenChest", n:sub(14)) end) end
        end)
    end
    local ignoreFolder = workspace:FindFirstChild("Ignore")
    if ignoreFolder then hookIgnore(ignoreFolder) end
    workspace.ChildAdded:Connect(function(c)
        if c.Name == "Ignore" then openedChestIds = {}; hookIgnore(c) end
    end)

    task.spawn(function()
        local ody = Net:WaitForChild("Odyssey", 120)
        if not ody then return end
        local adv = ody:WaitForChild("Adventure", 120)
        if not adv then return end

        -- Vote: fire requestNextRoom when vote starts, one retry after 2s
        local voteEvC = adv:WaitForChild("VoteEvent", 30)
        if voteEvC then
            local voteActive = false
            voteEvC.OnClientEvent:Connect(function(action)
                if action == "VoteStarted" then
                    voteActive = true
                    if not getAutoNextRoom() then return end
                    task.spawn(requestNextRoom)
                    task.delay(2, function()
                        if voteActive and getAutoNextRoom() then
                            task.spawn(requestNextRoom)
                        end
                    end)
                elseif action == "VoteEnded" or action == "VoteCancelled" then
                    voteActive = false
                end
            end)
        end

        -- Shop: fire Close(nil) once when server opens shop
        local shopEvC = adv:FindFirstChild("ShopEvent")
        if shopEvC then
            shopEvC.OnClientEvent:Connect(function(action)
                if action ~= "Open" then return end
                if not getAutoSkipShop() then return end
                task.defer(function()
                    pcall(function() shopEvC:FireServer("Close", nil) end)
                end)
            end)
        end

        -- Unit reward: fire Skip(nil) once when offer received
        local unitEvC = adv:FindFirstChild("UnitRewardEvent")
        if unitEvC then
            unitEvC.OnClientEvent:Connect(function(action)
                if action ~= "Offer" then return end
                if not getSkipUnitReward() then return end
                task.defer(function()
                    pcall(function() unitEvC:FireServer("Skip", nil) end)
                end)
            end)
        end

        -- Treasure: collect when floor begins
        local treasureEvC = adv:FindFirstChild("TreasureEvent")
        if treasureEvC then
            treasureEvC.OnClientEvent:Connect(function(action)
                if action ~= "Begin" then return end
                if not getAutoCollectChests() then return end
                task.spawn(function()
                    task.wait(0.3)
                    collectAndCloseTreasure()
                end)
            end)
        end

        -- Card pick: hookmetamethod + synchronous piggyback through old()
        -- Button1Down doesn't work on mobile. Instead: when Offer arrives,
        -- set pendingCardPick=true and fire MapEvent to trigger the hook.
        -- Inside the hook, we call old(cardEvC,"Pick",bestIdx) synchronously
        -- from within a legitimate FireServer context.
        local cardEvC = adv:FindFirstChild("CardPickEvent")
        if cardEvC and typeof(hookmetamethod) == "function" then
            local pendingPick  = false
            local pendingIdx   = 1

            cardEvC.OnClientEvent:Connect(function(action, data)
                if action == "Offer" then
                    currentOffer = data
                    if not (getAutoPick() or getAutoRagnawCards()) then return end
                    -- Calculate best card now so hook can use it immediately
                    local opts = type(data) == "table" and data.Options
                    local bestIdx, bestScore = 1, -1
                    if type(opts) == "table" then
                        for i, card in ipairs(opts) do
                            if type(card) == "table" then
                                local s = rarityScore(tostring(card.Rarity or ""):lower())
                                if s > bestScore then bestIdx=i; bestScore=s end
                            end
                        end
                    end
                    pendingIdx  = bestIdx
                    pendingPick = true
                    -- Trigger hook via a benign remote so piggyback fires ASAP
                    task.spawn(function()
                        task.wait(0.1)
                        local mapEv = adv:FindFirstChild("MapEvent")
                        if mapEv then
                            pcall(function() mapEv:FireServer("RequestSnapshot") end)
                        end
                    end)
                elseif action == "BasicCardGranted" or action == "CharacterCardGranted"
                    or action == "Skipped" then
                    currentOffer  = nil
                    pendingPick   = false
                end
            end)

            local old; old = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    -- Piggyback: inject card pick synchronously inside this hook frame
                    if pendingPick and self ~= cardEvC then
                        pendingPick = false
                        -- old() with cardEvC uses the current namecall method ("FireServer")
                        -- This is equivalent to cardEvC:FireServer("Pick", pendingIdx)
                        -- but goes through the original __namecall instead of our hook
                        pcall(old, cardEvC, "Pick", pendingIdx)
                    end
                    -- Redirect if player manually taps a card
                    if self == cardEvC then
                        local args = {...}
                        if args[1] == "Pick" and (getAutoPick() or getAutoRagnawCards())
                        and currentOffer then
                            local opts = type(currentOffer) == "table"
                                and currentOffer.Options
                            if type(opts) == "table" and #opts > 0 then
                                local bestIdx, bestScore = args[2] or 1, -1
                                for i, card in ipairs(opts) do
                                    if type(card) == "table" then
                                        local s = rarityScore(tostring(card.Rarity or ""):lower())
                                        if s > bestScore then bestIdx=i; bestScore=s end
                                    end
                                end
                                args[2] = bestIdx
                            end
                            return old(self, table.unpack(args))
                        end
                    end
                end
                return old(self, ...)
            end)
        end
    end)
end

end -- close Odyssey do block

-- ======================
-- SPRING LTM TAB
-- ======================
do
local springPage = tabPages["SpringLTM"]
local springSec = section(springPage, "Spring LTM", 1)

-- ── Confirm Placement ─────────────────────────────────────────────
-- UI path: PlayerGui.HUD.SpringEventHUD.WallPlacementHUD (watches whole panel)
-- Remote:  Networking.SpringEvent.ConfirmPlacement
local _, getConfirmPlacement = toggle(springSec, "Confirm Placement", 1, false, "spring.confirmplacement")
label(springSec, "Auto-confirms wall placement when the placement phase begins", 2)
do
    local confirmFired = false
    local wpHUD        = nil
    local wpConn       = nil

    local function getWallPlacementHUD()
        local hud  = realGui:FindFirstChild("HUD")
        local sHUD = hud  and hud:FindFirstChild("SpringEventHUD")
        return sHUD and sHUD:FindFirstChild("WallPlacementHUD")
    end

    local function fireConfirm()
        if confirmFired then return end
        confirmFired = true
        local ev = Net:FindFirstChild("SpringEvent")
        ev = ev and ev:FindFirstChild("ConfirmPlacement")
        if ev then pcall(function() ev:FireServer() end) end
    end

    local function hookWPHUD(panel)
        wpHUD = panel
        if wpConn then wpConn:Disconnect() end
        wpConn = panel:GetPropertyChangedSignal("Visible"):Connect(function()
            if panel.Visible and getConfirmPlacement() then
                fireConfirm()
            else
                confirmFired = false
            end
        end)
        -- Fire immediately if already visible when we connect
        if panel.Visible and getConfirmPlacement() then fireConfirm() end
    end

    -- Heartbeat: find WallPlacementHUD once, then rely on signal
    RunSvc.Heartbeat:Connect(function()
        if not getConfirmPlacement() then confirmFired = false; return end
        if not inGameMode()          then confirmFired = false; return end
        if wpHUD and wpHUD.Parent   then return end  -- already hooked
        local panel = getWallPlacementHUD()
        if panel then hookWPHUD(panel) end
    end)
end

-- ── Wave Purchase (Skip 5 at waves 5, 10, 15, 20) ────────────────
local _, getWavePurchase = toggle(springSec, "Wave Purchase (Skip 5)", 3, false, "spring.wavepurchase")
label(springSec, "Purchases Skip Waves x5 at waves 5 → 10 → 15 → 20", 4)
do
    local MILESTONES = {5, 10, 15, 20}
    local fired = {}
    RunSvc.Heartbeat:Connect(function()
        if not getWavePurchase() then fired = {}; return end
        if not inGameMode() then fired = {}; return end
        local cur = currentWave
        if cur == 0 then restartFired = false; return end  -- reset flag so it fires again after restart
        if cur < 5 then fired = {}; return end
        for _, w in ipairs(MILESTONES) do
            if cur >= w and not fired[w] then
                fired[w] = true
                local springEv = Net:FindFirstChild("SpringEvent")
                local ev = springEv and springEv:FindFirstChild("ShopEvent")
                if ev then pcall(function() ev:FireServer("Purchase", "SkipWaves5") end) end
            end
        end
    end)
end
end

-- ======================
-- MACRO TAB
-- ======================
do
local macroPage = tabPages["Macro"]
local Net        = RS:FindFirstChild("Networking")
local unitEv     = Net and Net:FindFirstChild("UnitEvent")
local abilityEv  = Net and Net:FindFirstChild("AbilityEvent")

-- Macro storage: saved to writefile so they persist between sessions
local MACRO_FILE = "OzWare_macros.json"
local macros = {}  -- { [name] = { events = [{t,remote,args}], duration } }

local function saveMacros()
    -- Serialize only primitive args (strings, numbers, bools, tables of those)
    local function serArgs(args)
        local out = {}
        for i, v in ipairs(args) do
            local t = typeof(v)
            if t == "string" or t == "number" or t == "boolean" then
                out[i] = {type=t, value=tostring(v)}
            elseif t == "table" then
                local tbl = {}
                for k, val in pairs(v) do
                    tbl[tostring(k)] = tostring(val)
                end
                out[i] = {type="table", value=tbl}
            end
        end
        return out
    end
    local data = {}
    for name, mac in pairs(macros) do
        local evts = {}
        for _, e in ipairs(mac.events) do
            table.insert(evts, {t=e.t, remote=e.remote, args=serArgs(e.args)})
        end
        data[name] = {events=evts, duration=mac.duration}
    end
    pcall(function()
        writefile(MACRO_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadMacros()
    pcall(function()
        if not isfile(MACRO_FILE) then return end
        local raw = readfile(MACRO_FILE)
        local data = HttpService:JSONDecode(raw)
        for name, mac in pairs(data) do
            macros[name] = mac
        end
    end)
end
loadMacros()

-- ── State ────────────────────────────────────────────────────────
local selectedMacro = nil
local recording     = false
local playing       = false
local recStart      = 0
local hookConn      = nil  -- active __namecall hook during recording

-- ── UI helpers ───────────────────────────────────────────────────
local headerSec  = section(macroPage, "Macros", 1)
local nameSec    = section(macroPage, "Macro Name", 2)
local listSec    = section(macroPage, "Saved Macros", 3)
local controlSec = section(macroPage, "Controls", 4)

-- Name input
local nameBox = input(nameSec, "Enter macro name...", 1)
local createBtn = btn(nameSec, "Create Macro", C.ACCENT, 2)

-- Selection label
local selLabel = Instance.new("TextLabel")
selLabel.Size = UDim2.new(1,0,0,22)
selLabel.BackgroundTransparency = 1
selLabel.Text = "Selected: none"
selLabel.TextColor3 = C.SUBTEXT
selLabel.TextSize = 12
selLabel.Font = FONT_SEMI
selLabel.TextXAlignment = Enum.TextXAlignment.Left
selLabel.LayoutOrder = 3
selLabel.Parent = nameSec

-- Macro list scroll
local listScroll = Instance.new("ScrollingFrame")
listScroll.Size = UDim2.new(1,0,0,160)
listScroll.BackgroundColor3 = C.BG
listScroll.BorderSizePixel = 0
listScroll.ScrollBarThickness = 4
listScroll.ScrollBarImageColor3 = C.ACCENT
listScroll.CanvasSize = UDim2.new(0,0,0,0)
listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
listScroll.LayoutOrder = 1
listScroll.Parent = listSec
corner(listScroll, 8)
listLayout(listScroll, nil, 4); padding(listScroll, nil, 6, 6, 6, 6)

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,0,0,22)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = C.SUBTEXT
statusLabel.TextSize = 12
statusLabel.Font = FONT_SEMI
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.LayoutOrder = 1
statusLabel.Parent = controlSec

-- Control buttons
local recBtn  = btn(controlSec, "Record",   Color3.fromRGB(220,80,80),   2)
local playBtn = btn(controlSec, "Play",     C.GREEN,                       3)
local stopBtn = btn(controlSec, "Stop",     Color3.fromRGB(120,120,140),  4)
local delBtn  = btn(controlSec, "Delete",   C.RED,                         5)

-- ── List rebuild ─────────────────────────────────────────────────
local function setStatus(txt, col)
    statusLabel.Text = txt
    statusLabel.TextColor3 = col or C.SUBTEXT
end

local function rebuildList()
    for _, c in ipairs(listScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local names = {}
    for k in pairs(macros) do table.insert(names, k) end
    table.sort(names)

    if #names == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1,0,0,28)
        empty.BackgroundTransparency = 1
        empty.Text = "No macros yet — create one above"
        empty.TextColor3 = C.SUBTEXT
        empty.TextSize = 12
        empty.Font = FONT_REG
        empty.LayoutOrder = 1
        empty.Parent = listScroll
        return
    end

    for i, name in ipairs(names) do
        local mac = macros[name]
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1,0,0,32)
        row.BackgroundColor3 = (selectedMacro == name) and C.ACCENT or Color3.fromRGB(35,35,38)
        row.AutoButtonColor = false
        row.Text = ""
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = listScroll
        corner(row, 5)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-60,1,0)
        lbl.Position = UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = ("%s  (%d events)"):format(name, #(mac.events or {}))
        lbl.TextColor3 = (selectedMacro == name) and Color3.fromRGB(20,24,40) or C.TEXT
        lbl.TextSize = 12
        lbl.Font = FONT_SEMI
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        row.MouseButton1Click:Connect(function()
            selectedMacro = (selectedMacro == name) and nil or name
            selLabel.Text = selectedMacro and ("Selected: "..selectedMacro) or "Selected: none"
            selLabel.TextColor3 = selectedMacro and C.ACCENT or C.SUBTEXT
            rebuildList()
        end)
    end
end
rebuildList()

-- ── Create macro ─────────────────────────────────────────────────
createBtn.MouseButton1Click:Connect(function()
    local name = nameBox.Text:match("^%s*(.-)%s*$")
    if not name or name == "" then
        return notify("Enter a macro name first", false)
    end
    if macros[name] then
        return notify("Macro '"..name.."' already exists", false)
    end
    macros[name] = {events={}, duration=0}
    selectedMacro = name
    selLabel.Text = "Selected: "..name
    selLabel.TextColor3 = C.ACCENT
    nameBox.Text = ""
    saveMacros()
    rebuildList()
    notify("Macro '"..name.."' created", true)
end)

-- ── Arg serializer for replay ─────────────────────────────────────
local function deserializeArgs(serialized)
    local args = {}
    for i, entry in ipairs(serialized) do
        if entry.type == "string" then
            args[i] = entry.value
        elseif entry.type == "number" then
            args[i] = tonumber(entry.value)
        elseif entry.type == "boolean" then
            args[i] = (entry.value == "true")
        elseif entry.type == "table" then
            local tbl = {}
            for k, v in pairs(entry.value) do
                local nk = tonumber(k) or k
                local nv = tonumber(v)
                tbl[nk] = nv ~= nil and nv or v
            end
            args[i] = tbl
        end
    end
    return args
end

-- ── Record ───────────────────────────────────────────────────────
recBtn.MouseButton1Click:Connect(function()
    if not selectedMacro then
        return notify("Select or create a macro first", false)
    end
    if playing then
        return notify("Stop playback first", false)
    end
    if not inGameMode() then
        return notify("Must be in a match to record", false)
    end
    if typeof(hookmetamethod) ~= "function" then
        return notify("Executor lacks hookmetamethod", false)
    end

    if recording then
        -- Stop recording
        recording = false
        local mac = macros[selectedMacro]
        if mac then
            mac.duration = os.clock() - recStart
        end
        -- Unhook by replacing with passthrough (can't unhook in most executors)
        -- The hook checks `recording` so it silently passes through when false
        recBtn.Text = "Record"
        recBtn.BackgroundColor3 = Color3.fromRGB(220,80,80)
        saveMacros()
        local evCount = mac and #mac.events or 0
        setStatus(("Recorded %d events"):format(evCount), C.GREEN)
        notify(("Saved %d events"):format(evCount), true)
        rebuildList()
        return
    end

    -- Start recording — clear existing events
    macros[selectedMacro].events = {}
    recStart = os.clock()
    recording = true
    recBtn.Text = "Stop Recording"
    recBtn.BackgroundColor3 = C.YELLOW
    setStatus("Recording...", C.YELLOW)
    notify("Recording: "..selectedMacro, true)

    -- Hook __namecall to capture UnitEvent and AbilityEvent
    -- Only captures "Render" (place) and "Activate" (ability) — skips UUID-based calls
    if typeof(hookmetamethod) == "function" then
        local watched = {}
        if unitEv    then watched[unitEv]    = "Unit"    end
        if abilityEv then watched[abilityEv] = "Ability" end

        local old; old = hookmetamethod(game, "__namecall", function(self, ...)
            local m = getnamecallmethod()
            if (m == "FireServer" or m == "InvokeServer") and watched[self] and recording then
                local args = {...}
                local action = typeof(args[1]) == "string" and args[1] or ""
                -- Only record placement and ability activations (not Upgrade/Sell/ChangePriority)
                if action == "Render" or action == "Activate" then
                    table.insert(macros[selectedMacro].events, {
                        t      = os.clock() - recStart,
                        remote = watched[self],
                        args   = args,
                    })
                end
            end
            return old(self, ...)
        end)
    end
end)

-- ── Play ─────────────────────────────────────────────────────────
playBtn.MouseButton1Click:Connect(function()
    if not selectedMacro then
        return notify("Select a macro first", false)
    end
    if recording then
        return notify("Stop recording first", false)
    end
    if playing then
        return notify("Already playing", false)
    end
    if not inGameMode() then
        return notify("Must be in a match to play", false)
    end

    local mac = macros[selectedMacro]
    if not mac or #mac.events == 0 then
        return notify("Macro is empty — record something first", false)
    end

    playing = true
    setStatus("Playing: "..selectedMacro, C.GREEN)
    notify("Playing: "..selectedMacro, true)

    task.spawn(function()
        local t0 = os.clock()
        local prevT = 0

        for _, evt in ipairs(mac.events) do
            if not playing then break end
            local delay = evt.t - prevT
            if delay > 0 then task.wait(delay) end
            if not playing then break end

            -- Re-resolve remotes at play time in case of rejoin
            local remote
            if evt.remote == "Unit" then
                remote = Net and Net:FindFirstChild("UnitEvent")
            elseif evt.remote == "Ability" then
                remote = Net and Net:FindFirstChild("AbilityEvent")
            end

            if remote then
                -- Deserialize args from saved format
                local args = deserializeArgs(evt.args)
                pcall(function() remote:FireServer(table.unpack(args)) end)
            end

            prevT = evt.t
        end

        playing = false
        setStatus("Playback complete", C.SUBTEXT)
        notify("Macro done: "..selectedMacro, true)
    end)
end)

-- ── Stop ─────────────────────────────────────────────────────────
stopBtn.MouseButton1Click:Connect(function()
    if recording then
        -- Simulate stop recording
        recording = false
        local mac = macros[selectedMacro]
        if mac then mac.duration = os.clock() - recStart end
        recBtn.Text = "Record"
        recBtn.BackgroundColor3 = Color3.fromRGB(220,80,80)
        saveMacros()
        rebuildList()
        setStatus("Recording stopped", C.SUBTEXT)
    end
    if playing then
        playing = false
        setStatus("Stopped", C.SUBTEXT)
        notify("Playback stopped", true)
    end
end)

-- ── Delete ───────────────────────────────────────────────────────
delBtn.MouseButton1Click:Connect(function()
    if not selectedMacro then
        return notify("Select a macro to delete", false)
    end
    local name = selectedMacro
    macros[name] = nil
    selectedMacro = nil
    selLabel.Text = "Selected: none"
    selLabel.TextColor3 = C.SUBTEXT
    saveMacros()
    rebuildList()
    setStatus("Deleted: "..name, C.SUBTEXT)
    notify("Deleted: "..name, true)
end)

end -- close Macro Tab do block

-- ======================
-- BOOT
-- ======================
switchTab("Lobby")
notify("OzWare V3 loaded", true)
task.defer(openWindow) -- show GUI on inject

-- ======================
-- FLOATING TOGGLE (bottom-left)  +  SUMMON UI SUPPRESSOR
-- ======================
do
-- ── Float button ───────────────────────────────────────────────────
local floatBtn = Instance.new("ImageButton")
floatBtn.Name="OzFloat"
floatBtn.Size=UDim2.new(0,52,0,52)
floatBtn.Position=UDim2.new(0,16,1,-68)
floatBtn.AnchorPoint=Vector2.new(0,0)
floatBtn.BackgroundColor3=Color3.fromRGB(0,0,0)
floatBtn.BackgroundTransparency=0
floatBtn.BorderSizePixel=0; floatBtn.AutoButtonColor=false
floatBtn.ZIndex=50; floatBtn.Image=""; floatBtn.Parent=gui
Instance.new("UICorner",floatBtn).CornerRadius=UDim.new(0,26)
floatBtn.ClipsDescendants=true
stroke(floatBtn,Color3.fromRGB(0,0,0),2)

-- Glow bloom
local fbGlow = Instance.new("ImageLabel",floatBtn)
fbGlow.Size=UDim2.new(0,80,0,80); fbGlow.AnchorPoint=Vector2.new(0.5,0.5)
fbGlow.Position=UDim2.new(0.5,0,0.5,0); fbGlow.BackgroundTransparency=1
fbGlow.Image="rbxassetid://5028857084"; fbGlow.ImageColor3=C.ACCENT2
fbGlow.ImageTransparency=0.55; fbGlow.ZIndex=49

-- Logo image on float button
local eyeLbl = Instance.new("ImageLabel",floatBtn)
eyeLbl.Size=UDim2.new(0,44,0,44)
eyeLbl.AnchorPoint=Vector2.new(0.5,0.5)
eyeLbl.Position=UDim2.new(0.5,0,0.5,0)
eyeLbl.BackgroundTransparency=1
eyeLbl.Image="rbxassetid://85161257906284"
eyeLbl.ScaleType=Enum.ScaleType.Fit; eyeLbl.ZIndex=51


-- Float button: drag vs tap
local dragging2  = false
local startPos2  = nil
local startInput2 = nil
local pressT     = nil

floatBtn.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging2   = true
        startPos2   = floatBtn.Position
        startInput2 = i.Position
        pressT      = tick()
    end
end)

floatBtn.InputEnded:Connect(function(i)
    if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end
    local moved = startInput2 and (Vector2.new(i.Position.X,i.Position.Y) - Vector2.new(startInput2.X,startInput2.Y)).Magnitude > 8
    dragging2 = false
    if not moved and pressT and (tick()-pressT) < 0.4 then
        if isOpen then closeWindow() else openWindow() end
    end
end)

UIS.InputChanged:Connect(function(i)
    if not dragging2 then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        if not startInput2 then return end
        local d = i.Position - startInput2
        floatBtn.Position = UDim2.new(
            startPos2.X.Scale, startPos2.X.Offset + d.X,
            startPos2.Y.Scale, startPos2.Y.Offset + d.Y
        )
    end
end)

end -- close Float button do block

end) -- close task.defer wrapper