-- ======================
-- |        OzWare       |
-- |    V3 Dashboard     |
-- ======================

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenSvc     = game:GetService("TweenService")
local RunSvc       = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")

local player    = Players.LocalPlayer
local ok, _gui  = pcall(function() return gethui() end)
local playerGui = ok and _gui or player:WaitForChild("PlayerGui")

local Net       = RS:WaitForChild("Networking")

-- ======================
-- THEME (dark purple / grunge)
-- ======================
local C = {
    BG       = Color3.fromRGB(12, 10, 18),         -- near-black purple background
    PANEL    = Color3.fromRGB(20, 16, 30),         -- sidebar / titlebar
    CARD     = Color3.fromRGB(24, 20, 38),         -- section cards
    BORDER   = Color3.fromRGB(90, 40, 120),        -- purple border
    ACCENT   = Color3.fromRGB(180, 60, 255),       -- vivid purple
    ACCENT2  = Color3.fromRGB(255, 40, 200),       -- hot pink/magenta
    GREEN    = Color3.fromRGB(80, 220, 170),
    RED      = Color3.fromRGB(255, 80, 120),
    YELLOW   = Color3.fromRGB(245, 200, 90),
    TEXT     = Color3.fromRGB(255, 255, 255),
    SUBTEXT  = Color3.fromRGB(180, 160, 210),
    DIM      = Color3.fromRGB(140, 120, 175),
    DISABLED = Color3.fromRGB(45, 38, 65),
    ACTIVE   = Color3.fromRGB(180, 60, 255),       -- active tab = purple pill
}
local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.GothamSemibold
local FONT_REG  = Enum.Font.Gotham


local function inGameMode()
    -- Regular match: map folder exists in workspace
    if getMapRoot() then return true end
    -- Odyssey run: Adventure subfolder with VoteEvent exists under Networking
    -- This is the most reliable signal — VoteEvent only exists during an active run
    local net = RS:FindFirstChild("Networking")
    local ody = net and net:FindFirstChild("Odyssey")
    local adv = ody and ody:FindFirstChild("Adventure")
    if adv and adv:FindFirstChild("VoteEvent") then return true end
    -- Fallback: any of these workspace folders indicate an active match
    for _, name in ipairs({
        "OdysseyRoom","AdventureRoom","Adventure","OdysseyMap","AdventureMap",
        "Odyssey","OdysseyStage","AdventureStage","OdysseyHolder","AdventureHolder",
        "GameMap","GameFolder","BattleMap","Match","MatchFolder",
    }) do
        if workspace:FindFirstChild(name) then return true end
    end
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
local LOGO_ASSET = "rbxassetid://YOUR_LOGO_ID"  -- replace with your uploaded asset ID
local WIN_W, WIN_H = 740, 475
local SIDEBAR_W    = 144

-- ── Window frame ─────────────────────────────────────────────────
local win = Instance.new("Frame")
win.Name             = "Window"
win.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
win.AnchorPoint      = Vector2.new(0.5, 0.5)
win.Position         = UDim2.new(0.5, 0, 0.5, 0)
win.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
win.BorderSizePixel  = 0
win.ClipsDescendants = true
win.Active           = true
win.Visible          = false   -- starts hidden; float button reveals it

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

win.ZIndex           = 10
win.Parent           = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)
local winStroke = Instance.new("UIStroke", win)
winStroke.Color = Color3.fromRGB(60, 30, 90)
winStroke.Thickness = 1

-- Subtle inner gradient on window background
do
    local bg = Instance.new("Frame", win)
    bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(20,10,35)
    bg.BorderSizePixel = 0; bg.ZIndex = 0
    local g = Instance.new("UIGradient", bg)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(22,10,38)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(10,10,18)),
    })
    g.Rotation = 135
end

-- ── Header (logo banner) ─────────────────────────────────────────
local header = Instance.new("Frame", win)
header.Size             = UDim2.new(1, 0, 0, 78)
header.BackgroundColor3 = Color3.fromRGB(16, 10, 28)
header.BorderSizePixel  = 0
header.ZIndex           = 12
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)
-- Cover bottom-round on header
local headerCover = Instance.new("Frame", header)
headerCover.Size             = UDim2.new(1,0,0,14)
headerCover.Position         = UDim2.new(0,0,1,-14)
headerCover.BackgroundColor3 = Color3.fromRGB(16,10,28)
headerCover.BorderSizePixel  = 0; headerCover.ZIndex = 13
-- Subtle gradient on header
local hgrad = Instance.new("UIGradient", header)
hgrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30,12,50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(13,10,22)),
})
hgrad.Rotation = 90
-- Bottom separator line
local sep = Instance.new("Frame", win)
sep.Size             = UDim2.new(1,0,0,1)
sep.Position         = UDim2.new(0,0,0,78)
sep.BackgroundColor3 = Color3.fromRGB(60,30,90)
sep.BorderSizePixel  = 0; sep.ZIndex = 14

-- Logo image centered in header
local logoImg = Instance.new("ImageLabel", header)
logoImg.Size             = UDim2.new(0, 160, 0, 56)
logoImg.AnchorPoint      = Vector2.new(0.5, 0.5)
logoImg.Position         = UDim2.new(0.5, 0, 0.5, 0)
logoImg.BackgroundTransparency = 1
logoImg.Image            = LOGO_ASSET
logoImg.ScaleType        = Enum.ScaleType.Fit
logoImg.ZIndex           = 14
-- Fallback text if no asset ID yet
local logoFallback = Instance.new("TextLabel", header)
logoFallback.Size             = UDim2.new(0, 200, 1, 0)
logoFallback.AnchorPoint      = Vector2.new(0.5, 0.5)
logoFallback.Position         = UDim2.new(0.5, 0, 0.5, 0)
logoFallback.BackgroundTransparency = 1
logoFallback.Text             = "OzWare"
logoFallback.TextColor3       = Color3.fromRGB(255,255,255)
logoFallback.TextSize         = 28
logoFallback.Font             = FONT_BOLD
logoFallback.ZIndex           = 15
logoFallback.Visible          = (LOGO_ASSET == "rbxassetid://YOUR_LOGO_ID")
do
    local g2 = Instance.new("UIGradient", logoFallback)
    g2.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200,80,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,60,200)),
    })
    g2.Rotation = 0
end
-- Version badge
local verBadge = Instance.new("TextLabel", header)
verBadge.Size             = UDim2.new(0,28,0,16)
verBadge.AnchorPoint      = Vector2.new(1,0)
verBadge.Position         = UDim2.new(1,-10,0,8)
verBadge.BackgroundColor3 = Color3.fromRGB(140,40,200)
verBadge.BorderSizePixel  = 0
verBadge.Text             = "V3"
verBadge.TextColor3       = Color3.fromRGB(255,255,255)
verBadge.TextSize         = 10; verBadge.Font = FONT_BOLD
verBadge.ZIndex           = 15
Instance.new("UICorner",verBadge).CornerRadius = UDim.new(0,4)

-- Drag via header
local dragging, dragStart, winStart = false, nil, nil
header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; winStart=win.Position
    end
end)
header.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=false
    end
end)
UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        win.Position=UDim2.new(winStart.X.Scale,winStart.X.Offset+d.X,winStart.Y.Scale,winStart.Y.Offset+d.Y)
    end
end)

-- ── Sidebar ───────────────────────────────────────────────────────
local sidebar = Instance.new("Frame", win)
sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, -96)
sidebar.Position         = UDim2.new(0, 0, 0, 86)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
sidebar.BorderSizePixel  = 0; sidebar.ZIndex = 11
-- Right border only
local sideStroke = Instance.new("Frame", sidebar)
sideStroke.Size             = UDim2.new(0,1,1,0)
sideStroke.Position         = UDim2.new(1,-1,0,0)
sideStroke.BackgroundColor3 = Color3.fromRGB(50,25,75)
sideStroke.BorderSizePixel  = 0; sideStroke.ZIndex = 12

local tabList = Instance.new("Frame", sidebar)
tabList.Size                = UDim2.new(1,0,1,-60)
tabList.Position            = UDim2.new(0,0,0,8)
tabList.BackgroundTransparency = 1; tabList.ZIndex = 12
listLayout(tabList, nil, 2, Enum.HorizontalAlignment.Center)

-- Avatar footer
local footer = Instance.new("Frame", sidebar)
footer.Size             = UDim2.new(1,-12,0,50)
footer.Position         = UDim2.new(0,6,1,-56)
footer.BackgroundColor3 = Color3.fromRGB(25,15,40)
footer.BorderSizePixel  = 0; footer.ZIndex = 12
Instance.new("UICorner",footer).CornerRadius=UDim.new(0,8)
local avImg = Instance.new("ImageLabel", footer)
avImg.Size=UDim2.new(0,32,0,32); avImg.Position=UDim2.new(0,8,0.5,-16)
avImg.BackgroundColor3=C.CARD; avImg.BorderSizePixel=0; avImg.ZIndex=13
Instance.new("UICorner",avImg).CornerRadius=UDim.new(0,16)
stroke(avImg,C.ACCENT,1)
task.spawn(function()
    local ok,url=pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
    end)
    if ok then avImg.Image=url end
end)
local avName = Instance.new("TextLabel", footer)
avName.Size=UDim2.new(1,-50,1,0); avName.Position=UDim2.new(0,46,0,0)
avName.BackgroundTransparency=1; avName.Text=player.DisplayName or player.Name
avName.TextColor3=Color3.fromRGB(220,220,235); avName.TextSize=11; avName.Font=FONT_SEMI
avName.TextXAlignment=Enum.TextXAlignment.Left
avName.TextTruncate=Enum.TextTruncate.AtEnd; avName.ZIndex=13

-- ── Content area ──────────────────────────────────────────────────
local contentArea = Instance.new("Frame", win)
contentArea.Size             = UDim2.new(1, -(SIDEBAR_W+14), 1, -96)
contentArea.Position         = UDim2.new(0, SIDEBAR_W+8, 0, 86)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.ZIndex           = 11

-- ── Tab system ────────────────────────────────────────────────────
local tabButtons, tabLabels, tabIcons, tabPages, activeTab = {}, {}, {}, {}, nil
local TAB_NAMES = {"Lobby","Joiner","Game","Odyssey","Macro"}

local function makePage()
    local p=Instance.new("ScrollingFrame")
    p.Size=UDim2.new(1,0,1,0); p.BackgroundTransparency=1; p.BorderSizePixel=0
    p.ScrollBarThickness=3; p.ScrollBarImageColor3=Color3.fromRGB(140,40,200)
    p.CanvasSize=UDim2.new(0,0,0,0); p.AutomaticCanvasSize=Enum.AutomaticSize.Y
    p.Visible=false; p.ZIndex=12; p.Parent=contentArea
    listLayout(p,nil,8); padding(p,nil,4,12,2,8)
    return p
end

local function switchTab(name)
    for n,_ in pairs(tabPages) do
        tabPages[n].Visible=false
        if tabButtons[n] then
            tween(tabButtons[n],{BackgroundTransparency=1},0.15)
            if tabLabels[n] then tabLabels[n].TextColor3=Color3.fromRGB(120,100,150) end
            if tabIcons[n]  then tabIcons[n].TextColor3=Color3.fromRGB(120,100,150) end
            -- hide active indicator
            local ind = tabButtons[n]:FindFirstChild("ActiveBar")
            if ind then tween(ind,{BackgroundTransparency=1},0.15) end
        end
    end
    tabPages[name].Visible=true
    tween(tabButtons[name],{BackgroundTransparency=0.88},0.15)
    tabLabels[name].TextColor3=Color3.fromRGB(255,255,255)
    tabIcons[name].TextColor3=C.ACCENT2
    local ind = tabButtons[name]:FindFirstChild("ActiveBar")
    if ind then tween(ind,{BackgroundTransparency=0},0.2) end
    activeTab=name
end

for i,name in ipairs(TAB_NAMES) do
    local b = Instance.new("TextButton", tabList)
    b.Size=UDim2.new(1,0,0,40); b.BackgroundColor3=Color3.fromRGB(180,80,255)
    b.BackgroundTransparency=1; b.Text=""; b.AutoButtonColor=false
    b.BorderSizePixel=0; b.LayoutOrder=i; b.ZIndex=13
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,0)

    -- Left accent bar (visible when active)
    local bar = Instance.new("Frame", b)
    bar.Name="ActiveBar"; bar.Size=UDim2.new(0,3,0.6,0)
    bar.AnchorPoint=Vector2.new(0,0.5); bar.Position=UDim2.new(0,0,0.5,0)
    bar.BackgroundColor3=C.ACCENT2; bar.BorderSizePixel=0; bar.ZIndex=15
    bar.BackgroundTransparency=1
    Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)

    -- Label only — no icon
    local lbl = Instance.new("TextLabel", b)
    lbl.Size=UDim2.new(1,-16,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=name
    lbl.TextColor3=Color3.fromRGB(110,95,140)
    lbl.TextSize=13; lbl.Font=FONT_SEMI
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=14

    -- dummy ico table entry so switchTab doesn't error
    local ico = Instance.new("TextLabel", b)
    ico.Size=UDim2.new(0,0,0,0); ico.BackgroundTransparency=1
    ico.Text=""; ico.ZIndex=0

    tabButtons[name]=b; tabLabels[name]=lbl; tabIcons[name]=ico
    tabPages[name]=makePage()

    b.MouseButton1Click:Connect(function() switchTab(name) end)
    b.MouseEnter:Connect(function()
        if activeTab~=name then
            tween(b,{BackgroundTransparency=0.93},0.1)
            lbl.TextColor3=Color3.fromRGB(180,160,210)
        end
    end)
    b.MouseLeave:Connect(function()
        if activeTab~=name then
            tween(b,{BackgroundTransparency=1},0.1)
            lbl.TextColor3=Color3.fromRGB(110,95,140)
        end
    end)
end

-- ======================
-- COMPONENTS
-- ======================
local function section(page, title, order)
    local card=Instance.new("Frame")
    card.Size=UDim2.new(1,-4,0,0); card.AutomaticSize=Enum.AutomaticSize.Y
    card.BackgroundColor3=C.CARD; card.BorderSizePixel=0
    card.LayoutOrder=order or 1; card.ZIndex=2; card.Parent=page
    corner(card,10); stroke(card,C.BORDER,1)
    listLayout(card,nil,6); padding(card,nil,10,12,12,12)
    if title and title ~= "" then
        local hdr=Instance.new("Frame")
        hdr.Size=UDim2.new(1,0,0,22); hdr.BackgroundTransparency=1
        hdr.LayoutOrder=0; hdr.ZIndex=3; hdr.Parent=card
        local bar=Instance.new("Frame")
        bar.Size=UDim2.new(0,3,1,0); bar.BackgroundColor3=C.ACCENT
        bar.BorderSizePixel=0; bar.ZIndex=3; bar.Parent=hdr
        corner(bar,2); gradient(bar,C.ACCENT2,C.ACCENT,90)
        local lbl=Instance.new("TextLabel")
        lbl.Size=UDim2.new(1,-12,1,0); lbl.Position=UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=title; lbl.TextColor3=C.TEXT
        lbl.TextSize=13; lbl.Font=FONT_BOLD
        lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=3; lbl.Parent=hdr
    end
    return card
end

local function btn(parent, label, color, order)
    color = color or C.ACCENT
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,32); b.BackgroundColor3=color
    b.Text=label; b.TextColor3=C.TEXT; b.TextSize=14; b.Font=FONT_BOLD
    b.BorderSizePixel=0; b.LayoutOrder=order or 99; b.ZIndex=3; b.Parent=parent
    corner(b,7); gradient(b,color,color:Lerp(Color3.new(0,0,0),0.25),90)
    b.MouseEnter:Connect(function() tween(b,{BackgroundTransparency=0.2}) end)
    b.MouseLeave:Connect(function() tween(b,{BackgroundTransparency=0}) end)
    return b
end

local function label(parent, text, order)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,0,0,18); l.BackgroundTransparency=1
    l.Text=text; l.TextColor3=C.SUBTEXT; l.TextSize=11; l.Font=FONT_REG
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.LayoutOrder=order or 99; l.ZIndex=3; l.Parent=parent
    return l
end

local function input(parent, placeholder, order)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,32); f.BackgroundColor3=C.BG; f.BorderSizePixel=0
    f.LayoutOrder=order or 99; f.ZIndex=3; f.Parent=parent
    corner(f,7); stroke(f,C.BORDER,1)
    local tb=Instance.new("TextBox")
    tb.Size=UDim2.new(1,-16,1,0); tb.Position=UDim2.new(0,8,0,0)
    tb.BackgroundTransparency=1; tb.Text=""
    tb.PlaceholderText=placeholder; tb.PlaceholderColor3=C.DIM
    tb.TextColor3=C.TEXT; tb.TextSize=13; tb.Font=FONT_REG
    tb.TextXAlignment=Enum.TextXAlignment.Left; tb.ZIndex=4; tb.Parent=f
    tb.Focused:Connect(function() tween(f,{BackgroundColor3=C.PANEL}) end)
    tb.FocusLost:Connect(function() tween(f,{BackgroundColor3=C.BG}) end)
    return tb
end

local function toggle(parent, text, order, default, saveKey)
    -- Full-width row with a small indicator light. Only the circle lights up;
    -- the row itself stays dark so enabled states do not flood the panel.
    saveKey = saveKey or ("toggle:"..text)

    local btnRow=Instance.new("TextButton")
    btnRow.Size=UDim2.new(1,0,0,34); btnRow.AutoButtonColor=false
    btnRow.BackgroundColor3=C.PANEL; btnRow.BorderSizePixel=0
    btnRow.Text=""; btnRow.LayoutOrder=order or 99; btnRow.ZIndex=3; btnRow.Parent=parent
    corner(btnRow,7); stroke(btnRow,C.BORDER,1)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-40,1,0); lbl.Position=UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=C.TEXT; lbl.TextSize=13; lbl.Font=FONT_SEMI
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4; lbl.Parent=btnRow

    local light=Instance.new("Frame")
    light.Size=UDim2.new(0,12,0,12); light.Position=UDim2.new(1,-22,0.5,-6)
    light.BackgroundColor3=C.DISABLED; light.BorderSizePixel=0; light.ZIndex=5; light.Parent=btnRow
    corner(light,6)

    local glow=Instance.new("Frame")
    glow.Size=UDim2.new(0,22,0,22); glow.Position=UDim2.new(0.5,-11,0.5,-11)
    glow.BackgroundColor3=C.ACCENT; glow.BackgroundTransparency=1
    glow.BorderSizePixel=0; glow.ZIndex=4; glow.Parent=light
    corner(glow,11)

    local enabled = getSavedToggle(saveKey, default)
    local function apply()
        tween(btnRow,{BackgroundColor3=C.PANEL})
        if enabled then
            tween(light,{BackgroundColor3=C.ACCENT})
            tween(glow,{BackgroundTransparency=0.35})
            lbl.TextColor3 = C.TEXT
        else
            tween(light,{BackgroundColor3=C.DISABLED})
            tween(glow,{BackgroundTransparency=1})
            lbl.TextColor3 = C.SUBTEXT
        end
    end
    apply()

    local callbacks = {}
    btnRow.MouseButton1Click:Connect(function()
        enabled = not enabled
        setSavedToggle(saveKey, enabled)
        apply()
        for _,cb in ipairs(callbacks) do task.spawn(cb, enabled) end
    end)
    return btnRow, function() return enabled end, function(cb)
        table.insert(callbacks, cb)
        -- Fire immediately if already ON when script loads (e.g. saved state)
        if enabled then task.spawn(cb, true) end
    end
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
label(sumSec, "Loops summon using the game's own max/current currency handling.", 1)

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
    local _, getOn = toggle(sumSec, "Auto: "..b.name, i+1, false, "summon-v7:"..b.id)
    task.spawn(function()
        while true do
            if getOn() and not inGameMode() then
                fireBanner(b.id)
            end
            task.wait(1.25)
        end
    end)
end

-- Claimers (each has a Run button + Loop toggle)
local claimSec = section(lobbyPage, "Claimer", 2)
local CLAIMERS = {
    { name="Claim All Quests", color=C.GREEN, fn=function() Net.Quests.ClaimQuest:FireServer("ClaimAll") end },
    { name="Claim All Milestones", color=Color3.fromRGB(60,130,220), fn=function()
        for _,m in ipairs({10,25,50,70,100,150,200,250,300,400,500,750,1000}) do
            Net.Milestones.MilestonesEvent:FireServer("Claim", m); task.wait(0.08)
        end
    end},
    { name="Claim Daily Reward", color=C.YELLOW, fn=function()
        for day=1,7 do Net.DailyRewardEvent:FireServer("Claim",{[1]="Special",[2]=day}); task.wait(0.08) end
    end},
    { name="Claim Battle Pass", color=Color3.fromRGB(160,60,220), fn=function() Net.BattlepassEvent:FireServer("ClaimAll") end},
}
local loopGetters = {}
for i,c in ipairs(CLAIMERS) do
    -- Row holding button + loop pill
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,34); row.BackgroundTransparency=1
    row.LayoutOrder=i; row.ZIndex=3; row.Parent=claimSec
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,-78,1,0); b.Position=UDim2.new(0,0,0,0)
    b.BackgroundColor3=c.color; b.Text=c.name; b.TextColor3=C.TEXT
    b.TextSize=14; b.Font=FONT_BOLD; b.BorderSizePixel=0
    b.ZIndex=3; b.Parent=row; corner(b,7)
    gradient(b,c.color,c.color:Lerp(Color3.new(0,0,0),0.25),90)
    b.MouseButton1Click:Connect(function() safeCall(c.fn, c.name.." done!", "Claim failed") end)
    -- Loop pill (toggle)
    local track=Instance.new("TextButton")
    track.Size=UDim2.new(0,72,1,0); track.Position=UDim2.new(1,-72,0,0)
    track.BackgroundColor3=C.DISABLED; track.Text="Loop OFF"; track.TextColor3=C.TEXT
    track.TextSize=11; track.Font=FONT_BOLD; track.BorderSizePixel=0
    track.AutoButtonColor=false; track.ZIndex=3; track.Parent=row; corner(track,7)
    local on=false
    track.MouseButton1Click:Connect(function()
        on = not on
        tween(track,{BackgroundColor3 = on and C.GREEN or C.DISABLED})
        track.Text = on and "Loop ON" or "Loop OFF"
    end)
    loopGetters[i] = function() return on end
end
local allBtn = btn(claimSec, "Run All Claims", C.ACCENT, #CLAIMERS+10)
allBtn.MouseButton1Click:Connect(function()
    safeCall(function() for _,c in ipairs(CLAIMERS) do c.fn(); task.wait(0.2) end end, "All rewards claimed!", "Claim all failed")
end)
-- Looper: fires each enabled claimer once per 5-second cycle, only in lobby.
-- Uses a single connection instead of a while-true loop so it never blocks
-- or interrupts other coroutines.
do
    local loopClock = 0
    RunSvc.Heartbeat:Connect(function()
        if os.clock() - loopClock < 5 then return end
        loopClock = os.clock()
        -- Claimers are lobby-only actions; skip entirely while in a match.
        if inGameMode() then return end
        for i, c in ipairs(CLAIMERS) do
            if loopGetters[i] and loopGetters[i]() then
                task.spawn(function() pcall(c.fn) end)
            end
        end
    end)
end
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

local matchSec = section(gamePage, "Match Controls", 1)

-- Skip Wave: toggle, fires every 3s while on and in-match
local _, getSkipWave, onSkipWave = toggle(matchSec, "Skip Wave", C.ACCENT, 1, "game.skipwave")
local skipWaveClock = 0
RunSvc.Heartbeat:Connect(function()
    if not getSkipWave() then return end
    if not inGameMode() then return end
    if os.clock() - skipWaveClock < 3 then return end
    skipWaveClock = os.clock()
    local r = Net:FindFirstChild("SkipWaveEvent")
    if r and r:IsA("RemoteEvent") then pcall(function() r:FireServer("Skip") end) end
end)

-- ======================
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
-- CONFIRMED paths: workspace.Terrain, game:GetService("Lighting")
-- Makes everything flat grey — no textures, no sky, no particles.
local fpsApplied = false
local _, getBoostFPS, onBoostFPS = toggle(utilSec, "Boost FPS", 4, false, "util.fpsbst")
onBoostFPS(function(on)
    if on and not fpsApplied then
        fpsApplied = true
        local Lighting = game:GetService("Lighting")

        -- Lowest quality setting
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

        -- Nuke all Lighting children (Sky, Atmosphere, PostEffects, etc.)
        for _, c in ipairs(Lighting:GetChildren()) do
            pcall(function() c:Destroy() end)
        end
        -- Flat grey lighting
        Lighting.GlobalShadows        = false
        Lighting.FogEnd               = 9e9
        Lighting.FogStart             = 9e9
        Lighting.Brightness           = 0
        Lighting.Ambient              = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient       = Color3.fromRGB(200, 200, 200)
        Lighting.ClockTime            = 14
        Lighting.ExposureCompensation = 0
        Lighting.ColorShift_Bottom    = Color3.new(0,0,0)
        Lighting.ColorShift_Top       = Color3.new(0,0,0)

        -- Terrain: flat grey, no decoration, no water effects
        local Terrain = workspace.Terrain
        Terrain.WaterWaveSize     = 0
        Terrain.WaterWaveSpeed    = 0
        Terrain.WaterReflectance  = 0
        Terrain.WaterTransparency = 1
        Terrain.Decoration        = false
        -- Remove clouds from Terrain
        for _, c in ipairs(Terrain:GetChildren()) do
            if c:IsA("Clouds") then pcall(function() c:Destroy() end) end
        end

        -- Simplify every instance in workspace
        local function simplify(inst)
            if inst:IsA("BasePart") then
                pcall(function()
                    inst.Material    = Enum.Material.SmoothPlastic
                    inst.CastShadow  = false
                    inst.Reflectance = 0
                    -- Make terrain-adjacent parts grey
                    inst.BrickColor  = BrickColor.new("Medium stone grey")
                end)
            end
            local cls = inst.ClassName
            if cls=="ParticleEmitter" or cls=="Trail" or cls=="Beam"
            or cls=="Smoke" or cls=="Fire" or cls=="Sparkles"
            or cls=="SelectionBox" or cls=="Atmosphere" or cls=="Sky"
            or cls=="Clouds" or cls=="PointLight" or cls=="SpotLight"
            or cls=="SurfaceLight" then
                pcall(function() inst:Destroy() end)
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                pcall(function() inst.Transparency = 1 end)
            elseif inst:IsA("SpecialMesh") then
                pcall(function() inst.MeshType = Enum.MeshType.Block end)
            end
        end

        for _, inst in ipairs(workspace:GetDescendants()) do simplify(inst) end
        workspace.DescendantAdded:Connect(function(inst)
            if getBoostFPS() then simplify(inst) end
        end)

        notify("FPS Boost ON", true)
    elseif not on and fpsApplied then
        fpsApplied = false
        notify("FPS Boost OFF — rejoin to fully restore", true)
    end
end)

end -- close Game Tab do block

-- ======================
-- ODYSSEY TAB  (dynamic, no UUIDs)
-- ======================
do
local odysseyPage = tabPages["Odyssey"]
local autoSec = section(odysseyPage, "Auto Behavior", 1)
local _, getAutoNextRoom      = toggle(autoSec, "Auto Next Room",                    1, false, "odyssey.auto_next_room")
label(autoSec, "Continues to the next room automatically", 2)
local _, getAutoPick          = toggle(autoSec, "Auto Select Cards",                 3, true,  "odyssey.auto_select_cards")
label(autoSec, "Picks highest rarity card when card screen appears", 4)
local _, getAutoRagnawCards   = toggle(autoSec, "Auto Select Unit Cards (Ragnaw)",   5, false, "odyssey.auto_ragnaw_unit_cards")
label(autoSec, "Prioritises Ragnaw unit cards when picking", 6)
local _, getAutoSkipShop      = toggle(autoSec, "Auto Skip Shop",                    7, false, "odyssey.auto_skip_shop.v3")
label(autoSec, "Closes Stiches' Shop automatically", 8)
local _, getAutoCollectChests = toggle(autoSec, "Auto Collect Chests",               9, false, "odyssey.auto_collect_chest.v3")
label(autoSec, "Opens all chests in Treasure Room", 10)
local _, getSkipUnitReward    = toggle(autoSec, "Skip Unit Reward",                 11, false, "odyssey.skip_unit_reward")
label(autoSec, "Skips unit reward panel after elite rooms", 12)

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

-- --- Card discovery ---------------------------------------------------------
-- Cards come from one of:
--   1) ReplicatedStorage / Odyssey / Cards (or similar)
--   2) Scraped at runtime when the card-pick UI opens
local function isRagnawTargetCard(name)
    return RAGNAW_TARGET_CARDS[(name or ""):lower():gsub("^%s+",""):gsub("%s+$","")] == true
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
    return playerGui:FindFirstChild("AdventureHUD")
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
    local hud = getAdventureHUD()
    if not hud then return nil end
    local cc = hud:FindFirstChild("ChooseCard")
    if not cc or not cc.Visible then return nil end

    -- CONFIRMED path: ChooseCard.Content.ListContainer.ScrollIndicatorFrame
    local sif = cc:FindFirstChild("Content")
    sif = sif and sif:FindFirstChild("ListContainer")
    sif = sif and sif:FindFirstChild("ScrollIndicatorFrame")
    if not sif then return nil end

    local cards = {}
    for _, child in ipairs(sif:GetChildren()) do
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
    local hud = getAdventureHUD()
    if hud then
        clickClose(hud:FindFirstChild("Stiches' Shop_Export"))
    end
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

    -- Click confirmed Close button: TreasurePanel.Content.TopFrame.RightFrame.RightFrame.Close
    local hud = getAdventureHUD()
    if hud then clickClose(hud:FindFirstChild("TreasurePanel")) end
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
    -- Also click Close if present
    local panel = findAdventurePanel("BossRewardPickPanel")
               or findAdventurePanel("RunRewardsPanelRoot")
    clickClose(panel)
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

-- ── Event-driven automation ───────────────────────────────────────
-- Uses GetPropertyChangedSignal("Visible") — fires the instant each
-- panel appears. Much more reliable than polling every 0.5s.

local function doCardPick()
    if not (getAutoPick() or getAutoRagnawCards()) then return end
    -- Small delay so server finishes setting up pick state
    task.wait(0.3)
    local ev = getONet("CardPickEvent")
    if not ev then return end

    -- Find best card by rarity from button text
    local cards = getCardButtons()
    local bestIdx = 1
    if cards and #cards > 0 then
        local bestScore = -1
        for i, c in ipairs(cards) do
            local score = rarityScore(c.text)
            if score > bestScore then bestIdx = i; bestScore = score end
        end
    end

    -- Fire Pick twice — first selects, second confirms character cards
    pcall(function() ev:FireServer("Pick", bestIdx) end)
    task.wait(0.35)
    pcall(function() ev:FireServer("Pick", bestIdx) end)
end

local function doShop()
    if not getAutoSkipShop() then return end
    task.wait(0.15)
    closeShopGui()
    if getAutoNextRoom() then task.wait(0.5); requestNextRoom() end
end

local function doTreasure()
    if not getAutoCollectChests() then return end
    openedChests = {}
    task.wait(0.5)
    collectAndCloseTreasure()
    if getAutoNextRoom() then task.wait(1); requestNextRoom() end
end

local function doUnitReward()
    if not getSkipUnitReward() then return end
    task.wait(0.15)
    skipUnitRewardPanel()
end

-- Connect signals once AdventureHUD and its panels are available
local function hookPanels(hud)
    local function onVisible(panel, fn)
        if not panel then return end
        panel:GetPropertyChangedSignal("Visible"):Connect(function()
            if panel.Visible then task.spawn(fn) end
        end)
    end

    onVisible(hud:FindFirstChild("ChooseCard"),             doCardPick)
    onVisible(hud:FindFirstChild("Stiches' Shop_Export"),   doShop)
    onVisible(hud:FindFirstChild("TreasurePanel"),          doTreasure)
    onVisible(hud:FindFirstChild("BossRewardPickPanel"),    doUnitReward)
    onVisible(hud:FindFirstChild("RunRewardsPanelRoot"),    doUnitReward)
end

-- Try to hook now; retry every second until AdventureHUD is found
task.spawn(function()
    local hooked = false
    while not hooked do
        local hud = playerGui:FindFirstChild("AdventureHUD")
        if hud then
            hookPanels(hud)
            hooked = true
        else
            -- Wait for AdventureHUD to appear
            playerGui.ChildAdded:Wait()
        end
    end
end)

-- Also hook when playerGui gets a new AdventureHUD (e.g. after rejoin)
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "AdventureHUD" then
        task.wait(0.5)
        hookPanels(child)
    end
end)

-- Auto Next Room: keep polling since there's no panel to watch
do
    local roomClock = 0
    RunSvc.Heartbeat:Connect(function()
        if not getAutoNextRoom() then return end
        if not inGameMode() then return end
        local now = os.clock()
        if now - roomClock >= 2 then
            roomClock = now
            task.spawn(requestNextRoom)
        end
    end)
end

end -- close Odyssey do block

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
corner(listScroll, 7); stroke(listScroll, C.BORDER, 1)
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
        row.BackgroundColor3 = (selectedMacro == name) and C.ACCENT or C.PANEL
        row.AutoButtonColor = false
        row.Text = ""
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = listScroll
        corner(row, 6)

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
floatBtn.BackgroundColor3=Color3.fromRGB(18,10,30)
floatBtn.BackgroundTransparency=0
floatBtn.BorderSizePixel=0; floatBtn.AutoButtonColor=false
floatBtn.ZIndex=50; floatBtn.Image=""; floatBtn.Parent=gui
Instance.new("UICorner",floatBtn).CornerRadius=UDim.new(0,26)
stroke(floatBtn,C.ACCENT,2)

-- Glow bloom
local fbGlow = Instance.new("ImageLabel",floatBtn)
fbGlow.Size=UDim2.new(0,80,0,80); fbGlow.AnchorPoint=Vector2.new(0.5,0.5)
fbGlow.Position=UDim2.new(0.5,0,0.5,0); fbGlow.BackgroundTransparency=1
fbGlow.Image="rbxassetid://5028857084"; fbGlow.ImageColor3=C.ACCENT2
fbGlow.ImageTransparency=0.55; fbGlow.ZIndex=49

-- Eye icon (matches OzWare logo aesthetic)
local eyeLbl = Instance.new("TextLabel",floatBtn)
eyeLbl.Size=UDim2.new(1,0,1,0); eyeLbl.BackgroundTransparency=1
eyeLbl.Text="👁"; eyeLbl.TextSize=24; eyeLbl.Font=FONT_BOLD
eyeLbl.TextColor3=C.ACCENT2; eyeLbl.ZIndex=51


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
