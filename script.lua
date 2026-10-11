--[[
    MM2 Hub — Flagship Glass Edition

    Flow
      Wrong game : environment check card -> "Environment Mismatch" notice
                   (Discord invite copy button + anti-phishing alert)
      MM2        : loader hub (real progress + telemetry), minimize-to-pill,
                   Tic-Tac-Toe minigame

    Notes
      * Progress bar and telemetry lines report what the script actually does
        (download size, compile, run, errors). Nothing is simulated.
      * The payload host is shown in the hub so users can see what is fetched.
      * BOT_MISTAKE_CHANCE lets the Tic-Tac-Toe bot slip sometimes (0 = unbeatable).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

if not game:IsLoaded() then game.Loaded:Wait() end

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ═══ Config ═════════════════════════════════════════════════════════════════
local MM2_ID = 142823291
local SCRIPT_URL = "https://cdn.sourceb.in/bins/AhNbx38Buf/0"
local SCRIPT_HOST = "cdn.sourceb.in"
local DISCORD_URL = "https://discord.gg/KnRMYe7Kn"
local ALERT_TEXT = "SECURITY ALERT: Never enter your Roblox login credentials on external websites or fake Roblox group links! BEAM SITE ALERT!"
local BOT_MISTAKE_CHANCE = 0.15

local Theme = {
    Glass = Color3.fromRGB(24, 22, 28),
    GlassAlpha = 0.35,
    Surface = Color3.fromRGB(40, 37, 46),
    Quartz = Color3.fromRGB(236, 222, 231),
    Rose = Color3.fromRGB(205, 160, 182),
    Text = Color3.fromRGB(245, 245, 250),
    Sub = Color3.fromRGB(160, 155, 175),
    Success = Color3.fromRGB(80, 200, 140),
    Discord = Color3.fromRGB(114, 137, 218),
    Danger = Color3.fromRGB(225, 90, 110),
    White = Color3.fromRGB(255, 255, 255),
}

-- ═══ Connection tracking (cleaned up when the GUI is destroyed) ═════════════
local conns: {RBXScriptConnection} = {}
local function track(c: RBXScriptConnection): RBXScriptConnection
    table.insert(conns, c)
    return c
end
local function cleanup()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
end

-- ═══ Core helpers & object factories ════════════════════════════════════════
local function tw(o: Instance, props: {[string]: any}, t: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
    local tween = TweenService:Create(o, TweenInfo.new(t or 0.3, style or Enum.EasingStyle.Exponential, dir or Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

local function merge(base: {[string]: any}, extra: {[string]: any}?): {[string]: any}
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    if extra then for k, v in pairs(extra) do out[k] = v end end
    return out
end

local function new(className: string, parent: Instance?, props: {[string]: any}?): any
    local inst: any = Instance.new(className)
    if props then
        for k, v in pairs(props) do inst[k] = v end
    end
    inst.Parent = parent
    return inst
end

local function seq(...: number): NumberSequence
    local a = {...}
    local pts = {}
    for i = 1, #a, 2 do
        table.insert(pts, NumberSequenceKeypoint.new(a[i], a[i + 1]))
    end
    return NumberSequence.new(pts)
end

local SWEEP = seq(0, 0, 0.55, 1, 1, 1) -- comet arc used by the spinner
local SOLID = seq(0, 0, 1, 0)

local function corner(par: Instance, r: number?): UICorner
    return new("UICorner", par, {CornerRadius = UDim.new(0, r or 12)})
end

local function stroke(par: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
    return new("UIStroke", par, {
        Color = color or Theme.White,
        Thickness = thickness or 1,
        Transparency = transparency or 0.7,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

-- Hairline border with an alpha-masking gradient (bright at the top, fading down)
local function glassStroke(par: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
    local st = stroke(par, color, thickness, transparency)
    new("UIGradient", st, {Rotation = 90, Transparency = seq(0, 0, 0.5, 0.55, 1, 0.8)})
    return st
end

local function frame(par: Instance?, props: {[string]: any}?): Frame
    return new("Frame", par, merge({
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, props))
end

local function label(par: Instance?, props: {[string]: any}?): TextLabel
    return new("TextLabel", par, merge({
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = "",
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    }, props))
end

-- Inner glass card (0.45 transparency layer over the 0.35 window)
local function card(par: Instance, pos: UDim2, size: UDim2, tint: Color3?, alpha: number?, strokeColor: Color3?): Frame
    local c = frame(par, {
        Position = pos,
        Size = size,
        BackgroundColor3 = tint or Theme.Surface,
        BackgroundTransparency = alpha or 0.45,
    })
    corner(c, 12)
    glassStroke(c, strokeColor or Theme.White, 1, 0.75)
    return c
end

-- ═══ Flagship glass engine ══════════════════════════════════════════════════
-- Expects `panel` to already live inside a transparent root frame; the drop
-- shadow is built from sibling layers so it can sit behind the panel.
local function applyFlagshipGlassFx(panel: GuiObject, radius: number)
    local root = panel.Parent
    if root then
        for i = 1, 4 do
            local grow = i * 8
            local shadow = frame(root, {
                Name = "Shadow" .. i,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 5 + i * 2),
                Size = UDim2.new(1, grow, 1, grow),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.86 + i * 0.03,
                ZIndex = 1,
            })
            corner(shadow, radius + grow / 2)
        end
    end

    -- Frosted quartz veil
    local veil = frame(panel, {
        Name = "FrostVeil",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Quartz,
        BackgroundTransparency = 0.86,
        ZIndex = 1,
    })
    corner(veil, radius)
    new("UIGradient", veil, {Rotation = 90, Transparency = seq(0, 0, 0.55, 0.5, 1, 1)})

    -- Soft ambient light glow (muted rose -> lavender, diagonal)
    local glow = frame(panel, {
        Name = "AmbientGlow",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.84,
        ZIndex = 2,
    })
    corner(glow, radius)
    new("UIGradient", glow, {
        Rotation = 35,
        Color = ColorSequence.new(Theme.Rose, Theme.Sub),
        Transparency = seq(0, 0, 0.55, 0.75, 1, 1),
    })

    -- Top specular sheen
    local sheen = frame(panel, {
        Name = "TopSheen",
        Size = UDim2.new(1, 0, 0.42, 0),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.88,
        ZIndex = 3,
    })
    corner(sheen, radius)
    new("UIGradient", sheen, {Rotation = 90, Transparency = seq(0, 0, 1, 1)})

    -- High-contrast top-edge reflection
    local edge = frame(panel, {
        Name = "TopEdge",
        Position = UDim2.new(0, radius * 0.7, 0, 1),
        Size = UDim2.new(1, -radius * 1.4, 0, 1),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.15,
        ZIndex = 4,
    })
    new("UIGradient", edge, {Transparency = seq(0, 1, 0.5, 0, 1, 1)})

    -- Hairline border with alpha mask
    glassStroke(panel, Theme.White, 1.2, 0.45)
end

-- Window factory: transparent root (draggable/animatable) + glass panel + UIScale
local function glassWindow(parent: Instance, size: UDim2, pos: UDim2, radius: number, class: string?)
    local root = frame(parent, {
        Name = "Window",
        Size = size,
        Position = pos,
        BackgroundTransparency = 1,
        ZIndex = 2,
    })
    local scale = new("UIScale", root, {Scale = 1})
    local isButton = (class == "TextButton")
    local panel = new(class or "Frame", root, merge({
        Name = "Glass",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Glass,
        BackgroundTransparency = Theme.GlassAlpha,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, isButton and {Text = "", AutoButtonColor = false} or nil))
    corner(panel, radius)
    applyFlagshipGlassFx(panel, radius)
    return root, panel, scale
end

-- Button factory: holder (layout slot) + button with hover scale / fade / stroke glow
local function button(parent: Instance, size: UDim2, pos: UDim2, props: {[string]: any}, accent: Color3?, radius: number?)
    local tint = accent or Theme.Surface
    local holder = frame(parent, {
        Size = size,
        Position = pos,
        BackgroundTransparency = 1,
    })
    local btn = new("TextButton", holder, merge({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = tint,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "",
        TextSize = 12,
        TextColor3 = Theme.Text,
        ZIndex = 6,
    }, props))
    corner(btn, radius or 9)
    local st = glassStroke(btn, tint:Lerp(Theme.White, 0.55), 1, 0.7)
    local sc = new("UIScale", btn, {Scale = 1})
    local baseAlpha: number = btn.BackgroundTransparency
    local hovering = false

    btn.MouseEnter:Connect(function()
        hovering = true
        tw(sc, {Scale = 1.02}, 0.25)
        tw(btn, {BackgroundTransparency = math.max(baseAlpha - 0.18, 0.05), BackgroundColor3 = tint:Lerp(Theme.White, 0.12)}, 0.25)
        tw(st, {Transparency = 0.3, Color = Theme.White}, 0.25)
    end)
    btn.MouseLeave:Connect(function()
        hovering = false
        tw(sc, {Scale = 1}, 0.3)
        tw(btn, {BackgroundTransparency = baseAlpha, BackgroundColor3 = tint}, 0.3)
        tw(st, {Transparency = 0.7, Color = tint:Lerp(Theme.White, 0.55)}, 0.3)
    end)
    btn.MouseButton1Down:Connect(function() tw(sc, {Scale = 0.97}, 0.1) end)
    btn.MouseButton1Up:Connect(function()
        tw(sc, {Scale = hovering and 1.02 or 1}, 0.3, Enum.EasingStyle.Back)
    end)
    return btn, holder
end

-- ═══ Utilities ══════════════════════════════════════════════════════════════
local function makeDraggable(handle: GuiObject, target: GuiObject)
    local state = {Dragging = false, Moved = false}
    local startInput: Vector3 = Vector3.zero
    local startPos: UDim2 = target.Position

    handle.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state.Dragging = true
            state.Moved = false
            startInput = input.Position
            startPos = target.Position
        end
    end)
    track(UIS.InputChanged:Connect(function(input: InputObject)
        if state.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 4 then state.Moved = true end
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    track(UIS.InputEnded:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state.Dragging = false
        end
    end))
    return state
end

local function copyText(text: string): boolean
    local attempts = {
        function() setclipboard(text) end,
        function() writeclipboard(text) end,
        function() toclipboard(text) end,
    }
    for _, fn in ipairs(attempts) do
        if pcall(fn) then return true end
    end
    return false
end

local function fitFor(w: number, h: number): number
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return math.clamp(math.min((vp.X - 24) / w, (vp.Y - 24) / h), 0.5, 1)
end

-- Rotating gradient on a UIStroke = smooth comet spinner. Returns a stop function.
local function spinStroke(st: UIStroke): () -> ()
    local g = st:FindFirstChildOfClass("UIGradient") or new("UIGradient", st, {})
    g.Transparency = SWEEP
    local conn = track(RunService.RenderStepped:Connect(function(dt: number)
        g.Rotation = (g.Rotation + dt * 480) % 360
    end))
    return function()
        conn:Disconnect()
        g.Rotation = 0
        g.Transparency = SOLID
    end
end

-- ═══ Root GUI ═══════════════════════════════════════════════════════════════
for _, name in ipairs({"MM2_VerificationGui", "MM2_LoaderGui", "MM2_FlagshipHub"}) do
    local old = PG:FindFirstChild(name)
    if old then old:Destroy() end
end

local SG = new("ScreenGui", PG, {
    Name = "MM2_FlagshipHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
})
SG.Destroying:Connect(cleanup)

local function dismiss(scale: UIScale)
    tw(scale, {Scale = 0.88}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.delay(0.32, function() SG:Destroy() end)
end

-- ═══ WRONG GAME ═════════════════════════════════════════════════════════════
local function buildMismatchFlow()
    local dim = frame(SG, {
        Name = "Dim",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 7, 10),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 1,
    })
    tw(dim, {BackgroundTransparency = 0.45}, 0.7)

    -- Step 2: Environment Mismatch & Security Notice
    local function showNotice()
        local W, H = 440, 420
        local fit = fitFor(W, H)
        local root, panel, scale = glassWindow(SG, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), 18)
        root.AnchorPoint = Vector2.new(0.5, 0.5)
        scale.Scale = 0.88 * fit
        tw(scale, {Scale = fit}, 0.65, Enum.EasingStyle.Back)

        local header = frame(panel, {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1})
        makeDraggable(header, root)

        local dot = frame(header, {
            Position = UDim2.fromOffset(20, 22),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Theme.Danger,
        })
        corner(dot, 4)
        label(header, {
            Position = UDim2.fromOffset(38, 9),
            Size = UDim2.new(1, -100, 0, 20),
            Text = "Environment Mismatch",
            Font = Enum.Font.GothamBold,
            TextSize = 15,
        })
        label(header, {
            Position = UDim2.fromOffset(38, 29),
            Size = UDim2.new(1, -100, 0, 14),
            Text = "Compatibility & security notice",
            TextColor3 = Theme.Sub,
            TextSize = 11,
        })
        local closeBtn = button(header, UDim2.fromOffset(28, 28), UDim2.new(1, -44, 0, 12), {Text = "✕", TextSize = 11}, Theme.Danger, 8)
        closeBtn.MouseButton1Click:Connect(function() dismiss(scale) end)

        -- Info card
        local info = card(panel, UDim2.fromOffset(16, 58), UDim2.fromOffset(408, 104))
        label(info, {
            Position = UDim2.fromOffset(16, 12),
            Size = UDim2.new(1, -32, 0, 18),
            Text = "This hub only runs in Murder Mystery 2",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
        })
        label(info, {
            Position = UDim2.fromOffset(16, 34),
            Size = UDim2.new(1, -32, 0, 34),
            Text = "You're in a different game right now. Join Murder Mystery 2, then execute the script again from inside it.",
            TextColor3 = Theme.Sub,
            TextSize = 11.5,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        label(info, {
            Position = UDim2.fromOffset(16, 76),
            Size = UDim2.fromOffset(180, 16),
            RichText = true,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            Text = string.format('<font color="#A09BAF">Detected</font>  %d', game.PlaceId),
        })
        label(info, {
            Position = UDim2.fromOffset(212, 76),
            Size = UDim2.fromOffset(180, 16),
            RichText = true,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            Text = string.format('<font color="#A09BAF">Required</font>  %d', MM2_ID),
        })

        -- Anti-phishing alert banner
        local banner = card(panel, UDim2.fromOffset(16, 172), UDim2.fromOffset(408, 112), Theme.Danger, 0.82, Theme.Danger)
        local icon = frame(banner, {
            Position = UDim2.fromOffset(14, 14),
            Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = Theme.Danger,
            BackgroundTransparency = 0.35,
        })
        corner(icon, 15)
        label(icon, {
            Size = UDim2.fromScale(1, 1),
            Text = "!",
            Font = Enum.Font.GothamBlack,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        label(banner, {
            Position = UDim2.fromOffset(54, 12),
            Size = UDim2.new(1, -68, 0, 58),
            Text = ALERT_TEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        label(banner, {
            Position = UDim2.fromOffset(54, 74),
            Size = UDim2.new(1, -68, 0, 30),
            Text = "Roblox staff never ask for your password, .ROBLOSECURITY cookie, or 2FA code outside roblox.com.",
            TextColor3 = Theme.Sub,
            TextSize = 10.5,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })

        -- Discord gateway
        local linkBox = new("TextBox", panel, {
            Position = UDim2.fromOffset(16, 296),
            Size = UDim2.fromOffset(408, 34),
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 0.45,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = Enum.Font.GothamMedium,
            Text = DISCORD_URL,
            TextSize = 12,
            TextColor3 = Theme.Discord:Lerp(Theme.White, 0.4),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
        })
        corner(linkBox, 9)
        glassStroke(linkBox, Theme.White, 1, 0.75)
        new("UIPadding", linkBox, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
        linkBox:GetPropertyChangedSignal("Text"):Connect(function()
            if linkBox.Text ~= DISCORD_URL then linkBox.Text = DISCORD_URL end -- read-only, still selectable
        end)

        local copyBtn = button(panel, UDim2.fromOffset(408, 42), UDim2.fromOffset(16, 338), {
            Text = "Copy Discord Invite",
            TextSize = 13,
            BackgroundTransparency = 0.3,
        }, Theme.Discord, 11)
        local hint = label(panel, {
            Position = UDim2.fromOffset(16, 388),
            Size = UDim2.fromOffset(408, 16),
            Text = "Paste the invite into Discord  ›  Join Server",
            TextColor3 = Theme.Sub,
            TextSize = 10.5,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        local resetToken = 0
        copyBtn.MouseButton1Click:Connect(function()
            resetToken += 1
            local mine = resetToken
            if copyText(DISCORD_URL) then
                copyBtn.Text = "Copied to clipboard  ✓"
                tw(copyBtn, {BackgroundColor3 = Theme.Success}, 0.25)
                hint.Text = "Invite copied — paste it into Discord"
            else
                copyBtn.Text = "Clipboard unavailable"
                tw(copyBtn, {BackgroundColor3 = Theme.Danger}, 0.25)
                hint.Text = "Select the link above and copy it manually (Ctrl+C)"
            end
            task.delay(2.4, function()
                if mine ~= resetToken then return end
                copyBtn.Text = "Copy Discord Invite"
                tw(copyBtn, {BackgroundColor3 = Theme.Discord}, 0.3)
            end)
        end)
    end

    -- Step 1: environment check card (neutral, original design)
    local checkRoot, checkPanel, checkScale = glassWindow(SG, UDim2.fromOffset(340, 84), UDim2.fromScale(0.5, 0.5), 14)
    checkRoot.AnchorPoint = Vector2.new(0.5, 0.5)
    checkScale.Scale = 0.85
    tw(checkScale, {Scale = 1}, 0.65, Enum.EasingStyle.Back)

    local ring = new("TextButton", checkPanel, {
        Name = "Ring",
        Position = UDim2.fromOffset(22, 25),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 6,
    })
    corner(ring, 17)
    local ringStroke = stroke(ring, Theme.Quartz, 2, 0.3)
    new("UIGradient", ringStroke, {Transparency = SOLID})

    local checkMark = label(ring, {
        Size = UDim2.fromScale(1, 1),
        Text = "✓",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Success,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 7,
    })
    local markScale = new("UIScale", checkMark, {Scale = 1})

    label(checkPanel, {
        Position = UDim2.fromOffset(72, 22),
        Size = UDim2.new(1, -90, 0, 20),
        Text = "Environment check",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        ZIndex = 6,
    })
    local subLabel = label(checkPanel, {
        Position = UDim2.fromOffset(72, 44),
        Size = UDim2.new(1, -90, 0, 14),
        Text = "Click to confirm this game is supported",
        TextColor3 = Theme.Sub,
        TextSize = 11,
        ZIndex = 6,
    })

    ring.MouseEnter:Connect(function() tw(ringStroke, {Transparency = 0.05}, 0.2) end)
    ring.MouseLeave:Connect(function() tw(ringStroke, {Transparency = 0.3}, 0.2) end)

    local busy = false
    ring.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true
        subLabel.Text = "Checking game environment..."
        local stop = spinStroke(ringStroke)
        task.wait(1.4)
        stop()
        tw(ringStroke, {Color = Theme.Success, Transparency = 0.1}, 0.3)
        markScale.Scale = 0.3
        tw(checkMark, {TextTransparency = 0}, 0.25)
        tw(markScale, {Scale = 1}, 0.5, Enum.EasingStyle.Back)
        subLabel.Text = "Check complete"
        task.wait(0.8)
        tw(checkScale, {Scale = 0.85}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.wait(0.35)
        checkRoot:Destroy()
        showNotice()
    end)
end

-- ═══ MM2: LOADER HUB ════════════════════════════════════════════════════════
local function buildHub()
    local HUB_W, HUB_H = 360, 508
    local FIT = fitFor(HUB_W + 32, HUB_H + 70)
    local HUB_POS = UDim2.fromOffset(16, 70)

    local hubRoot, hub, hubScale = glassWindow(SG, UDim2.fromOffset(HUB_W, HUB_H), UDim2.fromOffset(-HUB_W - 40, 70), 18)
    hubScale.Scale = FIT

    local pillRoot, pillPanel, pillScale = glassWindow(SG, UDim2.fromOffset(176, 40), UDim2.fromOffset(16, 70), 20, "TextButton")
    pillRoot.Visible = false

    -- Header ----------------------------------------------------------------
    local header = frame(hub, {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1})
    makeDraggable(header, hubRoot)

    local hubDot = frame(header, {Position = UDim2.fromOffset(18, 21), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.Rose})
    corner(hubDot, 4)
    label(header, {
        Position = UDim2.fromOffset(36, 8),
        Size = UDim2.new(1, -130, 0, 20),
        Text = "MM2 Hub",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
    })
    label(header, {
        Position = UDim2.fromOffset(36, 28),
        Size = UDim2.new(1, -130, 0, 14),
        Text = "Script loader",
        TextColor3 = Theme.Sub,
        TextSize = 11,
    })
    local minBtn = button(header, UDim2.fromOffset(28, 28), UDim2.new(1, -78, 0, 11), {Text = "–", TextSize = 14}, Theme.Surface, 8)
    local closeBtn = button(header, UDim2.fromOffset(28, 28), UDim2.new(1, -44, 0, 11), {Text = "✕", TextSize = 11}, Theme.Danger, 8)

    -- Status card -----------------------------------------------------------
    local statusCard = card(hub, UDim2.fromOffset(12, 58), UDim2.fromOffset(336, 112))
    local pctLbl = label(statusCard, {
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.fromOffset(140, 28),
        Text = "0%",
        Font = Enum.Font.GothamBlack,
        TextSize = 24,
    })
    local elapsedLbl = label(statusCard, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 16),
        Size = UDim2.fromOffset(80, 18),
        Text = "0.0s",
        TextColor3 = Theme.Sub,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local statusLbl = label(statusCard, {
        Position = UDim2.fromOffset(14, 42),
        Size = UDim2.new(1, -28, 0, 16),
        Text = "Starting...",
        TextSize = 11.5,
    })
    local barBg = frame(statusCard, {
        Position = UDim2.fromOffset(14, 66),
        Size = UDim2.new(1, -28, 0, 8),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.9,
        ClipsDescendants = true,
    })
    corner(barBg, 4)
    local barFill = frame(barBg, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0,
        ZIndex = 6,
    })
    corner(barFill, 4)
    local ROSE_GRAD = ColorSequence.new(Theme.Rose, Theme.Quartz)
    local fillGrad = new("UIGradient", barFill, {Color = ROSE_GRAD})

    label(statusCard, {
        Position = UDim2.fromOffset(14, 86),
        Size = UDim2.fromOffset(220, 16),
        Text = "Source · " .. SCRIPT_HOST,
        TextColor3 = Theme.Sub,
        TextSize = 10.5,
    })
    local retryBtn, retryHolder = button(statusCard, UDim2.fromOffset(72, 24), UDim2.fromOffset(250, 78), {Text = "Retry", TextSize = 11}, Theme.Surface, 8)
    retryHolder.Visible = false

    -- Telemetry monitor -----------------------------------------------------
    local teleCard = card(hub, UDim2.fromOffset(12, 178), UDim2.fromOffset(336, 96))
    label(teleCard, {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.fromOffset(200, 14),
        Text = "TELEMETRY",
        Font = Enum.Font.GothamBold,
        TextSize = 9.5,
        TextColor3 = Theme.Sub,
    })
    local logScroll = new("ScrollingFrame", teleCard, {
        Position = UDim2.fromOffset(14, 26),
        Size = UDim2.new(1, -28, 0, 62),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ZIndex = 6,
    })
    new("UIListLayout", logScroll, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)})

    -- Minigame --------------------------------------------------------------
    label(hub, {
        Position = UDim2.fromOffset(14, 284),
        Size = UDim2.fromOffset(150, 22),
        Text = "Tic-Tac-Toe",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    })
    local gameStatus = label(hub, {
        Position = UDim2.fromOffset(160, 284),
        Size = UDim2.fromOffset(186, 22),
        Text = "You ✕  ·  Bot ○",
        TextColor3 = Theme.Sub,
        TextSize = 10.5,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local grid = frame(hub, {
        Position = UDim2.fromOffset(12, 312),
        Size = UDim2.fromOffset(336, 154),
        BackgroundTransparency = 1,
    })
    new("UIGridLayout", grid, {
        CellSize = UDim2.fromOffset(106, 46),
        CellPadding = UDim2.fromOffset(9, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    local resultLbl = label(hub, {
        Position = UDim2.fromOffset(12, 474),
        Size = UDim2.fromOffset(336, 18),
        Text = "",
        Font = Enum.Font.GothamBold,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Floating pill contents ------------------------------------------------
    local pillDot = frame(pillPanel, {Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.Rose})
    corner(pillDot, 4)
    label(pillPanel, {
        Position = UDim2.fromOffset(34, 0),
        Size = UDim2.fromOffset(80, 40),
        Text = "MM2 Hub",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    })
    local pillPct = label(pillPanel, {
        Position = UDim2.new(1, -66, 0, 0),
        Size = UDim2.fromOffset(50, 40),
        Text = "0%",
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    -- Telemetry + progress engine (reports real events only) ----------------
    local hubStart = os.clock()
    local logOrder = 0
    local function logLine(text: string, color: Color3?)
        logOrder += 1
        local ln = label(logScroll, {
            LayoutOrder = logOrder,
            Size = UDim2.new(1, -4, 0, 14),
            Font = Enum.Font.Code,
            TextSize = 10.5,
            TextColor3 = color or Theme.Sub,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextTransparency = 1,
            Text = string.format("[%05.2f] %s", os.clock() - hubStart, text),
            ZIndex = 7,
        })
        tw(ln, {TextTransparency = 0}, 0.3)
        task.delay(0.06, function()
            logScroll.CanvasPosition = Vector2.new(0, math.max(0, logScroll.AbsoluteCanvasSize.Y - logScroll.AbsoluteSize.Y))
        end)
    end

    local progress = new("NumberValue", SG, {Value = 0})
    progress.Changed:Connect(function(v: number)
        barFill.Size = UDim2.fromScale(v, 1)
        local txt = string.format("%d%%", math.floor(v * 100 + 0.5))
        pctLbl.Text = txt
        pillPct.Text = txt
    end)
    local function setProgress(p: number) tw(progress, {Value = p}, 0.6) end

    local function setStatus(text: string, color: Color3?)
        statusLbl.Text = text
        statusLbl.TextColor3 = color or Theme.Text
        statusLbl.TextTransparency = 0.8
        tw(statusLbl, {TextTransparency = 0}, 0.3)
    end
    local function setDots(color: Color3)
        tw(hubDot, {BackgroundColor3 = color}, 0.3)
        tw(pillDot, {BackgroundColor3 = color}, 0.3)
    end

    local loading = false
    local function fail(msg: string)
        loading = false
        logLine(msg, Theme.Danger)
        setStatus("Failed — see telemetry", Theme.Danger)
        fillGrad.Color = ColorSequence.new(Theme.Danger, Theme.Danger:Lerp(Theme.White, 0.25))
        setDots(Theme.Danger)
        retryHolder.Visible = true
    end

    local function runPayload()
        if loading then return end
        loading = true
        retryHolder.Visible = false
        fillGrad.Color = ROSE_GRAD
        setDots(Theme.Rose)
        tw(progress, {Value = 0}, 0.2)

        local runStart = os.clock()
        task.spawn(function()
            while loading and SG.Parent do
                elapsedLbl.Text = string.format("%.1fs", os.clock() - runStart)
                task.wait(0.1)
            end
        end)

        setStatus("Requesting script from " .. SCRIPT_HOST .. "...")
        logLine("Requesting script from " .. SCRIPT_HOST)
        setProgress(0.12)

        local okGet, src = pcall(function() return game:HttpGet(SCRIPT_URL, true) end)
        if not okGet or type(src) ~= "string" or #src == 0 then
            return fail("Download failed: " .. tostring(src))
        end
        logLine(string.format("Received %d bytes", #src))
        setStatus(string.format("Downloaded %d bytes", #src))
        setProgress(0.45)
        task.wait(0.2)

        local fn, compileErr = loadstring(src)
        if not fn then
            return fail("Compile error: " .. tostring(compileErr))
        end
        logLine("Script compiled")
        setStatus("Compiled — starting script...")
        setProgress(0.75)
        task.wait(0.2)

        -- Run in its own thread so a long-running payload cannot freeze the hub
        local reported, runErr = false, nil
        task.spawn(function()
            local ok, err = pcall(fn)
            if not ok then
                runErr = tostring(err)
                if reported then logLine("Script error: " .. runErr, Theme.Danger) end
            end
        end)
        local waited = 0
        while waited < 1.5 and not runErr do
            task.wait(0.1)
            waited += 0.1
        end
        reported = true
        if runErr then
            return fail("Script error: " .. runErr)
        end

        loading = false
        elapsedLbl.Text = string.format("%.1fs", os.clock() - runStart)
        logLine("Script is running", Theme.Success)
        setStatus("Script loaded", Theme.Success)
        setProgress(1)
        fillGrad.Color = ColorSequence.new(Theme.Success, Theme.Success:Lerp(Theme.White, 0.3))
        setDots(Theme.Success)
    end

    retryBtn.MouseButton1Click:Connect(function() task.spawn(runPayload) end)

    -- Tic-Tac-Toe -----------------------------------------------------------
    local board: {string} = {}
    local cells = {}
    local gameOver, playerTurn = false, true
    local WINS = {{1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7}}

    local function winLine(b: {string}, m: string): {number}?
        for _, w in ipairs(WINS) do
            if b[w[1]] == m and b[w[2]] == m and b[w[3]] == m then return w end
        end
        return nil
    end
    local function isFull(b: {string}): boolean
        for i = 1, 9 do if b[i] == "" then return false end end
        return true
    end
    local function minimax(b: {string}, depth: number, isMax: boolean, alpha: number, beta: number): number
        if winLine(b, "O") then return 10 - depth end
        if winLine(b, "X") then return depth - 10 end
        if isFull(b) then return 0 end
        if isMax then
            local best = -math.huge
            for i = 1, 9 do
                if b[i] == "" then
                    b[i] = "O"
                    local s = minimax(b, depth + 1, false, alpha, beta)
                    b[i] = ""
                    best = math.max(best, s)
                    alpha = math.max(alpha, best)
                    if beta <= alpha then break end
                end
            end
            return best
        else
            local best = math.huge
            for i = 1, 9 do
                if b[i] == "" then
                    b[i] = "X"
                    local s = minimax(b, depth + 1, true, alpha, beta)
                    b[i] = ""
                    best = math.min(best, s)
                    beta = math.min(beta, best)
                    if beta <= alpha then break end
                end
            end
            return best
        end
    end
    local function pickBotMove(): number?
        local empty = {}
        for i = 1, 9 do if board[i] == "" then table.insert(empty, i) end end
        if #empty == 0 then return nil end
        if math.random() < BOT_MISTAKE_CHANCE then return empty[math.random(#empty)] end
        local bestScore, bestIdx = -math.huge, empty[1]
        for _, i in ipairs(empty) do
            board[i] = "O"
            local s = minimax(board, 0, false, -math.huge, math.huge)
            board[i] = ""
            if s > bestScore then bestScore, bestIdx = s, i end
        end
        return bestIdx
    end

    local function setGameStatus(text: string, color: Color3)
        gameStatus.Text = text
        gameStatus.TextColor3 = color
    end
    local function flash(text: string, color: Color3)
        resultLbl.Text = text
        resultLbl.TextColor3 = color
        resultLbl.TextTransparency = 1
        tw(resultLbl, {TextTransparency = 0}, 0.3)
        task.delay(1.6, function() tw(resultLbl, {TextTransparency = 1}, 0.4) end)
    end
    local function placeMark(i: number, m: string)
        board[i] = m
        local c = cells[i]
        c.Text = (m == "X") and "✕" or "○"
        c.TextColor3 = (m == "X") and Theme.Rose or Theme.Discord
        c.TextSize = 10
        tw(c, {TextSize = 22}, 0.35, Enum.EasingStyle.Back)
    end
    local function resetGame()
        for i = 1, 9 do
            board[i] = ""
            cells[i].Text = ""
            cells[i].TextColor3 = Theme.Text
        end
        gameOver = false
        playerTurn = true
        setGameStatus("Your turn", Theme.Quartz)
    end
    local function endRound(text: string, color: Color3, line: {number}?)
        gameOver = true
        flash(text, color)
        setGameStatus("Round over", Theme.Sub)
        if line then
            for _, i in ipairs(line) do tw(cells[i], {TextColor3 = color}, 0.25) end
        end
        task.delay(1.9, resetGame)
    end
    local function botPlay()
        playerTurn = false
        setGameStatus("Bot is thinking...", Theme.Discord)
        task.delay(0.5, function()
            if gameOver then return end
            local m = pickBotMove()
            if m then
                placeMark(m, "O")
                local line = winLine(board, "O")
                if line then endRound("Bot wins — rematch?", Theme.Discord, line) return end
                if isFull(board) then endRound("Draw — go again", Theme.Sub) return end
            end
            playerTurn = true
            setGameStatus("Your turn", Theme.Quartz)
        end)
    end

    for i = 1, 9 do
        board[i] = ""
        local btn, holder = button(grid, UDim2.fromOffset(106, 46), UDim2.new(), {
            Text = "",
            Font = Enum.Font.GothamBlack,
            TextSize = 22,
        }, Theme.Surface, 9)
        holder.LayoutOrder = i
        cells[i] = btn
        btn.MouseButton1Click:Connect(function()
            if gameOver or not playerTurn or board[i] ~= "" then return end
            placeMark(i, "X")
            local line = winLine(board, "X")
            if line then endRound("You win!  Nice one", Theme.Success, line) return end
            if isFull(board) then endRound("Draw — go again", Theme.Sub) return end
            botPlay()
        end)
    end
    setGameStatus("Your turn", Theme.Quartz)

    -- Minimize / restore / close (spring-style tweens) ------------------------
    local minimized = false
    local pillDrag = makeDraggable(pillPanel, pillRoot)

    local function minimize()
        if minimized then return end
        minimized = true
        pillRoot.Position = hubRoot.Position
        tw(hubScale, {Scale = 0.12}, 0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
        task.delay(0.38, function()
            if not minimized then return end
            hubRoot.Visible = false
            pillRoot.Visible = true
            pillScale.Scale = 0.5
            tw(pillScale, {Scale = 1}, 0.55, Enum.EasingStyle.Back)
        end)
    end

    local function restore()
        if not minimized then return end
        minimized = false
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local ap = pillRoot.AbsolutePosition
        local x = math.clamp(ap.X, 0, math.max(vp.X - HUB_W * FIT, 0))
        local y = math.clamp(ap.Y, 0, math.max(vp.Y - HUB_H * FIT, 0))
        hubRoot.Position = UDim2.fromOffset(x, y)
        pillRoot.Visible = false
        hubRoot.Visible = true
        hubScale.Scale = 0.12
        tw(hubScale, {Scale = FIT}, 0.6, Enum.EasingStyle.Back)
    end

    minBtn.MouseButton1Click:Connect(minimize)
    closeBtn.MouseButton1Click:Connect(function() dismiss(hubScale) end)
    pillPanel.MouseButton1Click:Connect(function()
        if pillDrag.Moved then return end
        restore()
    end)
    pillPanel.MouseEnter:Connect(function() tw(pillScale, {Scale = 1.04}, 0.25) end)
    pillPanel.MouseLeave:Connect(function() tw(pillScale, {Scale = 1}, 0.3) end)

    -- Entry animation + start loading -----------------------------------------
    tw(hubRoot, {Position = HUB_POS}, 0.8, Enum.EasingStyle.Back)

    task.spawn(function()
        logLine(string.format("Hub ready · PlaceId %d", game.PlaceId))
        local okId, exName = pcall(function() return identifyexecutor and identifyexecutor() or "unknown" end)
        logLine("Executor: " .. tostring(okId and exName or "unknown"))
        task.wait(0.3)
        runPayload()
    end)
end

-- ═══ Entry point ════════════════════════════════════════════════════════════
if game.PlaceId == MM2_ID then
    buildHub()
else
    buildMismatchFlow()
end
