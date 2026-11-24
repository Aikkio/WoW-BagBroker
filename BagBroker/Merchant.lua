-- Автопродажа у торговца и панель-чек справа от его окна.
local _, BB = ...

local session
local ticker
local P, tabBtn
local prow = {}
local Verify
local pendRows = {}

local function Stop()
    if ticker then ticker:Cancel(); ticker = nil end
end

local function CountInBags(itemID)
    local n = 0
    for _, it in ipairs(BB.ScanBags()) do if it.itemID == itemID then n = n + it.count end end
    return n
end

function BB.RecordSale(it, reason)
    session = session or { sold = {}, pending = {} }
    table.insert(session.sold, {
        itemID = it.itemID, link = it.link, name = it.name, quality = it.quality, count = it.count,
        price = it.vendor, reason = reason or it.reason, bag = it.bag, slot = it.slot,
    })
    if not ticker then C_Timer.After(1.2, function() Verify(false) end) end
    BB.Refresh()
end

Verify = function(final)
    if not session then return end
    local keep, total, live = {}, 0, 0
    for _, s in ipairs(session.sold) do
        if s.returned or C_Container.GetContainerItemID(s.bag, s.slot) ~= s.itemID or s.checked then
            if not s.checked then s.after = CountInBags(s.itemID) end
            s.checked = true
            keep[#keep + 1] = s
            if not s.returned then total = total + s.price; live = live + 1 end
        end
    end
    session.sold = keep
    for id in pairs(BB.cdb.once) do
        if CountInBags(id) == 0 then BB.cdb.once[id] = nil end
    end
    if final and live > 0 and live ~= session.reportedCount then
        session.reportedCount = live
        BB.Print(("продано %d предм. на %s"):format(live, BB.Money(total)))
    end
    BB.Refresh()
end

local function Run()
    Stop()
    if not BB.MerchantOpen() then return end
    local queue, pending = BB.SellQueue(BB.ScanBags())
    session = { sold = {}, pending = pending }
    if #queue > 12 then
        BB.Print(("к продаже %d предм.: вернуть через выкуп можно будет только последние 12."):format(#queue))
    end
    local i = 0
    if #queue == 0 then BB.Refresh(); return end
    ticker = C_Timer.NewTicker(0.2, function()
        if not BB.MerchantOpen() or InCombatLockdown() or GetCursorInfo() ~= nil then Stop(); C_Timer.After(1, function() Verify(true) end); return end
        i = i + 1
        local it = queue[i]
        if not it then Stop(); C_Timer.After(1, function() Verify(true) end); return end
        if BB.SameItem(it) then
            C_Container.UseContainerItem(it.bag, it.slot)
            BB.RecordSale(it)
        end
    end)
end

local function InBuyback(link)
    for i = 1, GetNumBuybackItems() do if GetBuybackItemLink(i) == link then return i end end
end

local function DetectBuyback()
    if not session then return end
    local changed
    for _, s in ipairs(session.sold) do
        if s.checked and not s.returned and s.after and not InBuyback(s.link)
            and CountInBags(s.itemID) >= s.after + s.count then
            s.returned, changed = true, true
        end
    end
    if changed then BB.Refresh() end
end

local function Undo(s)
    if s.returned or (s.undoAt and GetTime() - s.undoAt < 2) then return end
    for i = GetNumBuybackItems(), 1, -1 do
        if GetBuybackItemLink(i) == s.link then
            s.undoAt = GetTime()
            BuybackItem(i)
            return
        end
    end
    BB.Print("не нашёл предмет во вкладке «Выкуп»: " .. (s.link or s.name))
end

local PANEL_W, ROW_W, PROW_H, PEND_H, OROW_H = 300, 276, 22, 52, 36
local panelTab
local orows = {}

local function SelectPanelTab(t)
    panelTab = t
    BB.Refresh()
end

local function CreatePanel()
    P = BB.CreateWindow("BagBrokerMerchant", "BagBroker", PANEL_W, 400)
    P:SetMovable(false)
    P.drag:Hide()
    P.CloseButton:SetScript("OnClick", function() BB.cdb.panelCollapsed = true; BB.Refresh() end)

    P.total = BB.Text(P, "GameFontHighlightLarge")
    P.total:SetPoint("LEFT", P, "TOPLEFT", 14, -44)
    P.sub = BB.Text(P, "GameFontDisableSmall")
    P.sub:SetPoint("RIGHT", P, "TOPRIGHT", -12, -44)
    P.sub:SetJustifyH("RIGHT")

    BB.CreateTabs(P, { { "sold", "Автопродажа" }, { "offer", "Предложения" } }, SelectPanelTab)

    local sv = CreateFrame("Frame", nil, P.Inset)
    sv:SetAllPoints()
    P.soldView = sv
    P.more = BB.Text(sv, "GameFontDisableSmall")
    P.empty = BB.Text(sv, "GameFontNormal")
    P.empty:SetPoint("TOPLEFT", 10, -12)
    P.empty:SetPoint("TOPRIGHT", -10, -12)
    P.empty:SetJustifyH("LEFT")
    P.toOffers = BB.Button(sv, "К предложениям", 160, 22)
    P.toOffers:SetPoint("TOPLEFT", P.empty, "BOTTOMLEFT", 0, -10)
    P.toOffers:SetScript("OnClick", function() SelectPanelTab("offer") end)

    P.undoAll = BB.Button(P, "Вернуть всё", 110, 22)
    P.undoAll:SetPoint("BOTTOMRIGHT", -8, 5)
    P.undoAll:SetScript("OnClick", function()
        if session then for _, s in ipairs(session.sold) do Undo(s) end end
    end)

    local ov = CreateFrame("Frame", nil, P.Inset)
    ov:SetAllPoints()
    P.offerView = ov
    P.filter = BB.Segmented(ov, {
        { "all", "Все" },
        { "vendor", "Торговцу" },
        { "auc", function(n) return n > 0 and ("Аукцион (" .. n .. ")") or "Аукцион" end },
    }, 88, function() return BB.cdb.offerFilter or "all" end, function(v) BB.cdb.offerFilter = v end)
    P.filter:SetPoint("TOP", 0, -6)
    P.oEmpty = BB.Text(ov, "GameFontDisable")
    P.oEmpty:SetPoint("TOPLEFT", 10, -40)
    P.oEmpty:SetPoint("TOPRIGHT", -10, -40)
    P.oEmpty:SetJustifyH("LEFT")
    P.oMore = BB.Text(ov, "GameFontDisableSmall")

    P.full = BB.Button(P, "Полное окно", 120, 22)
    P.full:SetPoint("BOTTOMRIGHT", -8, 5)
    P.full:SetScript("OnClick", function() BB.ShowTab("bags") end)

    tabBtn = BB.IconButton(UIParent, "Interface\\Icons\\INV_Misc_Bag_08", 30, nil)
    tabBtn:SetFrameStrata("HIGH")
    tabBtn:Hide()
    tabBtn:SetScript("OnClick", function() BB.cdb.panelCollapsed = false; BB.Refresh() end)
    tabBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("BagBroker")
        GameTooltip:AddLine(self.tip or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    tabBtn:SetScript("OnLeave", GameTooltip_Hide)
end

local function Row(i)
    local r = prow[i]
    if r then return r end
    r = CreateFrame("Frame", nil, P.soldView)
    r:SetSize(ROW_W, PROW_H)
    r.icon = BB.ItemIcon(r, 18)
    r.icon:SetPoint("LEFT", 2, 0)
    r.undo = BB.GlyphButton(r, "undo", 20, "Выкупить обратно")
    r.undo:SetPoint("RIGHT")
    r.price = BB.Text(r, "GameFontHighlightSmall")
    r.price:SetPoint("RIGHT", r.undo, "LEFT", -4, 0)
    r.name = BB.Text(r, "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r.price, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    prow[i] = r
    return r
end

local function PendRow(i)
    local r = pendRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, P.soldView)
    r:SetSize(ROW_W, PEND_H - 4)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 0.82, 0, 0.06)
    r.label = BB.Text(r, "GameFontNormalSmall")
    r.label:SetPoint("TOPLEFT", 6, -4)
    r.label:SetText("Ждёт решения")
    r.name = BB.Text(r, "GameFontHighlightSmall")
    r.name:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 6, 0)
    r.name:SetPoint("RIGHT", -6, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.sell = BB.Button(r, "Продать", 128, 20)
    r.sell:SetPoint("BOTTOMLEFT", 4, 4)
    r.keep = BB.Button(r, "Оставить", 128, 20)
    r.keep:SetPoint("BOTTOMRIGHT", -4, 4)
    pendRows[i] = r
    return r
end

local function OfferRow(i)
    local r = orows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, P.offerView)
    r:SetSize(ROW_W, OROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.icon = BB.ItemIcon(r, 28)
    r.icon:SetPoint("LEFT", 2, 0)
    r.more = BB.GlyphButton(r, "down", 22)
    r.more:SetPoint("RIGHT", 0, 0)
    r.act = BB.Button(r, "Продать", 82, 22)
    r.act:SetPoint("RIGHT", r.more, "LEFT", -3, 0)
    r.name = BB.Text(r, "GameFontHighlightSmall")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -2)
    r.name:SetPoint("RIGHT", r.act, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.info = BB.Text(r, "GameFontHighlightSmall")
    r.info:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 2)
    r.info:SetPoint("RIGHT", r.act, "LEFT", -6, 0)
    r.info:SetJustifyH("LEFT"); r.info:SetWordWrap(false)
    r.act:SetScript("OnClick", function()
        local it = r.item
        if not it then return end
        if it.hasNoValue then BB.Delete(it) else BB.SellNow(it) end
    end)
    r.more:SetScript("OnClick", function(self)
        if r.item then BB.OpenItemMenu(self, r.item, { noSellNow = true, protect = true, delete = true, side = true }) end
    end)
    orows[i] = r
    return r
end

local REASON = { ["1"] = "1", ["∞"] = "всегда", ["Х"] = "хлам", ["П"] = "правило", ["руч."] = "вручную" }

local function FillSold(sold, pending, live)
    local isEmpty = #sold == 0 and #pending == 0
    P.empty:SetShown(isEmpty); P.toOffers:SetShown(isEmpty)
    if isEmpty then P.empty:SetText(ticker and "Продаю..." or "Продавать нечего") end

    local y = -6
    local maxRows = math.floor((P:GetHeight() - 88 - 12 - #pending * PEND_H - 18) / PROW_H)
    for i, s in ipairs(sold) do
        local r = Row(i)
        if i <= maxRows then
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y)
            local cr, cg, cb = C_Item.GetItemQualityColor(s.quality or 1)
            BB.SetItemIcon(r.icon, { itemID = s.itemID, icon = C_Item.GetItemIconByID(s.itemID), quality = s.quality, count = 1, absent = true })
            r.icon:SetAlpha(s.returned and 0.4 or 1)
            r.name:SetText(s.name .. (s.count > 1 and (" x" .. s.count) or ""))
            r.name:SetTextColor(cr, cg, cb, s.returned and 0.4 or 1)
            r.price:SetText(s.returned and "|cff888888возвращён|r" or BB.Money(s.price))
            r.undo:SetShown(not s.returned)
            r.undo:SetEnabled(not (s.undoAt and GetTime() - s.undoAt < 2))
            r.undo:SetScript("OnClick", function() Undo(s) end)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if s.link then GameTooltip:SetHyperlink(s.link) end
                GameTooltip:AddLine("Причина: " .. (REASON[s.reason] or "-"), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", GameTooltip_Hide)
            r:EnableMouse(true)
            r:Show()
            y = y - PROW_H
        else
            r:Hide()
        end
    end
    for i = #sold + 1, #prow do prow[i]:Hide() end
    local hidden = #sold - maxRows
    if hidden > 0 then
        P.more:ClearAllPoints(); P.more:SetPoint("TOPLEFT", 10, y - 2)
        P.more:SetText("и ещё " .. hidden .. "..."); P.more:Show(); y = y - 18
    else
        P.more:Hide()
    end

    y = y - 8
    for i, it in ipairs(pending) do
        local r = PendRow(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y)
        local cr, cg, cb = C_Item.GetItemQualityColor(it.quality or 3)
        r.name:SetText(("|cff%02x%02x%02x%s|r: %s"):format(cr * 255, cg * 255, cb * 255, it.name, BB.Money(it.vendor)))
        r.sell:SetScript("OnClick", function()
            if BB.SameItem(it) and BB.MerchantOpen() then
                C_Container.UseContainerItem(it.bag, it.slot)
                table.remove(session.pending, i)
                BB.RecordSale(it)
            end
        end)
        r.keep:SetScript("OnClick", function() table.remove(session.pending, i); BB.Refresh() end)
        r:Show()
        y = y - PEND_H
    end
    for i = #pending + 1, #pendRows do pendRows[i]:Hide() end
    P.undoAll:SetEnabled(live > 0)
end

local function FillOffers(all)
    P.filter:Sync(BB.CountAuc(all))
    local list = BB.FilterOffers(all, BB.cdb.offerFilter)
    local maxRows = math.floor((P:GetHeight() - 88 - 12 - 18 - 28) / OROW_H)
    local y = -32
    for i, it in ipairs(list) do
        local r = OfferRow(i)
        if i <= maxRows then
            r.item = it
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, y)
            BB.SetItemIcon(r.icon, it)
            local qr, qg, qb = C_Item.GetItemQualityColor(it.quality or 1)
            r.name:SetText(it.name)
            r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            local price = it.hasNoValue and "|cff888888не купит|r" or BB.Money(it.vendor)
            local notes = BB.NotesText(it)
            r.info:SetText(notes ~= "" and (price .. "|cff606060  ·  |r" .. notes) or price)
            local mark = BB.MarkOf(it.itemID)
            if it.hasNoValue then
                r.act:SetText(BB.IsConfirming(it) and "|cffff6040Точно?|r" or "Выбросить")
            else
                r.act:SetText(mark and "Продать |cffffd100*|r" or "Продать")
            end
            r.more:SetGlyphState(nil)
            r:Show()
            y = y - OROW_H
        else
            r:Hide()
        end
    end
    for i = #list + 1, #orows do orows[i]:Hide() end
    P.oEmpty:SetShown(#list == 0)
    P.oEmpty:SetText(#all == 0 and "Нечего предложить." or "В этом фильтре пусто.")
    local hidden = #list - maxRows
    if hidden > 0 then
        P.oMore:ClearAllPoints(); P.oMore:SetPoint("TOPLEFT", 10, y - 4)
        P.oMore:SetText("и ещё " .. hidden .. " - в полном окне"); P.oMore:Show()
    else
        P.oMore:Hide()
    end
end

function BB.MerchantPanelShown()
    return BB.S.merchantPanel and BB.MerchantOpen()
end

function BB.RefreshMerchantPanel()
    if not P then return end
    if not (BB.S.merchantPanel and BB.MerchantOpen()) then
        P:Hide(); tabBtn:Hide(); return
    end
    local sold = session and session.sold or {}
    local pending = session and session.pending or {}
    local total, live = 0, 0
    for _, s in ipairs(sold) do if not s.returned then total = total + s.price; live = live + 1 end end
    local list = BB.Candidates(BB.ScanBags())
    tabBtn.tip = ("продано %d предм. на %s\nпредложений: %d"):format(live, BB.Money(total), #list)
    local anchor = MerchantFrame and MerchantFrame:IsShown() and MerchantFrame or nil

    if BB.cdb.panelCollapsed then
        P:Hide()
        tabBtn:ClearAllPoints()
        if anchor then tabBtn:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, -40)
        else tabBtn:SetPoint("LEFT", UIParent, "LEFT", 420, 120) end
        tabBtn:Show()
        return
    end
    tabBtn:Hide()
    P:ClearAllPoints()
    if anchor then
        P:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, 0)
        P:SetHeight(math.max(320, anchor:GetHeight()))
    else
        P:SetPoint("LEFT", UIParent, "LEFT", 420, 0)
        P:SetHeight(420)
    end
    P:Show()

    local t = panelTab or "sold"
    BB.SetTabText(P, "sold", live > 0 and ("Автопродажа (" .. live .. ")") or "Автопродажа")
    BB.SetTabText(P, "offer", "Предложения (" .. #list .. ")")
    BB.SelectTab(P, t)

    local isSold = t == "sold"
    P.soldView:SetShown(isSold); P.offerView:SetShown(not isSold)
    P.undoAll:SetShown(isSold)
    P.full:SetShown(not isSold)
    if isSold then
        P.total:SetFontObject(GameFontHighlightLarge)
        P.total:SetText("+" .. BB.Money(total))
        P.sub:SetText(("продано %d предм."):format(live))
        FillSold(sold, pending, live)
    else
        local free, all = BB.FreeSlots()
        P.total:SetFontObject(GameFontHighlight)
        P.total:SetText(("Свободно: %s%d|r из %d"):format(free == 0 and "|cffff6a4a" or "|cffffffff", free, all))
        P.sub:SetText("")
        FillOffers(list)
    end
end

function BB.InitMerchant()
    CreatePanel()
    BB.On("MERCHANT_SHOW", function()
        BB.merchantOpen = true
        session = { sold = {}, pending = {} }
        local queue, pending = BB.SellQueue(BB.ScanBags())
        panelTab = (#queue + #pending > 0) and "sold" or "offer"
        BB.Refresh()
        C_Timer.After(0.3, Run)
    end)
    BB.On("BAG_UPDATE_DELAYED", DetectBuyback)
    BB.On("MERCHANT_CLOSED", function()
        BB.merchantOpen = false
        Stop()
        if session then Verify(true) end
        session = nil
        BB.Refresh()
    end)
    BB.On("PLAYER_REGEN_DISABLED", Stop)
end
