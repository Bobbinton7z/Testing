-- ======================
-- |        OzWare       |
-- | Neon dashboard UI   |
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
local function UnitEvent()   return Net:FindFirstChild("UnitEvent") end
local function LobbyEvent()  return Net:FindFirstChild("LobbyEvent") end
local function SummonEvent() local u = Net:FindFirstChild("Units")    return u and u:FindFirstChild("SummonEvent") end
local function OdysseyNet()  local o = Net:FindFirstChild("Odyssey")  return o and o:FindFirstChild("Adventure") end
local function AbilityEvent()return Net:FindFirstChild("AbilityEvent") end
local function SkipWaveEvent()return Net:FindFirstChild("SkipWaveEvent") end

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
win.BackgroundColor3=C.BG; win.BorderSizePixel=0; win.ClipsDescendants=true; win.Parent=gui
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
titleLbl.BackgroundTransparency=1; titleLbl.Text="OzWare"
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
label(sumSec, "Loops max-pull (50). Game uses available currency.", 1)

-- Resolve a remote by a "/" path under ReplicatedStorage, logging each hop
local function resolveRemote(path)
    local node = RS
    for part in string.gmatch(path, "[^/]+") do
        if not node then return nil, "nil before "..part end
        local nxt = node:FindFirstChild(part)
        if not nxt then return nil, "missing: "..part.." under "..node:GetFullName() end
        node = nxt
    end
    return node
end

local function fireBanner(name, path, args)
    local remote, err = resolveRemote(path)
    if not remote then
        warn(("[OzWare][%s] remote not found (%s) | tried: %s"):format(name, err or "?", path))
        return false
    end
    if not remote:IsA("RemoteEvent") and not remote:IsA("RemoteFunction") then
        warn(("[OzWare][%s] resolved to %s, not a Remote (%s)"):format(name, remote.ClassName, remote:GetFullName()))
        return false
    end
    local ok, e = pcall(function()
        print(("[OzWare][%s] FireServer %s args=%s"):format(name, remote:GetFullName(), table.concat({tostring(args[1]),tostring(args[2]),tostring(args[3])}, ",")))
        remote:FireServer(table.unpack(args))
    end)
    if not ok then
        warn(("[OzWare][%s] FireServer ERROR: %s"):format(name, tostring(e)))
    end
    return ok
end

local BANNERS = {
    { name="Selection Banner",  call=function() return fireBanner("Selection Banner", "Networking/Units/SummonEvent", {"SummonMany", "Selection", 50}) end },
    { name="Special Banner",    call=function() return fireBanner("Special Banner",   "Networking/Units/SummonEvent", {"SummonMany", "Special", 50}) end },
    { name="Standard Memoria",  call=function() return fireBanner("Standard Memoria", "Networking/Units/SummonEvent", {"SummonMany", "StandardMemoria", 50}) end },
    { name="Spring Banner",     call=function() return fireBanner("Spring Banner",    "Networking/Units/SummonEvent", {"SummonMany", "Spring26", 50}) end },
    { name="Spring Memoria",    call=function() return fireBanner("Spring Memoria",   "Networking/Units/SummonEvent", {"SummonMany", "Spring26Memoria", 50}) end },
}

for i,b in ipairs(BANNERS) do
    local _, getOn = toggle(sumSec, "Auto: "..b.name, i+1, false)
    task.spawn(function()
        while true do
            if getOn() then
                b.call()
            end
            task.wait(0.6)
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
-- Looper
task.spawn(function()
    while true do
        for i,c in ipairs(CLAIMERS) do
            if loopGetters[i] and loopGetters[i]() then
                pcall(c.fn)
            end
            task.wait(0.1)
        end
        task.wait(3)
    end
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
        local LE = LobbyEvent()
        LE:FireServer("AddMatch", {
            Difficulty  = getNightmare() and "Nightmare" or "Normal",
            Act         = selAct,
            StageType   = selType,
            Stage       = selStage,
            FriendsOnly = getFriendsOnly(),
        })
        if getAutoStart() then
            task.wait(0.5)
            -- try common start signatures so you actually enter the stage
            pcall(function() LE:FireServer("StartMatch") end)
            pcall(function() LE:FireServer("PlayMatch") end)
            pcall(function() LE:FireServer("Start") end)
            local sm = Net:FindFirstChild("StartMatch", true) or Net:FindFirstChild("PlayMatch", true)
            if sm then pcall(function() sm:FireServer() end) end
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
local skipBtn = btn(matchSec, "Skip Wave", C.ACCENT, 1)
skipBtn.MouseButton1Click:Connect(function()
    safeCall(function() Net.SkipWaveEvent:FireServer("Skip") end, "Wave skipped", "Skip failed")
end)
local statusBtn = btn(matchSec, "Update Match Status", Color3.fromRGB(60,100,200), 2)
statusBtn.MouseButton1Click:Connect(function()
    safeCall(function() Net.MatchStatusEvent:FireServer("UpdateStatus", 2) end, "Status updated", "Status failed")
end)

local _, getAutoSkipWave = toggle(matchSec, "Auto Skip Wave (loop)", 3, false)
task.spawn(function()
    while true do
        task.wait(1.5)
        if getAutoSkipWave() then
            local r = SkipWaveEvent()
            if r then pcall(function() r:FireServer("Skip") end) end
        end
    end
end)

local unitSec = section(gamePage, "Unit Controls", 2)
label(unitSec, "Unit UUID", 1)
local uuidBox = input(unitSec, "Paste unit UUID here", 2)
local upgradeBtn = btn(unitSec, "Upgrade", C.ACCENT, 3)
upgradeBtn.MouseButton1Click:Connect(function()
    local uuid=uuidBox.Text; if uuid=="" then return notify("Enter a UUID first", false) end
    safeCall(function() UnitEvent():FireServer("Upgrade", uuid) end, "Unit upgraded", "Upgrade failed")
end)
label(unitSec, "Target Upgrade Level", 4)
local levelBox = input(unitSec, "e.g. 12", 5)
local upgradeMultiBtn = btn(unitSec, "Upgrade Multiple", Color3.fromRGB(80,60,220), 6)
upgradeMultiBtn.MouseButton1Click:Connect(function()
    local uuid=uuidBox.Text; local lv=tonumber(levelBox.Text)
    if uuid=="" or not lv then return notify("Enter UUID and level", false) end
    safeCall(function() UnitEvent():FireServer("UpgradeMultiple", uuid, lv) end, "Upgraded to "..lv, "Upgrade failed")
end)
local sellBtn = btn(unitSec, "Sell Unit", C.RED, 7)
sellBtn.MouseButton1Click:Connect(function()
    local uuid=uuidBox.Text; if uuid=="" then return notify("Enter a UUID first", false) end
    safeCall(function() UnitEvent():FireServer("Sell", uuid) end, "Unit sold", "Sell failed")
end)

local priSec = section(gamePage, "Unit Priority", 3)
label(priSec, "Uses UUID from above", 1)
for i,p in ipairs({"First","Last","Closest","Strongest","Weakest","Bosses"}) do
    local b=btn(priSec, p, Color3.fromRGB(45,45,80), i+1)
    b.MouseButton1Click:Connect(function()
        local uuid=uuidBox.Text; if uuid=="" then return notify("Enter a UUID first", false) end
        safeCall(function() UnitEvent():FireServer("ChangePriority", uuid, p) end, "Priority "..p, "Priority failed")
    end)
end

-- ======================
-- AUTO ABILITIES (per-unit, fires on cooldown)
-- ======================
local autoAbilities = {}  -- [key] = { args, cooldown, enabled, label }
local abilitySec = section(gamePage, "Auto Abilities", 4)
label(abilitySec, "Use an ability once - it gets captured below.", 1)

local cdBox = input(abilitySec, "Cooldown seconds for new entries (e.g. 10)", 2)
cdBox.Text = "10"

local abilityScroll = Instance.new("ScrollingFrame")
abilityScroll.Size=UDim2.new(1,0,0,140); abilityScroll.BackgroundColor3=C.BG
abilityScroll.BorderSizePixel=0; abilityScroll.ScrollBarThickness=4
abilityScroll.ScrollBarImageColor3=C.ACCENT
abilityScroll.CanvasSize=UDim2.new(0,0,0,0)
abilityScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
abilityScroll.LayoutOrder=3; abilityScroll.Parent=abilitySec
corner(abilityScroll,7); stroke(abilityScroll,C.BORDER,1)
listLayout(abilityScroll,nil,4); padding(abilityScroll,nil,6,6,6,6)

local function abilityKey(args)
    -- key by string-ified args so the same ability collapses to one row
    local parts = {}
    for i,a in ipairs(args) do
        local t = typeof(a)
        if t=="string" or t=="number" or t=="boolean" then
            parts[i] = tostring(a)
        else
            parts[i] = t
        end
    end
    return table.concat(parts, "|")
end

local abilityRows = {}
local function rebuildAbilityList()
    for _,c in ipairs(abilityScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    abilityRows = {}
    for key,entry in pairs(autoAbilities) do
        local row = Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=C.PANEL
        row.BorderSizePixel=0; row.Parent=abilityScroll
        corner(row,6)
        local lb=Instance.new("TextLabel")
        lb.Size=UDim2.new(1,-140,1,0); lb.Position=UDim2.new(0,8,0,0)
        lb.BackgroundTransparency=1; lb.Text=entry.label
        lb.TextColor3=C.TEXT; lb.TextSize=11; lb.Font=FONT_REG
        lb.TextXAlignment=Enum.TextXAlignment.Left
        lb.TextTruncate=Enum.TextTruncate.AtEnd; lb.Parent=row
        local cd=Instance.new("TextBox")
        cd.Size=UDim2.new(0,38,0,22); cd.Position=UDim2.new(1,-130,0.5,-11)
        cd.BackgroundColor3=C.BG; cd.Text=tostring(entry.cooldown)
        cd.TextColor3=C.TEXT; cd.TextSize=11; cd.Font=FONT_REG
        cd.BorderSizePixel=0; cd.Parent=row; corner(cd,4); stroke(cd,C.BORDER,1)
        cd.FocusLost:Connect(function()
            local n = tonumber(cd.Text); if n and n>0 then entry.cooldown=n else cd.Text=tostring(entry.cooldown) end
        end)
        local tg=Instance.new("TextButton")
        tg.Size=UDim2.new(0,46,0,22); tg.Position=UDim2.new(1,-86,0.5,-11)
        tg.BackgroundColor3 = entry.enabled and C.GREEN or C.DISABLED
        tg.Text = entry.enabled and "ON" or "OFF"
        tg.TextColor3=C.TEXT; tg.TextSize=11; tg.Font=FONT_BOLD; tg.BorderSizePixel=0; tg.Parent=row
        corner(tg,4)
        tg.MouseButton1Click:Connect(function()
            entry.enabled = not entry.enabled
            tg.BackgroundColor3 = entry.enabled and C.GREEN or C.DISABLED
            tg.Text = entry.enabled and "ON" or "OFF"
        end)
        local del=Instance.new("TextButton")
        del.Size=UDim2.new(0,34,0,22); del.Position=UDim2.new(1,-38,0.5,-11)
        del.BackgroundColor3=C.RED; del.Text="X"; del.TextColor3=C.TEXT
        del.TextSize=12; del.Font=FONT_BOLD; del.BorderSizePixel=0; del.Parent=row
        corner(del,4)
        del.MouseButton1Click:Connect(function()
            autoAbilities[key]=nil; rebuildAbilityList()
        end)
        abilityRows[key]=row
    end
end

local clrBtn = btn(abilitySec, "Clear Captured Abilities", Color3.fromRGB(120,120,140), 4)
clrBtn.MouseButton1Click:Connect(function() autoAbilities={}; rebuildAbilityList() end)

-- Hook ability fires to capture entries
local hookOK2 = (typeof(hookmetamethod)=="function") and (typeof(getnamecallmethod)=="function")
if hookOK2 then
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if m == "FireServer" and self == AbilityEvent() then
            local args = {...}
            local key = abilityKey(args)
            if not autoAbilities[key] then
                local cdN = tonumber(cdBox.Text) or 10
                local lbl = "Ability"
                if args[1] then lbl = tostring(args[1]) end
                if args[2] then lbl = lbl.."  "..tostring(args[2]):sub(1,18) end
                autoAbilities[key] = { args=args, cooldown=cdN, enabled=false, label=lbl, lastFire=0 }
                task.defer(rebuildAbilityList)
            else
                autoAbilities[key].lastFire = os.clock()
            end
        end
        return oldNC(self, ...)
    end)
end

-- Auto-ability loop
task.spawn(function()
    while true do
        task.wait(0.5)
        local ae = AbilityEvent()
        if ae then
            for _,entry in pairs(autoAbilities) do
                if entry.enabled and (os.clock() - entry.lastFire) >= entry.cooldown then
                    pcall(function() ae:FireServer(table.unpack(entry.args)) end)
                    entry.lastFire = os.clock()
                end
            end
        end
    end
end)

-- ======================
-- UTILITY  (delete map / enemies, boost fps)
-- ======================
local utilSec = section(gamePage, "Utility", 5)

local savedMapParts = nil
local function getMapRoot()
    return workspace:FindFirstChild("Map")
        or workspace:FindFirstChild("MapHolder")
        or workspace:FindFirstChild("Maps")
        or workspace:FindFirstChild("Stage")
end

local _, getDeleteMap = toggle(utilSec, "Delete Map (hide terrain)", 1, false)
task.spawn(function()
    while true do
        task.wait(2)
        if getDeleteMap() then
            local m = getMapRoot()
            if m then
                for _,d in ipairs(m:GetDescendants()) do
                    if d:IsA("BasePart") and d.Transparency < 1 then
                        d.Transparency = 1
                        if d.CanCollide then d.CanCollide = true end -- keep walkable
                    elseif d:IsA("Decal") or d:IsA("Texture") then
                        d.Transparency = 1
                    end
                end
            end
        end
    end
end)

local _, getDeleteEnemies = toggle(utilSec, "Delete Enemies (loop)", 2, false)
task.spawn(function()
    while true do
        task.wait(0.5)
        if getDeleteEnemies() then
            for _,folder in ipairs({"Enemies","Mobs","EnemiesFolder","Zombies"}) do
                local f = workspace:FindFirstChild(folder)
                if f then
                    for _,e in ipairs(f:GetChildren()) do
                        pcall(function() e:Destroy() end)
                    end
                end
            end
        end
    end
end)

local fpsApplied = false
local oldGfx = {}
local _, getBoostFPS = toggle(utilSec, "Boost FPS (low graphics)", 3, false)
task.spawn(function()
    local Lighting = game:GetService("Lighting")
    local Terrain  = workspace:FindFirstChildOfClass("Terrain")
    while true do
        task.wait(1)
        if getBoostFPS() and not fpsApplied then
            fpsApplied = true
            pcall(function()
                oldGfx.GlobalShadows = Lighting.GlobalShadows
                oldGfx.FogEnd = Lighting.FogEnd
                oldGfx.Brightness = Lighting.Brightness
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 1e9
                for _,e in ipairs(Lighting:GetDescendants()) do
                    if e:IsA("BloomEffect") or e:IsA("BlurEffect")
                       or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect")
                       or e:IsA("ColorCorrectionEffect") then
                        e.Enabled = false
                    end
                end
                if Terrain then
                    Terrain.WaterWaveSize = 0
                    Terrain.WaterWaveSpeed = 0
                    Terrain.WaterReflectance = 0
                    Terrain.WaterTransparency = 1
                end
                settings().Rendering.QualityLevel = 1
            end)
            -- strip particles/trails from existing instances
            for _,d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Trail")
                   or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                    d.Enabled = false
                end
            end
            notify("FPS Boost ON", true)
        elseif (not getBoostFPS()) and fpsApplied then
            fpsApplied = false
            pcall(function()
                if oldGfx.GlobalShadows ~= nil then Lighting.GlobalShadows = oldGfx.GlobalShadows end
                if oldGfx.FogEnd then Lighting.FogEnd = oldGfx.FogEnd end
                if oldGfx.Brightness then Lighting.Brightness = oldGfx.Brightness end
            end)
            notify("FPS Boost OFF", true)
        end
    end
end)

-- ======================
-- MACROS  (record/play unit + ability actions)
-- ======================
local macros = {}          -- [name] = { events = {{t, remoteName, args}}, duration }
local selectedMacro = nil
local recording = false
local playing = false
local recStart = 0
local recBuffer = nil

local macroSec = section(gamePage, "Macros", 4)
label(macroSec, "Records Unit placements + Abilities. Press Play when wave 1 starts.", 1)

local nameBox = input(macroSec, "Macro name...", 2)
local createBtn = btn(macroSec, "Create Macro", Color3.fromRGB(70,70,140), 3)

local selLblM = Instance.new("TextLabel")
selLblM.Size=UDim2.new(1,0,0,18); selLblM.BackgroundTransparency=1
selLblM.Text="Selected: (none)"; selLblM.TextColor3=C.SUBTEXT
selLblM.TextSize=12; selLblM.Font=FONT_SEMI
selLblM.TextXAlignment=Enum.TextXAlignment.Left
selLblM.LayoutOrder=4; selLblM.Parent=macroSec

local macroScroll = Instance.new("ScrollingFrame")
macroScroll.Size=UDim2.new(1,0,0,140); macroScroll.BackgroundColor3=C.BG
macroScroll.BorderSizePixel=0; macroScroll.ScrollBarThickness=4
macroScroll.ScrollBarImageColor3=C.ACCENT
macroScroll.CanvasSize=UDim2.new(0,0,0,0)
macroScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
macroScroll.ScrollingDirection=Enum.ScrollingDirection.Y
macroScroll.LayoutOrder=5; macroScroll.Parent=macroSec
corner(macroScroll,7); stroke(macroScroll,C.BORDER,1)
listLayout(macroScroll,nil,4); padding(macroScroll,nil,6,6,6,6)

local macroRows = {}
local function updateMacroSel()
    local n = selectedMacro
    if n and macros[n] then
        selLblM.Text = ("Selected: %s (%d events)"):format(n, #macros[n].events)
        selLblM.TextColor3 = C.ACCENT
    else
        selLblM.Text = "Selected: (none)"; selLblM.TextColor3 = C.SUBTEXT
    end
    for k,row in pairs(macroRows) do
        local active = (k == selectedMacro)
        row.BackgroundColor3 = active and C.ACCENT or C.PANEL
        if row:FindFirstChild("Lbl") then
            row.Lbl.TextColor3 = active and Color3.fromRGB(20,24,40) or C.TEXT
        end
    end
end

local function rebuildMacroList()
    for _,c in ipairs(macroScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    macroRows = {}
    local names = {}
    for k,_ in pairs(macros) do table.insert(names,k) end
    table.sort(names)
    for i,name in ipairs(names) do
        local row = Instance.new("TextButton")
        row.Size=UDim2.new(1,0,0,28); row.BackgroundColor3=C.PANEL
        row.AutoButtonColor=false; row.Text=""; row.BorderSizePixel=0
        row.LayoutOrder=i; row.Parent=macroScroll
        corner(row,6)
        local lb = Instance.new("TextLabel"); lb.Name="Lbl"
        lb.Size=UDim2.new(1,-70,1,0); lb.Position=UDim2.new(0,10,0,0)
        lb.BackgroundTransparency=1
        lb.Text=("%s  -  %d ev"):format(name, #macros[name].events)
        lb.TextColor3=C.TEXT; lb.TextSize=12; lb.Font=FONT_SEMI
        lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=row
        local del = Instance.new("TextButton")
        del.Size=UDim2.new(0,54,0,20); del.Position=UDim2.new(1,-60,0.5,-10)
        del.BackgroundColor3=C.RED; del.Text="Delete"; del.TextColor3=C.TEXT
        del.TextSize=11; del.Font=FONT_BOLD; del.BorderSizePixel=0; del.Parent=row
        corner(del,5)
        del.MouseButton1Click:Connect(function()
            macros[name]=nil
            if selectedMacro==name then selectedMacro=nil end
            rebuildMacroList(); updateMacroSel()
        end)
        macroRows[name]=row
        row.MouseButton1Click:Connect(function()
            selectedMacro = (selectedMacro==name) and nil or name
            updateMacroSel()
        end)
    end
    updateMacroSel()
end

createBtn.MouseButton1Click:Connect(function()
    local n = nameBox.Text
    if not n or n=="" then return notify("Type a macro name first", false) end
    if macros[n] then return notify("Macro already exists", false) end
    macros[n] = { events = {}, duration = 0 }
    nameBox.Text = ""
    selectedMacro = n
    rebuildMacroList()
    notify("Macro created: "..n, true)
end)

-- __namecall hook (executor required)
local hookOK = (typeof(hookmetamethod)=="function") and (typeof(getnamecallmethod)=="function")
if hookOK then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if recording and m == "FireServer" and selectedMacro and macros[selectedMacro] then
            local ue, ae = UnitEvent(), AbilityEvent()
            if self == ue or self == ae then
                local args = {...}
                table.insert(macros[selectedMacro].events, {
                    t = os.clock() - recStart,
                    remote = (self == ue) and "Unit" or "Ability",
                    args = args,
                })
            end
        end
        return oldNamecall(self, ...)
    end)
end

local recBtn  = btn(macroSec, "Start Recording", Color3.fromRGB(220,90,90), 6)
local playBtn = btn(macroSec, "Play Macro",      C.GREEN, 7)
local stopBtn = btn(macroSec, "Stop Playback",   Color3.fromRGB(120,120,140), 8)

recBtn.MouseButton1Click:Connect(function()
    if not hookOK then return notify("Executor lacks hookmetamethod", false) end
    if not selectedMacro then return notify("Select or create a macro first", false) end
    if recording then
        recording = false
        recBtn.Text = "Start Recording"
        recBtn.BackgroundColor3 = Color3.fromRGB(220,90,90)
        local mac = macros[selectedMacro]
        if mac then mac.duration = os.clock() - recStart end
        notify(("Recorded %d events"):format(mac and #mac.events or 0), true)
        rebuildMacroList()
    else
        macros[selectedMacro].events = {}
        recStart = os.clock()
        recording = true
        recBtn.Text = "Stop Recording"
        recBtn.BackgroundColor3 = C.YELLOW
        notify("Recording macro: "..selectedMacro, true)
    end
end)

playBtn.MouseButton1Click:Connect(function()
    if not selectedMacro or not macros[selectedMacro] then return notify("Select a macro", false) end
    if playing then return notify("Already playing", false) end
    local mac = macros[selectedMacro]
    if #mac.events == 0 then return notify("Macro is empty", false) end
    playing = true
    notify("Playing macro: "..selectedMacro, true)
    task.spawn(function()
        local t0 = os.clock()
        for _,ev in ipairs(mac.events) do
            if not playing then break end
            local delay = ev.t - (os.clock() - t0)
            if delay > 0 then task.wait(delay) end
            if not playing then break end
            local remote = (ev.remote == "Unit") and UnitEvent() or AbilityEvent()
            if remote then pcall(function() remote:FireServer(table.unpack(ev.args)) end) end
        end
        playing = false
        notify("Macro playback done", true)
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    if recording then
        recording = false
        recBtn.Text = "Start Recording"
        recBtn.BackgroundColor3 = Color3.fromRGB(220,90,90)
        local mac = macros[selectedMacro]
        if mac then mac.duration = os.clock() - recStart end
        rebuildMacroList()
    end
    if playing then playing = false; notify("Playback stopped", true) end
end)

rebuildMacroList()
end

-- ======================
-- ODYSSEY TAB  (dynamic, no UUIDs)
-- ======================
do
local odysseyPage = tabPages["Odyssey"]
local function getONet(name) return OdysseyNet() and OdysseyNet():FindFirstChild(name) end

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

-- Heuristic: any card whose name contains a unit name OR has UnitName attribute = unit-specific
local function classifyCard(name, obj)
    local n = (name or ""):lower()
    if obj and obj:GetAttribute("UnitName") then return "unit" end
    -- typical unit-specific keywords (game-tunable)
    for _,k in ipairs({"unit","goku","luffy","naruto","saitama","ichigo","gojo","sukuna","tanjiro","sasuke","vegeta"}) do
        if n:find(k, 1, true) then return "unit" end
    end
    return "generic"
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

-- Runtime scrape: watch PlayerGui for card-pick UIs and learn card names
-- Event-driven scrape: only scan a card-pick UI when it actually appears.
local function scrapeGui(g)
    local lname = g.Name:lower()
    if not (lname:find("card") or lname:find("odyssey")) then return end
    for _,d in ipairs(g:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text
            if t and #t>2 and #t<40 and not t:find("%d%d%d") then
                local parentName = d.Parent and d.Parent.Name or ""
                if parentName:lower():find("card") or d.Name:lower():find("card") or d.Name:lower():find("option") then
                    addCard(t, d)
                end
            end
        end
    end
end
playerGui.ChildAdded:Connect(function(g)
    task.wait(0.3) -- let it populate
    pcall(scrapeGui, g)
end)

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
local _, getAutoSkipShop       = toggle(autoSec, "Auto skip shop", 7, true, "odyssey.auto_skip_shop")
label(autoSec, "Will close shop UI; pair this with Auto Next Room", 8)
local _, getAutoCollectChests  = toggle(autoSec, "Auto Collect chest", 9, true, "odyssey.auto_collect_chest")
label(autoSec, "Will collect chests and close the treasure UI; pair this with Auto Next Room", 10)

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

local function pickIndex(cards, indexHint)
    local ev = getONet("CardPickEvent")
    if not ev then return false end
    pcall(function() ev:FireServer("Pick", indexHint or 1) end)
    return true
end

local function skipCards()
    local ev = getONet("CardPickEvent")
    if not ev then return end
    pcall(function() ev:FireServer("Skip", 0) end)
end

-- Find the current open card-pick UI and scrape option names
local function readOpenCardOptions()
    for _,g in ipairs(playerGui:GetChildren()) do
        local lname = g.Name:lower()
        if (lname:find("card") or lname:find("odyssey")) and g.Enabled ~= false then
            local opts = {}
            for _,d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local pn = (d.Parent and d.Parent.Name or ""):lower()
                    if pn:find("card") or d.Name:lower():find("card") or d.Name:lower():find("option") then
                        local t = d.Text
                        if t and #t>2 and #t<40 then
                            table.insert(opts, t)
                        end
                    end
                end
            end
            if #opts > 0 then return opts end
        end
    end
    return nil
end

local function closeMatchingUI(keywords)
    for _,g in ipairs(playerGui:GetChildren()) do
        local n = g.Name:lower()
        local hit = false
        for _,k in ipairs(keywords) do if n:find(k) then hit=true; break end end
        if hit then
            -- click any close button we can find
            for _,d in ipairs(g:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    local dn = d.Name:lower()
                    if dn:find("close") or dn:find("exit") or d.Text=="X" or d.Text=="x" then
                        pcall(function() firesignal(d.MouseButton1Click) end)
                        pcall(function() d.Visible = false end)
                    end
                end
            end
            pcall(function() g.Enabled = false end)
        end
    end
end

-- Find narrow chest containers ONCE; never full-workspace scan in the hot loop.
local CHEST_FOLDER_NAMES = {"Chests","OdysseyChests","Odyssey","AdventureChests","Adventure"}
local function getChestRoots()
    local roots = {}
    for _,name in ipairs(CHEST_FOLDER_NAMES) do
        local w = workspace:FindFirstChild(name)
        if w then table.insert(roots, w) end
        local r = RS:FindFirstChild(name)
        if r then table.insert(roots, r) end
    end
    return roots
end
local openedChests = {}
local UUID_PAT = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local function fireChest(chestRemote, uuid)
    if not uuid or openedChests[uuid] then return end
    if typeof(uuid) ~= "string" or not uuid:match(UUID_PAT) then return end
    openedChests[uuid] = true
    pcall(function() chestRemote:FireServer("OpenChest", uuid) end)
end

local RARITY_SCORE = {
    common=1, uncommon=2, rare=3, epic=4, legendary=5, mythic=6, mythical=6, secret=7, celestial=8, divine=9
}
-- Ragnaw (Regnaw / Rage) target cards. Match either DisplayName or CardId.
local RAGNAW_TARGET_CARDS = {
    ["rageful arrival"]         = true, ["legendaryplacementdamage"]   = true,
    ["elite conquest"]          = true, ["legendaryeliteplacement"]    = true,
    ["all-range rage"]          = true, ["all range rage"]             = true, ["mythicfullaoe"] = true,
    ["monarch's breakthrough"]  = true, ["monarchs breakthrough"]      = true,
    ["monarch breakthrough"]    = true, ["epicpermanentplacements"]    = true,
}

local function rarityScore(name)
    local n = (name or ""):lower()
    local best = 0
    for key,score in pairs(RARITY_SCORE) do
        if n:find(key, 1, true) and score > best then best = score end
    end
    return best
end

local function isRagnawTargetCard(name)
    local n = (name or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    return RAGNAW_TARGET_CARDS[n] == true
end

local function chooseCardIndex(opts)
    local bestIdx, bestScore

    if getAutoRagnawCards() and ragnawPickCount < 4 then
        for i,name in ipairs(opts) do
            if isRagnawTargetCard(name) and not ragnawPickedThisRun[name] then
                local score = 100 + rarityScore(name)
                if not bestScore or score > bestScore then
                    bestIdx, bestScore = i, score
                end
            end
        end
        if bestIdx then return bestIdx, "ragnaw" end
    end

    -- If Ragnaw mode active and quota filled (or no target card in this set),
    -- skip any unit-card screen so the run keeps moving.
    if getAutoRagnawCards() then
        local allUnit = #opts > 0
        for _,name in ipairs(opts) do
            if classifyCard(name) ~= "unit" then allUnit = false; break end
        end
        if allUnit then return nil, "skip-unit" end
    end

    if getAutoPick() then
        for i,name in ipairs(opts) do
            local kind = classifyCard(name)
            local score = rarityScore(name)
            if kind == "generic" then score = score + 20 end
            if not bestScore or score > bestScore then
                bestIdx, bestScore = i, score
            end
        end
    end

    return bestIdx, "basic"
end

local function requestNextRoom()
    local cardEv = getONet("CardPickEvent")
    if cardEv then pcall(function() cardEv:FireServer("Skip", 0) end) end

    local roomEv = getONet("RoomEvent") or getONet("MapEvent") or getONet("AdventureEvent")
    if roomEv then
        pcall(function() roomEv:FireServer("Next") end)
        pcall(function() roomEv:FireServer("NextRoom") end)
        pcall(function() roomEv:FireServer("Continue") end)
    end
end

-- Card pick loop: choose basic/highest-rarity cards, with optional Ragnaw unit-card priority.
task.spawn(function()
    while true do
        task.wait(1)
        if getAutoPick() or getAutoRagnawCards() or getAutoNextRoom() then
            local ok, opts = pcall(readOpenCardOptions)
            if ok and opts then
                local chosenIdx, reason = chooseCardIndex(opts)
                if chosenIdx then
                    pickIndex(opts, chosenIdx)
                    if reason == "ragnaw" then
                        local cardName = opts[chosenIdx]
                        ragnawPickedThisRun[cardName] = true
                        ragnawPickCount = math.min(4, ragnawPickCount + 1)
                    end
                elseif reason == "skip-unit" then
                    -- Ragnaw quota filled or no target card here: skip the unit-card screen.
                    local cardEv = getONet("CardPickEvent")
                    if cardEv then pcall(function() cardEv:FireServer("Skip", 0) end) end
                    if getAutoNextRoom() then requestNextRoom() end
                elseif getAutoNextRoom() then
                    requestNextRoom()
                end
            elseif getAutoNextRoom() then
                requestNextRoom()
            end
        end
    end
end)

-- Chest loop: narrow scan, slow tick (2s)
task.spawn(function()
    while true do
        task.wait(2)
        if getAutoCollectChests() then
            local sm = Net:FindFirstChild("StageMechanics")
            local chestRemote = sm and sm:FindFirstChild("OdysseyChest")
            if chestRemote then
                for _,root in ipairs(getChestRoots()) do
                    for _,inst in ipairs(root:GetChildren()) do
                        local n = inst.Name
                        fireChest(chestRemote, n)
                        fireChest(chestRemote, inst:GetAttribute("UUID"))
                        fireChest(chestRemote, inst:GetAttribute("Id"))
                        fireChest(chestRemote, inst:GetAttribute("ChestId"))
                    end
                end
            end
            closeMatchingUI({"treasure","chest"})
            if getAutoNextRoom() then requestNextRoom() end
        end
        if getAutoSkipShop() then
            local shopEv = getONet("ShopEvent")
            if shopEv then pcall(function() shopEv:FireServer("Close") end) end
            closeMatchingUI({"shop"})
            if getAutoNextRoom() then requestNextRoom() end
        end
    end
end)

-- UI close loop: event-driven, only touches matching new children
local function maybeCloseGui(g)
    if g == gui then return end
    local n = g.Name:lower()
    if getAutoCollectChests() and (n:find("treasure") or n:find("chest")) then
        pcall(function() g.Enabled = false end)
        if getAutoNextRoom() then requestNextRoom() end
        return
    end
    if getAutoSkipShop() and n:find("shop") then
        pcall(function() g.Enabled = false end)
        if getAutoNextRoom() then requestNextRoom() end
        return
    end
end
playerGui.ChildAdded:Connect(function(g) task.wait(0.1); pcall(maybeCloseGui, g) end)
end

-- ======================
-- BOOT
-- ======================
switchTab("Lobby")
notify("OzWare v2.0 loaded", true)
print("[OzWare v2] loaded.")


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

-- Suppress in-game Summon result UI (causes frame drops)
local SUMMON_UI_KEYWORDS = {"summon","banner","reward","pull","gacha"}
local suppressed = setmetatable({}, {__mode="k"})
local function suppressSummon(g)
    if g == gui or suppressed[g] then return end
    local n = g.Name:lower()
    for _,k in ipairs(SUMMON_UI_KEYWORDS) do
        if n:find(k) then
            suppressed[g] = true
            pcall(function() g.Enabled = false end)
            -- one-shot kill, no descendant walk in a loop
            pcall(function() g:Destroy() end)
            return
        end
    end
end
for _,g in ipairs(playerGui:GetChildren()) do suppressSummon(g) end
playerGui.ChildAdded:Connect(function(g) task.wait(0.05); pcall(suppressSummon, g) end)
end
