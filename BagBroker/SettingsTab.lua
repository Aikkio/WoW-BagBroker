-- Вкладка «Настройки» в окне BagBroker. Страница в «Параметрах» игры только ведёт сюда.
local _, BB = ...

local COL_W = 318
local CTRL_X = 196
local ROW = 28
local styleAtLoad

local function QName(q)
    local name = _G["ITEM_QUALITY" .. q .. "_DESC"] or ({ [1] = "Обычное", [2] = "Необычное", [3] = "Редкое", [4] = "Эпическое" })[q]
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and c.hex and (c.hex .. name .. "|r") or name
end

function BB.CreateProfile(name, copy)
    name = strtrim(name or "")
    if name == "" then BB.Print("введи имя профиля"); return false end
    if BB.db.profiles[name] then BB.Print("профиль «" .. name .. "» уже есть"); return false end
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
    if BB.ProfileUsers(name) > 1 then BB.Print("профиль используют другие персонажи - сначала переключи их"); return end
    if #BB.ProfileList() <= 1 then BB.Print("это единственный профиль"); return end
    BB.db.profiles[name] = nil
    if BB.db.newCharProfile == name then BB.db.newCharProfile = BB.OWN end
    local own = BB.CharKey()
    BB.db.profiles[own] = BB.db.profiles[own] or BB.NewProfile()
    BB.SetProfile(own)
end

StaticPopupDialogs.BAGBROKER_DELETE_PROFILE = {
    text = "Удалить профиль «%s»?",
    button1 = DELETE or "Удалить",
    button2 = CANCEL or "Отмена",
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

local function Label(p, text, x, y)
    local l = BB.Text(p, "GameFontHighlight")
    l:SetPoint("TOPLEFT", x, y - 4)
    l:SetWidth(CTRL_X - 10); l:SetJustifyH("LEFT"); l:SetWordWrap(false)
    l:SetText(text)
    return l
end

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

function BB.CreateSettingsTab(parent)
    local S = BB.S
    styleAtLoad = S.style
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(parent:GetWidth())

    local x, y = 6, -6
    Header(p, "Цены", x, y); y = y - 24
    Label(p, "Комиссия аукциона", x, y)
    Choice(p, x + CTRL_X, y, 116, { { 5, "5%" }, { 15, "15%" } },
        function() return math.floor((S.ahCut or 0.05) * 100 + 0.5) end,
        function(v) S.ahCut = v / 100 end)
    y = y - ROW
    Label(p, "Срок для расчёта залога", x, y)
    Choice(p, x + CTRL_X, y, 116, { { 2, "2 часа" }, { 8, "8 часов" }, { 24, "24 часа" } },
        function() return S.depositHours or 8 end,
        function(v) S.depositHours = v end)
    y = y - ROW
    Label(p, "Аукцион выгоднее от", x, y)
    local silver = Number(p, x + CTRL_X - 6, y, "с", 0, 999, function() return S.minGainSilver or 5 end, function(v) S.minGainSilver = v end)
    local pct = Number(p, x + CTRL_X + 54, y, "%", 0, 100, function() return S.minGainPct or 10 end, function(v) S.minGainPct = v end)
    local both = BB.Text(p, "GameFontDisableSmall")
    both:SetPoint("LEFT", silver.unit, "RIGHT", 2, 0); both:SetText("и")
    y = y - ROW
    Label(p, "Цена устаревает через", x, y)
    Number(p, x + CTRL_X - 6, y, "дн.", 1, 99, function() return S.staleDays or 7 end, function(v) S.staleDays = v end)
    y = y - ROW - 10

    Header(p, "Подтверждения", x, y); y = y - 24
    Label(p, "Выбрасывать вторым кликом", x, y)
    Choice(p, x + CTRL_X, y, 116, { { 1, QName(1) }, { 2, QName(2) }, { 3, QName(3) } },
        function() return S.confirmDeleteQuality or 2 end,
        function(v) S.confirmDeleteQuality = v end)
    y = y - ROW
    Label(p, "Продажу подтверждать", x, y)
    Choice(p, x + CTRL_X, y, 116, { { 2, QName(2) }, { 3, QName(3) }, { 4, QName(4) } },
        function() return S.confirmSellQuality or 3 end,
        function(v) S.confirmSellQuality = v end)
    local leftBottom = y - ROW

    x, y = 6 + COL_W + 16, -6
    Header(p, "Окна", x, y); y = y - 24
    Check(p, x, y, "Компактное окно, когда сумки полны", function() return S.autoCompact end, function(v) S.autoCompact = v end); y = y - 26
    Check(p, x, y, "Показывать в бою", function() return S.showInCombat end, function(v) S.showInCombat = v end); y = y - 26
    Check(p, x, y, "Панель у торговца", function() return S.merchantPanel end, function(v) S.merchantPanel = v end); y = y - 26
    Check(p, x, y, "Кнопка у миникарты", function() return BB.MinimapShown() end, function(v) BB.SetMinimapShown(v) end); y = y - 30
    Label(p, "Оформление", x, y)
    Choice(p, x + 110, y, 140, { { "auto", "Авто" }, { "native", "Как окна игры" }, { "eui", "EllesmereUI" } },
        function() return S.style or "auto" end,
        function(v) S.style = v end)
    local reload = BB.Button(p, "/reload", 60, 22)
    reload:SetPoint("TOPLEFT", x + 256, y)
    reload:SetScript("OnClick", function() ReloadUI() end)
    syncers[#syncers + 1] = function() reload:SetShown(S.style ~= styleAtLoad) end
    local rightBottom = y - ROW

    x, y = 6, math.min(leftBottom, rightBottom) - 10
    Header(p, "Профиль отметок", x, y); y = y - 24
    Label(p, "Профиль персонажа", x, y)
    Choice(p, x + CTRL_X, y, 116 + COL_W - CTRL_X + 4, function()
            local t = {}
            for _, n in ipairs(BB.ProfileList()) do
                local users = BB.ProfileUsers(n)
                t[#t + 1] = { n, users > 1 and (n .. "  |cff888888(" .. users .. ")|r") or n }
            end
            return t
        end,
        function() return BB.profileName end,
        function(v) if v ~= BB.profileName and BB.db.profiles[v] then BB.SetProfile(v) end end)
    local x2 = 6 + COL_W + 16
    Label(p, "Новым персонажам", x2, y)
    Choice(p, x2 + 110, y, 200, function()
            local t = { { BB.OWN, "Свой профиль" } }
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
    ph:SetPoint("LEFT", 2, 0); ph:SetText("имя нового профиля")
    name:SetScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == "") end)
    local create = BB.Button(p, "Создать", 90, 22)
    create:SetPoint("LEFT", name, "RIGHT", 8, 0)
    create:SetScript("OnClick", function() if BB.CreateProfile(name:GetText(), false) then name:SetText("") end; name:ClearFocus() end)
    local copy = BB.Button(p, "Копия текущего", 130, 22)
    copy:SetPoint("LEFT", create, "RIGHT", 4, 0)
    copy:SetScript("OnClick", function() if BB.CreateProfile(name:GetText(), true) then name:SetText("") end; name:ClearFocus() end)
    local del = BB.Button(p, "Удалить текущий", 140, 22)
    del:SetPoint("TOPRIGHT", p, "TOPLEFT", 6 + 2 * COL_W + 16, y)
    del:SetScript("OnClick", function() StaticPopup_Show("BAGBROKER_DELETE_PROFILE", BB.profileName) end)
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
