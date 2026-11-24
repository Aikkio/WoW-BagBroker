-- Settings tab of the BagBroker window. The game options page only links here.
local _, BB = ...
local L = BB.L

local COL_W = 318
local COL2_X = 6 + COL_W + 16
local CTRL_X = 196
local ROW = 26
local styleAtLoad, localeAtLoad

local function QName(q)
    local names = { [1] = L("Common"), [2] = L("Uncommon"), [3] = L("Rare"), [4] = L("Epic") }
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and c.hex and (c.hex .. names[q] .. "|r") or names[q]
end

function BB.CreateProfile(name, copy)
    name = strtrim(name or "")
    if name == "" then BB.Print(L("enter a profile name")); return false end
    if BB.db.profiles[name] then BB.Print(L('profile "%s" already exists', name)); return false end
    local p = BB.NewProfile()
    if copy then
        for k in pairs(BB.P.always) do p.always[k] = true end
        for k in pairs(BB.P.protect) do p.protect[k] = true end
        for k, v in pairs(BB.P.rules) do p.rules[k] = v end
        for k, v in pairs(BB.P.guard) do p.guard[k] = v end
    end
    BB.db.profiles[name] = p
    BB.SetProfile(name)
    return true
end

local function DeleteProfile()
    local name = BB.profileName
    if BB.ProfileUsers(name) > 1 then BB.Print(L("profile is used by other characters - switch them first")); return end
    if #BB.ProfileList() <= 1 then BB.Print(L("this is the only profile")); return end
    BB.db.profiles[name] = nil
    if BB.db.newCharProfile == name then BB.db.newCharProfile = BB.OWN end
    local own = BB.CharKey()
    BB.db.profiles[own] = BB.db.profiles[own] or BB.NewProfile()
    BB.SetProfile(own)
end

StaticPopupDialogs.BAGBROKER_DELETE_PROFILE = {
    text = "",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function() DeleteProfile() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
}

local syncers = {}

local function Header(p, text, x, y)
    local h = BB.Text(p, "GameFontNormal")
    h:SetPoint("TOPLEFT", x, y)
    h:SetText(text)
    return h
end

local function Label(p, text, x, y, w)
    local l = BB.Text(p, "GameFontHighlight")
    l:SetPoint("TOPLEFT", x, y - 4)
    l:SetWidth(w or (CTRL_X - 10)); l:SetJustifyH("LEFT"); l:SetWordWrap(false)
    l:SetText(text)
    return l
end

-- options: a table or a function returning { {value, label}, ... }
local function Choice(p, x, y, w, options, get, set)
    local b = BB.DropButton(p, "", w, 22)
    b:SetPoint("TOPLEFT", x, y)
    local function Opts() return type(options) == "function" and options() or options end
    b:SetScript("OnClick", function(self)
        BB.OpenList(self, Opts(), get(), function(v) set(v); BB.Refresh() end)
    end)
    syncers[#syncers + 1] = function()
        local cur, label = get(), nil
        for _, o in ipairs(Opts()) do if o[1] == cur then label = o[2] end end
        b:SetText(label or tostring(cur))
        b:PaintArrow()
    end
    return b
end

-- Numeric field with a unit label to its right.
local function Number(p, x, y, unit, min, max, get, set)
    local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    eb:SetSize(40, 20)
    eb:SetPoint("TOPLEFT", x + 6, y - 1)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(3)
    eb:SetJustifyH("CENTER")
    local u = BB.Text(p, "GameFontHighlight")
    u:SetPoint("LEFT", eb, "RIGHT", 6, 0)
    u:SetText(unit)
    eb.unit = u
    local function Commit(self)
        local v = tonumber(self:GetText())
        if v then
            v = math.max(min, math.min(max, math.floor(v)))
            if v ~= get() then set(v); BB.Refresh() end
        end
        self:SetText(tostring(get()))
    end
    eb:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", Commit)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(tostring(get())); self:ClearFocus() end)
    BB.Skin("EditBox", eb)
    syncers[#syncers + 1] = function() if not eb:HasFocus() then eb:SetText(tostring(get())) end end
    return eb
end

local function Check(p, x, y, label, get, set)
    local c = BB.Check(p, label, get, function(v) set(v); BB.Refresh() end)
    c:SetPoint("TOPLEFT", x - 2, y + 1)
    syncers[#syncers + 1] = function() c:SetChecked(get() and true or false) end
    return c
end

local function NeedsReload()
    return BB.S.style ~= styleAtLoad or BB.S.locale ~= localeAtLoad
end

function BB.CreateSettingsTab(parent)
    local S = BB.S
    styleAtLoad, localeAtLoad = S.style, S.locale
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(parent:GetWidth())

    -- Left column: prices and confirmations
    local x, y = 6, -6
    Header(p, L("Prices"), x, y); y = y - 24
    Label(p, L("Auction fee"), x, y)
    Choice(p, x + CTRL_X, y, 116, { { 5, "5%" }, { 15, "15%" } },
        function() return math.floor((S.ahCut or 0.05) * 100 + 0.5) end,
        function(v) S.ahCut = v / 100 end)
    y = y - ROW
    Label(p, L("Deposit duration"), x, y)
    Choice(p, x + CTRL_X, y, 116, { { 2, L("2 hours") }, { 8, L("8 hours") }, { 24, L("24 hours") } },
        function() return S.depositHours or 8 end,
        function(v) S.depositHours = v end)
    y = y - ROW
    Label(p, L("Auction better by"), x, y)
    Number(p, x + CTRL_X - 6, y, L("silver"), 0, 999, function() return S.minGainSilver or 5 end, function(v) S.minGainSilver = v end)
    y = y - ROW
    Label(p, L("and at least"), x + 12, y, CTRL_X - 22)
    Number(p, x + CTRL_X - 6, y, "%", 0, 100, function() return S.minGainPct or 10 end, function(v) S.minGainPct = v end)
    y = y - ROW
    Label(p, L("Price goes stale after"), x, y)
    Number(p, x + CTRL_X - 6, y, L("days"), 1, 99, function() return S.staleDays or 7 end, function(v) S.staleDays = v end)
    y = y - ROW - 10

    Header(p, L("Confirmations"), x, y); y = y - 24
    Label(p, L("Delete with second click"), x, y)
    Choice(p, x + CTRL_X, y, 116, { { 1, QName(1) }, { 2, QName(2) }, { 3, QName(3) } },
        function() return S.confirmDeleteQuality or 2 end,
        function(v) S.confirmDeleteQuality = v end)
    y = y - ROW
    Label(p, L("Confirm sale from"), x, y)
    Choice(p, x + CTRL_X, y, 116, { { 2, QName(2) }, { 3, QName(3) }, { 4, QName(4) } },
        function() return S.confirmSellQuality or 3 end,
        function(v) S.confirmSellQuality = v end)
    local leftBottom = y - ROW

    -- Right column: windows, appearance, language
    x, y = COL2_X, -6
    Header(p, L("Windows"), x, y); y = y - 24
    Check(p, x, y, L("Compact window when bags are full"), function() return S.autoCompact end, function(v) S.autoCompact = v end); y = y - 26
    Check(p, x, y, L("Show in combat"), function() return S.showInCombat end, function(v) S.showInCombat = v end); y = y - 26
    Check(p, x, y, L("Merchant panel"), function() return S.merchantPanel end, function(v) S.merchantPanel = v end); y = y - 26
    Check(p, x, y, L("Minimap button"), function() return BB.MinimapShown() end, function(v) BB.SetMinimapShown(v) end); y = y - 30
    Label(p, L("Appearance"), x, y, 100)
    Choice(p, x + 110, y, 200, { { "auto", L("Auto") }, { "native", L("Like game windows") }, { "eui", L("EllesmereUI") } },
        function() return S.style or "auto" end,
        function(v) S.style = v end)
    y = y - ROW
    Label(p, L("Language"), x, y, 100)
    Choice(p, x + 110, y, 200, {
            { "auto", L("Auto (client language)") },
            { "enUS", "English" },
            { "esES", "Español" },
            { "ruRU", "Русский" },
        },
        function() return S.locale or "auto" end,
        function(v) S.locale = v end)
    y = y - ROW
    local hint = BB.Text(p, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", x, y - 5)
    hint:SetWidth(240); hint:SetJustifyH("LEFT"); hint:SetWordWrap(false)
    hint:SetText(L("Reload to apply"))
    local reload = BB.Button(p, "/reload", 60, 22)
    reload:SetPoint("TOPLEFT", x + 256, y)
    reload:SetScript("OnClick", function() ReloadUI() end)
    syncers[#syncers + 1] = function()
        local show = NeedsReload()
        reload:SetShown(show); hint:SetShown(show)
    end
    local rightBottom = y - ROW

    -- Profile, full width
    x, y = 6, math.min(leftBottom, rightBottom) - 10
    Header(p, L("Marks profile"), x, y); y = y - 24
    Label(p, L("Character profile"), x, y)
    Choice(p, x + CTRL_X, y, 240, function()
            local t = {}
            for _, n in ipairs(BB.ProfileList()) do
                local users = BB.ProfileUsers(n)
                t[#t + 1] = { n, users > 1 and (n .. "  |cff888888(" .. users .. ")|r") or n }
            end
            return t
        end,
        function() return BB.profileName end,
        function(v) if v ~= BB.profileName and BB.db.profiles[v] then BB.SetProfile(v) end end)
    y = y - ROW
    Label(p, L("New characters"), x, y)
    Choice(p, x + CTRL_X, y, 240, function()
            local t = { { BB.OWN, L("Own profile") } }
            for _, n in ipairs(BB.ProfileList()) do t[#t + 1] = { n, n } end
            return t
        end,
        function()
            local v = BB.db.newCharProfile
            return (v == BB.OWN or not BB.db.profiles[v]) and BB.OWN or v
        end,
        function(v) BB.db.newCharProfile = v end)
    y = y - ROW - 4

    local name = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    name:SetSize(180, 20)
    name:SetPoint("TOPLEFT", x + 8, y - 1)
    name:SetAutoFocus(false)
    name:SetMaxLetters(40)
    name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    name:SetScript("OnEnterPressed", function(self) if BB.CreateProfile(self:GetText(), false) then self:SetText("") end; self:ClearFocus() end)
    BB.Skin("EditBox", name)
    local ph = BB.Text(name, "GameFontDisable")
    ph:SetPoint("LEFT", 2, 0); ph:SetText(L("new profile name"))
    name:SetScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == "") end)
    local create = BB.Button(p, L("Create"), 90, 22)
    create:SetPoint("LEFT", name, "RIGHT", 8, 0)
    create:SetScript("OnClick", function() if BB.CreateProfile(name:GetText(), false) then name:SetText("") end; name:ClearFocus() end)
    local copy = BB.Button(p, L("Copy current"), 130, 22)
    copy:SetPoint("LEFT", create, "RIGHT", 4, 0)
    copy:SetScript("OnClick", function() if BB.CreateProfile(name:GetText(), true) then name:SetText("") end; name:ClearFocus() end)
    local del = BB.Button(p, L("Delete current"), 150, 22)
    del:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, y)
    del:SetScript("OnClick", function()
        StaticPopupDialogs.BAGBROKER_DELETE_PROFILE.text = L('Delete profile "%s"?')
        StaticPopup_Show("BAGBROKER_DELETE_PROFILE", BB.profileName)
    end)
    syncers[#syncers + 1] = function() del:SetEnabled(#BB.ProfileList() > 1 and BB.ProfileUsers(BB.profileName) <= 1) end
    y = y - ROW

    local height = -y + 6
    p:SetHeight(height)
    function p:Sync()
        for _, f in ipairs(syncers) do f() end
        return height
    end
    return p
end
