-- Prices: vendor + Auctionator (checked at login), deposit, "where is it better".
local _, BB = ...

local CALLER = "BagBroker"
local ahOK = false

local function API() return Auctionator and Auctionator.API and Auctionator.API.v1 end

function BB.InitPrices()
    local api = API()
    if not (api and type(api.GetAuctionPriceByItemLink) == "function"
        and type(api.GetAuctionAgeByItemLink) == "function") then
        ahOK = false
        return
    end
    local ok = pcall(api.GetAuctionPriceByItemID, CALLER, BB.HEARTHSTONE)
    if not ok then
        ahOK = false
        return
    end
    ahOK = true
    if type(api.RegisterForDBUpdate) == "function" then
        pcall(api.RegisterForDBUpdate, CALLER, function()
            BB.db.lastScanTime = time()
            BB.Refresh()
        end)
    end
end

function BB.HasAuction() return ahOK end

-- Price per item and age in days. A provider error disables it until /reload.
function BB.AuctionInfo(link)
    if not ahOK or not link then return nil end
    local api = API()
    local ok, price = pcall(api.GetAuctionPriceByItemLink, CALLER, link)
    if not ok then ahOK = false; return nil end
    if not price or price <= 0 then return nil end
    local ok2, age = pcall(api.GetAuctionAgeByItemLink, CALLER, link)
    if not ok2 then age = nil end
    local exact = true
    if type(api.IsAuctionDataExactByItemLink) == "function" then
        local ok3, e = pcall(api.IsAuctionDataExactByItemLink, CALLER, link)
        if ok3 and e == false then exact = false end
    end
    return price, age, exact
end

-- Forever deposit: 2.5% of the vendor price per hour (8 h = 20%, 24 h = 60%).
function BB.Deposit(sellPrice, count)
    return math.floor((sellPrice or 0) * (count or 1) * 0.025 * (BB.S.depositHours or 8))
end

function BB.PriceItem(it)
    local S = BB.S
    it.vendor = (it.sellPrice or 0) * it.count
    it.ahNet, it.age, it.exact, it.fresh, it.aucWins = nil, nil, true, false, false
    if not it.isBound and not it.hasNoValueAH then
        local per, age, exact = BB.AuctionInfo(it.link)
        if per then
            it.ahNet = math.floor(per * it.count * (1 - (S.ahCut or 0.05)))
            it.age, it.exact = age, exact
            it.fresh = age ~= nil and age <= (S.staleDays or 7)
            if it.fresh then
                local gain = it.ahNet - it.vendor - BB.Deposit(it.sellPrice, it.count)
                local need = math.max((S.minGainSilver or 5) * 100, it.vendor * (S.minGainPct or 10) / 100)
                it.aucWins = gain >= need
            end
        end
    end
    it.value = it.vendor
    if it.fresh and it.ahNet and it.ahNet > it.value then it.value = it.ahNet end
end

function BB.AgeText(it)
    if not ahOK then return "", 0.6, 0.6, 0.6 end
    if it.isBound then return BB.L("personal"), 0.55, 0.55, 0.55 end
    if not it.ahNet then return BB.L("no data"), 0.55, 0.55, 0.55 end
    local age = it.age or 99
    local stale = BB.S.staleDays or 7
    if age == 0 then
        return BB.L("today"), 0.45, 0.85, 0.5
    elseif age == 1 then
        return BB.L("yesterday"), 0.45, 0.85, 0.5
    elseif age <= stale then
        return BB.L("%d d. ago", age), 0.9, 0.75, 0.35
    end
    return BB.L("%d d., stale", age), 0.95, 0.5, 0.35
end
