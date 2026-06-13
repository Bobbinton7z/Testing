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
local realGui        = player:WaitForChild("PlayerGui")
local currentStageData = {}  -- populated by GameEvent data and ShowEndScreenEvent

-- Safe path traversal — accessible everywhere in the script
local function safePath(root, ...)
    local cur = root
    for _, key in ipairs({...}) do
        if not cur then return nil end
        cur = cur:FindFirstChild(key)
    end
    return cur
end

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
local LOGO_ASSET = "rbxassetid://112304523807314"
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
    local function setter(val)
        if enabled == val then return end
        enabled = val; setSavedToggle(saveKey, enabled); apply()
        for _, cb in ipairs(callbacks) do task.spawn(cb, enabled) end
    end
    row.MouseButton1Click:Connect(function()
        enabled=not enabled; setSavedToggle(saveKey,enabled); apply()
        for _,cb in ipairs(callbacks) do task.spawn(cb,enabled) end
    end)
    return row, function() return enabled end, function(cb)
        table.insert(callbacks,cb)
        if enabled then task.spawn(cb,true) end
    end, setter
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



-- ── End screen vote helper (shared by handler + live callbacks) ──────────────
local function _doEndScreenVote()
    if not _endScreenEvRef then return end
    task.wait(0.5)
    if getAutoNext and getAutoNext() then
        _endScreenEvRef:FireServer("Next")
        pcall(function()
            local es = realGui:FindFirstChild("EndScreen")
            local btn = es and safePath(es,"Holder","Buttons","Next","Button")
            if btn then btn.Activated:Fire() end
        end)
        _endScreenShowing = false
    elseif getAutoRetry and getAutoRetry() then
        _endScreenEvRef:FireServer("Retry")
        pcall(function()
            local es = realGui:FindFirstChild("EndScreen")
            local btn = es and safePath(es,"Holder","Buttons","Retry","Button")
            if btn then btn.Activated:Fire() end
        end)
        _endScreenShowing = false
    end
end

-- ── Auto Next / Auto Retry via ShowEndScreenEvent (event-driven) ─────────────
-- ShowEndScreenEvent fires with full match data the instant end screen appears
-- EndScreen is cloned fresh each time so polling FindFirstChild is unreliable
-- Buttons use Activated not MouseButton1Click (confirmed from decompile)
local _showEndEv = Net:FindFirstChild("EndScreen") and
                   Net.EndScreen:FindFirstChild("ShowEndScreenEvent")
if _showEndEv then
    _showEndEv.OnClientEvent:Connect(function(data)
        if type(data) == "table" then currentStageData = data end
        _endScreenEvRef = Net.EndScreen:FindFirstChild("VoteEvent")
        if not _endScreenEvRef then return end
        _endScreenShowing = true
        _doEndScreenVote()
    end)
end


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
    onAutoSkipStart(function(enabled)
        local ev = settingsEv or (Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent"))
        if ev then pcall(function() ev:FireServer("Toggle", "AutoSkipStart") end) end
    end)
    -- Server may reset AutoSkipStart to false — re-enable if our toggle is still on
    local incomingSkipStartEv = Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent")
    if incomingSkipStartEv then
        incomingSkipStartEv.OnClientEvent:Connect(function(action, data)
            if action ~= "Update" then return end
            if type(data) ~= "table" then return end
            if data[1] == "AutoSkipStart" and data[2] == false and getAutoSkipStart() then
                local ev = settingsEv or (Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent"))
                if ev then
                    task.wait(0.1)
                    pcall(function() ev:FireServer("Toggle", "AutoSkipStart") end)
                end
            end
        end)
    end
end
-- Auto Next
local _, getAutoNext, onAutoNext = toggle(gpList, "Auto Next", 2, false, "game.autonext")
onAutoNext(function(on)
    if on and _endScreenShowing then task.spawn(_doEndScreenVote) end
end)
-- Auto Retry
local _, getAutoRetry, onAutoRetry = toggle(gpList, "Auto Retry", 3, false, "game.autoretry")
onAutoRetry(function(on)
    if on and _endScreenShowing then task.spawn(_doEndScreenVote) end
end)
-- Auto Skip Wave
local _, getSkipWave, onSkipWave = toggle(gpList, "Auto Skip Wave", 4, false, "game.skipwave")
do
    local settingsEv = Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent")
    onSkipWave(function(on)
        local ev = settingsEv or (Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent"))
        if not ev then return end
        -- Sync toggle state with server immediately
        -- Read current server state first via a no-op, then set correct state
        if on then
            pcall(function() ev:FireServer("Toggle", "AutoSkipWaves") end)
        else
            pcall(function() ev:FireServer("Toggle", "AutoSkipWaves") end)
        end
    end)
    -- Server resets AutoSkipWaves=false after every wave skip
    -- Listen for that reset and re-enable if our toggle is still on
    local incomingSettingsEv = Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent")
    if incomingSettingsEv then
        incomingSettingsEv.OnClientEvent:Connect(function(action, data)
            if action ~= "Update" then return end
            if type(data) ~= "table" then return end
            local key   = data[1]
            local value = data[2]
            if key == "AutoSkipWaves" and value == false and getSkipWave() then
                -- Server reset it — re-enable immediately
                local ev = settingsEv or (Net:FindFirstChild("Settings") and Net.Settings:FindFirstChild("SettingsEvent"))
                if ev then
                    task.wait(0.1)
                    pcall(function() ev:FireServer("Toggle", "AutoSkipWaves") end)
                end
            end
        end)
    end
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
        if currentWave < newTarget then
            restartFired = false
        end
        targetWave           = newTarget
        waveBox.Text         = tostring(targetWave)
        settings.restartWave = targetWave
        saveSettings()
        -- If we're already at or past the target, fire restart immediately
        if getRestartOnWave() and currentWave >= newTarget and currentWave > 0 and not restartFired then
            restartFired = true
            local ev = Net:FindFirstChild("MatchRestartSettingEvent")
            if ev then pcall(function() ev:FireServer("Vote") end) end
        end
    end

    waveBox.FocusLost:Connect(function()
        local n = tonumber(waveBox.Text)
        if n then setWave(n) else waveBox.Text = tostring(targetWave) end
        task.defer(function() waveBox:ReleaseFocus() end)
    end)

    -- Read wave directly from label path every 0.25s
    -- (avoids stale currentWave when HUD connection dies on restart)
    -- WaveInfoEvent sequence (from decompiled handler):
    --   "Show" fires during intermission (pre-wave countdown) → track wave number
    --   "Hide" fires when enemies actually spawn (real wave start) → trigger here
    local pendingWave = 0
    local waveInfoEvRst = Net:FindFirstChild("WaveInfoEvent")
    if waveInfoEvRst then
        waveInfoEvRst.OnClientEvent:Connect(function(action, data)
            if action == "Show" then
                -- Store upcoming wave number — don't trigger yet (still countdown)
                pendingWave = (type(data) == "table" and data.Wave) or 0
            elseif action == "Hide" then
                -- Banner hides = enemies spawning = wave truly started
                local waveNum = pendingWave
                if waveNum > 0 then currentWave = waveNum end
                if not getRestartOnWave() then return end
                if waveNum >= targetWave and not restartFired then
                    restartFired = true
                    local ev = Net:FindFirstChild("MatchRestartSettingEvent")
                    if ev then pcall(function() ev:FireServer("Vote") end) end
                elseif waveNum > 0 and waveNum < targetWave then
                    restartFired = false
                end
            end
        end)
    end

    pcall(function()
        local gh = require(game.ReplicatedStorage.Modules.Gameplay.GameHandler)
        gh.MatchRestarted:Connect(function()
            restartFired = false
        end)
        gh.MatchStarted:Connect(function()
            restartFired = false
        end)
    end)
    -- Fallback: raw GameEvent if require fails in executor
    local gameEvRst = Net:FindFirstChild("GameEvent")
    if gameEvRst then
        gameEvRst.OnClientEvent:Connect(function(action)
            if action == "GameRestarted" or action == "MatchStarted" then
                restartFired = false
            end
        end)
    end
    -- InterfaceEvent("Restarted") — final safety net
    local interfaceEvRst = Net:FindFirstChild("InterfaceEvent")
    if interfaceEvRst then
        interfaceEvRst.OnClientEvent:Connect(function(action)
            if action == "Restarted" then restartFired = false end
        end)
    end


    -- PopupEvent fires ("BaseCancelFrame", message) the instant the popup appears
    local popupEv = Net:FindFirstChild("ClientListeners") and
                    Net.ClientListeners:FindFirstChild("PopupEvent")
    if popupEv then
        popupEv.OnClientEvent:Connect(function(frameName)
            if frameName ~= "BaseCancelFrame" then return end
            task.wait(0.3)  -- give UI time to fully render
            pcall(function()
                local ps = realGui:FindFirstChild("PopupScreen")
                if not ps then return end
                -- Recursive search for the Cancel Button — handles any nesting depth
                local cancelFrame = ps:FindFirstChild("BaseCancelFrame", true)
                if not cancelFrame then return end
                local btn = cancelFrame:FindFirstChild("Button", true)
                if not btn then return end
                -- Try all available firing methods
                pcall(function() btn.MouseButton1Click:Fire() end)
                pcall(function() btn.Activated:Fire() end)
                pcall(function() btn.MouseButton1Down:Fire() end)
                pcall(function() btn.MouseButton1Up:Fire() end)
                pcall(function()
                    if typeof(getconnections) == "function" then
                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                            pcall(c.Function)
                        end
                    end
                end)
                pcall(function()
                    if typeof(firesignal) == "function" then
                        firesignal(btn.MouseButton1Click)
                    end
                end)
            end)
        end)
    end
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
local function applyDeleteMap()
    if mapDeleted then return end
    mapDeleted = true
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local pY  = hrp and hrp.Position.Y or 0
    local count = 0
    local function isPlatform(p)
        return (p.Size.X > 50 or p.Size.Z > 50) and math.abs(p.Position.Y - pY) <= 8
    end
    local charSet = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then charSet[pl.Character] = true end
    end
    local SKIP = {Entities=true, Ignore=true, Camera=true}
    for _, child in ipairs(workspace:GetChildren()) do
        if not (SKIP[child.Name] or child.ClassName == "Terrain" or charSet[child]) then
        for _, p in ipairs(child:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    if not isPlatform(p) then
                        p.Transparency = 1; p.CanCollide = false; p.CastShadow = false
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
                    child.Transparency = 1; child.CanCollide = false
                end
            end)
        end
        end  -- if not SKIP
    end
    notify(("Map: hid %d parts"):format(count), true)
end
onDeleteMap(function(on)
    if not on then mapDeleted = false; return end
    if mapDeleted then return end
    local waited = 0
    while not inGameMode() and waited < 60 do task.wait(0.5); waited = waited + 0.5 end
    if not inGameMode() then notify("Must be in a match", false); return end
    applyDeleteMap()
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
        if getDeleteEnemies() and inGameMode() then
            local entities = workspace:FindFirstChild("Entities")
            if entities then
                for _, model in ipairs(entities:GetChildren()) do
                    if not destroyedEnemies[model] then
                        if model:IsA("Model") or model:IsA("BasePart") then
                            destroyedEnemies[model] = true
                            pcall(function() model:Destroy() end)
                        end
                    end
                end
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
local fpsApplied     = false
local greenUnitsConn = nil

-- Strips a single unit folder down to flat green geometry
local function applyGreenUnit(unitFolder)
    for _, inst in ipairs(unitFolder:GetDescendants()) do
        if inst:IsA("BasePart") then
            pcall(function()
                inst.BrickColor  = BrickColor.new("Bright green")
                inst.Material    = Enum.Material.SmoothPlastic
                inst.CastShadow  = false
                inst.Reflectance = 0
            end)
        end
        local cls = inst.ClassName
        if cls=="ParticleEmitter" or cls=="Trail"     or cls=="Beam"
        or cls=="Smoke"           or cls=="Fire"      or cls=="Sparkles"
        or cls=="SelectionBox"    or cls=="BillboardGui"
        or cls=="PointLight"      or cls=="SpotLight" or cls=="SurfaceLight" then
            pcall(function() inst:Destroy() end)
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            pcall(function() inst.Transparency=1 end)
        elseif inst:IsA("SpecialMesh") then
            pcall(function() inst.MeshType=Enum.MeshType.Block end)
        end
    end
end

-- Hooks workspace.Units so every placement auto-greens during the session
local function hookGreenUnits(unitsFolder)
    if greenUnitsConn then greenUnitsConn:Disconnect() end
    greenUnitsConn = unitsFolder.ChildAdded:Connect(function(child)
        if fpsApplied then
            task.wait(0.1) -- let model fully replicate before stripping
            pcall(function() applyGreenUnit(child) end)
        end
    end)
end

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
    -- Green units pass — recolors workspace.Units over the grey simplify pass
    local unitsFolder = workspace:FindFirstChild("Units")
    if unitsFolder then
        for _, child in ipairs(unitsFolder:GetChildren()) do
            pcall(function() applyGreenUnit(child) end)
        end
        hookGreenUnits(unitsFolder)
    else
        -- Units folder not present yet — wait for it (mid-lobby inject)
        task.spawn(function()
            local w = 0
            while not workspace:FindFirstChild("Units") and w < 120 do
                task.wait(1); w = w + 1
            end
            local uf = workspace:FindFirstChild("Units")
            if uf and fpsApplied then
                for _, child in ipairs(uf:GetChildren()) do
                    pcall(function() applyGreenUnit(child) end)
                end
                hookGreenUnits(uf)
            end
        end)
    end
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
        if greenUnitsConn then greenUnitsConn:Disconnect(); greenUnitsConn = nil end
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

-- ================================================================
-- ODYSSEY CARD DATA
-- ================================================================
local _UNIT_ORDER = {
    "Iscanur (Pride)","Song Jinwu and Igros","Rogita (Super 4)",
    "Shinobi God (Infinite Dreams)","Regnaw (Rage)","Divalo (Requiem)",
    "Yomomata (Captain)","Hellkiller (Slayer)","Manipulator (Spider)",
    "Elastic Captain (Cog 5th)"
}
local _UNIT_SHORT = {
    ["Iscanur (Pride)"]               = "Iscanur",
    ["Song Jinwu and Igros"]          = "Song Jinwu",
    ["Rogita (Super 4)"]              = "Rogita",
    ["Shinobi God (Infinite Dreams)"] = "Shinobi God",
    ["Regnaw (Rage)"]                 = "Regnaw",
    ["Divalo (Requiem)"]              = "Divalo",
    ["Yomomata (Captain)"]            = "Yomomata",
    ["Hellkiller (Slayer)"]           = "Hellkiller",
    ["Manipulator (Spider)"]          = "Manipulator",
    ["Elastic Captain (Cog 5th)"]     = "Elastic Cap.",
}
local _UNIT_CARD_DATA = {
    ["Iscanur (Pride)"] = {
        {id="RarePlaceUpgradeFour",           n="Instant Noon",           r="Rare"},
        {id="RareBurnApplyPassive",            n="Scorching Presence",     r="Rare"},
        {id="RareBurnBonusDamage",             n="Burning Pride",          r="Rare"},
        {id="EpicBurnBonusDouble",             n="Double Hour",            r="Epic"},
        {id="EpicUltimateNoSell",              n="Unyielding Ultimate",    r="Epic"},
        {id="EpicLionsSinCooldown",            n="Lion's Sin",             r="Epic"},
        {id="LegendaryMaxBurnPiercesShields",  n="Shield-Piercing Sun",    r="Legendary"},
        {id="LegendaryAlwaysMaxBurn",          n="Everlasting Noon",       r="Legendary"},
        {id="LegendaryPlaceMaxUpgrade",        n="Peak Arrival",           r="Legendary"},
        {id="MythicPlaceAutoUltimate",         n="Opening Ultimate",       r="Mythic"},
        {id="MythicMaxUpgradeExtraPlacement",  n="Solar Expansion",        r="Mythic"},
        {id="MythicBurnDeletesSlot",           n="Sunlit Sacrifice",       r="Mythic"},
    },
    ["Song Jinwu and Igros"] = {
        {id="RarePassiveManaPerSecond",        n="Shadow Meter",           r="Rare"},
        {id="RareEliteYenPerWave",             n="Elite Bounty",           r="Rare"},
        {id="RareNukeDamagePerUse",            n="Growing Nuke",           r="Rare"},
        {id="EpicFillSlotsWithIgros",          n="Elite Knight Ranks",     r="Epic"},
        {id="EpicMaxMeter500",                 n="Expanded Meter",         r="Epic"},
        {id="EpicEliteDamageAndSummons",       n="Elite Shadow Assault",   r="Epic"},
        {id="LegendaryPlacementMeter",         n="Summoner's Arrival",     r="Legendary"},
        {id="LegendaryManaRefund",             n="Mana Reclaim",           r="Legendary"},
        {id="LegendaryEliteCooldown",          n="Elite Momentum",         r="Legendary"},
        {id="MythicDuplicateElitePerAlly",     n="Duplicated Elite",       r="Mythic"},
        {id="MythicBossEliteCap",              n="Boss-Room Legion",        r="Mythic"},
        {id="MythicConsumeAllManaEliteHP",     n="Total Meter Offering",   r="Mythic"},
    },
    ["Rogita (Super 4)"] = {
        {id="RareTeleportYen",                 n="Teleport Payout",        r="Rare"},
        {id="RareWaveUpgrade",                 n="Wave Training",          r="Rare"},
        {id="RareActiveNoCooldown",            n="Limitless Active",       r="Rare"},
        {id="EpicTeleportDamageStack",         n="Teleport Power-Up",      r="Epic"},
        {id="EpicAttackTeleport",              n="Blink Strike",           r="Epic"},
        {id="EpicDuplicatePlacementDamage",    n="Mirrored Impact",        r="Epic"},
        {id="LegendaryUpgradeRefund",          n="Efficient Fusion",       r="Legendary"},
        {id="LegendaryMonkeyKingPlusTwoClones",n="Extra Clones",           r="Legendary"},
        {id="LegendaryCloneDamagePerClone",    n="Clone Momentum",         r="Legendary"},
        {id="MythicTeleportAfterimage",        n="Afterimage Warp",        r="Mythic"},
        {id="MythicUpgradePlacement",          n="Training Grounds",       r="Mythic"},
        {id="MythicUpgradeGeneratesClone",     n="Clone Evolution",        r="Mythic"},
    },
    ["Shinobi God (Infinite Dreams)"] = {
        {id="RareNinjutsuPlacementYen",              n="Ninjutsu Payout",       r="Rare"},
        {id="RareExtraPlacementRestrictionBypass",   n="Infinite Dream Slot",   r="Rare"},
        {id="RareNoNinjutsuTeam",                    n="Lone Shinobi",          r="Rare"},
        {id="EpicDamageDebuffsStack",                n="Stacked Afflictions",   r="Epic"},
        {id="EpicLimitless",                         n="Boundless Growth",      r="Epic"},
        {id="EpicElitePlacement",                    n="Elite Claim",           r="Epic"},
        {id="LegendarySlumberStacks",                n="Layered Slumber",       r="Legendary"},
        {id="LegendaryAllUnitsNinjutsu",             n="Shared Ninjutsu",       r="Legendary"},
        {id="LegendaryActiveStun",                   n="Infinite Dream Stun",   r="Legendary"},
        {id="MythicPlacementDamageDebuffs",          n="Afflicted Arrival",     r="Mythic"},
        {id="MythicNinjutsuNoCooldown",              n="Endless Ninjutsu",      r="Mythic"},
        {id="MythicFreeUpgrades",                    n="Free Ascension",        r="Mythic"},
    },
    ["Regnaw (Rage)"] = {
        {id="RareKillYen",                     n="Rage Bounty",            r="Rare"},
        {id="RareRemoveShields",               n="Shieldbreaker",          r="Rare"},
        {id="RareCritChance",                  n="Critical Rage",          r="Rare"},
        {id="EpicPermanentPlacements",         n="Monarch's Breakthrough", r="Epic"},
        {id="EpicNullifyOvershield",           n="Nullifying Strike",      r="Epic"},
        {id="EpicCritSplash",                  n="Critical Shockwave",     r="Epic"},
        {id="LegendaryPlacementDamage",        n="Rageful Arrival",        r="Legendary"},
        {id="LegendaryElitePlacement",         n="Elite Conquest",         r="Legendary"},
        {id="LegendaryPlacementHitDamage",     n="Placement Shockwave",    r="Legendary"},
        {id="MythicFullAOE",                   n="All-Range Rage",         r="Mythic"},
        {id="MythicKillTemporaryPlacement",    n="Rage Slots",             r="Mythic"},
        {id="MythicUpgradeScaling",            n="Escalating Fury",        r="Mythic"},
    },
    ["Divalo (Requiem)"] = {
        {id="RarePlaceMaxUpgrade",             n="Max Ascended",           r="Rare"},
        {id="RareKingsCourt",                  n="King's Court",           r="Rare"},
        {id="RareTimeSlowing",                 n="Time Slowing",           r="Rare"},
        {id="EpicFullErasure",                 n="Full Erasure",           r="Epic"},
        {id="EpicEchoedErasure",               n="Echoed Erasure",         r="Epic"},
        {id="EpicAfflictionBonus",             n="Affliction Bonus",       r="Epic"},
        {id="LegendaryErasureReduced",         n="Erasure Reduced",        r="Legendary"},
        {id="LegendaryRendingStrikes",         n="Rending Strikes",        r="Legendary"},
        {id="LegendaryCounterStorm",           n="Counter Storm",          r="Legendary"},
        {id="MythicEchoesOfErasure",           n="Echoes of Erasure",      r="Mythic"},
        {id="MythicRoyalCourt",                n="Royal Court",            r="Mythic"},
        {id="MythicInescapableStatus",         n="Inescapable Status",     r="Mythic"},
    },
    ["Yomomata (Captain)"] = {
        {id="RareEternalBankai",               n="Eternal Bankai",         r="Rare"},
        {id="RareSearingPierce",               n="Searing Pierce",         r="Rare"},
        {id="RareEndlessSouth",                n="Endless South",          r="Rare"},
        {id="EpicTakedownSpawn",               n="Takedown Spawn",         r="Epic"},
        {id="EpicBurningToBleed",              n="Burning to Bleed",       r="Epic"},
        {id="EpicSharedReaping",               n="Shared Reaping",         r="Epic"},
        {id="LegendaryAscendingCaptain",       n="Ascending Captain",      r="Legendary"},
        {id="LegendaryNorthsPyre",             n="North's Pyre",           r="Legendary"},
        {id="LegendaryLingeringBurn",          n="Lingering Burn",         r="Legendary"},
        {id="MythicIntenseBankai",             n="Intense Bankai",         r="Mythic"},
        {id="MythicTwinSpecters",              n="Twin Specters",          r="Mythic"},
        {id="MythicSoulContinuation",          n="Soul Continuation",      r="Mythic"},
    },
    ["Hellkiller (Slayer)"] = {
        {id="RareShotgunSpecialist",           n="Shotgun Specialist",     r="Rare"},
        {id="RarePurePower",                   n="Pure Power",             r="Rare"},
        {id="RareBossSlayer",                  n="Boss Slayer",            r="Rare"},
        {id="EpicAutoUpgrader",                n="Auto Upgrader",          r="Epic"},
        {id="EpicKillerMomentum",              n="Killer Momentum",        r="Epic"},
        {id="EpicCoopShooting",                n="Co-op Shooting",         r="Epic"},
        {id="LegendaryInfiniteHellwalker",     n="Infinite Hellwalker",    r="Legendary"},
        {id="LegendaryNoReload",               n="No Reload",              r="Legendary"},
        {id="LegendaryFixedSpeed",             n="Fixed Speed",            r="Legendary"},
        {id="MythicEchoingWounds",             n="Echoing Wounds",         r="Mythic"},
        {id="MythicEmptyMagazine",             n="Empty Magazine",         r="Mythic"},
        {id="MythicTearingStrike",             n="Tearing Strike",         r="Mythic"},
    },
    ["Manipulator (Spider)"] = {
        {id="RareHyperTempo",                  n="Hyper Tempo",            r="Rare"},
        {id="RareEndlessWeb",                  n="Endless Web",            r="Rare"},
        {id="RareAmplifiedAffliction",         n="Amplified Affliction",   r="Rare"},
        {id="EpicBleedOut",                    n="Bleed Out",              r="Epic"},
        {id="EpicPiercingToxins",              n="Piercing Toxins",        r="Epic"},
        {id="EpicMultipliedNegativity",        n="Multiplied Negativity",  r="Epic"},
        {id="LegendaryCompoundAffliction",     n="Compound Affliction",    r="Legendary"},
        {id="LegendaryCritFollowup",           n="Crit Followup",          r="Legendary"},
        {id="LegendaryEndlessGrowth",          n="Endless Growth",         r="Legendary"},
        {id="MythicBleedMultiplication",       n="Bleed Multiplication",   r="Mythic"},
        {id="MythicWebbedAffliction",          n="Webbed Affliction",      r="Mythic"},
        {id="MythicUniversalVanity",           n="Universal Vanity",       r="Mythic"},
    },
    ["Elastic Captain (Cog 5th)"] = {
        {id="RareBossPromotion",               n="Boss Promotion",         r="Rare"},
        {id="RareBaseBuild",                   n="Base Build",             r="Rare"},
        {id="RareMeterCompensation",           n="Meter Compensation",     r="Rare"},
        {id="EpicCogMultiplier",               n="Cog Multiplier",         r="Epic"},
        {id="EpicFloorPower",                  n="Floor Power",            r="Epic"},
        {id="EpicTripleStrike",                n="Triple Strike",          r="Epic"},
        {id="LegendaryMeterMastery",           n="Meter Mastery",          r="Legendary"},
        {id="LegendaryGlobalReach",            n="Global Reach",           r="Legendary"},
        {id="LegendarySunGodVitality",         n="Sun God Vitality",       r="Legendary"},
        {id="MythicOneTrueCaptain",            n="One True Captain",       r="Mythic"},
        {id="MythicReducedCooldowns",          n="Reduced Cooldowns",      r="Mythic"},
        {id="MythicFrenziedSunGod",            n="Frenzied Sun God",       r="Mythic"},
    },
}
-- Reverse lookup CardId → unit name
local _CARD_TO_UNIT = {}
for _u, _cards in pairs(_UNIT_CARD_DATA) do
    for _, _c in ipairs(_cards) do _CARD_TO_UNIT[_c.id] = _u end
end
-- Adventure uses Rare/Epic/Legendary/Mythic only (no Common/Uncommon/Super Rare)
local _BASIC_CARDS = {
    {n="Adrenaline Shot",       r="Rare"},      {n="Serrated Tips",         r="Rare"},
    {n="Precision Optics",      r="Rare"},      {n="Boxing Gloves",         r="Rare"},
    {n="Ambush",                r="Rare"},      {n="Concussive Blast",      r="Rare"},
    {n="Slayer Rounds",         r="Rare"},      {n="Military Training",     r="Rare"},
    {n="Infection",             r="Epic"},      {n="Base Shield",           r="Epic"},
    {n="Battle Frenzy",         r="Epic"},      {n="Extended Duration",     r="Epic"},
    {n="Treasure Map Fragment", r="Epic"},      {n="Quick Charge",          r="Epic"},
    {n="Potent Toxins",         r="Epic"},      {n="Volatile Demise",       r="Epic"},
    {n="Painful Gains",         r="Epic"},      {n="Numbing Agent",         r="Epic"},
    {n="The Best Defense\226\128\166", r="Legendary"},{n="Affinity",      r="Legendary"},
    {n="Resource Overflow",     r="Legendary"}, {n="Delicate Flower",       r="Legendary"},
    {n="Double Tap",            r="Legendary"}, {n="Essence Collector",     r="Legendary"},
    {n="Limit Break",           r="Mythic"},    {n="Golden Age",            r="Mythic"},
    {n="Crippling Field",       r="Mythic"},    {n="Luckcatcher",           r="Mythic"},
    {n="Unstoppable Force",     r="Mythic"},    {n="Spoils of War",         r="Mythic"},
    {n="True Strike",           r="Mythic"},    {n="Shop Cleaner",          r="Mythic"},
    {n="Cleansing Pool",        r="Mythic"},
}
-- Card selection state (persisted)
local _CARD_SAVE = "OzWare_odyssey_cards.json"
local _cardState = {selectedUnit=nil, unitPriority={}, basicPriority={}}
pcall(function()
    if isfile and isfile(_CARD_SAVE) then
        local t = game:GetService("HttpService"):JSONDecode(readfile(_CARD_SAVE))
        if type(t) == "table" then
            _cardState.selectedUnit  = t.selectedUnit
            _cardState.unitPriority  = type(t.unitPriority)  == "table" and t.unitPriority  or {}
            _cardState.basicPriority = type(t.basicPriority) == "table" and t.basicPriority or {}
        end
    end
end)
local function _saveCardState()
    pcall(function()
        writefile(_CARD_SAVE, game:GetService("HttpService"):JSONEncode(_cardState))
    end)
end
local _unitCardsPicked = 0  -- resets each adventure run
local _RARITY_COLOR = {
    Common       = Color3.fromRGB(160,160,160),
    Uncommon     = Color3.fromRGB(80,210,80),
    Rare         = Color3.fromRGB(90,140,255),
    ["Super Rare"] = Color3.fromRGB(200,80,255),
    Epic         = Color3.fromRGB(255,140,40),
    Legendary    = Color3.fromRGB(255,195,30),
    Mythic       = Color3.fromRGB(220,80,150),
}

-- Pre-compute unique 1-N default rankings for basic cards.
-- Lower rarity = lower rank, higher rarity = higher rank.
-- Within same rarity, cards keep their order from _BASIC_CARDS.
local _BASIC_CARD_DEFAULTS = {}
do
    local _rarityOrder = {Rare=1, Epic=2, Legendary=3, Mythic=4}
    local _sorted = {}
    for _, c in ipairs(_BASIC_CARDS) do table.insert(_sorted, c) end
    table.sort(_sorted, function(a, b)
        return (_rarityOrder[a.r] or 0) < (_rarityOrder[b.r] or 0)
    end)
    for rank, c in ipairs(_sorted) do
        _BASIC_CARD_DEFAULTS[c.n] = rank
    end
end

-- Returns numeric priority for a key; handles old boolean saves (true → 1)
local function getPriority(tbl, key)
    local v = tbl[key]
    if not v then return 0 end
    if v == true then return 1 end
    return tonumber(v) or 0
end

-- Refresher lookup tables so swap can update the other card's UI label instantly
local _basicCardRefreshers = {}
local _unitCardRefreshers  = {}

-- Sets key in tbl to newVal, swapping with any other entry that already holds newVal
local function _doPrioritySet(tbl, refreshers, key, newVal)
    newVal = math.max(1, math.floor(newVal))
    local oldP = getPriority(tbl, key)
    if newVal == oldP then return end
    for otherKey, _ in pairs(tbl) do
        if otherKey ~= key and getPriority(tbl, otherKey) == newVal then
            tbl[otherKey] = oldP
            if refreshers[otherKey] then refreshers[otherKey]() end
            break
        end
    end
    tbl[key] = newVal
end
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

local _, getAutoNextRoom, onAutoNextRoom = toggle(advListFrame, "Auto Next Room", 1, false, "odyssey.auto_next_room")
onAutoNextRoom(function(on)
    if not on then return end
    if _voteIsActive then
        task.spawn(requestNextRoom)
    else
        -- Missed VoteStarted event — check map panel directly
        local hud = getAdventureHUD()
        if hud then
            local mapRoot = hud:FindFirstChild("AdventureMapRoot")
            if mapRoot and mapRoot.Visible then
                _voteIsActive = true
                task.spawn(requestNextRoom)
            end
        end
        -- Also try via exposed remote
        if _voteEvC then task.spawn(requestNextRoom) end
    end
end)
label(advListFrame, "Continues to the next room automatically", 2)
local _, getAutoPick, onAutoPick, setAutoPick = toggle(advListFrame, "Auto Select Cards", 3, true, "odyssey.auto_select_cards")
onAutoPick(function(on)
    if on and getRandomPick and getRandomPick() then setRandomPick(false) end
    if not on then return end
    task.spawn(doPickFromPanel)
end)
label(advListFrame, "Picks by priority ranking when card screen appears", 4)
local _, getRandomPick, onRandomPick, setRandomPick = toggle(advListFrame, "Random Pick", 5, false, "odyssey.random_pick")
onRandomPick(function(on)
    if on and getAutoPick() then setAutoPick(false) end
    if not on then return end
    task.spawn(doPickFromPanel)
end)
label(advListFrame, "Picks a card randomly — mutually exclusive with Auto Select Cards", 6)
local _, getAutoSkipShop, onAutoSkipShop = toggle(advListFrame, "Auto Skip Shop", 9, false, "odyssey.auto_skip_shop.v3")
onAutoSkipShop(function(on)
    if on and _shopIsOpen and _shopEvRef then
        pcall(function() _shopEvRef:FireServer("Close", nil) end)
        _shopIsOpen = false
    end
end)
label(advListFrame, "Closes Stiches' Shop automatically", 10)
local _, getAutoCollectChests, onAutoCollectChests = toggle(advListFrame, "Auto Collect Chests", 11, false, "odyssey.auto_collect_chest.v3")
label(advListFrame, "Opens all chests in Treasure Room", 12)
onAutoCollectChests(function(on)
    if not on then return end
    local remote = _treasureEvC  -- StageMechanics.OdysseyChest
    if not remote then return end
    task.spawn(function()
        local ignore = workspace:FindFirstChild("Ignore")
        if not ignore then return end
        local opened = {}
        for _, model in ipairs(ignore:GetChildren()) do
            local n = model.Name
            if n:sub(1,13) == "OdysseyChest_" and n:sub(1,17) ~= "OdysseyChestPing_" then
                local id = model:GetAttribute("Id") or n:sub(14)
                if id and not opened[id] then
                    opened[id] = true
                    pcall(function() remote:FireServer("OpenChest", id) end)
                    task.wait(0.1)
                end
            end
        end
    end)
end)
local _, getSkipUnitReward, onSkipUnitReward = toggle(advListFrame, "Skip Unit Reward", 13, false, "odyssey.skip_unit_reward")
onSkipUnitReward(function(on)
    if on and _unitRewardShowing and _unitRewardEvRef then
        pcall(function() _unitRewardEvRef:FireServer("Skip", nil) end)
        _unitRewardShowing = false
    end
end)
label(advListFrame, "Skips unit reward panel after elite rooms", 14)

local ragnawPickedThisRun = {}
local ragnawPickCount     = 0

local _treasureEvC = nil  -- exposed for live toggle-on handler
local _voteEvC     = nil  -- exposed for live toggle-on handler
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
    -- Recursive search since panels are nested under MatchPanels.Panels etc.
    return hud:FindFirstChild(name, true)
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
    if not getAutoNextRoom() then return end  -- re-check after wait
    local voteEv = getONet("VoteEvent")
    if not voteEv then return end
    for _, idx in ipairs({1, 2, 3, 4, 5}) do
        pcall(function() voteEv:FireServer("Vote", idx) end)
        task.wait(0.05)
    end
    local modEv = getONet("ModifierEvent")
    if modEv then pcall(function() modEv:FireServer("ClientReady") end) end
end


-- ── Module-level state — declared here so _doPick and all callbacks share the same upvalues ──
local _currentOffer      = nil
local _voteIsActive      = false
local _advCardEvC        = nil
local _endScreenShowing  = false
local _endScreenEvRef    = nil
local _shopIsOpen        = false
local _shopEvRef         = nil
local _unitRewardShowing = false
local _unitRewardEvRef   = nil
local getAutoUnitCard    = nil  -- assigned inside Unit Card do block below

-- Normalizes card names for priority matching:
-- handles unicode ellipsis (…) vs ASCII (...) variants
local function _normName(s)
    if not s then return "" end
    s = s:gsub("\226\128\166", "...")  -- unicode ellipsis → ASCII dots
    s = s:gsub("%s+", " ")             -- collapse whitespace
    return s:lower():match("^%s*(.-)%s*$")  -- trim + lowercase
end

-- _doPick defined here so both the Unit Card do block and the event handlers share it
local function _doPick(offer)
    if not offer or not _advCardEvC then return end
    local opts = type(offer) == "table" and offer.Options or {}
    local kind = type(offer) == "table" and (offer.Kind or "") or ""
    local bestIdx = nil

    -- Random Pick and Auto Select Cards are mutually exclusive (enforced by UI)
    local useRandom = getRandomPick and getRandomPick()

    if kind == "Character" and getAutoUnitCard and getAutoUnitCard() then
        if _unitCardsPicked >= 4 then
            pcall(function() _advCardEvC:FireServer("Skip", 0) end)
            return
        end
        local sel = _cardState.selectedUnit
        local matched = {}
        for i, card in ipairs(opts) do
            if type(card) == "table" then
                local charName = card.CharacterName or ""
                if charName ~= "" and (not sel or charName == sel) then
                    table.insert(matched, {idx=i, id=card.CardId or ""})
                end
            end
        end
        if #matched == 0 then
            for i, card in ipairs(opts) do
                if type(card) == "table" then
                    table.insert(matched, {idx=i, id=card.CardId or ""})
                end
            end
        end
        if #matched > 0 then
            if useRandom then
                bestIdx = matched[math.random(#matched)].idx
            else
                local bestPrio = -1
                for _, m in ipairs(matched) do
                    local p = getPriority(_cardState.unitPriority, m.id)
                    if p > bestPrio then bestPrio = p; bestIdx = m.idx end
                end
                if bestPrio == 0 then bestIdx = matched[math.random(#matched)].idx end
            end
        end

    elseif kind ~= "Character" and ((getAutoPick and getAutoPick()) or useRandom) then
        if useRandom then
            if #opts > 0 then bestIdx = math.random(1, #opts) end
        else
            local bestPrio = 0
            for i, card in ipairs(opts) do
                if type(card) == "table" then
                    local name     = card.CardName or card.CardId or card.DisplayName or ""
                    local normCard = _normName(name)
                    local p = getPriority(_cardState.basicPriority, name)
                    if p == 0 then
                        for storedName, _ in pairs(_cardState.basicPriority) do
                            if _normName(storedName) == normCard then
                                p = getPriority(_cardState.basicPriority, storedName); break
                            end
                        end
                    end
                    if p > bestPrio then bestPrio = p; bestIdx = i end
                end
            end
            if not bestIdx and #opts > 0 then bestIdx = math.random(1, #opts) end
        end
    end

    if not bestIdx then return end
    local captured  = bestIdx
    local isUnitCard = kind == "Character"
    task.spawn(function()
        task.wait(0.2)
        -- Unit cards: first fire selects, second fire confirms (card 1 is pre-selected
        -- so firing twice is harmless for it; cards 2/3 require two fires to pick)
        pcall(function() _advCardEvC:FireServer("Pick", captured) end)
        if isUnitCard then
            task.wait(0.35)
            pcall(function() _advCardEvC:FireServer("Pick", captured) end)
        end
    end)
end

local _pickFired       = false  -- set when doPickFromPanel fires, cleared on grant/skip

-- GUI-based card pick fallback: used when _currentOffer is nil
-- Reads card buttons from the panel and matches against priority via text blob
local function doPickFromPanel()
    local useRandom = getRandomPick and getRandomPick()
    if not (getAutoPick() or (getAutoUnitCard and getAutoUnitCard()) or useRandom) then return end
    local ev = getONet("CardPickEvent")
    if not ev then return end

    if _currentOffer then
        _doPick(_currentOffer)
        return
    end

    local cards = getCardButtons()
    if not cards or #cards == 0 then return end

    local bestIdx = nil
    if useRandom or not getAutoPick() then
        bestIdx = math.random(1, #cards)
    else
        local bestPrio = 0
        for i, c in ipairs(cards) do
            local blob = c.text
            for storedName, _ in pairs(_cardState.basicPriority) do
                local p = getPriority(_cardState.basicPriority, storedName)
                if p > bestPrio and blob:find(_normName(storedName), 1, true) then
                    bestPrio = p; bestIdx = i
                end
            end
        end
        if not bestIdx then bestIdx = math.random(1, #cards) end
    end

    if not bestIdx then return end
    _pickFired = true
    local idx = bestIdx
    task.spawn(function()
        task.wait(0.2)
        pcall(function() ev:FireServer("Pick", idx) end)
    end)
end

-- Hook CardPickPanel visibility — fires only when panel appears.
-- Uses DescendantAdded because panel is created dynamically on each offer.
local _cardPanelHooked = false
local function hookCardPanel()
    local hud = getAdventureHUD()
    if not hud then return end

    local function shouldPick()
        return getAutoPick() or (getAutoUnitCard and getAutoUnitCard()) or (getRandomPick and getRandomPick())
    end

    local function connectPanel(panel)
        if _cardPanelHooked then return end
        _cardPanelHooked = true
        panel:GetPropertyChangedSignal("Visible"):Connect(function()
            if not panel.Visible then _pickFired = false; return end
            if not shouldPick() then return end
            if _currentOffer then return end
            if _pickFired then return end
            task.wait(0.2)
            task.spawn(doPickFromPanel)
        end)
        if panel.Visible and not _currentOffer and not _pickFired and shouldPick() then
            task.spawn(doPickFromPanel)
        end
    end

    -- Panel might already exist
    local panel = hud:FindFirstChild("CardPickPanel", true)
                or hud:FindFirstChild("ChooseCard", true)
    if panel then
        connectPanel(panel)
        return
    end

    -- Panel doesn't exist yet — watch for it to be added dynamically
    hud.DescendantAdded:Connect(function(d)
        if not _cardPanelHooked
        and (d.Name == "CardPickPanel" or d.Name == "ChooseCard") then
            connectPanel(d)
        end
    end)
end
do
local unitCardSec = section(odysseyPage, "Unit Card", 2)
local _, _gAutoUnitCard, onAutoUnitCard = toggle(unitCardSec, "Auto Unit Card", 1, false, "odyssey.autounitcard")
getAutoUnitCard = _gAutoUnitCard  -- assign to outer upvalue so _doPick can see it
onAutoUnitCard(function(on)
    if on then task.spawn(doPickFromPanel) end
end)
label(unitCardSec, "Picks cards for selected unit; skips after 4 per run", 2)

-- Helper: card selector row
local function makeCardRow(parent, cardId, cardName, rarity, order, priorityTbl)
    local row = Instance.new("Frame", parent)
    row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=Color3.fromRGB(30,30,30)
    row.BackgroundTransparency=0; row.BorderSizePixel=0; row.LayoutOrder=order; row.ZIndex=4
    if order > 1 then
        local s=Instance.new("Frame",row); s.Size=UDim2.new(1,-20,0,1); s.Position=UDim2.new(0,10,0,0)
        s.BackgroundColor3=Color3.fromRGB(40,40,45); s.BorderSizePixel=0; s.ZIndex=5
    end
    local dot=Instance.new("Frame",row); dot.Size=UDim2.new(0,6,0,6); dot.Position=UDim2.new(0,10,0.5,-3)
    dot.BackgroundColor3=_RARITY_COLOR[rarity] or C.SUBTEXT; dot.BorderSizePixel=0; dot.ZIndex=5; corner(dot,3)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-62,1,0); lbl.Position=UDim2.new(0,22,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=cardName; lbl.TextColor3=C.TEXT
    lbl.TextSize=12; lbl.Font=FONT_REG; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=5; lbl.TextTruncate=Enum.TextTruncate.AtEnd
    local txt=Instance.new("TextBox",row); txt.Size=UDim2.new(0,50,0,22)
    txt.Position=UDim2.new(1,-56,0.5,-11); txt.BackgroundColor3=Color3.fromRGB(40,40,45)
    txt.BorderSizePixel=0; txt.TextColor3=C.ACCENT; txt.TextSize=12; txt.Font=FONT_SEMI
    txt.ZIndex=6; txt.ClearTextOnFocus=false; txt.TextXAlignment=Enum.TextXAlignment.Center
    corner(txt,4)
    local function refreshUC()
        txt.Text=tostring(getPriority(priorityTbl,cardId))
    end
    refreshUC()
    _unitCardRefreshers[cardId]=refreshUC
    txt.FocusLost:Connect(function()
        local v=tonumber(txt.Text)
        if not v or v<1 then txt.Text=tostring(getPriority(priorityTbl,cardId)); return end
        _doPrioritySet(priorityTbl,_unitCardRefreshers,cardId,v)
        txt.Text=tostring(getPriority(priorityTbl,cardId))
        _saveCardState()
    end)
    row.MouseEnter:Connect(function() tween(row,{BackgroundColor3=Color3.fromRGB(38,38,38)},0.08) end)
    row.MouseLeave:Connect(function() tween(row,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end)
end

-- Chip row (horizontal scroll, single-select)
local chipOuter=Instance.new("Frame",unitCardSec); chipOuter.Size=UDim2.new(1,0,0,44)
chipOuter.BackgroundTransparency=1; chipOuter.BorderSizePixel=0; chipOuter.LayoutOrder=3; chipOuter.ClipsDescendants=true
local chipScroll=Instance.new("ScrollingFrame",chipOuter); chipScroll.Size=UDim2.new(1,0,1,0)
chipScroll.BackgroundTransparency=1; chipScroll.BorderSizePixel=0; chipScroll.ScrollBarThickness=0
chipScroll.ScrollingDirection=Enum.ScrollingDirection.X; chipScroll.AutomaticCanvasSize=Enum.AutomaticSize.X
chipScroll.CanvasSize=UDim2.new(0,0,0,0); chipScroll.ZIndex=4
local cLL=Instance.new("UIListLayout",chipScroll); cLL.FillDirection=Enum.FillDirection.Horizontal
cLL.Padding=UDim.new(0,5); cLL.SortOrder=Enum.SortOrder.LayoutOrder; cLL.VerticalAlignment=Enum.VerticalAlignment.Center
local cPad=Instance.new("UIPadding",chipScroll); cPad.PaddingLeft=UDim.new(0,8); cPad.PaddingRight=UDim.new(0,8)

-- Unit cards collapsible (dynamic content)
local ucColBtn=Instance.new("TextButton",unitCardSec)
ucColBtn.Size=UDim2.new(1,0,0,38); ucColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
ucColBtn.BackgroundTransparency=0; ucColBtn.BorderSizePixel=0; ucColBtn.LayoutOrder=4; ucColBtn.ZIndex=3
ucColBtn.Text="▶  Unit Card Priority"; ucColBtn.TextColor3=C.SUBTEXT; ucColBtn.TextSize=12; ucColBtn.Font=FONT_SEMI
ucColBtn.AutoButtonColor=false
do local d=Instance.new("Frame",ucColBtn); d.Size=UDim2.new(1,-20,0,1); d.Position=UDim2.new(0,10,0,0)
   d.BackgroundColor3=Color3.fromRGB(40,40,45); d.BorderSizePixel=0; d.ZIndex=4 end
ucColBtn.MouseEnter:Connect(function() tween(ucColBtn,{BackgroundColor3=Color3.fromRGB(40,40,40)},0.08) end)
ucColBtn.MouseLeave:Connect(function() tween(ucColBtn,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end)
local ucList=Instance.new("Frame",unitCardSec); ucList.Size=UDim2.new(1,0,0,0)
ucList.AutomaticSize=Enum.AutomaticSize.Y; ucList.BackgroundColor3=Color3.fromRGB(30,30,30)
ucList.BackgroundTransparency=0; ucList.BorderSizePixel=0; ucList.LayoutOrder=4; ucList.ZIndex=3
listLayout(ucList,nil,0)
local ucDoToggle, ucGetOpen = makeCollapsible(ucColBtn, ucList, "Unit Card Priority")

local function rebuildUnitCards()
    local selUnit = _cardState.selectedUnit
    ucColBtn.Text = (ucGetOpen() and "▼" or "▶") .. "  " ..
        (selUnit and (_UNIT_SHORT[selUnit] .. " Cards") or "Unit Card Priority")
    for _, c in ipairs(ucList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    if not selUnit then return end
    local cards = _UNIT_CARD_DATA[selUnit] or {}
    -- Compute unique 1-N defaults for this unit's cards (higher rarity = higher rank)
    local _rarityOrder = {Rare=1, Epic=2, Legendary=3, Mythic=4}
    local _sortedU = {}
    for _, c in ipairs(cards) do table.insert(_sortedU, c) end
    table.sort(_sortedU, function(a, b)
        return (_rarityOrder[a.r] or 0) < (_rarityOrder[b.r] or 0)
    end)
    for rank, c in ipairs(_sortedU) do
        if getPriority(_cardState.unitPriority, c.id) == 0 then
            _cardState.unitPriority[c.id] = rank
        end
    end
    _saveCardState()
    -- Build rows
    for i, card in ipairs(cards) do
        makeCardRow(ucList, card.id, card.n, card.r, i, _cardState.unitPriority)
    end
end

-- Build chips
local _chipBtns = {}
for i, unitFull in ipairs(_UNIT_ORDER) do
    local short = _UNIT_SHORT[unitFull]
    local chip=Instance.new("TextButton",chipScroll)
    chip.Size=UDim2.new(0,0,0,30); chip.AutomaticSize=Enum.AutomaticSize.X
    chip.BackgroundColor3=_cardState.selectedUnit==unitFull and C.ACCENT or Color3.fromRGB(38,38,42)
    chip.BackgroundTransparency=0; chip.BorderSizePixel=0; chip.LayoutOrder=i; chip.ZIndex=4
    chip.Text="  "..short.."  "; chip.TextSize=11; chip.Font=FONT_SEMI; chip.AutoButtonColor=false
    chip.TextColor3=_cardState.selectedUnit==unitFull and Color3.fromRGB(255,255,255) or C.SUBTEXT
    corner(chip,6)
    _chipBtns[unitFull]=chip
    chip.MouseButton1Click:Connect(function()
        for n,b in pairs(_chipBtns) do
            tween(b,{BackgroundColor3=Color3.fromRGB(38,38,42)},0.1); b.TextColor3=C.SUBTEXT
        end
        if _cardState.selectedUnit == unitFull then
            _cardState.selectedUnit = nil
        else
            _cardState.selectedUnit = unitFull
            tween(chip,{BackgroundColor3=C.ACCENT},0.1); chip.TextColor3=Color3.fromRGB(255,255,255)
        end
        _saveCardState()
        rebuildUnitCards()
        -- Re-fire pick if an offer is currently showing
        if _currentOffer and getAutoUnitCard and getAutoUnitCard() then
            _doPick(_currentOffer)
        end
    end)
end
rebuildUnitCards()
end -- Unit Card section

-- ── Basic Cards Section ────────────────────────────────────────────
do
local basicCardSec = section(odysseyPage, "Basic Cards", 3)

local bcColBtn=Instance.new("TextButton",basicCardSec)
bcColBtn.Size=UDim2.new(1,0,0,38); bcColBtn.BackgroundColor3=Color3.fromRGB(30,30,30)
bcColBtn.BackgroundTransparency=0; bcColBtn.BorderSizePixel=0; bcColBtn.LayoutOrder=1; bcColBtn.ZIndex=3
bcColBtn.Text="▶  Basic Card Priority"; bcColBtn.TextColor3=C.SUBTEXT; bcColBtn.TextSize=12; bcColBtn.Font=FONT_SEMI
bcColBtn.AutoButtonColor=false
bcColBtn.MouseEnter:Connect(function() tween(bcColBtn,{BackgroundColor3=Color3.fromRGB(40,40,40)},0.08) end)
bcColBtn.MouseLeave:Connect(function() tween(bcColBtn,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end)
local bcList=Instance.new("Frame",basicCardSec); bcList.Size=UDim2.new(1,0,0,0)
bcList.AutomaticSize=Enum.AutomaticSize.Y; bcList.BackgroundColor3=Color3.fromRGB(30,30,30)
bcList.BackgroundTransparency=0; bcList.BorderSizePixel=0; bcList.LayoutOrder=1; bcList.ZIndex=3
listLayout(bcList,nil,0)
makeCollapsible(bcColBtn, bcList, "Basic Card Priority")

local prevRarity = nil
for i, card in ipairs(_BASIC_CARDS) do
    -- Rarity separator header
    if card.r ~= prevRarity then
        prevRarity = card.r
        local rhdr=Instance.new("TextLabel",bcList)
        rhdr.Size=UDim2.new(1,0,0,20); rhdr.BackgroundColor3=Color3.fromRGB(25,25,28)
        rhdr.BackgroundTransparency=0; rhdr.BorderSizePixel=0; rhdr.LayoutOrder=i*2-1; rhdr.ZIndex=4
        rhdr.Text=card.r; rhdr.TextColor3=_RARITY_COLOR[card.r] or C.DIM
        rhdr.TextSize=10; rhdr.Font=FONT_BOLD; rhdr.TextXAlignment=Enum.TextXAlignment.Center
    end
    -- Card row
    local row=Instance.new("Frame",bcList); row.Size=UDim2.new(1,0,0,34)
    row.BackgroundColor3=Color3.fromRGB(30,30,30); row.BackgroundTransparency=0
    row.BorderSizePixel=0; row.LayoutOrder=i*2; row.ZIndex=4
    do local s=Instance.new("Frame",row); s.Size=UDim2.new(1,-20,0,1); s.Position=UDim2.new(0,10,0,0)
       s.BackgroundColor3=Color3.fromRGB(40,40,45); s.BorderSizePixel=0; s.ZIndex=5 end
    local dot=Instance.new("Frame",row); dot.Size=UDim2.new(0,6,0,6); dot.Position=UDim2.new(0,10,0.5,-3)
    dot.BackgroundColor3=_RARITY_COLOR[card.r] or C.SUBTEXT; dot.BorderSizePixel=0; dot.ZIndex=5; corner(dot,3)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-62,1,0); lbl.Position=UDim2.new(0,22,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=card.n; lbl.TextColor3=C.TEXT
    lbl.TextSize=12; lbl.Font=FONT_REG; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=5; lbl.TextTruncate=Enum.TextTruncate.AtEnd
    local cardName=card.n
    if getPriority(_cardState.basicPriority,cardName)==0 then
        _cardState.basicPriority[cardName]=_BASIC_CARD_DEFAULTS[cardName] or 1
    end
    local txt=Instance.new("TextBox",row); txt.Size=UDim2.new(0,50,0,22)
    txt.Position=UDim2.new(1,-56,0.5,-11); txt.BackgroundColor3=Color3.fromRGB(40,40,45)
    txt.BorderSizePixel=0; txt.TextColor3=C.ACCENT; txt.TextSize=12; txt.Font=FONT_SEMI
    txt.ZIndex=6; txt.ClearTextOnFocus=false; txt.TextXAlignment=Enum.TextXAlignment.Center
    corner(txt,4)
    local function refreshBC()
        txt.Text=tostring(getPriority(_cardState.basicPriority,cardName))
    end
    refreshBC()
    _basicCardRefreshers[cardName]=refreshBC
    txt.FocusLost:Connect(function()
        local v=tonumber(txt.Text)
        if not v or v<1 then txt.Text=tostring(getPriority(_cardState.basicPriority,cardName)); return end
        _doPrioritySet(_cardState.basicPriority,_basicCardRefreshers,cardName,v)
        txt.Text=tostring(getPriority(_cardState.basicPriority,cardName))
        _saveCardState()
    end)
    row.MouseEnter:Connect(function() tween(row,{BackgroundColor3=Color3.fromRGB(38,38,38)},0.08) end)
    row.MouseLeave:Connect(function() tween(row,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end)
end
_saveCardState()  -- persist first-run defaults immediately
end -- Basic Cards section

-- ── Odyssey automation: event-driven ────────────────────────────
-- All connections use WaitForChild so lobby injection works too.
do
    local openedChestIds = {}

    -- Chest opening now handled via TreasureEvent.OnClientEvent("Begin") below
    -- (removed old StageMechanics.OdysseyChest UUID approach — incorrect for Adventure)

    task.spawn(function()
        local ody = Net:WaitForChild("Odyssey", 120)
        if not ody then return end
        local adv = ody:WaitForChild("Adventure", 120)
        if not adv then return end

        -- Vote: fire requestNextRoom when vote starts, one retry after 2s
        local voteEvC = adv:WaitForChild("VoteEvent", 30)
        _voteEvC = voteEvC  -- expose for live toggle-on handler
        if voteEvC then
            voteEvC.OnClientEvent:Connect(function(action)
                if action == "VoteStarted" then
                    _voteIsActive = true
                    if not getAutoNextRoom() then return end
                    task.spawn(requestNextRoom)
                    task.delay(2, function()
                        if _voteIsActive and getAutoNextRoom() then
                            task.spawn(requestNextRoom)
                        end
                    end)
                elseif action == "VoteEnded" or action == "VoteCancelled" then
                    _voteIsActive = false
                end
            end)
        end

        -- Shop: fire Close(nil) once when server opens shop
        local shopEvC = adv:FindFirstChild("ShopEvent")
        if shopEvC then
            _shopEvRef = shopEvC
            shopEvC.OnClientEvent:Connect(function(action)
                if action == "Open" then
                    _shopIsOpen = true
                    if getAutoSkipShop() then
                        task.defer(function()
                            pcall(function() shopEvC:FireServer("Close", nil) end)
                            _shopIsOpen = false
                        end)
                    end
                elseif action == "Close" then
                    _shopIsOpen = false
                end
            end)
        end

        -- Unit reward: fire Skip(nil) once when offer received
        local unitEvC = adv:FindFirstChild("UnitRewardEvent")
        if unitEvC then
            _unitRewardEvRef = unitEvC
            unitEvC.OnClientEvent:Connect(function(action)
                if action == "Offer" then
                    _unitRewardShowing = true
                    if getSkipUnitReward() then
                        task.defer(function()
                            pcall(function() unitEvC:FireServer("Skip", nil) end)
                            _unitRewardShowing = false
                        end)
                    end
                else
                    _unitRewardShowing = false
                end
            end)
        end

        -- Treasure: TreasureEvent("Begin") is the trigger.
        -- CONFIRMED from OdysseyChestHandler decompile: chest opening uses
        -- StageMechanics.OdysseyChest:FireServer("OpenChest", id)
        -- Chest ID is read from model's "Id" attribute (preserves original type).
        local treasureEvC = adv:FindFirstChild("TreasureEvent")
        local stageMech   = Net:FindFirstChild("StageMechanics")
        local chestRemote = stageMech and stageMech:FindFirstChild("OdysseyChest")
        _treasureEvC = chestRemote  -- expose for live toggle-on handler

        local function openAllChests()
            if not chestRemote then return end
            local ignore = workspace:FindFirstChild("Ignore")
            if not ignore then return end
            local opened = {}
            for _, model in ipairs(ignore:GetChildren()) do
                local n = model.Name
                if n:sub(1,13) == "OdysseyChest_" and n:sub(1,17) ~= "OdysseyChestPing_" then
                    local id = model:GetAttribute("Id") or n:sub(14)
                    if id and not opened[id] then
                        opened[id] = true
                        pcall(function() chestRemote:FireServer("OpenChest", id) end)
                        task.wait(0.1)
                    end
                end
            end
        end

        if treasureEvC then
            treasureEvC.OnClientEvent:Connect(function(action)
                if action ~= "Begin" then return end
                if not getAutoCollectChests() then return end
                task.spawn(function()
                    task.wait(0.3)
                    openAllChests()
                end)
            end)
        end

        -- Card pick: direct fire approach
        -- data.Kind == "Character" = unit card offer (confirmed from Cobalt capture)
        -- card.CharacterName used for unit matching (direct field, no reverse lookup needed)
        local cardEvC = adv:FindFirstChild("CardPickEvent")
        if cardEvC then
            _advCardEvC = cardEvC  -- expose for live-update callbacks
            -- StateEvent: reset counters + re-apply FPS/map on new Adventure room
            local stateEvC = adv:FindFirstChild("StateEvent")
            if stateEvC then
                stateEvC.OnClientEvent:Connect(function(action)
                    if action == "InitializedInMatch" then
                        _unitCardsPicked = 0
                        task.spawn(function()
                            task.wait(1)
                            if getBoostFPS and getBoostFPS() then
                                fpsApplied = false; applyFPSBoost()
                            end
                            if getDeleteMap and getDeleteMap() then
                                mapDeleted = false; applyDeleteMap()
                            end
                        end)
                    elseif action == "Ended" then
                        _unitCardsPicked = 0
                    end
                end)
            end

            cardEvC.OnClientEvent:Connect(function(action, data)
                if action == "Offer" then
                    _currentOffer = data
                    _pickFired    = false
                    _doPick(data)
                elseif action == "CharacterCardGranted" then
                    _unitCardsPicked = _unitCardsPicked + 1
                    _currentOffer = nil
                    _pickFired    = false
                elseif action == "BasicCardGranted" or action == "Skipped" then
                    _currentOffer = nil
                    _pickFired    = false
                end
            end)
            -- Hook panel visibility now that remotes are ready
            task.spawn(hookCardPanel)
        end

        -- ── Startup state check ───────────────────────────────────────
        -- Handles the case where script is executed while already inside an adventure
        -- (events already fired before our listeners connected)
        task.wait(0.5)

        -- Treasure: if chests are already in workspace.Ignore, open them
        if getAutoCollectChests() and treasureEvC then
            task.spawn(function()
                local ignore = workspace:FindFirstChild("Ignore")
                if not ignore then return end
                local opened = {}
                for _, model in ipairs(ignore:GetChildren()) do
                    local n = model.Name
                    if n:sub(1,13) == "OdysseyChest_" and n:sub(1,17) ~= "OdysseyChestPing_" then
                        local uuid = n:sub(14)
                        if not opened[uuid] then
                            opened[uuid] = true
                            pcall(function() treasureEvC:FireServer("OpenChest", uuid) end)
                            task.wait(0.1)
                        end
                    end
                end
            end)
        end

        -- Vote: if map panel is already visible, fire next room
        if getAutoNextRoom() and voteEvC then
            local hud = getAdventureHUD()
            local mapRoot = hud and hud:FindFirstChild("AdventureMapRoot")
            if mapRoot and mapRoot.Visible then
                _voteIsActive = true
                task.spawn(requestNextRoom)
            end
        end

        -- Cards: hook panel visibility for missed-event recovery
        if getAutoPick() or (getAutoUnitCard and getAutoUnitCard()) then
            task.spawn(hookCardPanel)
        end

        -- Shop: if shop already open, close it
        if getAutoSkipShop() and _shopEvRef then
            local hud = getAdventureHUD()
            local shop = hud and hud:FindFirstChild("Stiches' Shop_Export")
            if shop and isPanelOpen(shop) then
                _shopIsOpen = true
                pcall(function() _shopEvRef:FireServer("Close", nil) end)
                _shopIsOpen = false
            end
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
        if cur == 0 then restartFired = false; waveAtTargetSince = 0; return end  -- reset flag so it fires again after restart
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
    -- Events store structured data directly — no raw Roblox types
    pcall(function()
        writefile(MACRO_FILE, HttpService:JSONEncode(macros))
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
local selectedMacro  = nil
local recording      = false
local playing        = false
local autoPlay       = false  -- stays on until manually disabled
local recStart       = 0

-- UUID ↔ identifier tracking
-- Recording: maps runtime UUIDs → identifier so Upgrade/Sell/etc can record by name
-- Playback:  maps identifier → list of live UUIDs so we can resolve back to UUID
local recUUIDs       = {}   -- { [uuid] = identifier }
local playUUIDs      = {}   -- { [identifier] = {uuid, uuid, ...} }
local unitWatcher    = nil  -- ChildAdded connection on workspace.Units
local lastNinjutsuT  = -999 -- mirrors game's 10s Ninjutsu cooldown

-- Ninjutsu remote
local mechFolder = Net:FindFirstChild("Mechanics")
local ninjutsuEv = mechFolder and mechFolder:FindFirstChild("Ninjutsu")

-- ── UI ──────────────────────────────────────────────────────────
local macroSec   = section(macroPage, "Macro", 1)
local createSec  = section(macroPage, "Create Macro", 2)
local controlSec = section(macroPage, "Controls", 3)

-- ── Collapsible: macro list ───────────────────────────────────────
local macroColBtn = Instance.new("TextButton", macroSec)
macroColBtn.Size = UDim2.new(1,0,0,38)
macroColBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
macroColBtn.BackgroundTransparency = 0
macroColBtn.BorderSizePixel = 0
macroColBtn.LayoutOrder = 1
macroColBtn.ZIndex = 3
macroColBtn.Text = "▶  No macro selected"
macroColBtn.TextColor3 = C.SUBTEXT
macroColBtn.TextSize = 12
macroColBtn.Font = FONT_SEMI
macroColBtn.AutoButtonColor = false
do local d=Instance.new("Frame",macroColBtn); d.Size=UDim2.new(1,-20,0,1)
   d.Position=UDim2.new(0,10,0,0); d.BackgroundColor3=Color3.fromRGB(40,40,45); d.BorderSizePixel=0; d.ZIndex=4 end
macroColBtn.MouseEnter:Connect(function() tween(macroColBtn,{BackgroundColor3=Color3.fromRGB(40,40,40)},0.08) end)
macroColBtn.MouseLeave:Connect(function() tween(macroColBtn,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.08) end)

local listFrame = Instance.new("Frame", macroSec)
listFrame.Size = UDim2.new(1,0,0,0)
listFrame.AutomaticSize = Enum.AutomaticSize.Y
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.LayoutOrder = 1

local listScroll = Instance.new("ScrollingFrame", listFrame)
listScroll.Size = UDim2.new(1,0,0,160)
listScroll.BackgroundColor3 = Color3.fromRGB(22,22,22)
listScroll.BorderSizePixel = 0
listScroll.ScrollBarThickness = 4
listScroll.ScrollBarImageColor3 = C.ACCENT
listScroll.CanvasSize = UDim2.new(0,0,0,0)
listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
listScroll.ZIndex = 3
corner(listScroll, 8)
listLayout(listScroll, nil, 4); padding(listScroll, nil, 6, 6, 6, 6)
makeCollapsible(macroColBtn, listFrame, "Macro")

-- ── Create row ───────────────────────────────────────────────────
local createRow = Instance.new("Frame", createSec)
createRow.Size = UDim2.new(1,0,0,36)
createRow.BackgroundTransparency = 1
createRow.BorderSizePixel = 0
createRow.LayoutOrder = 1
do local ll=Instance.new("UIListLayout",createRow)
   ll.FillDirection=Enum.FillDirection.Horizontal; ll.Padding=UDim.new(0,6)
   ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.VerticalAlignment=Enum.VerticalAlignment.Center end

local nameBox = Instance.new("TextBox", createRow)
nameBox.Size = UDim2.new(1,-86,1,0)
nameBox.BackgroundColor3 = Color3.fromRGB(30,30,30)
nameBox.BorderSizePixel = 0
nameBox.Text = ""
nameBox.PlaceholderText = "Macro name..."
nameBox.PlaceholderColor3 = C.DIM
nameBox.TextColor3 = C.TEXT
nameBox.TextSize = 12
nameBox.Font = FONT_REG
nameBox.ClearTextOnFocus = false
nameBox.LayoutOrder = 1
nameBox.ZIndex = 3
corner(nameBox, 6)
do local p=Instance.new("UIPadding",nameBox); p.PaddingLeft=UDim.new(0,8); p.PaddingRight=UDim.new(0,8) end
nameBox.FocusLost:Connect(function() task.defer(function() nameBox:ReleaseFocus() end) end)

local createBtn = Instance.new("TextButton", createRow)
createBtn.Size = UDim2.new(0,80,1,0)
createBtn.BackgroundColor3 = C.ACCENT
createBtn.BorderSizePixel = 0
createBtn.Text = "Create"
createBtn.TextColor3 = Color3.fromRGB(255,255,255)
createBtn.TextSize = 12
createBtn.Font = FONT_SEMI
createBtn.AutoButtonColor = false
createBtn.LayoutOrder = 2
createBtn.ZIndex = 3
corner(createBtn, 6)
createBtn.MouseEnter:Connect(function() tween(createBtn,{BackgroundColor3=Color3.fromRGB(200,60,130)},0.08) end)
createBtn.MouseLeave:Connect(function() tween(createBtn,{BackgroundColor3=C.ACCENT},0.08) end)

-- ── Status + control buttons ─────────────────────────────────────
local statusLabel = Instance.new("TextLabel", controlSec)
statusLabel.Size = UDim2.new(1,0,0,20)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = C.SUBTEXT
statusLabel.TextSize = 11
statusLabel.Font = FONT_SEMI
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.LayoutOrder = 1

local playBtn = btn(controlSec, "Play",   Color3.fromRGB(38,38,42), 2)
local recBtn  = btn(controlSec, "Record", Color3.fromRGB(38,38,42), 3)

-- ── Helpers ──────────────────────────────────────────────────────
local function setStatus(txt, col)
    statusLabel.Text = txt
    statusLabel.TextColor3 = col or C.SUBTEXT
end

local function setRecordToggle(active)
    if active then
        tween(recBtn, {BackgroundColor3=C.ACCENT}, 0.12)
        recBtn.Text = "Recording..."
    else
        tween(recBtn, {BackgroundColor3=Color3.fromRGB(38,38,42)}, 0.12)
        recBtn.Text = "Record"
    end
end

local function setPlayToggle(active)
    if active then
        tween(playBtn, {BackgroundColor3=C.GREEN}, 0.12)
        playBtn.Text = "Playing..."
    else
        tween(playBtn, {BackgroundColor3=Color3.fromRGB(38,38,42)}, 0.12)
        playBtn.Text = "Play"
    end
end

local function updateColHeader()
    local arrow = "▶"
    macroColBtn.Text = arrow .. "  " .. (selectedMacro or "No macro selected")
    macroColBtn.TextColor3 = selectedMacro and C.ACCENT or C.SUBTEXT
end

local function rebuildList()
    for _, c in ipairs(listScroll:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    local names = {}
    for k in pairs(macros) do table.insert(names, k) end
    table.sort(names)

    if #names == 0 then
        local empty = Instance.new("TextLabel", listScroll)
        empty.Size = UDim2.new(1,0,0,28)
        empty.BackgroundTransparency = 1
        empty.Text = "No macros yet"
        empty.TextColor3 = C.SUBTEXT
        empty.TextSize = 12
        empty.Font = FONT_REG
        empty.TextXAlignment = Enum.TextXAlignment.Center
        empty.LayoutOrder = 1
        updateColHeader()
        return
    end

    for i, name in ipairs(names) do
        local mac = macros[name]
        local row = Instance.new("Frame", listScroll)
        row.Size = UDim2.new(1,0,0,34)
        row.BackgroundColor3 = (selectedMacro == name) and C.ACCENT or Color3.fromRGB(35,35,38)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.ZIndex = 3
        corner(row, 5)

        -- Name + event count
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1,-40,1,0)
        lbl.Position = UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = ("%s  ·  %d events"):format(name, #(mac.events or {}))
        lbl.TextColor3 = (selectedMacro == name) and Color3.fromRGB(255,255,255) or C.TEXT
        lbl.TextSize = 12
        lbl.Font = FONT_SEMI
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 4

        -- Delete X button
        local delX = Instance.new("TextButton", row)
        delX.Size = UDim2.new(0,28,0,28)
        delX.Position = UDim2.new(1,-34,0.5,-14)
        delX.BackgroundColor3 = Color3.fromRGB(180,50,50)
        delX.BorderSizePixel = 0
        delX.Text = "✕"
        delX.TextColor3 = Color3.fromRGB(255,255,255)
        delX.TextSize = 11
        delX.Font = FONT_BOLD
        delX.AutoButtonColor = false
        delX.ZIndex = 5
        corner(delX, 5)

        -- Select row
        local selBtn = Instance.new("TextButton", row)
        selBtn.Size = UDim2.new(1,-40,1,0)
        selBtn.BackgroundTransparency = 1
        selBtn.Text = ""
        selBtn.ZIndex = 4
        selBtn.AutoButtonColor = false
        selBtn.MouseButton1Click:Connect(function()
            selectedMacro = (selectedMacro == name) and nil or name
            rebuildList()
            updateColHeader()
        end)
        selBtn.MouseEnter:Connect(function()
            if selectedMacro ~= name then tween(row,{BackgroundColor3=Color3.fromRGB(45,45,50)},0.08) end
        end)
        selBtn.MouseLeave:Connect(function()
            if selectedMacro ~= name then tween(row,{BackgroundColor3=Color3.fromRGB(35,35,38)},0.08) end
        end)

        -- Delete row
        delX.MouseButton1Click:Connect(function()
            if recording or playing then return notify("Stop first", false) end
            local n = name
            macros[n] = nil
            if selectedMacro == n then selectedMacro = nil end
            saveMacros()
            rebuildList()
            updateColHeader()
            notify("Deleted: "..n, true)
        end)
    end
    updateColHeader()
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
    nameBox.Text = ""
    saveMacros()
    rebuildList()
    updateColHeader()
    notify("Macro '"..name.."' created", true)
end)

-- ── UUID helpers ─────────────────────────────────────────────────
-- Arms a one-shot ChildAdded watcher so the next new unit in workspace.Units
-- gets its UUID mapped to the given identifier
local function armUUIDCapture(identifier, onCaptured)
    if unitWatcher then unitWatcher:Disconnect(); unitWatcher = nil end
    local uf = workspace:FindFirstChild("Units")
    if not uf then return end
    unitWatcher = uf.ChildAdded:Connect(function(child)
        if unitWatcher then unitWatcher:Disconnect(); unitWatcher = nil end
        if recording then
            recUUIDs[child.Name] = identifier
        elseif playing then
            playUUIDs[identifier] = playUUIDs[identifier] or {}
            table.insert(playUUIDs[identifier], child.Name)
        end
        if onCaptured then onCaptured(child.Name) end
    end)
end

-- Returns the first available live UUID for an identifier during playback
local function resolveUUID(identifier)
    local list = playUUIDs[identifier]
    if list and #list > 0 then return list[1] end
    return nil
end

local function removePlayUUID(uuid)
    local identifier = nil
    for id, list in pairs(playUUIDs) do
        for i, v in ipairs(list) do
            if v == uuid then
                table.remove(list, i)
                identifier = id
                break
            end
        end
        if identifier then break end
    end
end

-- ── __namecall hook (installed once, gated by recording flag) ────
-- Captures: Render, Upgrade, Sell, ChangePriority (UnitEvent) + Ninjutsu
if typeof(hookmetamethod) == "function" then
    local watched = {}
    if unitEv    then watched[unitEv]    = "Unit"     end
    if ninjutsuEv then watched[ninjutsuEv] = "Ninjutsu" end

    local old; old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if recording and watched[self] and (m == "FireServer" or m == "InvokeServer") then
            local args   = {...}
            local mac    = macros[selectedMacro]
            local evType = watched[self]

            if evType == "Unit" then
                local action = typeof(args[1]) == "string" and args[1] or ""

                if action == "Render" then
                    -- args: "Render", {name, identifier, Vector3, rot}, {SlotIndex=n}
                    local info = args[2]
                    local slot = args[3]
                    if type(info) == "table" and info[2] and info[3] then
                        local identifier = info[2]
                        local pos        = info[3]
                        table.insert(mac.events, {
                            t      = os.clock() - recStart,
                            action = "Render",
                            data   = {
                                name       = info[1] or "",
                                identifier = identifier,
                                x          = pos.X, y = pos.Y, z = pos.Z,
                                rot        = info[4] or 0,
                                slotIndex  = slot and slot.SlotIndex or 1,
                            }
                        })
                        armUUIDCapture(identifier)
                    end

                elseif action == "Upgrade" then
                    local uuid = args[2]
                    local id   = recUUIDs[uuid]
                    if id then
                        table.insert(mac.events, {
                            t = os.clock() - recStart, action = "Upgrade",
                            data = { identifier = id }
                        })
                    end

                elseif action == "Sell" then
                    local uuid = args[2]
                    local id   = recUUIDs[uuid]
                    if id then
                        table.insert(mac.events, {
                            t = os.clock() - recStart, action = "Sell",
                            data = { identifier = id }
                        })
                        recUUIDs[uuid] = nil  -- unit is gone
                    end

                elseif action == "ChangePriority" then
                    local uuid = args[2]
                    local mode = args[3]
                    local id   = recUUIDs[uuid]
                    if id then
                        table.insert(mac.events, {
                            t = os.clock() - recStart, action = "ChangePriority",
                            data = { identifier = id, mode = mode }
                        })
                    end
                end

            elseif evType == "Ninjutsu" then
                -- args: donorUUID
                local donorUUID = args[1]
                local donorId   = recUUIDs[donorUUID]
                if donorId then
                    table.insert(mac.events, {
                        t = os.clock() - recStart, action = "Ninjutsu",
                        data = { donorIdentifier = donorId }
                    })
                    recUUIDs[donorUUID] = nil  -- donor unit consumed
                end
            end
        end
        return old(self, ...)
    end)
end

-- ── Record button ─────────────────────────────────────────────────
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
        setRecordToggle(false)
        saveMacros()
        local evCount = mac and #mac.events or 0
        setStatus(("Recorded %d events"):format(evCount), C.GREEN)
        notify("Recorded Macro", true)
        rebuildList()
        return
    end

    -- Start recording — clear previous events and UUID map
    macros[selectedMacro].events = {}
    recUUIDs  = {}
    recStart  = os.clock()
    recording = true
    setRecordToggle(true)
    setStatus("Recording...", C.YELLOW)
    notify("Recording " .. selectedMacro, true)
end)

-- ── Playback core ────────────────────────────────────────────────
local function startMacroPlayback()
    if not autoPlay or not selectedMacro then return end
    if playing then return end
    local mac = macros[selectedMacro]
    if not mac or #mac.events == 0 then return end

    playing      = true
    playUUIDs    = {}
    lastNinjutsuT = -999
    setStatus("Playing: " .. selectedMacro, C.GREEN)
    notify("Playing " .. selectedMacro, true)

    task.spawn(function()
        local prevT = 0
        for _, evt in ipairs(mac.events) do
            if not playing or not autoPlay then break end
            local delay = evt.t - prevT
            if delay > 0 then task.wait(delay) end
            if not playing or not autoPlay then break end

            local action = evt.action
            local data   = evt.data or {}

            if action == "Render" then
                armUUIDCapture(data.identifier)
                pcall(function()
                    unitEv:FireServer("Render",
                        {data.name, data.identifier,
                         Vector3.new(data.x, data.y, data.z), data.rot or 0},
                        {SlotIndex = data.slotIndex or 1}
                    )
                end)

            elseif action == "Ninjutsu" then
                -- Respect the game's 10-second cooldown
                local elapsed = os.clock() - lastNinjutsuT
                if elapsed < 10 then task.wait(10 - elapsed + 0.1) end
                if not playing or not autoPlay then break end
                local donorUUID = resolveUUID(data.donorIdentifier)
                if donorUUID and ninjutsuEv then
                    pcall(function() ninjutsuEv:FireServer(donorUUID) end)
                    lastNinjutsuT = os.clock()
                    removePlayUUID(donorUUID)
                end

            elseif action == "Upgrade" then
                local uuid = resolveUUID(data.identifier)
                if uuid then
                    pcall(function() unitEv:FireServer("Upgrade", uuid) end)
                end

            elseif action == "Sell" then
                local uuid = resolveUUID(data.identifier)
                if uuid then
                    pcall(function() unitEv:FireServer("Sell", uuid) end)
                    removePlayUUID(uuid)
                end

            elseif action == "ChangePriority" then
                local uuid = resolveUUID(data.identifier)
                if uuid then
                    pcall(function()
                        unitEv:FireServer("ChangePriority", uuid, data.mode)
                    end)
                end
            end

            prevT = evt.t
        end

        playing = false
        if unitWatcher then unitWatcher:Disconnect(); unitWatcher = nil end
        if autoPlay then
            setStatus("Waiting for next match...", C.SUBTEXT)
        else
            setPlayToggle(false)
            setStatus("Playback complete", C.SUBTEXT)
        end
    end)
end

-- ── Play toggle button ────────────────────────────────────────────
playBtn.MouseButton1Click:Connect(function()
    if autoPlay then
        -- Turn off — stop any active playback
        autoPlay = false
        playing  = false
        setPlayToggle(false)
        setStatus("Auto-play off", C.SUBTEXT)
        return
    end
    if not selectedMacro then
        return notify("Select a macro first", false)
    end
    if recording then
        return notify("Stop recording first", false)
    end
    if not inGameMode() then
        notify("Must be in a match to play", false)
    end
    local mac = macros[selectedMacro]
    if not mac or #mac.events == 0 then
        return notify("Macro is empty — record something first", false)
    end

    autoPlay = true
    setPlayToggle(true)
    setStatus("Auto-play on — waiting for match", C.GREEN)

    -- If already in a match start immediately, otherwise wait for MatchStarted
    if inGameMode() then
        startMacroPlayback()
    end
end)

-- ── Auto-play on MatchStarted ─────────────────────────────────────
pcall(function()
    local gh = require(game.ReplicatedStorage.Modules.Gameplay.GameHandler)
    gh.MatchStarted:Connect(function()
        if autoPlay then
            task.wait(0.5)
            startMacroPlayback()
        end
    end)
end)
local _playMatchEv = Net:FindFirstChild("GameEvent")
if _playMatchEv then
    _playMatchEv.OnClientEvent:Connect(function(action)
        if action == "MatchStarted" and autoPlay then
            task.wait(0.5)
            startMacroPlayback()
        end
    end)
end

-- ── Auto-stop recording on match end or restart ─────────────────
local function autoStopRecording(reason)
    if recording then
        recording = false
        if unitWatcher then unitWatcher:Disconnect(); unitWatcher = nil end
        recUUIDs = {}
        local mac = macros[selectedMacro]
        if mac then mac.duration = os.clock() - recStart end
        setRecordToggle(false)
        saveMacros()
        local evCount = mac and #mac.events or 0
        setStatus(("Stopped (%s) — %d events"):format(reason, evCount), C.SUBTEXT)
        notify("Recorded Macro", true)
        rebuildList()
    end
    if playing then
        playing = false
        if unitWatcher then unitWatcher:Disconnect(); unitWatcher = nil end
        playUUIDs = {}
        if not autoPlay then
            setPlayToggle(false)
        else
            setStatus("Waiting for next match...", C.SUBTEXT)
        end
    end
end

-- GameHandler module signals (most reliable)
pcall(function()
    local gh = require(game.ReplicatedStorage.Modules.Gameplay.GameHandler)
    gh.MatchEnded:Connect(function()
        autoStopRecording("match ended")
    end)
    gh.MatchRestarted:Connect(function()
        autoStopRecording("match restarted")
    end)
end)

-- Fallback: raw GameEvent
local _macroGameEv = Net:FindFirstChild("GameEvent")
if _macroGameEv then
    _macroGameEv.OnClientEvent:Connect(function(action)
        if action == "MatchEnded" then
            autoStopRecording("match ended")
        elseif action == "GameRestarted" then
            autoStopRecording("match restarted")
        end
    end)
end

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
eyeLbl.Image="rbxassetid://71180844435778"
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