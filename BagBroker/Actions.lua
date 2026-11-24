-- Действия: выбросить, отметить на продажу, защитить, продать сейчас.
local _, BB = ...

-- Предмет в слоте всё ещё тот, что показан в окне?
local function SameItem(it)
    if GetCursorInfo() ~= nil then return false end
    local ci = C_Container.GetContainerItemInfo(it.bag, it.slot)
    return ci and ci.itemID == it.itemID and (ci.stackCount or 1) == it.count and not ci.isLocked
end
BB.SameItem = SameItem

local confirmUntil = {}
local function Key(it) return it.bag .. ":" .. it.slot .. ":" .. it.itemID end

function BB.NeedsConfirm(it)
    return it.quality >= (BB.S.confirmDeleteQuality or 2)
end

function BB.IsConfirming(it)
    local t = confirmUntil[Key(it)]
    return t and t > GetTime()
end

-- Возвращает true, если предмет удалён. force - подтверждение уже получено (окно-вопрос).
function BB.Delete(it, force)
    if not it or not SameItem(it) then BB.Refresh(); return false end
    if BB.P.protect[it.itemID] or it.quality > BB.QUALITY_MAX_LISTED then return false end
    if it.isQuest and BB.P.guard.quest then return false end
    if not force and BB.NeedsConfirm(it) and not BB.IsConfirming(it) then
        confirmUntil[Key(it)] = GetTime() + 3
        C_Timer.After(3.05, BB.Refresh)
        BB.Refresh()
        return false
    end
    confirmUntil[Key(it)] = nil
    C_Container.PickupContainerItem(it.bag, it.slot)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or id ~= it.itemID then ClearCursor(); return false end
    DeleteCursorItem()
    if GetCursorInfo() ~= nil then ClearCursor(); return false end
    BB.Print("выброшено: " .. (it.link or it.name) .. (it.count > 1 and (" x" .. it.count) or ""))
    BB.Refresh()
    return true
end

function BB.SetMark(itemID, mark)
    BB.P.always[itemID] = nil
    BB.cdb.once[itemID] = nil
    if mark == "always" then BB.P.always[itemID] = true
    elseif mark == "once" then BB.cdb.once[itemID] = true end
    BB.Refresh()
end

function BB.Protect(itemID, on)
    BB.P.protect[itemID] = on and true or nil
    if on then BB.P.always[itemID] = nil; BB.cdb.once[itemID] = nil end
    BB.Refresh()
end

-- Торговец открыт по событиям (а не по MerchantFrame: его могут заменить другие аддоны).
BB.merchantOpen = false
-- Если рядом открыт банк, почта, обмен или аукцион, UseContainerItem положит предмет туда, а не продаст.
local OTHER = { "BankFrame", "MailFrame", "SendMailFrame", "TradeFrame", "AuctionFrame", "AuctionHouseFrame", "GuildBankFrame" }
function BB.OtherWindowOpen()
    for _, n in ipairs(OTHER) do
        local f = _G[n]
        if f and f.IsShown and f:IsShown() then return n end
    end
end
function BB.MerchantOpen()
    return BB.merchantOpen and not BB.OtherWindowOpen()
end

function BB.SellNow(it)
    if not BB.MerchantOpen() or not SameItem(it) or it.hasNoValue then return false end
    C_Container.UseContainerItem(it.bag, it.slot)
    if BB.RecordSale then BB.RecordSale(it, "руч.") end
    BB.Refresh()
    return true
end

-- Выброс из меню: там нет второго клика, поэтому спрашиваем окном.
StaticPopupDialogs.BAGBROKER_DELETE_ITEM = {
    text = "Выбросить %s?",
    button1 = YES or "Да",
    button2 = NO or "Нет",
    OnAccept = function(self, data) BB.Delete(data or self.data, true) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
}

function BB.DeleteAsk(it)
    if not it then return end
    if BB.NeedsConfirm(it) then
        local label = (it.link or it.name or "?") .. ((it.count or 1) > 1 and (" x" .. it.count) or "")
        StaticPopup_Show("BAGBROKER_DELETE_ITEM", label, nil, it)
    else
        BB.Delete(it, true)
    end
end
