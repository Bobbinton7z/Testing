-- ╔══════════════════════════════════════════╗
-- ║         ODYSSEY SCRIPT  v1.0             ║
-- ║     Premium GUI — All Confirmed Remotes  ║
-- ╚══════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local TweenSvc   = game:GetService("TweenService")
local RunSvc     = game:GetService("RunService")

local player     = Players.LocalPlayer
local ok, _gui   = pcall(function() return gethui() end)
local playerGui  = ok and _gui or game:GetService("CoreGui")
local Net        = RS:WaitForChild("Networking")

-- ══════════════════════════════════════════
--  THEME
-- ══════════════════════════════════════════
local C = {
    BG       = Color3.fromRGB(8,  8,  16),
    PANEL    = Color3.fromRGB(14, 14, 26),
    CARD     = Color3.fromRGB(20, 20, 38),
    BORDER   = Color3.fromRGB(40, 40, 70),
    ACCENT   = Color3.fromRGB(110, 70, 255),
    ACCENT2  = Color3.fromRGB(60, 170, 255),
    GREEN    = Color3.fromRGB(50, 200, 110),
    RED      = Color3.fromRGB(220, 60, 80),
    YELLOW   = Color3.fromRGB(220, 170, 40),
    TEXT     = Color3.fromRGB(220, 220, 245),
    SUBTEXT  = Color3.fromRGB(120, 120, 160),
    DISABLED = Color3.fromRGB(50, 50, 70),
}

local FONT_BOLD   = Enum.Font.GothamBold
local FONT_SEMI   = Enum.Font.GothamSemibold
local FONT_REG    = Enum.Font.Gotham

-- ══════════════════════════════════════════
--  REMOTES
-- ══════════════════════════════════════════
local UnitEvent     = Net:WaitForChild("UnitEvent")
local LobbyEvent    = Net:WaitForChild("LobbyEvent")
local SummonEvent   = Net.Units:WaitForChild("SummonEvent")

local OdysseyNet    = Net:FindFirstChild("Odyssey") and Net.Odyssey:FindFirstChild("Adventure")

-- ══════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════
local function tween(obj, props, t)
    TweenSvc:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad), props):Play()
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function gradient(parent, c0, c1, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c0),
        ColorSequenceKeypoint.new(1, c1 or c0),
    })
    g.Rotation = rot or 90
    g.Parent = parent
    return g
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.BORDER
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, all, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or all or 0)
    p.PaddingBottom = UDim.new(0, b or all or 0)
    p.PaddingLeft   = UDim.new(0, l or all or 0)
    p.PaddingRight  = UDim.new(0, r or all or 0)
    p.Parent = parent
    return p
end

local function listLayout(parent, dir, pad, align)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 6)
    l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
    l.Parent = parent
    return l
end

local notifQueue = {}
local function notify(msg, ok)
    local color = ok and C.GREEN or C.RED
    local icon  = ok and "✓" or "✕"

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 44)
    frame.Position = UDim2.new(0.5, -150, 1, 20)
    frame.BackgroundColor3 = C.PANEL
    frame.ZIndex = 100
    frame.Parent = gui
    corner(frame, 10)
    stroke(frame, color, 1)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -12)
    accent.Position = UDim2.new(0, 8, 0, 6)
    accent.BackgroundColor3 = color
    accent.ZIndex = 101
    accent.Parent = frame
    corner(accent, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -22, 1, 0)
    lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = icon .. "  " .. msg
    lbl.TextColor3 = C.TEXT
    lbl.TextSize = 12
    lbl.Font = FONT_SEMI
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 101
    lbl.Parent = frame

    local targetY = 1 - (0.06 * (#notifQueue + 1))
    table.insert(notifQueue, frame)
    tween(frame, {Position = UDim2.new(0.5, -150, targetY, -50)}, 0.3)

    task.delay(3, function()
        tween(frame, {Position = UDim2.new(0.5, -150, 1, 20), BackgroundTransparency = 1}, 0.25)
        tween(lbl, {TextTransparency = 1}, 0.25)
        task.wait(0.3)
        local idx = table.find(notifQueue, frame)
        if idx then table.remove(notifQueue, idx) end
        frame:Destroy()
    end)
end

local function safeCall(fn, successMsg, failPrefix)
    local ok, err = pcall(fn)
    notify(ok and successMsg or (failPrefix or "Error") .. ": " .. tostring(err), ok)
    return ok
end

-- ══════════════════════════════════════════
--  ROOT GUI
-- ══════════════════════════════════════════
if playerGui:FindFirstChild("OdysseyScript") then
    playerGui.OdysseyScript:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "OdysseyScript"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Main window
local win = Instance.new("Frame")
win.Name = "Window"
win.Size = UDim2.new(0, 500, 0, 620)
win.Position = UDim2.new(0.5, -250, 0.5, -310)
win.BackgroundColor3 = C.BG
win.BorderSizePixel = 0
win.Parent = gui
corner(win, 14)
stroke(win, C.BORDER, 1)

-- Glow behind window
local glow = Instance.new("ImageLabel")
glow.Size = UDim2.new(1, 80, 1, 80)
glow.Position = UDim2.new(0, -40, 0, -40)
glow.BackgroundTransparency = 1
glow.Image = "rbxassetid://5028857084"
glow.ImageColor3 = C.ACCENT
glow.ImageTransparency = 0.85
glow.ScaleType = Enum.ScaleType.Slice
glow.SliceCenter = Rect.new(24, 24, 276, 276)
glow.ZIndex = 0
glow.Parent = win

-- ── TITLE BAR ──────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 52)
titleBar.BackgroundColor3 = C.PANEL
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 2
titleBar.Parent = win
corner(titleBar, 14)

-- Cover bottom corners
local titleCover = Instance.new("Frame")
titleCover.Size = UDim2.new(1, 0, 0, 14)
titleCover.Position = UDim2.new(0, 0, 1, -14)
titleCover.BackgroundColor3 = C.PANEL
titleCover.BorderSizePixel = 0
titleCover.ZIndex = 2
titleCover.Parent = titleBar

-- Gradient accent line
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, -1)
accentLine.BackgroundColor3 = C.ACCENT
accentLine.BorderSizePixel = 0
accentLine.ZIndex = 3
accentLine.Parent = titleBar
gradient(accentLine, C.ACCENT, C.ACCENT2, 0)

-- Logo dot
local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.new(0, 8, 0, 8)
logoDot.Position = UDim2.new(0, 16, 0.5, -4)
logoDot.BackgroundColor3 = C.ACCENT
logoDot.BorderSizePixel = 0
logoDot.ZIndex = 3
logoDot.Parent = titleBar
corner(logoDot, 4)
gradient(logoDot, C.ACCENT, C.ACCENT2, 135)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -120, 1, 0)
titleLbl.Position = UDim2.new(0, 30, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "ODYSSEY SCRIPT"
titleLbl.TextColor3 = C.TEXT
titleLbl.TextSize = 15
titleLbl.Font = FONT_BOLD
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 3
titleLbl.Parent = titleBar

local versionLbl = Instance.new("TextLabel")
versionLbl.Size = UDim2.new(0, 40, 1, 0)
versionLbl.Position = UDim2.new(0, 175, 0, 0)
versionLbl.BackgroundTransparency = 1
versionLbl.Text = "v1.0"
versionLbl.TextColor3 = C.SUBTEXT
versionLbl.TextSize = 11
versionLbl.Font = FONT_REG
versionLbl.TextXAlignment = Enum.TextXAlignment.Left
versionLbl.ZIndex = 3
versionLbl.Parent = titleBar

-- Close / Minimize buttons
local function titleBtn(xOff, bg, symbol)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 26)
    b.Position = UDim2.new(1, xOff, 0.5, -13)
    b.BackgroundColor3 = bg
    b.Text = symbol
    b.TextColor3 = C.TEXT
    b.TextSize = 12
    b.Font = FONT_BOLD
    b.BorderSizePixel = 0
    b.ZIndex = 4
    b.Parent = titleBar
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.3}) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0}) end)
    return b
end

local closeBtn    = titleBtn(-12, C.RED,  "✕")
local minimizeBtn = titleBtn(-44, C.YELLOW, "─")

local minimized = false
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetSize = minimized and UDim2.new(0, 500, 0, 52) or UDim2.new(0, 500, 0, 620)
    tween(win, {Size = targetSize}, 0.3)
end)

-- Drag
local UIS = game:GetService("UserInputService")
local dragging, dragStart, winStart = false, nil, nil

titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        winStart  = win.Position
    end
end)

titleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - dragStart
        win.Position = UDim2.new(
            winStart.X.Scale, winStart.X.Offset + d.X,
            winStart.Y.Scale, winStart.Y.Offset + d.Y
        )
    end
end)

-- ── TAB BAR ────────────────────────────────
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 36)
tabBar.Position = UDim2.new(0, 12, 0, 58)
tabBar.BackgroundColor3 = C.PANEL
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 2
tabBar.Parent = win
corner(tabBar, 8)
listLayout(tabBar, Enum.FillDirection.Horizontal, 0)

-- ── CONTENT AREA ───────────────────────────
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -24, 1, -106)
contentArea.Position = UDim2.new(0, 12, 0, 100)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent = win

-- ══════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════
local tabButtons = {}
local tabPages   = {}
local activeTab  = nil

local TAB_NAMES = {"Lobby", "Joiner", "Game", "Odyssey"}

local function makePage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.ACCENT
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.ZIndex = 2
    page.Parent = contentArea
    listLayout(page, nil, 8)
    padding(page, nil, 8, 12, 0, 0)
    return page
end

local function switchTab(name)
    for n, pg in pairs(tabPages) do
        pg.Visible = false
        local btn = tabButtons[n]
        tween(btn, {BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 1}, 0.15)
        btn.TextColor3 = C.SUBTEXT
    end
    tabPages[name].Visible = true
    local btn = tabButtons[name]
    tween(btn, {BackgroundColor3 = C.ACCENT, BackgroundTransparency = 0}, 0.15)
    btn.TextColor3 = C.TEXT
    activeTab = name
end

for i, name in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.25, 0, 1, 0)
    btn.BackgroundColor3 = C.PANEL
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = C.SUBTEXT
    btn.TextSize = 13
    btn.Font = FONT_SEMI
    btn.BorderSizePixel = 0
    btn.LayoutOrder = i
    btn.ZIndex = 3
    btn.Parent = tabBar
    corner(btn, 8)

    tabButtons[name] = btn
    tabPages[name]   = makePage()

    btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ══════════════════════════════════════════
--  COMPONENT BUILDERS
-- ══════════════════════════════════════════
local function section(page, title, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C.CARD
    card.BorderSizePixel = 0
    card.LayoutOrder = order or 1
    card.ZIndex = 2
    card.Parent = page
    corner(card, 10)
    stroke(card, C.BORDER, 1)
    listLayout(card, nil, 6)
    padding(card, nil, 10, 12, 12, 12)

    -- Section header
    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 22)
    hdr.BackgroundTransparency = 1
    hdr.LayoutOrder = 0
    hdr.ZIndex = 3
    hdr.Parent = card

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = C.ACCENT
    bar.BorderSizePixel = 0
    bar.ZIndex = 3
    bar.Parent = hdr
    corner(bar, 2)
    gradient(bar, C.ACCENT, C.ACCENT2, 90)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = C.TEXT
    lbl.TextSize = 13
    lbl.Font = FONT_BOLD
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = hdr

    return card
end

local function btn(parent, label, color, order)
    color = color or C.ACCENT
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = color
    b.Text = label
    b.TextColor3 = C.TEXT
    b.TextSize = 13
    b.Font = FONT_SEMI
    b.BorderSizePixel = 0
    b.LayoutOrder = order or 99
    b.ZIndex = 3
    b.Parent = parent
    corner(b, 7)
    gradient(b, color, color:Lerp(Color3.new(0,0,0), 0.25), 90)
    b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.2}) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0}) end)
    return b
end

local function label(parent, text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.SUBTEXT
    l.TextSize = 11
    l.Font = FONT_REG
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order or 99
    l.ZIndex = 3
    l.Parent = parent
    return l
end

local function input(parent, placeholder, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundColor3 = C.BG
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order or 99
    frame.ZIndex = 3
    frame.Parent = parent
    corner(frame, 7)
    stroke(frame, C.BORDER, 1)

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -16, 1, 0)
    tb.Position = UDim2.new(0, 8, 0, 0)
    tb.BackgroundTransparency = 1
    tb.Text = ""
    tb.PlaceholderText = placeholder
    tb.PlaceholderColor3 = C.SUBTEXT
    tb.TextColor3 = C.TEXT
    tb.TextSize = 13
    tb.Font = FONT_REG
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.ZIndex = 4
    tb.Parent = frame

    tb.Focused:Connect(function() tween(frame, {BackgroundColor3 = C.PANEL}) end)
    tb.FocusLost:Connect(function()  tween(frame, {BackgroundColor3 = C.BG}) end)

    return tb
end

local function toggle(parent, text, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order or 99
    row.ZIndex = 3
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.TEXT
    lbl.TextSize = 13
    lbl.Font = FONT_REG
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 44, 0, 24)
    track.Position = UDim2.new(1, -44, 0.5, -12)
    track.BackgroundColor3 = C.DISABLED
    track.BorderSizePixel = 0
    track.ZIndex = 3
    track.Parent = row
    corner(track, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = C.TEXT
    knob.BorderSizePixel = 0
    knob.ZIndex = 4
    knob.Parent = track
    corner(knob, 9)

    local enabled = false
    local clickArea = Instance.new("TextButton")
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.ZIndex = 5
    clickArea.Parent = track

    clickArea.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            tween(track, {BackgroundColor3 = C.ACCENT})
            tween(knob,  {Position = UDim2.new(1, -21, 0.5, -9)})
        else
            tween(track, {BackgroundColor3 = C.DISABLED})
            tween(knob,  {Position = UDim2.new(0, 3, 0.5, -9)})
        end
    end)

    return row, function() return enabled end
end

local function chip(parent, text, selected, onClick)
    local c = Instance.new("TextButton")
    c.AutomaticSize = Enum.AutomaticSize.X
    c.Size = UDim2.new(0, 0, 1, -6)
    c.BackgroundColor3 = selected and C.ACCENT or C.PANEL
    c.Text = text
    c.TextColor3 = selected and C.TEXT or C.SUBTEXT
    c.TextSize = 12
    c.Font = FONT_SEMI
    c.BorderSizePixel = 0
    c.ZIndex = 4
    c.Parent = parent
    corner(c, 6)
    padding(c, nil, 0, 0, 10, 10)
    c.MouseButton1Click:Connect(onClick)
    return c
end

local function hScroll(parent, h, order)
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 0, h)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 0
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.X
    s.ScrollingDirection = Enum.ScrollingDirection.X
    s.LayoutOrder = order or 99
    s.ZIndex = 3
    s.Parent = parent
    listLayout(s, Enum.FillDirection.Horizontal, 6)
    padding(s, nil, 3, 3, 0, 0)
    return s
end

-- ══════════════════════════════════════════
--  LOBBY TAB
-- ══════════════════════════════════════════
local lobbyPage = tabPages["Lobby"]

-- ── Summoner ───────────────────────────────
local sumSec = section(lobbyPage, "⟳  Summoner", 1)

label(sumSec, "Summon Amount  (1 – 50)", 1)
local amountBox = input(sumSec, "Enter amount, e.g. 10", 2)

local BANNERS = {
    { name = "Selection Banner",  call = function(amt) Net.SummonSelectionEvent:FireServer("SummonMany", amt) end },
    { name = "Special Banner",    call = function(amt) Net.Units.SummonIndexEvent:FireServer("SummonMany", amt) end },
    { name = "Standard Memoria",  call = function(amt) Net.Memorias.MemoriaSummonEvent:FireServer("SummonMany", amt) end },
    { name = "Spring Banner",     call = function(amt) SummonEvent:FireServer("SummonMany", "Spring26", amt) end },
    { name = "Spring Memoria",    call = function(amt) SummonEvent:FireServer("SummonMany", "Spring26Memoria", amt) end },
}

for i, b in ipairs(BANNERS) do
    local color = (i <= 3) and C.ACCENT or C.ACCENT2
    local bb = btn(sumSec, b.name, color, i + 2)
    bb.MouseButton1Click:Connect(function()
        local amt = math.clamp(tonumber(amountBox.Text) or 1, 1, 50)
        safeCall(function() b.call(amt) end, "Summoning " .. b.name .. " x" .. amt, "Summon failed")
    end)
end

-- ── Claimer ────────────────────────────────
local claimSec = section(lobbyPage, "⬇  Claimer", 2)

local CLAIMERS = {
    { name = "Claim All Quests",     color = C.GREEN,  fn = function()
        Net.Quests.ClaimQuest:FireServer("ClaimAll")
    end},
    { name = "Claim All Milestones", color = Color3.fromRGB(60,130,220), fn = function()
        for _, m in ipairs({10,25,50,70,100,150,200,250,300,400,500,750,1000}) do
            Net.Milestones.MilestonesEvent:FireServer("Claim", m)
            task.wait(0.08)
        end
    end},
    { name = "Claim Daily Reward",   color = C.YELLOW, fn = function()
        for day = 1, 7 do
            Net.DailyRewardEvent:FireServer("Claim", {[1]="Special",[2]=day})
            task.wait(0.08)
        end
    end},
    { name = "Claim Battle Pass",    color = Color3.fromRGB(160,60,220), fn = function()
        Net.BattlepassEvent:FireServer("ClaimAll")
    end},
}

for i, c in ipairs(CLAIMERS) do
    local b = btn(claimSec, c.name, c.color, i)
    b.MouseButton1Click:Connect(function()
        safeCall(c.fn, c.name .. " claimed!", "Claim failed")
    end)
end

local claimAllBtn = btn(claimSec, "✦  Enable All Auto Claim", C.ACCENT, #CLAIMERS + 1)
claimAllBtn.MouseButton1Click:Connect(function()
    safeCall(function()
        for _, c in ipairs(CLAIMERS) do c.fn(); task.wait(0.2) end
    end, "All rewards claimed!", "Claim all failed")
end)

-- ══════════════════════════════════════════
--  JOINER TAB
-- ══════════════════════════════════════════
local joinerPage = tabPages["Joiner"]

local STAGES = {
    Story       = { Stage2={"Act1","Act2","Act3","Act4","Act5","Act6","Infinite","Sandbox"}, Stage3={"Act1","Act2"}, Stage4={"Act1","Act2","Act3","Act4","Act5","Act6","Act7","Act8","Act9"} },
    LegendStage = { Stage2={"Act1","Act2","Act3"}, Stage3={"Act1","Act2","Act3"}, Stage4={"Act1","Act2","Act3"} },
    Dungeon     = { Stage1={"Act1","Act2","Act3","OccultHunt"}, Stage2={"AntIsland"}, Stage3={"FrozenVolcano"}, Stage4={"Act1","Act2","Act3","Act4","Act5","Act6","Act7","Act8","Act9"}, Stage5={"Underworld"} },
    Raid        = { Stage1={"Act1","Act2","Act3","Act4"}, Stage2={"Act1","Act2","Act3","Act4","Act5"}, Stage3={"Act1","Act2"} },
    Challenge   = { Stage1={"ChallengeAct"}, Stage2={"ChallengeAct"}, Stage3={"ChallengeAct"} },
    BossEvent   = { IgrosEvent={"Act1","Act1Elite"}, SukonoEvent={"Act1"} },
    GuildWar    = { GuildWar={"Act1"} },
    Rememberance= { Stage1={"Act1"} },
}

local selType  = "Story"
local selStage = "Stage2"
local selAct   = "Act1"

local joinSec = section(joinerPage, "▶  Stage Joiner", 1)

-- Type row
label(joinSec, "Stage Type", 1)
local typeScroll = hScroll(joinSec, 34, 2)
local typeChips  = {}

-- Stage row
label(joinSec, "Stage", 3)
local stageScroll = hScroll(joinSec, 34, 4)
local stageChips  = {}

-- Act row
label(joinSec, "Act", 5)
local actScroll = hScroll(joinSec, 34, 6)
local actChips  = {}

local function refreshActs()
    for _, c in ipairs(actScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    actChips = {}
    local acts = STAGES[selType] and STAGES[selType][selStage] or {}
    selAct = acts[1] or selAct
    for _, a in ipairs(acts) do
        local c = chip(actScroll, a, a == selAct, function()
            selAct = a
            for _, ch in ipairs(actScroll:GetChildren()) do
                if ch:IsA("TextButton") then
                    tween(ch, {BackgroundColor3 = ch.Text == selAct and C.ACCENT or C.PANEL})
                    ch.TextColor3 = ch.Text == selAct and C.TEXT or C.SUBTEXT
                end
            end
        end)
        table.insert(actChips, c)
    end
end

local function refreshStages()
    for _, c in ipairs(stageScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    stageChips = {}
    local stages = STAGES[selType] or {}
    local first = true
    for sName in pairs(stages) do if first then selStage = sName; first = false end end
    for sName in pairs(stages) do
        local c = chip(stageScroll, sName, sName == selStage, function()
            selStage = sName
            for _, ch in ipairs(stageScroll:GetChildren()) do
                if ch:IsA("TextButton") then
                    tween(ch, {BackgroundColor3 = ch.Text == selStage and C.ACCENT or C.PANEL})
                    ch.TextColor3 = ch.Text == selStage and C.TEXT or C.SUBTEXT
                end
            end
            refreshActs()
        end)
        table.insert(stageChips, c)
    end
    refreshActs()
end

for tName in pairs(STAGES) do
    local c = chip(typeScroll, tName, tName == selType, function()
        selType = tName
        for _, ch in ipairs(typeScroll:GetChildren()) do
            if ch:IsA("TextButton") then
                tween(ch, {BackgroundColor3 = ch.Text == selType and C.ACCENT or C.PANEL})
                ch.TextColor3 = ch.Text == selType and C.TEXT or C.SUBTEXT
            end
        end
        refreshStages()
    end)
    table.insert(typeChips, c)
end

refreshStages()

-- Options
local optSec = section(joinerPage, "⚙  Options", 2)
local _, getNightmare = toggle(optSec, "Nightmare Mode", 1)
local _, getFriendsOnly = toggle(optSec, "Friends Only", 2)

-- Join button
local joinBtnSec = section(joinerPage, "", 3)
local joinBtn = btn(joinBtnSec, "▶  Join Match", C.GREEN, 1)
joinBtn.MouseButton1Click:Connect(function()
    safeCall(function()
        LobbyEvent:FireServer("AddMatch", {
            Difficulty  = getNightmare() and "Nightmare" or "Normal",
            Act         = selAct,
            StageType   = selType,
            Stage       = selStage,
            FriendsOnly = getFriendsOnly(),
        })
    end, "Joining " .. selType .. " › " .. selStage .. " › " .. selAct, "Join failed")
end)

-- ══════════════════════════════════════════
--  GAME TAB
-- ══════════════════════════════════════════
local gamePage = tabPages["Game"]

-- Match Controls
local matchSec = section(gamePage, "⏩  Match Controls", 1)
local skipBtn = btn(matchSec, "Skip Wave", C.ACCENT, 1)
skipBtn.MouseButton1Click:Connect(function()
    safeCall(function() Net.SkipWaveEvent:FireServer("Skip") end, "Wave skipped", "Skip failed")
end)

local statusBtn = btn(matchSec, "Update Match Status", Color3.fromRGB(60,100,200), 2)
statusBtn.MouseButton1Click:Connect(function()
    safeCall(function() Net.MatchStatusEvent:FireServer("UpdateStatus", 2) end, "Status updated", "Status failed")
end)

-- Unit Controls
local unitSec = section(gamePage, "🗡  Unit Controls", 2)
label(unitSec, "Unit UUID", 1)
local uuidBox = input(unitSec, "Paste unit UUID here", 2)

local upgradeBtn = btn(unitSec, "⬆  Upgrade", C.ACCENT, 3)
upgradeBtn.MouseButton1Click:Connect(function()
    local uuid = uuidBox.Text
    if uuid == "" then return notify("Enter a UUID first", false) end
    safeCall(function() UnitEvent:FireServer("Upgrade", uuid) end, "Unit upgraded", "Upgrade failed")
end)

label(unitSec, "Target Upgrade Level (UpgradeMultiple)", 4)
local levelBox = input(unitSec, "e.g. 12", 5)

local upgradeMultiBtn = btn(unitSec, "⬆⬆  Upgrade Multiple", Color3.fromRGB(80,60,220), 6)
upgradeMultiBtn.MouseButton1Click:Connect(function()
    local uuid = uuidBox.Text
    local lv   = tonumber(levelBox.Text)
    if uuid == "" or not lv then return notify("Enter UUID and level", false) end
    safeCall(function() UnitEvent:FireServer("UpgradeMultiple", uuid, lv) end, "Upgraded to level " .. lv, "Upgrade failed")
end)

local sellBtn = btn(unitSec, "💰  Sell Unit", C.RED, 7)
sellBtn.MouseButton1Click:Connect(function()
    local uuid = uuidBox.Text
    if uuid == "" then return notify("Enter a UUID first", false) end
    safeCall(function() UnitEvent:FireServer("Sell", uuid) end, "Unit sold", "Sell failed")
end)

-- Priority
local priSec = section(gamePage, "🎯  Unit Priority", 3)
label(priSec, "Uses UUID from above", 1)
local PRIORITIES = {"First","Last","Closest","Strongest","Weakest","Bosses"}
for i, p in ipairs(PRIORITIES) do
    local b = btn(priSec, p, Color3.fromRGB(45,45,80), i + 1)
    b.MouseButton1Click:Connect(function()
        local uuid = uuidBox.Text
        if uuid == "" then return notify("Enter a UUID first", false) end
        safeCall(function() UnitEvent:FireServer("ChangePriority", uuid, p) end, "Priority → " .. p, "Priority failed")
    end)
end

-- ══════════════════════════════════════════
--  ODYSSEY TAB
-- ══════════════════════════════════════════
local odysseyPage = tabPages["Odyssey"]

local function getONet(name)
    return OdysseyNet and OdysseyNet:FindFirstChild(name)
end

-- Cards
local cardSec = section(odysseyPage, "🃏  Card Picking", 1)
label(cardSec, "Card Index (1 – 3)", 1)
local cardBox = input(cardSec, "Enter card index", 2)

local pickBtn = btn(cardSec, "Pick Card", C.ACCENT, 3)
pickBtn.MouseButton1Click:Connect(function()
    local idx = tonumber(cardBox.Text)
    if not idx then return notify("Enter a card index", false) end
    safeCall(function() getONet("CardPickEvent"):FireServer("Pick", idx) end, "Picked card " .. idx, "Pick failed")
end)

local skipCardBtn = btn(cardSec, "Skip Cards", C.DISABLED, 4)
skipCardBtn.MouseButton1Click:Connect(function()
    safeCall(function() getONet("CardPickEvent"):FireServer("Skip", 0) end, "Cards skipped", "Skip failed")
end)

-- Room
local roomSec = section(odysseyPage, "🗺  Room & Voting", 2)
label(roomSec, "Room Index", 1)
local roomBox = input(roomSec, "Enter room index", 2)

local voteBtn = btn(roomSec, "Vote Room", C.ACCENT, 3)
voteBtn.MouseButton1Click:Connect(function()
    local idx = tonumber(roomBox.Text)
    if not idx then return notify("Enter a room index", false) end
    safeCall(function() getONet("VoteEvent"):FireServer("Vote", idx) end, "Voted room " .. idx, "Vote failed")
end)

local snapshotBtn = btn(roomSec, "Request Map Snapshot", Color3.fromRGB(60,100,180), 4)
snapshotBtn.MouseButton1Click:Connect(function()
    safeCall(function() getONet("MapEvent"):FireServer("RequestSnapshot") end, "Snapshot requested", "Snapshot failed")
end)

-- Shop
local shopSec = section(odysseyPage, "🛒  Shop", 3)
label(shopSec, "Card Index to Purchase", 1)
local shopBox = input(shopSec, "Enter card index", 2)

local purchaseBtn = btn(shopSec, "Purchase Card", C.GREEN, 3)
purchaseBtn.MouseButton1Click:Connect(function()
    local idx = tonumber(shopBox.Text)
    if not idx then return notify("Enter a card index", false) end
    safeCall(function() getONet("ShopEvent"):FireServer("Purchase", idx) end, "Purchased card " .. idx, "Purchase failed")
end)

local rerollBtn = btn(shopSec, "Reroll Shop", C.ACCENT, 4)
rerollBtn.MouseButton1Click:Connect(function()
    safeCall(function() getONet("ShopEvent"):FireServer("Reroll") end, "Shop rerolled", "Reroll failed")
end)

local closeShopBtn = btn(shopSec, "Close Shop", C.RED, 5)
closeShopBtn.MouseButton1Click:Connect(function()
    safeCall(function() getONet("ShopEvent"):FireServer("Close") end, "Shop closed", "Close failed")
end)

-- Chest
local chestSec = section(odysseyPage, "📦  Treasure Chest", 4)
label(chestSec, "Chest UUID", 1)
local chestBox = input(chestSec, "Enter chest UUID", 2)

local openChestBtn = btn(chestSec, "Open Chest", C.YELLOW, 3)
openChestBtn.MouseButton1Click:Connect(function()
    local uuid = chestBox.Text
    if uuid == "" then return notify("Enter chest UUID", false) end
    safeCall(function()
        local remote = Net:FindFirstChild("OdysseyChest", true)
        if remote then remote:FireServer("OpenChest", uuid) end
    end, "Chest opened", "Chest failed")
end)

-- End Run
local endSec = section(odysseyPage, "🏁  End Run", 5)
local endRunBtn = btn(endSec, "Request End Run Preview", C.RED, 1)
endRunBtn.MouseButton1Click:Connect(function()
    safeCall(function() getONet("EndRunEvent"):FireServer("RequestPreview") end, "End run preview opened", "End run failed")
end)

-- ══════════════════════════════════════════
--  BOOT
-- ══════════════════════════════════════════
switchTab("Lobby")

-- Boot
win.Position = UDim2.new(0.5, -250, 0.5, -310)

notify("Odyssey Script loaded ✦", true)
print("[OdysseyScript] GUI loaded successfully.")
