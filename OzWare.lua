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
-- THEME (high contrast)
-- ======================
local C = {
    BG       = Color3.fromRGB(28, 34, 52),       -- dark navy window
    PANEL    = Color3.fromRGB(22, 28, 44),       -- sidebar / titlebar (slightly darker)
    CARD     = Color3.fromRGB(34, 42, 62),       -- cards
    BORDER   = Color3.fromRGB(55, 65, 95),
    ACCENT   = Color3.fromRGB(95, 230, 240),     -- neon cyan
    ACCENT2  = Color3.fromRGB(255, 70, 160),     -- neon magenta
    GREEN    = Color3.fromRGB(80, 220, 170),
    RED      = Color3.fromRGB(255, 90, 130),
    YELLOW   = Color3.fromRGB(245, 200, 90),
    TEXT     = Color3.fromRGB(255, 255, 255),
    SUBTEXT  = Color3.fromRGB(245, 248, 255),
    DIM      = Color3.fromRGB(220, 226, 240),
    DISABLED = Color3.fromRGB(55, 60, 85),
    ACTIVE   = Color3.fromRGB(245, 248, 255),    -- light pill for active tab
}
local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.GothamSemibold
local FONT_REG  = Enum.Font.Gotham

-- ======================
-- REMOTES
-- ======================
local function OdysseyNet()   local o = Net:FindFirstChild("Odyssey") return o and o:FindFirstChild("Adventure") end

-- ======================
-- GAME-MODE GUARD (top-level, shared by all tabs)
-- Returns true only when the player is inside an active match/map,
-- not in the lobby. All automation loops check this before firing remotes.
-- ======================
local function getMapRoot()
    return workspace:FindFirstChild("Map")
        or workspace:FindFirstChild("MapHolder")
        or workspace:FindFirstChild("Maps")
        or workspace:FindFirstChild("Stage")
end

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
-- WINDOW
-- ======================
local win = Instance.new("Frame")
win.Name="Window"; win.Size=UDim2.new(0,720,0,460)
win.AnchorPoint=Vector2.new(0.5,0.5); win.Position=UDim2.new(0.5,0,0.5,0)
win.BackgroundColor3=C.BG; win.BorderSizePixel=0; win.ClipsDescendants=true
-- Active=true means only the window frame itself captures mouse events;
-- areas of the ScreenGui outside the window are fully click-through so
-- game buttons behind OzWare continue to work normally.
win.Active=true; win.Parent=gui
corner(win,18); stroke(win,C.BORDER,1)

-- Neon side glow bars (left = cyan, right = magenta) — parented to gui, hugging window
local function glowBar(side, col)
    local g=Instance.new("Frame")
    g.AnchorPoint=Vector2.new(0.5,0.5)
    g.Size=UDim2.new(0,4,0,420)
    -- side: -1 = left of window, +1 = right of window
    g.Position=UDim2.new(0.5, side * (360 + 16), 0.5, 0)
    g.BackgroundColor3=col; g.BorderSizePixel=0; g.ZIndex=0; g.Parent=gui
    corner(g,2)
    local s=Instance.new("ImageLabel")
    s.AnchorPoint=Vector2.new(0.5,0.5); s.Size=UDim2.new(0,90,1,80)
    s.Position=UDim2.new(0.5,0,0.5,0); s.BackgroundTransparency=1
    s.Image="rbxassetid://5028857084"; s.ImageColor3=col
    s.ImageTransparency=0.45; s.ZIndex=0; s.Parent=g
end

-- Title bar
local titleBar=Instance.new("Frame")
titleBar.Size=UDim2.new(1,0,0,52); titleBar.BackgroundColor3=C.PANEL
titleBar.BorderSizePixel=0; titleBar.ZIndex=2; titleBar.Parent=win
corner(titleBar,18)
local titleCover=Instance.new("Frame")
titleCover.Size=UDim2.new(1,0,0,18); titleCover.Position=UDim2.new(0,0,1,-18)
titleCover.BackgroundColor3=C.PANEL; titleCover.BorderSizePixel=0
titleCover.ZIndex=2; titleCover.Parent=titleBar

-- Monogram logo "Oz" with neon gradient
local logo=Instance.new("TextLabel")
logo.Size=UDim2.new(0,38,0,38); logo.Position=UDim2.new(0,14,0.5,-19)
logo.BackgroundTransparency=1; logo.Text="Oz"
logo.TextColor3=C.ACCENT; logo.TextSize=22; logo.Font=FONT_BOLD
logo.ZIndex=3; logo.Parent=titleBar
gradient(logo,C.ACCENT,C.ACCENT2,135)

-- Centered title
local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(0,200,1,0); titleLbl.AnchorPoint=Vector2.new(0.5,0)
titleLbl.Position=UDim2.new(0.5,0,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.Text="OzWare V3"
titleLbl.TextColor3=C.TEXT; titleLbl.TextSize=18; titleLbl.Font=FONT_BOLD
titleLbl.ZIndex=3; titleLbl.Parent=titleBar

-- Title buttons
local function titleBtn(rightOffset, bg, symbol)
    local b=Instance.new("TextButton")
    b.AnchorPoint=Vector2.new(1,0.5)
    b.Size=UDim2.new(0,28,0,28)
    b.Position=UDim2.new(1, -rightOffset, 0.5, 0)
    b.BackgroundColor3=bg; b.Text=symbol; b.TextColor3=C.TEXT
    b.TextSize=15; b.Font=FONT_BOLD; b.BorderSizePixel=0
    b.ZIndex=4; b.Parent=titleBar; corner(b,8)
    b.MouseEnter:Connect(function() tween(b,{BackgroundTransparency=0.3}) end)
    b.MouseLeave:Connect(function() tween(b,{BackgroundTransparency=0}) end)
    return b
end
-- (Minimize / Close buttons removed; using floating toggle bottom-left)


-- floating toggle handler is added after sidebar/contentArea exist (see bottom of file)

-- Drag
local dragging, dragStart, winStart = false, nil, nil
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; winStart=win.Position
    end
end)
titleBar.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        win.Position=UDim2.new(winStart.X.Scale, winStart.X.Offset+d.X, winStart.Y.Scale, winStart.Y.Offset+d.Y)
    end
end)

-- ======================
-- SIDEBAR (left vertical tabs) + CONTENT (right)
-- ======================
-- Sidebar container (no list layout — children positioned manually)
local sidebar=Instance.new("Frame")
sidebar.Size=UDim2.new(0,150,1,-64); sidebar.Position=UDim2.new(0,10,0,58)
sidebar.BackgroundColor3=C.PANEL; sidebar.BorderSizePixel=0; sidebar.ZIndex=2; sidebar.Parent=win
corner(sidebar,14)

-- Tab list (top of sidebar)
local tabList=Instance.new("Frame")
tabList.Size=UDim2.new(1,-12,1,-78); tabList.Position=UDim2.new(0,6,0,8)
tabList.BackgroundTransparency=1; tabList.ZIndex=3; tabList.Parent=sidebar
listLayout(tabList,nil,6,Enum.HorizontalAlignment.Center)

local contentArea=Instance.new("Frame")
contentArea.Size=UDim2.new(1, -180, 1, -64); contentArea.Position=UDim2.new(0,170,0,58)
contentArea.BackgroundTransparency=1; contentArea.ClipsDescendants=true; contentArea.Parent=win

local tabButtons, tabLabels, tabIcons, tabPages, activeTab = {}, {}, {}, {}, nil
local TAB_NAMES = {"Lobby","Joiner","Game","Odyssey"}
local TAB_ICONS = { Lobby="H", Joiner="J", Game="G", Odyssey="O" }

local function makePage()
    local p=Instance.new("ScrollingFrame")
    p.Size=UDim2.new(1,0,1,0); p.BackgroundTransparency=1; p.BorderSizePixel=0
    p.ScrollBarThickness=3; p.ScrollBarImageColor3=C.ACCENT
    p.CanvasSize=UDim2.new(0,0,0,0); p.AutomaticCanvasSize=Enum.AutomaticSize.Y
    p.Visible=false; p.ZIndex=2; p.Parent=contentArea
    listLayout(p,nil,8); padding(p,nil,4,12,2,8)
    return p
end

local function switchTab(name)
    for n,_ in pairs(tabPages) do
        tabPages[n].Visible=false
        tween(tabButtons[n],{BackgroundColor3=C.PANEL, BackgroundTransparency=1},0.15)
        tabLabels[n].TextColor3=C.SUBTEXT
        tabIcons[n].TextColor3=C.SUBTEXT
    end
    tabPages[name].Visible=true
    tween(tabButtons[name],{BackgroundColor3=C.ACTIVE, BackgroundTransparency=0},0.15)
    tabLabels[name].TextColor3=Color3.fromRGB(28,34,52)
    tabIcons[name].TextColor3=Color3.fromRGB(28,34,52)
    activeTab=name
end

for i,name in ipairs(TAB_NAMES) do
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,38); b.BackgroundColor3=C.ACTIVE; b.BackgroundTransparency=1
    b.Text=""; b.AutoButtonColor=false
    b.BorderSizePixel=0; b.LayoutOrder=i; b.ZIndex=3; b.Parent=tabList
    corner(b,10)
    local ico=Instance.new("TextLabel")
    ico.Size=UDim2.new(0,24,0,24); ico.Position=UDim2.new(0,10,0.5,-12)
    ico.BackgroundTransparency=1; ico.Text=TAB_ICONS[name] or ""
    ico.TextColor3=C.SUBTEXT; ico.TextSize=15; ico.Font=FONT_BOLD; ico.ZIndex=4; ico.Parent=b
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-40,1,0); lbl.Position=UDim2.new(0,38,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=name; lbl.TextColor3=C.SUBTEXT
    lbl.TextSize=13; lbl.Font=FONT_SEMI; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=4; lbl.Parent=b
    tabButtons[name]=b; tabLabels[name]=lbl; tabIcons[name]=ico
    tabPages[name]=makePage()
    b.MouseButton1Click:Connect(function() switchTab(name) end)
end

-- Avatar footer at bottom of sidebar
local footer=Instance.new("Frame")
footer.Size=UDim2.new(1,-12,0,60); footer.Position=UDim2.new(0,6,1,-66)
footer.BackgroundTransparency=1; footer.ZIndex=3; footer.Parent=sidebar
local avatar=Instance.new("ImageLabel")
avatar.Size=UDim2.new(0,40,0,40); avatar.Position=UDim2.new(0,4,0.5,-20)
avatar.BackgroundColor3=C.CARD; avatar.BorderSizePixel=0; avatar.ZIndex=4; avatar.Parent=footer
corner(avatar,20); stroke(avatar,C.ACCENT,1)
task.spawn(function()
    local ok,url = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    if ok then avatar.Image = url end
end)
local nameLbl=Instance.new("TextLabel")
nameLbl.Size=UDim2.new(1,-54,1,0); nameLbl.Position=UDim2.new(0,50,0,0)
nameLbl.BackgroundTransparency=1; nameLbl.Text=player.DisplayName or player.Name
nameLbl.TextColor3=C.TEXT; nameLbl.TextSize=12; nameLbl.Font=FONT_SEMI
nameLbl.TextXAlignment=Enum.TextXAlignment.Left
nameLbl.TextTruncate=Enum.TextTruncate.AtEnd; nameLbl.ZIndex=4; nameLbl.Parent=footer

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
        corner(bar,2); gradient(bar,C.ACCENT,C.ACCENT2,90)
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
    return btnRow, function() return enabled end, function(cb) table.insert(callbacks, cb) end
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
-- Hides all workspace descendants EXCEPT Entities folder (enemies) and player characters.
-- Units (non-Entities models with player owner) turn green.
local mapDeleted = false
local _, getDeleteMap, onDeleteMap = toggle(utilSec, "Delete Map Structures", 2, false, "util.deletemap")
onDeleteMap(function(on)
    if not on then mapDeleted = false; return end
    if mapDeleted then return end
    if not inGameMode() then notify("Must be in a match", false); return end
    mapDeleted = true

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local pY  = hrp and hrp.Position.Y or 0
    local count = 0

    -- Build player character set to skip
    local charSet = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then charSet[pl.Character] = true end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        -- Skip confirmed enemy folder
        if child.Name == "Entities" then continue end
        -- Skip player characters
        if charSet[child] then
            -- Tint green so still visible
            for _, p in ipairs(child:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.BrickColor = BrickColor.new("Bright green"); p.Material = Enum.Material.Neon; p.CastShadow = false end)
                end
            end
            continue
        end
        -- Skip Camera, Terrain (handled by FPS boost), non-parts
        if child:IsA("Camera") or child.ClassName == "Terrain" then continue end

        -- Everything else: hide BaseParts, keep floor collidable
        for _, p in ipairs(child:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 1 then
                p.Transparency = 1
                local isFloor = (pY - p.Position.Y) >= 0 and (pY - p.Position.Y) <= 6
                if not isFloor then p.CanCollide = false end
                pcall(function()
                    local m = p:FindFirstChildOfClass("SpecialMesh")
                    if m then m.MeshType = Enum.MeshType.Block end
                end)
                count = count + 1
            elseif p:IsA("Decal") or p:IsA("Texture") then
                p.Transparency = 1
            end
        end
        -- Also handle direct BasePart children
        if child:IsA("BasePart") and child.Transparency < 1 then
            child.Transparency = 1
            local isFloor = (pY - child.Position.Y) >= 0 and (pY - child.Position.Y) <= 6
            if not isFloor then child.CanCollide = false end
            count = count + 1
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
    end
end)

end

-- ======================
-- ODYSSEY TAB  (dynamic, no UUIDs)
-- ======================
do
local odysseyPage = tabPages["Odyssey"]
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
        REMOTES.CardPickEvent   = _advFolder:FindFirstChild("CardPickEvent")
        REMOTES.ShopEvent       = _advFolder:FindFirstChild("ShopEvent")
        REMOTES.TreasureEvent   = _advFolder:FindFirstChild("TreasureEvent")
        REMOTES.UnitRewardEvent = _advFolder:FindFirstChild("UnitRewardEvent")
        REMOTES.BossRewardEvent = _advFolder:FindFirstChild("BossRewardEvent")
        REMOTES.VoteEvent       = _advFolder:FindFirstChild("VoteEvent")
        REMOTES.MapEvent        = _advFolder:FindFirstChild("MapEvent")
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
    for k in pairs(REMOTES) do REMOTES[k] = nil end
    task.wait(3); refreshRemotes()
end)

local function getONet(name)
    -- If the remote is already cached, return it
    if REMOTES[name] then return REMOTES[name] end
    -- Adventure folder only exists during a run — refresh every time we miss
    refreshRemotes()
    return REMOTES[name]
end

-- Re-resolve remotes when a new child appears under Networking
-- (Adventure folder is added when the player enters a run)
Net.ChildAdded:Connect(function()
    refreshRemotes()
end)
local odyF = Net:FindFirstChild("Odyssey")
if odyF then
    odyF.ChildAdded:Connect(function() refreshRemotes() end)
else
    Net.ChildAdded:Connect(function(c)
        if c.Name == "Odyssey" then
            refreshRemotes()
            c.ChildAdded:Connect(function() refreshRemotes() end)
        end
    end)
end

-- --- Card discovery ---------------------------------------------------------
-- Cards come from one of:
--   1) ReplicatedStorage / Odyssey / Cards (or similar)
--   2) Scraped at runtime when the card-pick UI opens
local function tryFindCardsFolder()
    local candidates = {
        RS:FindFirstChild("Odyssey"),
        RS:FindFirstChild("Adventures"),
        RS:FindFirstChild("Adventure"),
    }
    for _,root in ipairs(candidates) do
        if root then
            local f = root:FindFirstChild("Cards", true)
            if f then return f end
        end
    end
    return nil
end

-- classifyCard: "generic" = basic card (single tap), "unit" = character card (double tap)
-- Uses the confirmed BASIC_CARDS list — no guesswork needed
local function classifyCard(name, obj)
    if not name or name == "" then return "generic" end
    return isBasicCard(name) and "generic" or "unit"
end

local discoveredCards = { generic = {}, unit = {} }
local selectedCards   = { generic = {}, unit = {} }  -- [cardName] = true

local function addCard(name, obj)
    if not name or name=="" then return end
    local kind = classifyCard(name, obj)
    for _,c in ipairs(discoveredCards[kind]) do if c==name then return end end
    table.insert(discoveredCards[kind], name)
end

local function scanCardsFromFolder()
    local folder = tryFindCardsFolder()
    if not folder then return 0 end
    local n=0
    for _,c in ipairs(folder:GetDescendants()) do
        if c:IsA("ModuleScript") or c:IsA("Folder") or c:IsA("Configuration") then
            addCard(c.Name, c); n=n+1
        end
    end
    return n
end

-- Card names are populated from BASIC_CARDS table and runtime UI scraping
-- in the ChildAdded handler below — no separate scrape needed here

-- --- UI: card list builder --------------------------------------------------
local function buildCardList(parent, kind, emptyMsg)
    local holder = Instance.new("Frame")
    holder.Size=UDim2.new(1,0,0,0); holder.AutomaticSize=Enum.AutomaticSize.Y
    holder.BackgroundTransparency=1; holder.LayoutOrder=10; holder.Parent=parent
    listLayout(holder, nil, 4)

    local empty = Instance.new("TextLabel")
    empty.Size=UDim2.new(1,0,0,20); empty.BackgroundTransparency=1
    empty.Text=emptyMsg; empty.TextColor3=C.DIM; empty.TextSize=11
    empty.Font=FONT_REG; empty.TextXAlignment=Enum.TextXAlignment.Left
    empty.Parent=holder

    local function redraw()
        for _,c in ipairs(holder:GetChildren()) do
            if c:IsA("Frame") or (c:IsA("TextLabel") and c ~= empty) then c:Destroy() end
        end
        local list = discoveredCards[kind]
        empty.Visible = (#list == 0)
        table.sort(list)
        for i,name in ipairs(list) do
            local row=Instance.new("Frame")
            row.Size=UDim2.new(1,0,0,26); row.BackgroundColor3=C.PANEL
            row.BorderSizePixel=0; row.LayoutOrder=i; row.Parent=holder
            corner(row,5)
            local cb=Instance.new("TextButton")
            cb.Size=UDim2.new(0,18,0,18); cb.Position=UDim2.new(0,6,0.5,-9)
            cb.BackgroundColor3 = selectedCards[kind][name] and C.ACCENT or C.BG
            cb.Text=selectedCards[kind][name] and "v" or ""
            cb.TextColor3=C.TEXT; cb.TextSize=12; cb.Font=FONT_BOLD
            cb.BorderSizePixel=0; cb.Parent=row; corner(cb,4); stroke(cb,C.BORDER,1)
            local lb=Instance.new("TextLabel")
            lb.Size=UDim2.new(1,-32,1,0); lb.Position=UDim2.new(0,30,0,0)
            lb.BackgroundTransparency=1; lb.Text=name; lb.TextColor3=C.TEXT
            lb.TextSize=12; lb.Font=FONT_REG
            lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=row
            cb.MouseButton1Click:Connect(function()
                selectedCards[kind][name] = not selectedCards[kind][name] or nil
                cb.BackgroundColor3 = selectedCards[kind][name] and C.ACCENT or C.BG
                cb.Text = selectedCards[kind][name] and "v" or ""
            end)
        end
    end

    redraw()
    return redraw
end

-- --- Sections ---------------------------------------------------------------
local autoSec = section(odysseyPage, "Auto Behavior", 1)
local _, getAutoNextRoom       = toggle(autoSec, "Auto Next Room", 1, false, "odyssey.auto_next_room")
label(autoSec, "Will continue to the next room when match is finished", 2)
local _, getAutoPick           = toggle(autoSec, "Auto select cards", 3, true, "odyssey.auto_select_cards")
label(autoSec, "Will select basic cards and prioritize the highest rarity", 4)
local _, getAutoRagnawCards    = toggle(autoSec, "Auto Select Unit Cards (Ragnaw Only)", 5, false, "odyssey.auto_ragnaw_unit_cards")
label(autoSec, "Will select 4 cards that pair good with Ragnaw", 6)
local _, getAutoSkipShop       = toggle(autoSec, "Auto Skip Shop", 7, false, "odyssey.auto_skip_shop.v3")
label(autoSec, "Closes Stiches' Shop and advances to next room", 8)
local _, getAutoCollectChests  = toggle(autoSec, "Auto Collect Chests", 9, false, "odyssey.auto_collect_chest.v3")
label(autoSec, "Opens all chests in Treasure Room and closes UI", 10)
local _, getSkipUnitReward     = toggle(autoSec, "Skip Unit Reward", 11, false, "odyssey.skip_unit_reward")
label(autoSec, "Skips the unit reward panel after clearing an elite room", 12)

-- =====================================================

-- ======================
-- ======================
-- ======================
-- ADVENTURE JOINER (character reference only)
-- ======================

-- Required by card automation below
local ragnawPickedThisRun = {}
local ragnawPickCount     = 0

local charSec = section(odysseyPage, "Supported Characters", 0)

-- Header note
local charNote = Instance.new("TextLabel")
charNote.Size                  = UDim2.new(1,0,0,16)
charNote.BackgroundTransparency = 1
charNote.Text                  = "Characters with unit-card support:"
charNote.TextColor3            = C.SUBTEXT
charNote.TextSize              = 11
charNote.Font                  = FONT_REG
charNote.TextXAlignment        = Enum.TextXAlignment.Left
charNote.LayoutOrder           = 1
charNote.Parent                = charSec

-- Regnaw (Rage) entry
local ragnawRow = Instance.new("Frame")
ragnawRow.Size              = UDim2.new(1,0,0,34)
ragnawRow.BackgroundColor3  = C.PANEL
ragnawRow.BorderSizePixel   = 0
ragnawRow.LayoutOrder       = 2
ragnawRow.Parent            = charSec
corner(ragnawRow, 7)
stroke(ragnawRow, C.ACCENT, 1)

local raDot = Instance.new("Frame")
raDot.Size             = UDim2.new(0,8,0,8)
raDot.Position         = UDim2.new(0,10,0.5,-4)
raDot.BackgroundColor3 = C.GREEN
raDot.BorderSizePixel  = 0
raDot.Parent           = ragnawRow
corner(raDot, 4)

local raName = Instance.new("TextLabel")
raName.Size              = UDim2.new(0.6,0,1,0)
raName.Position          = UDim2.new(0,24,0,0)
raName.BackgroundTransparency = 1
raName.Text              = "Regnaw (Rage)"
raName.TextColor3        = C.TEXT
raName.TextSize          = 13
raName.Font              = FONT_BOLD
raName.TextXAlignment    = Enum.TextXAlignment.Left
raName.Parent            = ragnawRow

local raBadge = Instance.new("TextLabel")
raBadge.Size             = UDim2.new(0,80,0,20)
raBadge.Position         = UDim2.new(1,-86,0.5,-10)
raBadge.BackgroundColor3 = C.GREEN
raBadge.BorderSizePixel  = 0
raBadge.Text             = "Active"
raBadge.TextColor3       = Color3.fromRGB(10,20,10)
raBadge.TextSize         = 11
raBadge.Font             = FONT_BOLD
raBadge.TextXAlignment   = Enum.TextXAlignment.Center
raBadge.Parent           = ragnawRow
corner(raBadge, 5)

-- ODYSSEY AUTOMATION LOOP
-- ======================
local function isMaxedUnitCard(cardName)
    -- Try to count how many of this card the player has via stat folder/attribute
    -- Common patterns: Player:FindFirstChild("OdysseyCards"), or per-unit count attribute
    local function countIn(container)
        if not container then return nil end
        local n = container:GetAttribute(cardName)
        if typeof(n)=="number" then return n end
        local child = container:FindFirstChild(cardName)
        if child then
            local v = child:GetAttribute("Count") or child:GetAttribute("Amount") or child:GetAttribute("Value")
            if typeof(v)=="number" then return v end
            if child:IsA("IntValue") or child:IsA("NumberValue") then return child.Value end
        end
        return nil
    end
    local locs = {
        player:FindFirstChild("OdysseyCards"),
        player:FindFirstChild("Odyssey"),
        player:FindFirstChild("AdventureCards"),
    }
    for _,l in ipairs(locs) do
        local c = countIn(l)
        if c then return c >= 4 end
    end
    return false
end

-- isUnitCardGui: true if any of the visible card options are NOT basic cards
-- (character-specific cards need double-fire to confirm)
local function isUnitCardPick(opts)
    if not opts then return false end
    for _, name in ipairs(opts) do
        if not isBasicCard(name) then return true end
    end
    return false
end

local function pickIndex(opts, indexHint)
    local ev = getONet("CardPickEvent")
    if not ev then return false end
    local idx = indexHint or 1
    pcall(function() ev:FireServer("Pick", idx) end)
    -- Character-specific cards need a second Pick to confirm (double-tap)
    if isUnitCardPick(opts) then
        task.wait(0.3)
        pcall(function() ev:FireServer("Pick", idx) end)
    end
    return true
end

local function skipCards()
    local ev = getONet("CardPickEvent")
    if not ev then return end
    pcall(function() ev:FireServer("Skip", 0) end)
end


local RARITY_SCORE = {
    common=1, uncommon=2, rare=3, epic=4, legendary=5,
    mythic=6, mythical=6, secret=7, celestial=8, divine=9
}

-- All confirmed basic card names (from OdysseyCardIcons module, UPD 12.5)
-- If a card name is in this set it's a BASIC card → single CardPickEvent("Pick", idx)
-- If it's NOT in this set it's a CHARACTER card → double-fire to confirm
local BASIC_CARDS = {
    ["Adrenaline Shot"]=true, ["Serrated Tips"]=true, ["Boxing Gloves"]=true,
    ["Precision Optics"]=true, ["Ambush"]=true, ["Essence Collector"]=true,
    ["Concussive Blast"]=true, ["Slayer Rounds"]=true, ["Military Training"]=true,
    ["Painful Gains"]=true, ["Volatile Demise"]=true, ["Infection"]=true,
    ["Base Shield"]=true, ["Battle Frenzy"]=true, ["Treasure Map Fragment"]=true,
    ["Quick Charge"]=true, ["Potent Toxins"]=true, ["Numbing Agent"]=true,
    ["Extended Duration"]=true, ["The Best Defense\226\128\166"]=true,
    ["The Best Defense..."]=true, -- display alias (ellipsis may render differently)
    ["Resource Overflow"]=true, ["Delicate Flower"]=true, ["Affinity"]=true,
    ["Double Tap"]=true, ["Unstoppable Force"]=true, ["Spoils of War"]=true,
    ["Limit Break"]=true, ["Golden Age"]=true, ["Crippling Field"]=true,
    ["Luckcatcher"]=true,
}

local function isBasicCard(name)
    return BASIC_CARDS[name] == true
end
local RAGNAW_TARGET_CARDS = {
    ["rageful arrival"]        = true, ["legendaryplacementdamage"]  = true,
    ["elite conquest"]         = true, ["legendaryeliteplacement"]   = true,
    ["all-range rage"]         = true, ["all range rage"]            = true, ["mythicfullaoe"] = true,
    ["monarch's breakthrough"] = true, ["monarchs breakthrough"]     = true,
    ["monarch breakthrough"]   = true, ["epicpermanentplacements"]   = true,
}
local function rarityScore(name)
    local n = (name or ""):lower()
    local best = 0
    for key, score in pairs(RARITY_SCORE) do
        if n:find(key, 1, true) and score > best then best = score end
    end
    return best
end
local function isRagnawTargetCard(name)
    return RAGNAW_TARGET_CARDS[(name or ""):lower():gsub("^%s+",""):gsub("%s+$","")] == true
end
local function chooseCardIndex(opts)
    local bestIdx, bestScore
    if getAutoRagnawCards() and ragnawPickCount < 4 then
        for i, name in ipairs(opts) do
            if isRagnawTargetCard(name) and not ragnawPickedThisRun[name] then
                local score = 100 + rarityScore(name)
                if not bestScore or score > bestScore then bestIdx, bestScore = i, score end
            end
        end
        if bestIdx then return bestIdx, "ragnaw" end
    end
    if getAutoRagnawCards() then
        local allUnit = #opts > 0
        for _, name in ipairs(opts) do
            if classifyCard(name) ~= "unit" then allUnit = false; break end
        end
        if allUnit then return nil, "skip-unit" end
    end
    if getAutoPick() then
        for i, name in ipairs(opts) do
            local score = rarityScore(name)
            if classifyCard(name) == "generic" then score = score + 20 end
            if not bestScore or score > bestScore then bestIdx, bestScore = i, score end
        end
    end
    return bestIdx, "basic"
end

-- ── Card UI detection ───────────────────────────────────────────
-- CONFIRMED from logger: card names are in TextLabels with Name="ModifierTitle"
-- inside a parent Frame named "Main". Cards appear left-to-right = index 1,2,3.
-- Basic card UI:     title "Choose a basic card",     buttons: Reroll, Skip
-- Character card UI: title "Choose a character-specific card", buttons: Confirm Choice, Skip
-- Both use CardPickEvent:FireServer("Pick", index) and ("Skip", 0)


-- ── AdventureHUD helper ──────────────────────────────────────────
-- CONFIRMED: all panels live inside PlayerGui.AdventureHUD
-- AdventureHUD children:
--   ChooseCard              — card pick panel
--   Stiches' Shop_Export    — shop panel (note: Stiches, one t)
--   TreasurePanel           — treasure room panel
--   RunRewardsPanelRoot     — unit reward after elite room ("CLAIM YOUR REWARDS")
--   AdventureMapRoot        — map/vote UI

local function getAdventureHUD()
    return playerGui:FindFirstChild("AdventureHUD")
end

local function getPanelVisible(panelName)
    local hud = getAdventureHUD()
    if not hud then return false end
    local panel = hud:FindFirstChild(panelName)
    if not panel then return false end
    -- Panel is active if it exists and is not explicitly invisible
    return panel.Visible ~= false
end

-- ── Card pick ────────────────────────────────────────────────────
-- CONFIRMED: cards are in AdventureHUD.ChooseCard
-- ModifierTitle TextLabels sorted left-to-right = index 1,2,3
local function readOpenCardOptions()
    local hud = getAdventureHUD()
    if not hud then return nil end
    local chooseCard = hud:FindFirstChild("ChooseCard")
    if not chooseCard or chooseCard.Visible == false then return nil end

    local cards = {}
    local hasSkip, hasReroll, hasConfirm = false, false, false
    for _, d in ipairs(chooseCard:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "ModifierTitle" and d.Text and #d.Text > 1 then
            table.insert(cards, {text = d.Text, x = d.AbsolutePosition.X})
        end
        if d:IsA("TextButton") and d.Text then
            local tl = d.Text:lower()
            if tl == "skip"       then hasSkip    = true end
            if tl:find("reroll")  then hasReroll  = true end
            if tl:find("confirm") then hasConfirm = true end
        end
    end
    if #cards == 0 then return nil end
    if not hasSkip then return nil end
    table.sort(cards, function(a, b) return a.x < b.x end)
    local opts = {}
    for _, c in ipairs(cards) do table.insert(opts, c.text) end
    return opts
end

-- ── Shop ─────────────────────────────────────────────────────────
-- CONFIRMED: AdventureHUD["Stiches' Shop_Export"]
local function isShopOpen()
    return getPanelVisible("Stiches' Shop_Export")
end

local function closeShopGui()
    refreshRemotes()
    local shopEv = getONet("ShopEvent")
    if shopEv then pcall(function() shopEv:FireServer("Close") end) end
end

-- ── Treasure ─────────────────────────────────────────────────────
-- CONFIRMED: AdventureHUD.TreasurePanel
-- TreasureEvent:FireServer("OpenChest", index) — indices 1-12
local function isTreasureOpen()
    return getPanelVisible("TreasurePanel")
end

local openedChests = {}
local function collectAndCloseTreasure()
    refreshRemotes()
    local treasureEv = getONet("TreasureEvent")
    if treasureEv then
        for i = 1, 12 do
            if not openedChests[i] then
                openedChests[i] = true
                pcall(function() treasureEv:FireServer("OpenChest", i) end)
                task.wait(0.08)
            end
        end
    end
    -- Click Close button inside TreasurePanel
    local hud = getAdventureHUD()
    if hud then
        local panel = hud:FindFirstChild("TreasurePanel")
        if panel then
            local closeBtn = panel:FindFirstChild("Close", true)
            if closeBtn then
                pcall(function() closeBtn.Activated:Fire() end)
                pcall(function() closeBtn.MouseButton1Click:Fire() end)
            end
        end
    end
end

-- ── Unit Reward ───────────────────────────────────────────────────
-- CONFIRMED: AdventureHUD.RunRewardsPanelRoot — "CLAIM YOUR REWARDS"
-- UnitRewardEvent:FireServer("Skip") to skip
local function isUnitRewardOpen()
    return getPanelVisible("RunRewardsPanelRoot")
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

-- ── Master automation loop ────────────────────────────────────────
-- Single Heartbeat poll. Checks AdventureHUD panel visibility directly.
do
    local clocks = {card=0, shop=0, treasure=0, room=0, unit=0}
    local shopDone, treasureDone, unitDone = false, false, false

    RunSvc.Heartbeat:Connect(function()
        local now = os.clock()
        if not inGameMode() then
            shopDone = false; treasureDone = false; unitDone = false
            return
        end

        -- Unit Reward (check every 0.5s)
        if getSkipUnitReward() and now - clocks.unit >= 0.5 then
            clocks.unit = now
            if isUnitRewardOpen() then
                if not unitDone then
                    unitDone = true
                    task.spawn(skipUnitRewardPanel)
                end
            else
                unitDone = false
            end
        end

        -- Card pick (check every 0.5s)
        if (getAutoPick() or getAutoRagnawCards()) and now - clocks.card >= 0.5 then
            clocks.card = now
            local opts = readOpenCardOptions()
            if opts and #opts > 0 then
                local chosenIdx, reason = chooseCardIndex(opts)
                if chosenIdx then
                    pickIndex(opts, chosenIdx)
                    if reason == "ragnaw" then
                        ragnawPickedThisRun[opts[chosenIdx]] = true
                        ragnawPickCount = math.min(4, ragnawPickCount + 1)
                    end
                elseif reason == "skip-unit" then
                    skipCards()
                end
                clocks.room = now + 2
                return
            end
        end

        -- Shop (check every 1s, fire once per appearance)
        if getAutoSkipShop() and now - clocks.shop >= 1 then
            clocks.shop = now
            if isShopOpen() then
                if not shopDone then
                    shopDone = true
                    task.spawn(function()
                        closeShopGui()
                        if getAutoNextRoom() then task.wait(0.5); requestNextRoom() end
                    end)
                end
            else
                shopDone = false
            end
        end

        -- Treasure (check every 1s, fire once per appearance)
        if getAutoCollectChests() and now - clocks.treasure >= 1 then
            clocks.treasure = now
            if isTreasureOpen() then
                if not treasureDone then
                    treasureDone = true
                    openedChests = {}
                    task.spawn(function()
                        collectAndCloseTreasure()
                        if getAutoNextRoom() then task.wait(1); requestNextRoom() end
                    end)
                end
            else
                treasureDone = false
            end
        end

        -- Auto Next Room (check every 2s)
        if getAutoNextRoom() and now - clocks.room >= 2 then
            clocks.room = now
            task.spawn(requestNextRoom)
        end
    end)
end
end -- close Odyssey do block

-- ======================
-- BOOT
-- ======================
switchTab("Lobby")
notify("OzWare V3 loaded", true)


-- ======================
-- FLOATING TOGGLE (bottom-left)  +  SUMMON UI SUPPRESSOR
-- ======================
do
local floatBtn = Instance.new("TextButton")
floatBtn.Name = "OzFloat"
floatBtn.Size = UDim2.new(0, 52, 0, 52)
floatBtn.Position = UDim2.new(0, 16, 1, -68)
floatBtn.AnchorPoint = Vector2.new(0,0)
floatBtn.BackgroundColor3 = C.PANEL
floatBtn.Text = "Oz"
floatBtn.TextColor3 = C.ACCENT
floatBtn.TextSize = 20
floatBtn.Font = FONT_BOLD
floatBtn.BorderSizePixel = 0
floatBtn.AutoButtonColor = false
floatBtn.ZIndex = 50
floatBtn.Parent = gui
corner(floatBtn, 26)
stroke(floatBtn, C.ACCENT, 2)
gradient(floatBtn, C.ACCENT, C.ACCENT2, 135)

-- Drag support for floating button
do
    local dragging, startPos, startInput
    floatBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; startPos=floatBtn.Position; startInput=i.Position
        end
    end)
    floatBtn.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d = i.Position - startInput
            floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end

-- Tap (no drag) toggles window
local pressStart, pressPos
floatBtn.MouseButton1Down:Connect(function() pressStart = tick(); pressPos = floatBtn.Position end)
floatBtn.MouseButton1Click:Connect(function()
    if pressStart and (tick()-pressStart) < 0.4 and pressPos and pressPos == floatBtn.Position then
        win.Visible = not win.Visible
    elseif not pressStart then
        win.Visible = not win.Visible
    else
        -- treat as tap if barely moved
        win.Visible = not win.Visible
    end
end)

-- ======================
-- Safety note
-- ======================
-- Do not destroy game ScreenGuis and do not monkey-patch SummonAnimationHandler.
-- Both approaches can leave WindowHandler / game button state stuck, which is
-- what made summon buttons and mode-join buttons stop responding.
end
