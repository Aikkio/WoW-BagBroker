-- Windows: full and compact, the Sell menu, auto-sell rules.
local _, BB = ...
local L = BB.L

local W, C, menu
local tab = "bags"
local ROW_H = 38
local WIDE_W, WIDE_H = 700, 470
local CHILD_W = 656
local COL_VENDOR = 330
local COL_AH = 344

local function QColor(q)
    local r, g, b = C_Item.GetItemQualityColor(q or 1)
    return r or 1, g or 1, b or 1
end

local function Border(frame)
    local t = {}
    for i = 1, 4 do
        local l = frame:CreateTexture(nil, "OVERLAY")
        l:SetColorTexture(0, 0, 0, 1)
        t[i] = l
    end
    t[1]:SetPoint("TOPLEFT"); t[1]:SetPoint("TOPRIGHT"); t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT"); t[2]:SetPoint("BOTTOMRIGHT"); t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT"); t[3]:SetPoint("BOTTOMLEFT"); t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT"); t[4]:SetPoint("BOTTOMRIGHT"); t[4]:SetWidth(1)
    frame.SetBorderColor = function(_, r, g, b) for i = 1, 4 do t[i]:SetColorTexture(r, g, b, 1) end end
end

local function ItemIcon(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 1, -1); b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Border(b)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -1, 2)
    b:SetScript("OnEnter", function(self)
        local it = self.item
        if not it then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if it.bag and not it.absent then GameTooltip:SetBagItem(it.bag, it.slot)
        else GameTooltip:SetItemByID(it.itemID) end
        BB.AddNotesToTooltip(GameTooltip, it)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end
BB.ItemIcon = ItemIcon

local function SetIcon(b, it)
    b.item = it
    b.tex:SetTexture(it.icon or 134400)
    b.count:SetText((it.count or 1) > 1 and it.count or "")
    if (it.quality or 1) >= 2 then b:SetBorderColor(QColor(it.quality)) else b:SetBorderColor(0, 0, 0) end
end
BB.SetItemIcon = SetIcon

local MENU_W, LINE_H = 250, 22

local function CreateMenu()
    menu = CreateFrame("Frame", "BagBrokerSellMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetSize(MENU_W, 10)
    menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    menu:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    menu:EnableMouse(true)
    menu:Hide()
    menu.lines = {}

    menu.head = BB.Text(menu, "GameFontNormal")
    menu.head:SetPoint("TOPLEFT", 12, -9)
    menu.head:SetWidth(MENU_W - 24); menu.head:SetJustifyH("LEFT"); menu.head:SetWordWrap(false)

    local function Line(i)
        local b = menu.lines[i]
        if b then return b end
        b = CreateFrame("Button", nil, menu)
        b:SetSize(MENU_W - 12, LINE_H)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.1)
        b.check = b:CreateTexture(nil, "OVERLAY")
        b.check:SetSize(14, 14)
        b.check:SetPoint("LEFT", 6, 0)
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.fs = BB.Text(b, "GameFontHighlight")
        b.fs:SetPoint("LEFT", 24, 0); b.fs:SetJustifyH("LEFT")
        b.sep = b:CreateTexture(nil, "ARTWORK")
        b.sep:SetHeight(1)
        b.sep:SetPoint("LEFT", 6, 0); b.sep:SetPoint("RIGHT", -6, 0)
        b.sep:SetColorTexture(1, 1, 1, 0.15)
        menu.lines[i] = b
        return b
    end

    -- extra: { noSellNow = true, protect = true, delete = true } - entries for the vendor panel.
    function menu:Open(owner, it, extra)
        extra = extra or {}
        local mark = BB.MarkOf(it.itemID)
        local opts = {}
        if not extra.noSellNow and BB.MerchantOpen() and not it.absent and not it.hasNoValue then
            opts[#opts + 1] = { "|cffffd100" .. L("Sell now") .. "|r", function() BB.SellNow(it) end }
            opts[#opts + 1] = { sep = true }
        end
        opts[#opts + 1] = { L("Next visit only"), function() BB.SetMark(it.itemID, mark == "once" and nil or "once") end, mark == "once" }
        opts[#opts + 1] = { L("Always sell"), function() BB.SetMark(it.itemID, mark == "always" and nil or "always") end, mark == "always" }
        if mark then
            opts[#opts + 1] = { "|cffaaaaaa" .. L("Don't sell") .. "|r", function() BB.SetMark(it.itemID, nil) end }
        end
        if extra.protect or extra.delete then opts[#opts + 1] = { sep = true } end
        if extra.protect then
            opts[#opts + 1] = { L("Protect - don't offer"), function() BB.Protect(it.itemID, true) end }
        end
        if extra.delete and not it.absent then
            opts[#opts + 1] = { "|cffff8a5c" .. L("Delete") .. "|r", function() BB.DeleteAsk(it) end }
        end

        local r, g, b = QColor(it.quality)
        self:Render(owner, opts, { title = it.name or ("item:" .. it.itemID), r = r, g = g, b = b, side = extra.side })
    end

    -- Shared rendering: entries { label, fn, checked } or { sep = true }.
    -- o: { title, r, g, b, side, width }
    function menu:Render(owner, opts, o)
        o = o or {}
        local w = o.width or MENU_W
        self:SetWidth(w)
        self.head:SetWidth(w - 24)
        self.head:SetShown(o.title ~= nil)
        if o.title then self.head:SetText(o.title); self.head:SetTextColor(o.r or 1, o.g or 0.82, o.b or 0) end
        local y = o.title and -28 or -6
        for i, o in ipairs(opts) do
            local line = Line(i)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 6, y)
            if o.sep then
                line:SetHeight(9); line:EnableMouse(false); line:SetWidth(w - 12)
                line.fs:SetText(""); line.check:Hide(); line.sep:Show()
                y = y - 9
            else
                line:SetHeight(LINE_H); line:EnableMouse(true); line:SetWidth(w - 12)
                line.sep:Hide()
                line.fs:SetText(o[1])
                line.fs:SetWidth(w - 40); line.fs:SetWordWrap(false)
                line.check:SetShown(o[3] and true or false)
                line:SetScript("OnClick", function() menu:Hide(); o[2]() end)
                y = y - LINE_H
            end
            line:Show()
        end
        for i = #opts + 1, #self.lines do self.lines[i]:Hide() end
        self:SetHeight(-y + 8)
        self:ClearAllPoints()
        if o.side then self:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
        else self:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2) end
        self.owner = owner
        self:Show()
    end
    menu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end)
    pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN")
    BB.Skin("Panel", menu)
end

local rows = {}

local function CreateRow(i)
    local r = CreateFrame("Frame", nil, W.child)
    r:SetSize(CHILD_W, ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.icon = ItemIcon(r, 30)
    r.icon:SetPoint("LEFT", 4, 0)
    r.name = BB.Text(r, "GameFontHighlight")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.name:SetWidth(228); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.tag = BB.Text(r, "GameFontNormalSmall")
    r.tag:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
    r.tag:SetWidth(228); r.tag:SetJustifyH("LEFT"); r.tag:SetWordWrap(false)
    r.vendor = BB.Text(r, "GameFontHighlightSmall")
    r.vendor:SetPoint("RIGHT", r, "LEFT", COL_VENDOR, 0); r.vendor:SetJustifyH("RIGHT")
    r.ah = BB.Text(r, "GameFontHighlightSmall")
    r.ah:SetPoint("TOPLEFT", COL_AH, -6); r.ah:SetJustifyH("LEFT")
    r.age = BB.Text(r, "GameFontDisableSmall")
    r.age:SetPoint("BOTTOMLEFT", COL_AH, 6); r.age:SetJustifyH("LEFT")

    r.shield = BB.GlyphButton(r, "shield", 24, L("Protect"))
    r.shield:SetPoint("RIGHT", -4, 0)
    r.sell = BB.DropButton(r, L("Sell"), 104, 22)
    r.sell:SetPoint("RIGHT", r.shield, "LEFT", -4, 0)
    r.trash = BB.GlyphButton(r, "trash", 24, L("Delete"))
    r.trash:SetPoint("RIGHT", r.sell, "LEFT", -4, 0)
    r.unprot = BB.Button(r, L("Remove protection"), 150, 22)
    r.unprot:SetPoint("RIGHT", -4, 0)

    r.trash:SetScript("OnClick", function() BB.Delete(r.item) end)
    r.sell:SetScript("OnClick", function(self)
        if menu:IsShown() and menu.owner == self then menu:Hide() else menu:Open(self, r.item) end
    end)
    r.shield:SetScript("OnClick", function() BB.Protect(r.item.itemID, true) end)
    r.unprot:SetScript("OnClick", function() BB.Protect(r.item.itemID, false) end)
    rows[i] = r
    return r
end

local function MarkText(mark)
    if mark == "once" then return "|cffffd100" .. L("will sell once") .. "|r" end
    if mark == "always" then return "|cffffd100" .. L("selling always") .. "|r" end
end

local function FillRow(r, it, mode)
    r.item = it
    SetIcon(r.icon, it)
    r.name:SetText(it.name or ("item:" .. it.itemID))
    r.name:SetTextColor(QColor(it.quality))
    local mark = BB.MarkOf(it.itemID)
    local parts = {}
    if mode ~= "prot" and mode ~= "guard" and MarkText(mark) then parts[#parts + 1] = MarkText(mark) end
    if it.absent then parts[#parts + 1] = "|cff888888" .. L("not in bags") .. "|r" end
    local notes = BB.NotesText(it)
    if notes ~= "" then parts[#parts + 1] = notes end
    local tag = table.concat(parts, "|cff606060  ·  |r")
    local confirming = not it.absent and mode ~= "prot" and mode ~= "guard" and BB.IsConfirming(it)
    if confirming then tag = "|cffff6040" .. L("press the trash can again") .. "|r" end
    r.tag:SetText(tag)

    if mode == "guard" then
        r.vendor:SetText("|cff888888" .. L("preset") .. "|r"); r.ah:SetText(""); r.age:SetText("")
    elseif it.absent or mode == "prot" then
        r.vendor:SetText(""); r.ah:SetText(""); r.age:SetText("")
    else
        r.vendor:SetText(it.hasNoValue and ("|cff888888" .. L("won't buy") .. "|r") or BB.Money(it.vendor))
        if it.aucWins then r.vendor:SetTextColor(0.6, 0.6, 0.6) else r.vendor:SetTextColor(1, 1, 1) end
        r.ah:SetText(it.ahNet and ((it.exact and "" or "~ ") .. BB.Money(it.ahNet)) or "|cff888888-|r")
        if it.aucWins then r.ah:SetTextColor(0.62, 0.82, 0.96) else r.ah:SetTextColor(0.6, 0.6, 0.6) end
        local txt, cr, cg, cb = BB.AgeText(it)
        r.age:SetText(txt); r.age:SetTextColor(cr, cg, cb)
    end

    local isProt, isGuard = mode == "prot", mode == "guard"
    r.unprot:SetShown(isProt)
    r.shield:SetShown(not isProt and not isGuard)
    r.sell:SetShown(not isProt and not isGuard)
    r.trash:SetShown(not isProt and not isGuard and not it.absent)
    if not isProt and not isGuard then
        r.sell:SetText(mark == "once" and L("Once") or mark == "always" and L("Always") or L("Sell"))
        r.sell:SetEnabled(not it.hasNoValue)
        r.sell:PaintArrow()
        r.shield:SetGlyphState(nil)
        r.trash.tip = confirming and L("Press again to delete") or L("Delete")
        r.trash:SetGlyphState(confirming and "danger" or nil)
    end
    r:Show()
end

-- Checkbox panel above the list: auto-sell rules ("For sale") and protection presets
-- ("Protected"). defs: { key, label [, child = { key, label }] }: the nested checkbox
-- is visible only while its parent is on. cols: number of columns.
local function CreateRulesPanel(parent, title, defs, store, cols)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(CHILD_W, 40)
    local t = BB.Text(p, "GameFontNormal")
    t:SetPoint("TOPLEFT", 6, -6)
    t:SetText(title)
    p.count = BB.Text(p, "GameFontDisableSmall")
    p.count:SetPoint("LEFT", t, "RIGHT", 10, 0)
    p.items = {}
    for i, d in ipairs(defs) do
        local c = BB.Check(p, d[2], function() return store()[d[1]] end,
            function(v) store()[d[1]] = v; BB.Refresh() end)
        c.key = d[1]
        local item = { check = c }
        if d.child then
            local sub = BB.Check(p, d.child[2], function() return store()[d.child[1]] end,
                function(v) store()[d.child[1]] = v; BB.Refresh() end)
            sub.key = d.child[1]
            item.child = sub
        end
        p.items[i] = item
    end
    local colW = math.floor((CHILD_W - 8) / (cols or 1))
    function p:Sync()
        local st = store()
        local perCol = math.ceil(#self.items / (cols or 1))
        local maxY = 0
        for i, item in ipairs(self.items) do
            local col = math.floor((i - 1) / perCol)
            if (i - 1) % perCol == 0 then self.y = -26 end
            item.check:SetChecked(st[item.check.key] and true or false)
            item.check:ClearAllPoints()
            item.check:SetPoint("TOPLEFT", 4 + col * colW, self.y)
            self.y = self.y - 24
            if item.child then
                local on = st[item.check.key] and true or false
                item.child:SetShown(on)
                if on then
                    item.child:SetChecked(st[item.child.key] and true or false)
                    item.child:ClearAllPoints()
                    item.child:SetPoint("TOPLEFT", 4 + col * colW + 24, self.y)
                    self.y = self.y - 24
                end
            end
            maxY = math.max(maxY, -self.y)
        end
        self:SetHeight(maxY + 8)
        return maxY + 8
    end
    return p
end

local function CreateSellRules(parent)
    return CreateRulesPanel(parent, L("Auto-sell rules"), {
        { "junk", L("Junk (gray items)"), child = { "junkGear", L("except equipment") } },
        { "unusable", L("Soulbound gear your class can't use") },
        { "lowGear", L("Soulbound gear 10+ levels below you") },
        { "food", L("Food, drink and potions 10+ levels below you") },
    }, function() return BB.P.rules end, 1)
end

local function CreateGuardRules(parent)
    return CreateRulesPanel(parent, L("Don't offer"), {
        { "quest", L("Quest items") },
        { "pvp", L("Honor marks and currency") },
        { "container", L("Unopened containers") },
        { "key", L("Keys") },
        { "tool", L("Profession tools") },
        { "reagent", L("Reagents for my professions") },
    }, function() return BB.P.guard end, 2)
end

local function SetTab(t)
    tab = t
    if menu then menu:Hide() end
    BB.Refresh()
end

local function CreateWide()
    W = BB.CreateWindow("BagBrokerWide", "BagBroker", WIDE_W, WIDE_H)
    BB.RestorePosition(W, "BagBrokerWide", "CENTER", nil, "CENTER", 0, 40)
    tinsert(UISpecialFrames, "BagBrokerWide")

    W.free = BB.Text(W, "GameFontHighlight")
    W.free:SetPoint("TOPLEFT", 14, -36)
    W.mode = BB.Button(W, L("Compact"), 110, 22)
    W.mode:SetPoint("TOPRIGHT", -10, -30)
    W.mode:SetScript("OnClick", function() BB.ShowWindow("compact") end)
    W.filter = BB.Segmented(W, {
        { "all", L("All") },
        { "vendor", L("To vendor") },
        { "auc", function(n) return n > 0 and L("Auction (%d)", n) or L("Auction") end },
    }, 96, function() return BB.cdb.offerFilter or "all" end, function(v) BB.cdb.offerFilter = v end)
    W.filter:SetPoint("TOPLEFT", 170, -31)
    W.status = BB.Text(W, "GameFontDisableSmall")
    W.status:SetPoint("TOPRIGHT", W.Inset, "TOPRIGHT", -30, -8)

    BB.CreateTabs(W, { { "bags", L("Bags") }, { "sell", L("For sale") }, { "prot", L("Protected") },
        { "settings", L("Settings"), right = true } }, SetTab)

    local inset = W.Inset
    local h1 = BB.Text(inset, "GameFontDisableSmall")
    h1:SetPoint("TOPLEFT", 6 + 42, -8); h1:SetText(L("ITEM, CHEAPEST FIRST"))
    local h2 = BB.Text(inset, "GameFontDisableSmall")
    h2:SetPoint("TOPRIGHT", inset, "TOPLEFT", 6 + COL_VENDOR, -8); h2:SetText(L("VENDOR"))
    local h3 = BB.Text(inset, "GameFontDisableSmall")
    h3:SetPoint("TOPLEFT", 6 + COL_AH, -8); h3:SetText(L("AUCTION, NET"))
    W.headers = { h1, h2, h3 }

    local sc = CreateFrame("ScrollFrame", "BagBrokerWideScroll", inset, "UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT", 6, -24)
    sc:SetPoint("BOTTOMRIGHT", -26, 4)
    local child = CreateFrame("Frame", nil, sc)
    child:SetSize(CHILD_W, 10)
    sc:SetScrollChild(child)
    W.scroll, W.child = sc, child
    BB.Skin("ScrollBar", sc.ScrollBar)

    W.rules = CreateSellRules(child)
    W.rules:SetPoint("TOPLEFT", 0, 0)
    W.guard = CreateGuardRules(child)
    W.guard:SetPoint("TOPLEFT", 0, 0)
    W.settings = BB.CreateSettingsTab(child)
    W.settings:SetPoint("TOPLEFT", 0, 0)
    W.empty = BB.Text(child, "GameFontDisable")
    W.empty:SetWidth(CHILD_W - 20); W.empty:SetJustifyH("LEFT")

    W.footer = BB.Text(W, "GameFontHighlightSmall")
    W.footer:SetPoint("BOTTOMLEFT", 14, 10)
    W.cheap = BB.Button(W, L("Delete cheapest item"), 230, 22)
    W.cheap:SetPoint("BOTTOMRIGHT", -8, 5)
    W.cheap:SetScript("OnClick", function() if W.first then BB.Delete(W.first) end end)

    W:SetScript("OnShow", function() BB.Refresh() end)
    W:SetScript("OnHide", function()
        if menu then menu:Hide() end
        W:SetFrameStrata("HIGH")
    end)
end

local function SellRows(items)
    local seen, out = {}, {}
    for _, it in ipairs(items) do
        if not seen[it.itemID] and BB.MarkOf(it.itemID) and not BB.P.protect[it.itemID] then
            seen[it.itemID] = true
            out[#out + 1] = it
        end
    end
    local ids = {}
    for id in pairs(BB.P.always) do ids[id] = true end
    for id in pairs(BB.cdb.once) do ids[id] = true end
    for id in pairs(ids) do
        if not seen[id] then
            local name, _, q, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
            out[#out + 1] = { itemID = id, name = name, quality = q or 1, icon = icon, count = 1, absent = true }
        end
    end
    return out
end

local function ProtRows(items, guarded)
    local seen, out = {}, {}
    for _, it in ipairs(items) do
        if BB.P.protect[it.itemID] and not seen[it.itemID] then seen[it.itemID] = true; out[#out + 1] = it end
    end
    for id in pairs(BB.P.protect) do
        if not seen[id] then
            local name, _, q, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
            out[#out + 1] = { itemID = id, name = name, quality = q or 1, icon = icon, count = 1, absent = true }
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    local gseen = {}
    for _, it in ipairs(guarded or {}) do
        if not seen[it.itemID] and not gseen[it.itemID] then
            gseen[it.itemID] = true
            it.guardRow = true
            out[#out + 1] = it
        end
    end
    return out
end

local function RefreshWide(items, list, free, total, guarded)
    W.free:SetText(L("Free: %s%d|r of %d", free == 0 and "|cffff6a4a" or "|cffffffff", free, total))
    local queue = BB.SellQueue(items)
    local qsum = 0
    for _, it in ipairs(queue) do qsum = qsum + it.vendor end

    local sellRows = SellRows(items)
    local protRows = ProtRows(items, guarded)
    local manualProt = 0
    for _, it in ipairs(protRows) do if not it.guardRow then manualProt = manualProt + 1 end end
    BB.SetTabText(W, "bags", L("Bags") .. " (" .. #list .. ")")
    BB.SetTabText(W, "sell", L("For sale") .. " (" .. #sellRows .. ")")
    BB.SetTabText(W, "prot", L("Protected") .. " (" .. manualProt .. ")")
    BB.SelectTab(W, tab)

    local scan = BB.db.lastScanTime
    W.status:SetText(BB.HasAuction() and L("Auctionator, scan %s", scan and date("%d.%m %H:%M", scan) or "-")
        or L("Auctionator not found - vendor prices only"))

    W.filter:SetShown(tab == "bags"); W.status:SetShown(tab == "bags")
    W.filter:Sync(BB.CountAuc(list))
    local data, mode = BB.FilterOffers(list, BB.cdb.offerFilter), "bag"
    if tab == "sell" then data, mode = sellRows, "sell" elseif tab == "prot" then data, mode = protRows, "prot"
    elseif tab == "settings" then data, mode = {}, "settings" end

    local y = 0
    W.rules:SetShown(tab == "sell")
    W.guard:SetShown(tab == "prot")
    W.settings:SetShown(tab == "settings")
    W.cheap:SetShown(tab ~= "settings")
    if tab == "sell" then
        local n = 0
        for _, it in ipairs(queue) do if it.reason == "rule" or it.reason == "junk" then n = n + 1 end end
        W.rules.count:SetText(n > 0 and L("will sell now: %d", n) or "")
        y = W.rules:Sync() + 4
    elseif tab == "prot" then
        W.guard.count:SetText(#(guarded or {}) > 0 and L("hidden: %d", #guarded) or "")
        y = W.guard:Sync() + 4
    elseif tab == "settings" then
        y = W.settings:Sync()
    end
    for _, h in ipairs(W.headers) do h:SetShown(tab == "bags") end
    W.scroll:SetPoint("TOPLEFT", 6, tab == "bags" and -24 or -6)

    for i, it in ipairs(data) do
        local r = rows[i] or CreateRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y - (i - 1) * ROW_H)
        FillRow(r, it, (mode == "prot" and it.guardRow) and "guard" or mode)
    end
    for i = #data + 1, #rows do rows[i]:Hide() end

    W.empty:ClearAllPoints()
    W.empty:SetPoint("TOPLEFT", 8, -y - 10)
    if #data == 0 and tab ~= "settings" then
        W.empty:SetText(tab == "prot" and L("No protected items.")
            or tab == "sell" and L("Nothing marked manually.")
            or (#list > 0 and L("Nothing here for this filter.") or L("Nothing to suggest in your bags.")))
        W.empty:Show()
    else
        W.empty:Hide()
    end
    W.child:SetHeight(math.max(10, y + #data * ROW_H))

    W.footer:SetText(L("Will sell at vendor: |cffffffff%d|r items, %s", #queue, BB.Money(qsum)))
    W.first = list[1]
    W.cheap:SetEnabled(list[1] ~= nil)
    W.cheap:SetText(list[1] and BB.IsConfirming(list[1]) and ("|cffff6040" .. L("Really delete?") .. "|r") or L("Delete cheapest item"))
end

local crow = {}
local function CreateCompact()
    C = BB.CreateWindow("BagBrokerCompact", L("Bags full"), 290, 256)
    BB.RestorePosition(C, "BagBrokerCompact", "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -280, 220)
    C.free = BB.Text(C, "GameFontHighlight")
    C.free:SetPoint("TOPLEFT", 14, -36)
    C.expand = BB.Button(C, L("Expand"), 110, 22)
    C.expand:SetPoint("TOPRIGHT", -10, -30)
    C.expand:SetScript("OnClick", function() BB.ShowWindow("wide") end)
    C.Inset:SetPoint("BOTTOMRIGHT", -6, 26)

    local big = BB.Button(C.Inset, "", 264, 42)
    big:SetPoint("TOP", 0, -6)
    local fs = big:GetFontString()
    if fs then fs:SetText("") end
    big.l1 = BB.Text(big, "GameFontNormal")
    big.l1:SetPoint("TOP", 0, -7)
    big.l2 = BB.Text(big, "GameFontHighlightSmall")
    big.l2:SetPoint("BOTTOM", 0, 7); big.l2:SetWidth(248); big.l2:SetWordWrap(false)
    big:SetScript("OnClick", function() if C.first then BB.Delete(C.first) end end)
    C.big = big

    for i = 1, 4 do
        local r = CreateFrame("Frame", nil, C.Inset)
        r:SetSize(264, 26)
        r:SetPoint("TOP", big, "BOTTOM", 0, -6 - (i - 1) * 28)
        r.icon = ItemIcon(r, 24); r.icon:SetPoint("LEFT")
        r.shield = BB.GlyphButton(r, "shield", 22, L("Protect"))
        r.shield:SetPoint("RIGHT")
        r.trash = BB.GlyphButton(r, "trash", 22, L("Delete"))
        r.trash:SetPoint("RIGHT", r.shield, "LEFT", -2, 0)
        r.price = BB.Text(r, "GameFontHighlightSmall")
        r.price:SetPoint("RIGHT", r.trash, "LEFT", -6, 0)
        r.name = BB.Text(r, "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", r.price, "LEFT", -6, 0)
        r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.trash:SetScript("OnClick", function() BB.Delete(r.item) end)
        r.shield:SetScript("OnClick", function() BB.Protect(r.item.itemID, true) end)
        crow[i] = r
    end
    C.more = CreateFrame("Button", nil, C)
    C.more:SetSize(264, 18)
    C.more:SetPoint("BOTTOMLEFT", 14, 5)
    C.more.fs = BB.Text(C.more, "GameFontNormalSmall")
    C.more.fs:SetPoint("LEFT")
    C.more:SetScript("OnEnter", function(self) self.fs:SetTextColor(1, 1, 1) end)
    C.more:SetScript("OnLeave", function(self) self.fs:SetTextColor(1, 0.82, 0) end)
    C.more:SetScript("OnClick", function() BB.ShowWindow("wide") end)
    C:SetScript("OnShow", function() BB.Refresh() end)
    C:SetScript("OnHide", function()
        if not C.quietHide then BB.dismissedAt = GetTime() end
        C.quietHide, C.auto = nil, nil
    end)
end

local function RefreshCompact(list, free, total)
    C.free:SetText(L("Free: %s%d|r of %d", free == 0 and "|cffff6a4a" or "|cffffffff", free, total))
    BB.SetTitle(C, free == 0 and L("Bags full") or "BagBroker")
    local first = list[1]
    C.first = first
    if first then
        C.big:Enable()
        C.big.l1:SetText(BB.IsConfirming(first) and ("|cffff6040" .. L("Really delete?") .. "|r") or L("Delete cheapest item"))
        local r, g, b = QColor(first.quality)
        C.big.l2:SetText(("|cff%02x%02x%02x%s|r x%d, %s"):format(r * 255, g * 255, b * 255, first.name, first.count, BB.Money(first.value)))
    else
        C.big:Disable()
        C.big.l1:SetText(L("Nothing to delete"))
        C.big.l2:SetText("")
    end
    for i = 1, 4 do
        local r, it = crow[i], list[i + 1]
        if it then
            r.item = it
            SetIcon(r.icon, it)
            r.name:SetText(it.name); r.name:SetTextColor(QColor(it.quality))
            r.price:SetText(BB.Money(it.value))
            local confirming = BB.IsConfirming(it)
            r.trash.tip = confirming and L("Press again to delete") or L("Delete")
            r.trash:SetGlyphState(confirming and "danger" or nil)
            r.shield:SetGlyphState(nil)
            r:Show()
        else
            r:Hide()
        end
    end
    local more = math.max(0, #list - 5)
    C.more.fs:SetText(more > 0 and L("%d more: sell, mark, protect  >", more) or L("Open full window  >"))
end

function BB.RefreshUI()
    local wShown, cShown = W and W:IsShown(), C and C:IsShown()
    if not (wShown or cShown) then return end
    local items = BB.ScanBags()
    local list, _, guarded = BB.Candidates(items)
    local free, total = BB.FreeSlots()
    if wShown then RefreshWide(items, list, free, total, guarded) end
    if cShown then RefreshCompact(list, free, total) end
end

function BB.ShowWindow(mode, auto)
    if mode == "compact" then
        if W:IsShown() then W:Hide() end
        BB.dismissedAt = nil
        BB.cdb.mode = auto and BB.cdb.mode or "compact"
        C.auto = auto
        C:Show()
    else
        if C:IsShown() then C.quietHide = true; C:Hide() end
        BB.cdb.mode = "wide"
        W:Show()
    end
    BB.Refresh()
end

-- above: raise the window over the game options (called from the addon page there).
function BB.ShowTab(t, above)
    tab = t
    if above then W:SetFrameStrata("DIALOG") end
    BB.ShowWindow("wide")
    if above then W:Raise() end
end

function BB.OpenOptions(above) BB.ShowTab("settings", above) end

function BB.ToggleWindow()
    if W:IsShown() or C:IsShown() then W:Hide(); C:Hide()
    else BB.ShowWindow(BB.cdb.mode == "compact" and "compact" or "wide") end
end

function BB.ResetPositions()
    BB.RestorePosition(W, "BagBrokerWide", "CENTER", nil, "CENTER", 0, 40)
    BB.RestorePosition(C, "BagBrokerCompact", "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -280, 220)
end

local lastFree
local function AutoPopup()
    if not BB.S.autoCompact or W:IsShown() or C:IsShown() then return end
    if InCombatLockdown() and not BB.S.showInCombat then return end
    if BB.dismissedAt and GetTime() - BB.dismissedAt < 60 then return end
    if BB.MerchantPanelShown and BB.MerchantPanelShown() then return end
    BB.ShowWindow("compact", true)
end

function BB.InitUI()
    CreateMenu()
    CreateWide()
    CreateCompact()
    lastFree = BB.FreeSlots()

    BB.On("BAG_UPDATE_DELAYED", function()
        local free = BB.FreeSlots()
        if free == 0 and (lastFree or 1) > 0 then AutoPopup() end
        if C.auto and C:IsShown() and free >= 2 then C.quietHide = true; C:Hide() end
        lastFree = free
        BB.Refresh()
    end)
    BB.On("UI_ERROR_MESSAGE", function(a, b)
        if (b or a) == ERR_INV_FULL then AutoPopup() end
    end)
    BB.On("GET_ITEM_INFO_RECEIVED", function()
        if BB.ScanIncomplete() then BB.Refresh() end
    end)
    BB.On("PLAYER_REGEN_DISABLED", function()
        if not BB.S.showInCombat then W:Hide(); C:Hide() end
    end)
end

function BB.OpenItemMenu(owner, it, extra)
    if menu:IsShown() and menu.owner == owner then menu:Hide() else menu:Open(owner, it, extra) end
end

-- Drop-down list under a button: options = { {value, label}, ... }.
function BB.OpenList(owner, options, current, onPick)
    if menu:IsShown() and menu.owner == owner then menu:Hide(); return end
    local opts = {}
    for _, v in ipairs(options) do
        opts[#opts + 1] = { v[2], function() onPick(v[1]) end, v[1] == current }
    end
    menu:Render(owner, opts, { width = math.max(160, math.floor(owner:GetWidth() + 0.5)) })
end
