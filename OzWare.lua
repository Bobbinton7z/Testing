-- ============================================================
-- OzWare  |  Liquid Glass UI
-- Game Tab: Remote Logger (Phase 1)
-- ============================================================

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local TweenSvc    = game:GetService("TweenService")
local RunSvc      = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player    = Players.LocalPlayer
local ok, _gui  = pcall(function() return gethui() end)
local playerGui = ok and _gui or player:WaitForChild("PlayerGui")
local Net       = RS:WaitForChild("Networking")

-- ============================================================
-- REMOTES  (preserved from previous script)
-- ============================================================
local function UnitEvent()      return Net:FindFirstChild("UnitEvent") end
local function LobbyEvent()     return Net:FindFirstChild("LobbyEvent") end
local function SummonEvent()    local u = Net:FindFirstChild("Units")    return u and u:FindFirstChild("SummonEvent") end
local function OdysseyNet()     local o = Net:FindFirstChild("Odyssey")  return o and o:FindFirstChild("Adventure") end
local function AbilityEvent()   return Net:FindFirstChild("AbilityEvent") end
local function SkipWaveEvent()  return Net:FindFirstChild("SkipWaveEvent") end

-- ============================================================
-- GAME-MODE GUARD
-- ============================================================
local function getMapRoot()
    return workspace:FindFirstChild("Map")
        or workspace:FindFirstChild("MapHolder")
        or workspace:FindFirstChild("Maps")
        or workspace:FindFirstChild("Stage")
end

local function inGameMode()
    if getMapRoot() then return true end
    for _, name in ipairs({"OdysseyRoom","AdventureRoom","Adventure",
                           "OdysseyMap","AdventureMap","Stage","Match"}) do
        if workspace:FindFirstChild(name) then return true end
    end
    return false
end

-- ============================================================
-- THEME  –  Liquid Glass
-- ============================================================
local C = {
    -- Base glass surfaces
    GLASS_BG     = Color3.fromRGB(255, 255, 255),   -- white tinted glass
    GLASS_CARD   = Color3.fromRGB(240, 242, 255),
    GLASS_DARK   = Color3.fromRGB(220, 224, 245),

    -- Accents (pulled from image: purple, teal, gradient pinks)
    PURPLE       = Color3.fromRGB(130, 80, 230),
    TEAL         = Color3.fromRGB(60, 210, 190),
    PINK         = Color3.fromRGB(220, 130, 210),
    BLUE         = Color3.fromRGB(80, 140, 230),
    GREEN        = Color3.fromRGB(60, 200, 130),
    RED          = Color3.fromRGB(230, 80, 100),
    YELLOW       = Color3.fromRGB(230, 190, 60),

    -- Text
    TEXT         = Color3.fromRGB(30, 30, 50),
    SUBTEXT      = Color3.fromRGB(100, 105, 140),
    DIM          = Color3.fromRGB(160, 165, 195),

    -- Stroke / border
    BORDER       = Color3.fromRGB(200, 205, 230),
    BORDER_LIGHT = Color3.fromRGB(230, 232, 248),

    -- Tab active pill
    PILL_BG      = Color3.fromRGB(248, 249, 255),
}

local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.GothamSemibold
local FONT_REG  = Enum.Font.Gotham

-- ============================================================
-- HELPERS
-- ============================================================
local function tween(o, p, t)
    TweenSvc:Create(o, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad), p):Play()
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, col, th, trans)
    local s = Instance.new("UIStroke")
    s.Color = col or C.BORDER
    s.Thickness = th or 1
    s.Transparency = trans or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function listLayout(p, dir, pad, ha, va)
    local l = Instance.new("UIListLayout")
    l.FillDirection   = dir or Enum.FillDirection.Vertical
    l.SortOrder       = Enum.SortOrder.LayoutOrder
    l.Padding         = UDim.new(0, pad or 6)
    l.HorizontalAlignment = ha or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = va or Enum.VerticalAlignment.Top
    l.Parent = p
    return l
end

local function padding(p, all, t, b, l, r)
    local pd = Instance.new("UIPadding")
    pd.PaddingTop    = UDim.new(0, t or all or 0)
    pd.PaddingBottom = UDim.new(0, b or all or 0)
    pd.PaddingLeft   = UDim.new(0, l or all or 0)
    pd.PaddingRight  = UDim.new(0, r or all or 0)
    pd.Parent = p
    return pd
end

-- Glass surface: frosted white panel with thin bright border
local function glassFrame(parent, size, pos, order, radius, tintCol, tintAlpha)
    local f = Instance.new("Frame")
    f.Size = size or UDim2.new(1, 0, 0, 40)
    if pos then f.Position = pos end
    f.BackgroundColor3 = tintCol or C.GLASS_BG
    f.BackgroundTransparency = tintAlpha or 0.72
    f.BorderSizePixel = 0
    if order then f.LayoutOrder = order end
    f.Parent = parent
    corner(f, radius or 14)
    stroke(f, C.BORDER_LIGHT, 1, 0.3)
    return f
end

-- ============================================================
-- ROOT GUI
-- ============================================================
if playerGui:FindFirstChild("OzWare") then playerGui.OzWare:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name          = "OzWare"
gui.ResetOnSpawn  = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder  = -1
gui.Parent        = playerGui

-- Soft ambient backdrop blur tint (the warm beige-ish shadow in reference)
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(200, 195, 210)
backdrop.BackgroundTransparency = 0.88
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = gui

-- ============================================================
-- MAIN WINDOW  –  rounded glass card
-- ============================================================
local win = Instance.new("Frame")
win.Name               = "Window"
win.Size               = UDim2.new(0, 680, 0, 500)
win.AnchorPoint        = Vector2.new(0.5, 0.5)
win.Position           = UDim2.new(0.5, 0, 0.5, 0)
win.BackgroundColor3   = Color3.fromRGB(248, 248, 255)
win.BackgroundTransparency = 0.08
win.BorderSizePixel    = 0
win.ClipsDescendants   = true
win.Active             = true
win.ZIndex             = 2
win.Parent             = gui
corner(win, 22)
-- Crisp glass border
local winStroke = Instance.new("UIStroke")
winStroke.Color     = Color3.fromRGB(255, 255, 255)
winStroke.Thickness = 1.5
winStroke.Transparency = 0.25
winStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
winStroke.Parent    = win

-- Subtle inner gradient so it looks like frosted glass catching light
local winGrad = Instance.new("UIGradient")
winGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(245, 245, 255)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(225, 228, 248)),
})
winGrad.Rotation = 135
winGrad.Parent   = win

-- ============================================================
-- TITLE BAR
-- ============================================================
local titleBar = Instance.new("Frame")
titleBar.Size              = UDim2.new(1, 0, 0, 54)
titleBar.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
titleBar.BackgroundTransparency = 0.55
titleBar.BorderSizePixel   = 0
titleBar.ZIndex            = 4
titleBar.Parent            = win
-- round top only: cover bottom corners with a solid cover strip
local tbCover = Instance.new("Frame")
tbCover.Size = UDim2.new(1, 0, 0, 22)
tbCover.Position = UDim2.new(0, 0, 1, -22)
tbCover.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
tbCover.BackgroundTransparency = 0.55
tbCover.BorderSizePixel = 0
tbCover.ZIndex = 4
tbCover.Parent = titleBar
corner(titleBar, 22)

-- Bottom border separator
local titleSep = Instance.new("Frame")
titleSep.Size = UDim2.new(1, 0, 0, 1)
titleSep.Position = UDim2.new(0, 0, 1, -1)
titleSep.BackgroundColor3 = C.BORDER_LIGHT
titleSep.BackgroundTransparency = 0
titleSep.BorderSizePixel = 0
titleSep.ZIndex = 5
titleSep.Parent = titleBar

-- Logo pill
local logoPill = Instance.new("Frame")
logoPill.Size = UDim2.new(0, 72, 0, 30)
logoPill.Position = UDim2.new(0, 16, 0.5, -15)
logoPill.BackgroundColor3 = C.PURPLE
logoPill.BackgroundTransparency = 0
logoPill.BorderSizePixel = 0
logoPill.ZIndex = 6
logoPill.Parent = titleBar
corner(logoPill, 15)
local logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.PURPLE),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 100, 240)),
})
logoGrad.Rotation = 135
logoGrad.Parent = logoPill
local logoLbl = Instance.new("TextLabel")
logoLbl.Size = UDim2.new(1, 0, 1, 0)
logoLbl.BackgroundTransparency = 1
logoLbl.Text = "OzWare"
logoLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
logoLbl.TextSize = 13
logoLbl.Font = FONT_BOLD
logoLbl.ZIndex = 7
logoLbl.Parent = logoPill

-- Version badge
local verLbl = Instance.new("TextLabel")
verLbl.Size = UDim2.new(0, 60, 0, 20)
verLbl.Position = UDim2.new(0, 98, 0.5, -10)
verLbl.BackgroundTransparency = 1
verLbl.Text = "v3.0"
verLbl.TextColor3 = C.SUBTEXT
verLbl.TextSize = 11
verLbl.Font = FONT_SEMI
verLbl.TextXAlignment = Enum.TextXAlignment.Left
verLbl.ZIndex = 6
verLbl.Parent = titleBar

-- Window drag
local dragging, dragStart, winStart = false, nil, nil
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; winStart = win.Position
    end
end)
titleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - dragStart
        win.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset + d.X, winStart.Y.Scale, winStart.Y.Offset + d.Y)
    end
end)

-- ============================================================
-- TAB BAR  (bottom of title bar — pill row like reference)
-- ============================================================
local tabBarHolder = Instance.new("Frame")
tabBarHolder.Size = UDim2.new(0, 340, 0, 34)
tabBarHolder.AnchorPoint = Vector2.new(0.5, 0.5)
tabBarHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
tabBarHolder.BackgroundColor3 = Color3.fromRGB(230, 232, 248)
tabBarHolder.BackgroundTransparency = 0.2
tabBarHolder.BorderSizePixel = 0
tabBarHolder.ZIndex = 6
tabBarHolder.Parent = titleBar
corner(tabBarHolder, 17)
stroke(tabBarHolder, C.BORDER_LIGHT, 1, 0.2)
listLayout(tabBarHolder, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
padding(tabBarHolder, nil, 4, 4, 6, 6)

local TAB_NAMES = {"Lobby", "Joiner", "Game", "Settings"}
local tabBtns, tabPages, activeTab = {}, {}, nil

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -24, 1, -66)
contentArea.Position = UDim2.new(0, 12, 0, 60)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.ZIndex = 3
contentArea.Parent = win

local function makePage()
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = C.PURPLE
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = false
    p.ZIndex = 3
    p.Parent = contentArea
    listLayout(p, nil, 10)
    padding(p, nil, 10, 14, 2, 6)
    return p
end

-- Active tab indicator (sliding pill)
local activePill = Instance.new("Frame")
activePill.Size = UDim2.new(0, 74, 0, 26)
activePill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
activePill.BackgroundTransparency = 0.05
activePill.BorderSizePixel = 0
activePill.ZIndex = 5
activePill.Parent = tabBarHolder
corner(activePill, 13)
stroke(activePill, Color3.fromRGB(255, 255, 255), 1, 0.4)

local function switchTab(name)
    for n, _ in pairs(tabPages) do
        tabPages[n].Visible = false
        if tabBtns[n] then
            tabBtns[n].TextColor3 = C.SUBTEXT
            tween(tabBtns[n], {TextColor3 = C.SUBTEXT})
        end
    end
    tabPages[name].Visible = true
    if tabBtns[name] then
        tween(tabBtns[name], {TextColor3 = C.TEXT})
        -- Slide the pill to the active button
        local bPos = tabBtns[name].AbsolutePosition
        local hPos = tabBarHolder.AbsolutePosition
        tween(activePill, {Position = UDim2.new(0, bPos.X - hPos.X - 2, 0, 2)}, 0.2)
    end
    activeTab = name
end

for i, name in ipairs(TAB_NAMES) do
    tabPages[name] = makePage()
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, 74, 1, -8)
    tb.BackgroundTransparency = 1
    tb.Text = name
    tb.TextColor3 = C.SUBTEXT
    tb.TextSize = 12
    tb.Font = FONT_SEMI
    tb.BorderSizePixel = 0
    tb.AutoButtonColor = false
    tb.LayoutOrder = i
    tb.ZIndex = 7
    tb.Parent = tabBarHolder
    corner(tb, 12)
    tabBtns[name] = tb
    tb.MouseButton1Click:Connect(function() switchTab(name) end)
    tb.MouseEnter:Connect(function()
        if activeTab ~= name then tween(tb, {TextColor3 = C.TEXT}) end
    end)
    tb.MouseLeave:Connect(function()
        if activeTab ~= name then tween(tb, {TextColor3 = C.SUBTEXT}) end
    end)
end

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
local notifQueue = {}
local function notify(msg, success)
    local color = success and C.GREEN or C.RED
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 280, 0, 44)
    f.Position = UDim2.new(0.5, -140, 1, 20)
    f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    f.BackgroundTransparency = 0.12
    f.BorderSizePixel = 0
    f.ZIndex = 100
    f.Parent = gui
    corner(f, 12)
    stroke(f, color, 1.5, 0.1)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 0, 24)
    accent.Position = UDim2.new(0, 10, 0.5, -12)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0
    accent.ZIndex = 101
    accent.Parent = f
    corner(accent, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -26, 1, 0)
    lbl.Position = UDim2.new(0, 22, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = (success and "✓  " or "✕  ") .. msg
    lbl.TextColor3 = C.TEXT
    lbl.TextSize = 12
    lbl.Font = FONT_SEMI
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 101
    lbl.Parent = f

    local targetY = 1 - (0.07 * (#notifQueue + 1))
    table.insert(notifQueue, f)
    tween(f, {Position = UDim2.new(0.5, -140, targetY, -50)}, 0.3)
    task.delay(3.5, function()
        tween(f, {Position = UDim2.new(0.5, -140, 1, 20), BackgroundTransparency = 1}, 0.25)
        tween(lbl, {TextTransparency = 1}, 0.25)
        task.wait(0.3)
        local idx = table.find(notifQueue, f)
        if idx then table.remove(notifQueue, idx) end
        f:Destroy()
    end)
end

-- ============================================================
-- COMPONENT LIBRARY
-- ============================================================

-- Glass card section
local function glassSection(page, title, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.5
    card.BorderSizePixel = 0
    card.LayoutOrder = order or 1
    card.ZIndex = 4
    card.Parent = page
    corner(card, 14)
    stroke(card, Color3.fromRGB(255, 255, 255), 1, 0.35)
    listLayout(card, nil, 8)
    padding(card, nil, 12, 14, 14, 14)

    if title and title ~= "" then
        local hdr = Instance.new("TextLabel")
        hdr.Size = UDim2.new(1, 0, 0, 18)
        hdr.BackgroundTransparency = 1
        hdr.Text = title:upper()
        hdr.TextColor3 = C.SUBTEXT
        hdr.TextSize = 10
        hdr.Font = FONT_BOLD
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.LayoutOrder = 0
        hdr.ZIndex = 5
        hdr.Parent = card
        -- letter-spacing via 2 spaces between chars is not possible in Roblox,
        -- so just use a colored accent dot prefix
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 5, 0, 5)
        dot.Position = UDim2.new(0, 0, 0.5, -3)
        dot.BackgroundColor3 = C.PURPLE
        dot.BorderSizePixel = 0
        dot.ZIndex = 6
        dot.Parent = hdr
        corner(dot, 3)
        hdr.Position = UDim2.new(0, 10, 0, 0)
        hdr.Size = UDim2.new(1, -10, 0, 18)
    end

    return card
end

-- Pill button (rounded, liquid-glass style)
local function pillBtn(parent, label, accentCol, order)
    accentCol = accentCol or C.PURPLE
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = accentCol
    b.BackgroundTransparency = 0
    b.Text = label
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 13
    b.Font = FONT_BOLD
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.LayoutOrder = order or 99
    b.ZIndex = 5
    b.Parent = parent
    corner(b, 18)
    -- sheen gradient
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180,180,200)),
    })
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 0.7),
    })
    g.Rotation = 90
    g.Parent = b
    b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.15}) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0}) end)
    b.MouseButton1Down:Connect(function() tween(b, {BackgroundTransparency = 0.3}) end)
    b.MouseButton1Up:Connect(function() tween(b, {BackgroundTransparency = 0}) end)
    return b
end

-- Flat glass button (secondary style)
local function ghostBtn(parent, label, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(240, 242, 255)
    b.BackgroundTransparency = 0.3
    b.Text = label
    b.TextColor3 = C.TEXT
    b.TextSize = 13
    b.Font = FONT_SEMI
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.LayoutOrder = order or 99
    b.ZIndex = 5
    b.Parent = parent
    corner(b, 10)
    stroke(b, C.BORDER, 1, 0.3)
    b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.1}) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0.3}) end)
    return b
end

-- Chip label
local function labelTxt(parent, text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.SUBTEXT
    l.TextSize = 11
    l.Font = FONT_REG
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order or 99
    l.ZIndex = 5
    l.Parent = parent
    return l
end

-- Glass toggle
local function glassToggle(parent, text, order, default)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 0.55
    row.Text = ""
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 99
    row.ZIndex = 5
    row.Parent = parent
    corner(row, 10)
    stroke(row, C.BORDER_LIGHT, 1, 0.25)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.TEXT
    lbl.TextSize = 13
    lbl.Font = FONT_SEMI
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 6
    lbl.Parent = row

    -- The toggle track (like in the reference image — small pill)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 36, 0, 20)
    track.Position = UDim2.new(1, -46, 0.5, -10)
    track.BackgroundColor3 = C.BORDER
    track.BorderSizePixel = 0
    track.ZIndex = 6
    track.Parent = row
    corner(track, 10)
    stroke(track, Color3.fromRGB(255,255,255), 1, 0.5)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 7
    knob.Parent = track
    corner(knob, 7)

    local on = default or false
    local function apply()
        if on then
            tween(track, {BackgroundColor3 = C.PURPLE})
            tween(knob,  {Position = UDim2.new(0, 19, 0.5, -7)})
        else
            tween(track, {BackgroundColor3 = C.BORDER})
            tween(knob,  {Position = UDim2.new(0, 3, 0.5, -7)})
        end
    end
    apply()

    row.MouseButton1Click:Connect(function()
        on = not on
        apply()
    end)

    return row, function() return on end
end

-- ============================================================
-- ============================================================
-- GAME TAB  —  Remote Logger
-- ============================================================
-- ============================================================
do
local gamePage = tabPages["Game"]

-- ── Section 1: Logger ──────────────────────────────────────
local logSec = glassSection(gamePage, "Remote Logger", 1)

-- Info label
labelTxt(logSec, "Intercepts FireServer calls and logs args in real-time.", 1)

-- Log display frame
local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, 0, 0, 200)
logFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
logFrame.BackgroundTransparency = 0.05
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 3
logFrame.ScrollBarImageColor3 = C.TEAL
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.ScrollingDirection = Enum.ScrollingDirection.Y
logFrame.LayoutOrder = 2
logFrame.ZIndex = 6
logFrame.Parent = logSec
corner(logFrame, 10)
stroke(logFrame, Color3.fromRGB(60, 70, 110), 1, 0.3)
listLayout(logFrame, nil, 0)
padding(logFrame, nil, 6, 6, 8, 8)

-- Control row: Filter input + Clear + Pause
local ctrlRow = Instance.new("Frame")
ctrlRow.Size = UDim2.new(1, 0, 0, 34)
ctrlRow.BackgroundTransparency = 1
ctrlRow.LayoutOrder = 3
ctrlRow.ZIndex = 6
ctrlRow.Parent = logSec

-- Filter TextBox (glass input)
local filterFrame = Instance.new("Frame")
filterFrame.Size = UDim2.new(1, -154, 1, 0)
filterFrame.Position = UDim2.new(0, 0, 0, 0)
filterFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
filterFrame.BackgroundTransparency = 0.4
filterFrame.BorderSizePixel = 0
filterFrame.ZIndex = 6
filterFrame.Parent = ctrlRow
corner(filterFrame, 9)
stroke(filterFrame, C.BORDER, 1, 0.3)

local filterBox = Instance.new("TextBox")
filterBox.Size = UDim2.new(1, -20, 1, 0)
filterBox.Position = UDim2.new(0, 10, 0, 0)
filterBox.BackgroundTransparency = 1
filterBox.Text = ""
filterBox.PlaceholderText = "Filter remotes..."
filterBox.PlaceholderColor3 = C.DIM
filterBox.TextColor3 = C.TEXT
filterBox.TextSize = 12
filterBox.Font = FONT_REG
filterBox.TextXAlignment = Enum.TextXAlignment.Left
filterBox.ClearTextOnFocus = false
filterBox.ZIndex = 7
filterBox.Parent = filterFrame

-- Pause button
local pauseBtn = Instance.new("TextButton")
pauseBtn.Size = UDim2.new(0, 68, 1, 0)
pauseBtn.Position = UDim2.new(1, -144, 0, 0)
pauseBtn.BackgroundColor3 = C.YELLOW
pauseBtn.BackgroundTransparency = 0.1
pauseBtn.Text = "⏸ Pause"
pauseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
pauseBtn.TextSize = 11
pauseBtn.Font = FONT_BOLD
pauseBtn.BorderSizePixel = 0
pauseBtn.AutoButtonColor = false
pauseBtn.ZIndex = 6
pauseBtn.Parent = ctrlRow
corner(pauseBtn, 9)

-- Clear button
local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 68, 1, 0)
clearBtn.Position = UDim2.new(1, -70, 0, 0)
clearBtn.BackgroundColor3 = C.RED
clearBtn.BackgroundTransparency = 0.1
clearBtn.Text = "✕ Clear"
clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearBtn.TextSize = 11
clearBtn.Font = FONT_BOLD
clearBtn.BorderSizePixel = 0
clearBtn.AutoButtonColor = false
clearBtn.ZIndex = 6
clearBtn.Parent = ctrlRow
corner(clearBtn, 9)

-- Toggle row: capture filters
local captureRow = Instance.new("Frame")
captureRow.Size = UDim2.new(1, 0, 0, 30)
captureRow.BackgroundTransparency = 1
captureRow.LayoutOrder = 4
captureRow.ZIndex = 6
captureRow.Parent = logSec
listLayout(captureRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

local function captureChip(parent, label, col, order)
    local c = Instance.new("TextButton")
    c.AutomaticSize = Enum.AutomaticSize.X
    c.Size = UDim2.new(0, 0, 1, 0)
    c.BackgroundColor3 = col
    c.BackgroundTransparency = 0.2
    c.Text = label
    c.TextColor3 = Color3.fromRGB(255, 255, 255)
    c.TextSize = 11
    c.Font = FONT_SEMI
    c.BorderSizePixel = 0
    c.AutoButtonColor = false
    c.LayoutOrder = order
    c.ZIndex = 7
    c.Parent = parent
    corner(c, 8)
    padding(c, nil, 0, 0, 10, 10)
    local active = true
    local function applyState()
        tween(c, {BackgroundTransparency = active and 0.1 or 0.6})
        c.TextColor3 = active and Color3.fromRGB(255,255,255) or C.DIM
    end
    applyState()
    c.MouseButton1Click:Connect(function()
        active = not active
        applyState()
    end)
    return c, function() return active end
end

local chipUnit,    getCapUnit    = captureChip(captureRow, "UnitEvent",    C.PURPLE, 1)
local chipAbility, getCapAbility = captureChip(captureRow, "AbilityEvent", C.TEAL,   2)
local chipSkip,    getCapSkip    = captureChip(captureRow, "SkipWave",     C.BLUE,   3)
local chipAll,     getCapAll     = captureChip(captureRow, "All Remotes",  C.PINK,   4)

-- ── Section 2: Log Stats ──────────────────────────────────
local statSec = glassSection(gamePage, "Session Stats", 2)
local statRow = Instance.new("Frame")
statRow.Size = UDim2.new(1, 0, 0, 44)
statRow.BackgroundTransparency = 1
statRow.LayoutOrder = 1
statRow.ZIndex = 6
statRow.Parent = statSec
listLayout(statRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

local function statChip(parent, label, col, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 130, 1, 0)
    f.BackgroundColor3 = col
    f.BackgroundTransparency = 0.82
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.ZIndex = 6
    f.Parent = parent
    corner(f, 10)
    stroke(f, col, 1, 0.5)
    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, 0, 0, 24)
    valLbl.Position = UDim2.new(0, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = "0"
    valLbl.TextColor3 = col
    valLbl.TextSize = 18
    valLbl.Font = FONT_BOLD
    valLbl.ZIndex = 7
    valLbl.Parent = f
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.Position = UDim2.new(0, 0, 0, 26)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = C.SUBTEXT
    nameLbl.TextSize = 10
    nameLbl.Font = FONT_SEMI
    nameLbl.ZIndex = 7
    nameLbl.Parent = f
    return valLbl
end

local statTotal   = statChip(statRow, "Total Calls",   C.PURPLE, 1)
local statUnit    = statChip(statRow, "Unit Fires",    C.TEAL,   2)
local statAbility = statChip(statRow, "Ability Fires", C.PINK,   3)

-- ── Section 3: Capture Options ────────────────────────────
local optSec = glassSection(gamePage, "Logger Options", 3)
local _, getLogTimestamp = glassToggle(optSec, "Show Timestamps",     1, true)
local _, getLogStack     = glassToggle(optSec, "Show Argument Types", 2, false)
local _, getAutoScroll   = glassToggle(optSec, "Auto-Scroll Log",     3, true)

local exportBtn = pillBtn(optSec, "Copy Log to Clipboard", C.TEAL, 4)

-- ── Logger logic ──────────────────────────────────────────
local logEntries = {}
local totalCalls = 0
local unitCalls  = 0
local abilityCalls = 0
local logPaused  = false
local MAX_LOG    = 200  -- cap to avoid memory bloat

-- Color coding per remote type
local REMOTE_COLORS = {
    UnitEvent     = C.PURPLE,
    AbilityEvent  = C.TEAL,
    SkipWaveEvent = C.BLUE,
    LobbyEvent    = C.GREEN,
    SummonEvent   = C.YELLOW,
    Default       = C.DIM,
}

local function getRemoteColor(name)
    for k, col in pairs(REMOTE_COLORS) do
        if name:find(k) then return col end
    end
    return REMOTE_COLORS.Default
end

local function rgb2hex(c)
    return string.format("%02X%02X%02X",
        math.floor(c.R * 255),
        math.floor(c.G * 255),
        math.floor(c.B * 255))
end

local function appendLog(remoteName, args)
    if logPaused then return end

    -- Filter check
    local filter = filterBox.Text:lower()
    if filter ~= "" and not remoteName:lower():find(filter, 1, true) then return end

    -- Chip filters
    local isUnit    = remoteName:find("UnitEvent")
    local isAbility = remoteName:find("AbilityEvent")
    local isSkip    = remoteName:find("SkipWave")
    if not getCapAll() then
        if isUnit    and not getCapUnit()    then return end
        if isAbility and not getCapAbility() then return end
        if isSkip    and not getCapSkip()    then return end
        -- if none of the specific ones match and "All" is off, show if specifically filtered
        if not isUnit and not isAbility and not isSkip and not getCapAll() then return end
    end

    totalCalls += 1
    if isUnit    then unitCalls    += 1 end
    if isAbility then abilityCalls += 1 end

    statTotal.Text   = tostring(totalCalls)
    statUnit.Text    = tostring(unitCalls)
    statAbility.Text = tostring(abilityCalls)

    -- Build arg string
    local argParts = {}
    for i, a in ipairs(args) do
        local t = typeof(a)
        if getLogStack() then
            argParts[i] = string.format("[%s] %s", t, tostring(a):sub(1, 30))
        else
            argParts[i] = tostring(a):sub(1, 40)
        end
    end
    local argStr = table.concat(argParts, "  ·  ")

    local ts = ""
    if getLogTimestamp() then
        local t = os.clock()
        ts = string.format("[%05.1fs] ", t % 99999)
    end

    local col = getRemoteColor(remoteName)
    local shortName = remoteName:match("[^%.]+$") or remoteName

    -- Cap log length
    if #logEntries >= MAX_LOG then
        local oldest = logEntries[1]
        if oldest and oldest.Parent then oldest:Destroy() end
        table.remove(logEntries, 1)
    end

    local row = Instance.new("TextLabel")
    row.Size = UDim2.new(1, 0, 0, 16)
    row.BackgroundTransparency = 1
    row.RichText = true
    row.Text = string.format(
        '<font color="#%s"><b>%s%s</b></font>  <font color="#%s">%s</font>',
        rgb2hex(col), ts, shortName,
        rgb2hex(C.DIM), argStr ~= "" and argStr or "(no args)"
    )
    row.TextColor3 = C.DIM
    row.TextSize = 11
    row.Font = FONT_REG
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextTruncate = Enum.TextTruncate.AtEnd
    row.ZIndex = 8
    row.Parent = logFrame
    table.insert(logEntries, row)

    if getAutoScroll() then
        logFrame.CanvasPosition = Vector2.new(0, math.max(0, logFrame.AbsoluteCanvasSize.Y - logFrame.AbsoluteSize.Y))
    end
end

-- Pause toggle
local isPaused = false
pauseBtn.MouseButton1Click:Connect(function()
    isPaused = not isPaused
    logPaused = isPaused
    pauseBtn.Text = isPaused and "▶ Resume" or "⏸ Pause"
    tween(pauseBtn, {BackgroundColor3 = isPaused and C.GREEN or C.YELLOW})
end)

-- Clear
clearBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(logEntries) do
        if c and c.Parent then c:Destroy() end
    end
    logEntries = {}
    totalCalls = 0; unitCalls = 0; abilityCalls = 0
    statTotal.Text = "0"; statUnit.Text = "0"; statAbility.Text = "0"
end)

-- Export
exportBtn.MouseButton1Click:Connect(function()
    local lines = {}
    for _, row in ipairs(logEntries) do
        if row and row.Parent then
            table.insert(lines, row.Text:gsub("<[^>]+>", ""))
        end
    end
    local out = table.concat(lines, "\n")
    if setclipboard then
        setclipboard(out)
        notify("Log copied to clipboard!", true)
    else
        notify("setclipboard not available", false)
    end
end)

-- ── Hook: intercept FireServer ──────────────────────────────
local hookReady = typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function"

if hookReady then
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local name = (typeof(self) == "Instance" and self:IsA("RemoteEvent") or self:IsA("RemoteFunction"))
                and self:GetFullName()
                or tostring(self)
            task.defer(function()
                pcall(appendLog, name, {...})
            end)
        end
        return oldNC(self, ...)
    end)
    notify("Logger hook active", true)
else
    -- Fallback: poll known remotes every 0.5s by watching for changes
    -- (limited — only catches remotes we know about)
    notify("hookmetamethod unavailable — limited logging", false)
    task.spawn(function()
        -- Passive monitor: just surface known remotes as discovered
        local known = {
            UnitEvent(), AbilityEvent(), SkipWaveEvent(),
            LobbyEvent(), SummonEvent()
        }
        local logged = {}
        while true do
            task.wait(0.5)
            for _, r in ipairs(known) do
                if r and not logged[r] then
                    logged[r] = true
                    appendLog(r:GetFullName(), {"[remote discovered — hook inactive]"})
                end
            end
        end
    end)
end

end -- Game tab

-- ============================================================
-- LOBBY TAB  (placeholder — coming next)
-- ============================================================
do
local lobbyPage = tabPages["Lobby"]
local sec = glassSection(lobbyPage, "Lobby", 1)
labelTxt(sec, "Auto Summon and Claimers — coming next phase.", 1)
end

-- ============================================================
-- JOINER TAB  (placeholder)
-- ============================================================
do
local joinerPage = tabPages["Joiner"]
local sec = glassSection(joinerPage, "Stage Joiner", 1)
labelTxt(sec, "Stage / Act selector — coming next phase.", 1)
end

-- ============================================================
-- SETTINGS TAB  (placeholder)
-- ============================================================
do
local settingsPage = tabPages["Settings"]
local sec = glassSection(settingsPage, "Settings", 1)
labelTxt(sec, "Theme, keybinds, and save options — coming next phase.", 1)
end

-- ============================================================
-- BOOT
-- ============================================================
switchTab("Game")
notify("OzWare loaded", true)

-- ============================================================
-- FLOATING TOGGLE BUTTON  (bottom-left, always visible)
-- ============================================================
do
    local floatBtn = Instance.new("TextButton")
    floatBtn.Name = "OzFloat"
    floatBtn.Size = UDim2.new(0, 52, 0, 52)
    floatBtn.Position = UDim2.new(0, 16, 1, -68)
    floatBtn.AnchorPoint = Vector2.new(0, 0)
    floatBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    floatBtn.BackgroundTransparency = 0.15
    floatBtn.Text = "Oz"
    floatBtn.TextColor3 = C.PURPLE
    floatBtn.TextSize = 18
    floatBtn.Font = FONT_BOLD
    floatBtn.BorderSizePixel = 0
    floatBtn.AutoButtonColor = false
    floatBtn.ZIndex = 50
    floatBtn.Parent = gui
    corner(floatBtn, 26)
    stroke(floatBtn, Color3.fromRGB(255, 255, 255), 1.5, 0.2)

    -- Gradient sheen
    local fg = Instance.new("UIGradient")
    fg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.PURPLE),
        ColorSequenceKeypoint.new(1, C.TEAL),
    })
    fg.Rotation = 135
    fg.Parent = floatBtn

    -- Drag support
    local fDragging, fStartPos, fStartInput
    floatBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            fDragging = true; fStartPos = floatBtn.Position; fStartInput = i.Position
        end
    end)
    floatBtn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            fDragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not fDragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - fStartInput
            floatBtn.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + d.X, fStartPos.Y.Scale, fStartPos.Y.Offset + d.Y)
        end
    end)

    -- Tap to toggle window
    local pressStart, pressPos
    floatBtn.MouseButton1Down:Connect(function()
        pressStart = tick(); pressPos = floatBtn.Position
    end)
    floatBtn.MouseButton1Click:Connect(function()
        if pressStart and (tick() - pressStart) < 0.35 then
            win.Visible = not win.Visible
            tween(floatBtn, {BackgroundTransparency = win.Visible and 0.15 or 0.4})
        end
    end)
end

print("[OzWare] loaded.")
