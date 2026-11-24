-- Внешний вид: родные шаблоны клиента + скин EllesmereUI, когда EUI красит окна игры.
local _, BB = ...

local MEDIA = "Interface\\AddOns\\BagBroker\\media\\"
BB.GLYPH = {
    shield = MEDIA .. "shield",
    trash  = MEDIA .. "trash",
    undo   = MEDIA .. "undo",
    down   = MEDIA .. "chevron_down",
    left   = MEDIA .. "chevron_left",
    right  = MEDIA .. "chevron_right",
}

local skinS
local queue = {}

local function ActiveEUILook()
    if not EllesmereUI then return nil end
    local slots = EllesmereUIDB and EllesmereUIDB.windowSkinStyleSlots
    return (type(slots) == "table" and slots.active) or "eui"
end
BB.ActiveEUILook = ActiveEUILook

local function EUIPaintsWindows()
    if not EllesmereUI then return false end
    local get = EllesmereUI.GetBlizzWindowStyle
    if type(get) == "function" then
        local ok, style = pcall(get, "merchant")
        if ok and style then return style == "eui" or style == "modern" end
    end
    local look = ActiveEUILook()
    return look == "eui" or look == "forever"
end

function BB.UseEUISkin()
    if not skinS then return false end
    local mode = BB.S and BB.S.style or "auto"
    if mode == "native" then return false end
    if mode == "eui" then return true end
    return EUIPaintsWindows()
end

function BB.StyleDescription()
    local look = ActiveEUILook()
    if not look then return "как окна игры (EllesmereUI не найден)" end
    if BB.UseEUISkin() then return "скин EllesmereUI (облик " .. look .. ")" end
    if not skinS and EUIPaintsWindows() then return "как окна игры (скины сторонних аддонов в EllesmereUI выключены)" end
    return "как окна игры (облик EllesmereUI: " .. look .. ")"
end

local function Apply(kind, obj, opts)
    if not obj or not skinS then return end
    local fn = skinS[kind]
    if type(fn) == "function" then pcall(fn, obj, opts) end
end

-- kind: Shell, Panel, Inset, Button, StateButtonLabel, CloseButton, ScrollBar, Checkbox, EditBox, Tab, Font
function BB.Skin(kind, obj, opts)
    if not obj then return end
    queue[#queue + 1] = { kind, obj, opts }
    if BB.UseEUISkin() then Apply(kind, obj, opts) end
end

function BB.SkinCall(kind, ...)
    if not BB.UseEUISkin() then return end
    local fn = skinS[kind]
    if type(fn) == "function" then pcall(fn, ...) end
end

if EllesmereUI and type(EllesmereUI.RegisterSkin) == "function" then
    EllesmereUI.RegisterSkin("BagBroker", function(S)
        if type(S) ~= "table" then return end
        skinS = S
        if not BB.UseEUISkin() then return end
        for i = 1, #queue do Apply(queue[i][1], queue[i][2], queue[i][3]) end
        if type(S.OnLooksChanged) == "function" then S.OnLooksChanged(function() if BB.Refresh then BB.Refresh() end end) end
        if BB.Refresh then BB.Refresh() end
    end)
end

function BB.GlyphColor(state)
    if state == "danger" then return 1, 0.38, 0.25 end
    if state == "dim" then return 0.45, 0.45, 0.45 end
    if state == "active" then return 1, 0.82, 0 end
    if state == "hover" then return 1, 1, 1 end
    if BB.UseEUISkin() then return 0.8, 0.8, 0.8 end
    return 1, 0.82, 0
end

function BB.Text(parent, template, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
    BB.Skin("Font", fs)
    return fs
end

local function HasTemplate(name)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
        return ok and info ~= nil
    end
    return name == "BasicFrameTemplate"
end

local function NewFrame(name)
    for _, tpl in ipairs({ "ButtonFrameTemplateNoPortrait", "ButtonFrameTemplate", "BasicFrameTemplate" }) do
        if HasTemplate(tpl) then
            local ok, f = pcall(CreateFrame, "Frame", name, UIParent, tpl)
            if ok and f then
                if tpl == "ButtonFrameTemplate" and ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
                return f, tpl
            end
        end
    end
    return CreateFrame("Frame", name, UIParent, "BackdropTemplate"), nil
end

function BB.SetTitle(f, text)
    if f.bbTitle then f.bbTitle:SetText(text)
    elseif f.SetTitle then f:SetTitle(text)
    elseif f.TitleText then f.TitleText:SetText(text) end
end

function BB.CreateWindow(name, title, w, h)
    local f = NewFrame(name)
    f:SetSize(w, h)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()

    local close = f.CloseButton
    if not close then
        close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 1)
        f.CloseButton = close
    end
    close:SetScript("OnClick", function() f:Hide() end)

    if not (f.SetTitle or f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)) then
        f.bbTitle = BB.Text(f, "GameFontNormal")
        f.bbTitle:SetPoint("TOP", 0, -6)
    end
    BB.SetTitle(f, title)

    if not f.Inset then f.Inset = CreateFrame("Frame", nil, f) end
    f.Inset:ClearAllPoints()
    f.Inset:SetPoint("TOPLEFT", 4, -58)
    f.Inset:SetPoint("BOTTOMRIGHT", -6, 30)

    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", -28, 0)
    drag:SetHeight(22)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if f:IsMovable() then f:StartMoving() end end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint(1)
        if name then BB.cdb.pos[name] = { p, rp, x, y } end
    end)
    f.drag = drag

    BB.Skin("Shell", f)
    BB.Skin("CloseButton", close)
    BB.Skin("Inset", f.Inset)
    return f
end

function BB.RestorePosition(f, name, p, rel, rp, x, y)
    f:ClearAllPoints()
    local s = BB.cdb.pos[name]
    if s then f:SetPoint(s[1], UIParent, s[2], s[3], s[4]) else f:SetPoint(p, rel or UIParent, rp, x, y) end
end

function BB.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 80, h or 22)
    b:SetText(text or "")
    BB.Skin("Button", b)
    BB.Skin("StateButtonLabel", b)
    return b
end

function BB.DropButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text or "")
    local fs = b:GetFontString()
    if fs then fs:ClearAllPoints(); fs:SetPoint("LEFT", 10, 0); fs:SetPoint("RIGHT", -20, 0); fs:SetJustifyH("LEFT") end
    local a = b:CreateTexture(nil, "OVERLAY", nil, 7)
    a:SetSize(10, 10)
    a:SetPoint("RIGHT", -8, 0)
    a:SetTexture(BB.GLYPH.down)
    b.Arrow = a
    b.PaintArrow = function(self)
        if self:IsEnabled() then self.Arrow:SetVertexColor(BB.GlyphColor()) else self.Arrow:SetVertexColor(BB.GlyphColor("dim")) end
    end
    b:HookScript("OnEnter", function(self) if self:IsEnabled() then self.Arrow:SetVertexColor(BB.GlyphColor("hover")) end end)
    b:HookScript("OnLeave", function(self) self:PaintArrow() end)
    b:PaintArrow()
    BB.Skin("Button", b, { "Arrow" })
    BB.Skin("StateButtonLabel", b)
    return b
end

function BB.GlyphButton(parent, glyph, size, tip, tipSub)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "OVERLAY", nil, 7)
    local pad = math.floor(size * 0.17 + 0.5)
    t:SetPoint("TOPLEFT", pad, -pad)
    t:SetPoint("BOTTOMRIGHT", -pad, pad)
    t:SetTexture(BB.GLYPH[glyph] or glyph)
    b.Icon = t
    b.state = nil
    b.tip, b.tipSub = tip, tipSub
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.35)
    function b:SetGlyphState(state)
        self.state = state
        if not self:IsEnabled() then self.Icon:SetVertexColor(BB.GlyphColor("dim")); return end
        self.Icon:SetVertexColor(BB.GlyphColor(state))
    end
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() and self.state ~= "danger" then self.Icon:SetVertexColor(BB.GlyphColor("hover")) end
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            if self.tipSub then GameTooltip:AddLine(self.tipSub, 0.75, 0.75, 0.75, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self:SetGlyphState(self.state); GameTooltip_Hide() end)
    b:HookScript("OnEnable", function(self) self:SetGlyphState(self.state) end)
    b:HookScript("OnDisable", function(self) self:SetGlyphState(self.state) end)
    b:SetGlyphState(nil)
    BB.Skin("Button", b, { "Icon" })
    return b
end

function BB.IconButton(parent, texture, size, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(texture)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = t
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end
    return b
end

function BB.Check(parent, label, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    local fs = BB.Text(c, "GameFontHighlight")
    fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    if c.Text then c.Text:SetText("") end
    if c.text then c.text:SetText("") end
    c.label = fs
    c:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    c:SetChecked(get() and true or false)
    BB.Skin("Checkbox", c)
    return c
end

function BB.CreateTabs(f, defs, onSelect)
    f.Tabs = {}
    local native = HasTemplate("PanelTabButtonTemplate") and PanelTemplates_SetNumTabs and PanelTemplates_SetTab
    for i, d in ipairs(defs) do
        local tab
        if native then
            tab = CreateFrame("Button", f:GetName() .. "Tab" .. i, f, "PanelTabButtonTemplate")
            tab:SetID(i)
            if d.right then tab:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -12, 2)
            elseif i == 1 then tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
            else tab:SetPoint("TOPLEFT", f.Tabs[i - 1], "TOPRIGHT", 3, 0) end
        else
            tab = BB.Button(f, "", 120, 22)
            if d.right then tab:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -12, -2)
            elseif i == 1 then tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, -2)
            else tab:SetPoint("LEFT", f.Tabs[i - 1], "RIGHT", 4, 0) end
        end
        tab.key = d[1]
        tab:SetText(d[2])
        tab:SetScript("OnClick", function() onSelect(d[1]) end)
        f.Tabs[i] = tab
        if native then BB.Skin("Tab", tab) end
    end
    f.nativeTabs = native and true or false
    if native then pcall(PanelTemplates_SetNumTabs, f, #defs) end
end

function BB.SelectTab(f, key)
    for i, tab in ipairs(f.Tabs) do
        local sel = tab.key == key
        if f.nativeTabs then
            if sel then pcall(PanelTemplates_SetTab, f, i) end
            BB.SkinCall("SetTabSelection", tab, sel)
        else
            if sel then tab:LockHighlight() else tab:UnlockHighlight() end
        end
    end
end

function BB.SetTabText(f, key, text)
    for _, tab in ipairs(f.Tabs) do
        if tab.key == key and tab:GetText() ~= text then
            tab:SetText(text)
            if f.nativeTabs and PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
        end
    end
end

-- defs: { {key, label}, ... }; label может быть функцией (для счётчиков).
function BB.Segmented(parent, defs, w, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(#defs * w + (#defs - 1) * 2, 20)
    f.buttons = {}
    for i, d in ipairs(defs) do
        local b = BB.Button(f, "", w, 20)
        b:SetPoint("LEFT", (i - 1) * (w + 2), 0)
        b:SetScript("OnClick", function() set(d[1]); BB.Refresh() end)
        b.def = d
        f.buttons[i] = b
    end
    function f:Sync(...)
        local cur = get()
        for _, b in ipairs(self.buttons) do
            local d = b.def
            local text = type(d[2]) == "function" and d[2](...) or d[2]
            if d[1] == cur then
                b:SetText("|cffffd100" .. text .. "|r"); b:LockHighlight()
            else
                b:SetText(text); b:UnlockHighlight()
            end
        end
    end
    return f
end
