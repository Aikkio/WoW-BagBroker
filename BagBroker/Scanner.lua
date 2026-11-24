-- Сканер сумок: что лежит, сколько стоит, что можно предложить и что продать.
local _, BB = ...

local CLASS_ARMOR, CLASS_WEAPON, CLASS_CONSUMABLE = 4, 2, 0

local ARMOR = { -- subclass: 1 ткань, 2 кожа, 3 кольчуга, 4 латы, 6 щит
    WARRIOR = {1,2,3,4,6}, PALADIN = {1,2,3,4,6}, HUNTER = {1,2,3}, SHAMAN = {1,2,3,6},
    ROGUE = {1,2}, DRUID = {1,2}, PRIEST = {1}, MAGE = {1}, WARLOCK = {1},
}
local WEAPON = { -- 0 топор, 1 2р топор, 2 лук, 3 ружьё, 4 булава, 5 2р булава, 6 древковое, 7 меч, 8 2р меч, 10 посох, 13 кистевое, 15 кинжал, 16 метательное, 18 арбалет, 19 жезл
    WARRIOR = {0,1,2,3,4,5,6,7,8,10,13,15,16,18},
    PALADIN = {0,1,4,5,6,7,8},
    HUNTER  = {0,1,2,3,6,7,8,10,13,15,16,18},
    ROGUE   = {2,3,4,7,13,15,16,18},
    PRIEST  = {4,10,15,19},
    SHAMAN  = {0,1,4,5,10,13,15},
    MAGE    = {7,10,15,19},
    WARLOCK = {7,10,15,19},
    DRUID   = {4,5,10,13,15},
}
local function ToSet(t) local s = {} for _, v in ipairs(t) do s[v] = true end return s end
for k, v in pairs(ARMOR) do ARMOR[k] = ToSet(v) end
for k, v in pairs(WEAPON) do WEAPON[k] = ToSet(v) end

local function LastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

function BB.FreeSlots()
    local free, total = 0, 0
    for bag = 0, LastBag() do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 then
            free = free + (n or 0)
            total = total + (C_Container.GetContainerNumSlots(bag) or 0)
        end
    end
    return free, total
end

local function InEquipmentSet(bag, slot)
    local f = C_Container.GetContainerItemEquipmentSetInfo
    if type(f) ~= "function" then return false end
    local ok, inSet = pcall(f, bag, slot)
    return ok and inSet and true or false
end

function BB.ClassCanUse(it)
    local _, class = UnitClass("player")
    if it.classID == CLASS_ARMOR then
        if it.subclassID == 0 or it.subclassID == 5 or it.subclassID == 7 or it.subclassID == 8
            or it.subclassID == 9 or it.subclassID == 10 or it.subclassID == 11 then return true end
        local t = ARMOR[class]; if not t then return true end
        return t[it.subclassID] or false
    elseif it.classID == CLASS_WEAPON then
        if it.subclassID == 14 or it.subclassID == 20 then return true end
        local t = WEAPON[class]; if not t then return true end
        return t[it.subclassID] or false
    end
    return true
end

-- Сработало ли правило автопродажи; возвращает краткую причину.
function BB.RuleMatch(it)
    local R = BB.P.rules
    local isGear = it.classID == CLASS_ARMOR or it.classID == CLASS_WEAPON
    if R.junk and it.quality == 0 then
        if not (R.junkGear and isGear) then return "хлам" end
    end
    if it.quality and it.quality <= 2 and isGear and it.isBound then
        if R.unusable and not BB.ClassCanUse(it) then return "не для класса" end
        if R.lowGear and (it.reqLevel or 0) > 0 and (it.reqLevel + 10) <= UnitLevel("player") then return "низкий уровень" end
    end
    if R.food and it.classID == CLASS_CONSUMABLE and (it.subclassID == 5 or it.subclassID == 1) then
        local lvl = math.max(it.reqLevel or 0, it.itemLevel or 0)
        if lvl > 0 and (lvl + 10) <= UnitLevel("player") then return "слабая еда/зелье" end
    end
    return nil
end

local missingInfo = false
function BB.ScanBags()
    local items = {}
    missingInfo = false
    for bag = 0, LastBag() do
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local ci = C_Container.GetContainerItemInfo(bag, slot)
            if ci and ci.itemID then
                local name, _, quality, itemLevel, reqLevel, _, _, maxStack, equipLoc, icon, sellPrice, classID, subclassID =
                    C_Item.GetItemInfo(ci.hyperlink or ci.itemID)
                if not name then
                    missingInfo = true
                else
                    local q = C_Container.GetContainerItemQuestInfo(bag, slot)
                    local bound = ci.isBound
                    if bound == nil then bound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot)) end
                    local it = {
                        bag = bag, slot = slot, itemID = ci.itemID, link = ci.hyperlink, name = name,
                        quality = ci.quality or quality or 1, count = ci.stackCount or 1, icon = ci.iconFileID or icon,
                        locked = ci.isLocked, isBound = bound and true or false,
                        sellPrice = sellPrice or 0, hasNoValue = ci.hasNoValue or (sellPrice or 0) == 0,
                        classID = classID, subclassID = subclassID, reqLevel = reqLevel, itemLevel = itemLevel,
                        maxStack = maxStack, equipLoc = equipLoc,
                        isQuest = q and (q.isQuestItem or q.questID ~= nil) or false,
                        general = family == 0, hasLoot = ci.hasLoot and true or false,
                        inSet = InEquipmentSet(bag, slot),
                    }
                    BB.PriceItem(it)
                    BB.Annotate(it)
                    items[#items + 1] = it
                end
            end
        end
    end
    return items
end
function BB.ScanIncomplete() return missingInfo end

local function SortByValue(a, b)
    if a.value ~= b.value then return a.value < b.value end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    return a.count < b.count
end

function BB.Candidates(items)
    local out, prot, guarded = {}, {}, {}
    for _, it in ipairs(items) do
        if it.general and it.itemID ~= BB.HEARTHSTONE and it.quality <= BB.QUALITY_MAX_LISTED then
            if BB.P.protect[it.itemID] then prot[#prot + 1] = it
            elseif BB.GuardOf(it) then guarded[#guarded + 1] = it
            else out[#out + 1] = it end
        end
    end
    table.sort(out, SortByValue)
    table.sort(prot, SortByValue)
    table.sort(guarded, SortByValue)
    return out, prot, guarded
end

function BB.MarkOf(itemID)
    if BB.P.always[itemID] then return "always" end
    if BB.cdb.once[itemID] then return "once" end
    return nil
end

-- Что продаём у торговца: отметки + правила. Возвращает очередь и «ждёт решения».
function BB.SellQueue(items)
    local queue, pending = {}, {}
    for _, it in ipairs(items) do
        local ok = not it.isQuest and not it.hasNoValue and not it.locked
            and not BB.P.protect[it.itemID] and it.itemID ~= BB.HEARTHSTONE and not it.inSet
        local mark = BB.MarkOf(it.itemID)
        if ok and not mark and BB.GuardOf(it) then ok = false end
        if ok then
            local reason
            if mark then
                reason = mark == "always" and "∞" or "1"
            else
                local r = BB.RuleMatch(it)
                if r and not it.aucWins then reason = "П" end
                if r == "хлам" and reason then reason = "Х" end
            end
            if reason then
                it.reason = reason
                if it.quality >= (BB.S.confirmSellQuality or 3) then
                    pending[#pending + 1] = it
                else
                    queue[#queue + 1] = it
                end
            end
        end
    end
    return queue, pending
end
