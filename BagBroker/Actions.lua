-- Actions: delete, mark for sale, protect, sell now.
local _, BB = ...

-- Is the item in the slot still the one shown in the window?
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

-- Returns true if the item was deleted. force: confirmation already given (popup).
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
    BB.Print(BB.L("deleted: %s", (it.link or it.name) .. (it.count > 1 and (" x" .. it.count) or "")))
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

-- Merchant state comes from events, not MerchantFrame (other addons may replace it).
BB.merchantOpen = false
-- With a bank, mail, trade or auction window open, UseContainerItem would move the item there instead of selling it.
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
    if BB.RecordSale then BB.RecordSale(it, "manual") end
    BB.Refresh()
    return true
end

-- Deleting from a menu has no second click, so ask with a popup.
StaticPopupDialogs.BAGBROKER_DELETE_ITEM = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data) BB.Delete(data or self.data, true) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
}

function BB.DeleteAsk(it)
    if not it then return end
    if BB.NeedsConfirm(it) then
        local label = (it.link or it.name or "?") .. ((it.count or 1) > 1 and (" x" .. it.count) or "")
        StaticPopupDialogs.BAGBROKER_DELETE_ITEM.text = BB.L("Delete %s?")
        StaticPopup_Show("BAGBROKER_DELETE_ITEM", label, nil, it)
    else
        BB.Delete(it, true)
    end
end
