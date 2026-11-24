-- Item notes ("quest item", "for: Tailoring", "worse than equipped"...)
-- and the protection presets built on them.
local _, BB = ...
local L = BB.L

local CLASS_CONSUMABLE, CLASS_WEAPON, CLASS_ARMOR = 0, 2, 4
local CLASS_TRADEGOODS, CLASS_CURRENCY, CLASS_QUEST, CLASS_KEY = 7, 10, 12, 13
local WEAPON_FISHING = 20

local COLOR = { guard = "ffd100", good = "6fd16f", bad = "ff8a5c", info = "a0a0a0", auc = "9ed1f5" }

local PROF = { -- skillLine -> { enUS, esES, ruRU } names (default labels and lookup for the old skills API)
    [129] = { "First Aid", "Primeros auxilios", "Первая помощь" },
    [164] = { "Blacksmithing", "Herrería", "Кузнечное дело" },
    [165] = { "Leatherworking", "Peletería", "Кожевничество" },
    [171] = { "Alchemy", "Alquimia", "Алхимия" },
    [182] = { "Herbalism", "Herboristería", "Травничество" },
    [185] = { "Cooking", "Cocina", "Кулинария" },
    [186] = { "Mining", "Minería", "Горное дело" },
    [197] = { "Tailoring", "Sastrería", "Портняжное дело" },
    [202] = { "Engineering", "Ingeniería", "Инженерное дело" },
    [333] = { "Enchanting", "Encantamiento", "Наложение чар" },
    [356] = { "Fishing", "Pesca", "Рыбная ловля" },
    [393] = { "Skinning", "Desuello", "Снятие шкур" },
    [755] = { "Jewelcrafting", "Joyería", "Ювелирное дело" },
    [773] = { "Inscription", "Inscripción", "Начертание" },
}
local PROF_INDEX = { enUS = 1, esES = 2, ruRU = 3 }
local function ProfName(line) return PROF[line][PROF_INDEX[BB.locale] or 1] end
local known = {}   -- skillLine -> display name

local function RefreshProfessions()
    wipe(known)
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        for _, idx in pairs({ GetProfessions() }) do
            local ok, name, _, _, _, _, _, line = pcall(GetProfessionInfo, idx)
            if ok and line and PROF[line] then known[line] = name or ProfName(line) end
        end
    end
    if next(known) == nil and type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        local byName = {}
        for line, names in pairs(PROF) do for _, n in ipairs(names) do byName[n] = line end end
        for i = 1, GetNumSkillLines() do
            local name, header = GetSkillLineInfo(i)
            if name and not header and byName[name] then known[byName[name]] = name end
        end
    end
end
BB.KnownProfessions = function() return known end

local REAGENT = {
    [1]  = { "parts", { 202 } },
    [4]  = { "gems", { 755 } },
    [5]  = { "cloth", { 197, 129 } },
    [6]  = { "leather", { 165 } },
    [7]  = { "metal and stone", { 164, 202, 755 } },
    [8]  = { "meat", { 185 } },
    [9]  = { "herbs", { 171, 773 } },
    [10] = { "elements", { 164, 165, 197, 171, 202, 333 } },
    [12] = { "enchanting reagents", { 333 } },
    [16] = { "inscription", { 773 } },
}

-- Profession tools: itemID -> skillLine.
local TOOL = {
    [2901] = 186, [5956] = 164, [7005] = 393, [6219] = 202, [20815] = 755, [39505] = 773,
    [6218] = 333, [6339] = 333, [11130] = 333, [11145] = 333, [16207] = 333,
    [6256] = 356, [6365] = 356, [6366] = 356, [6367] = 356, [12225] = 356, [19022] = 356, [19970] = 356,
}

local PVP = { [20558] = true, [20559] = true, [20560] = true, [29024] = true, [42425] = true, [43589] = true, [47395] = true }
local function IsPvPMark(it)
    if PVP[it.itemID] then return true end
    local n = it.name or ""
    return n:find("Почетный знак") or n:find("Почётный знак") or n:find("Mark of Honor") or n:find("Знак чести") or n:find("Marca de honor")
end

local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local function ItemLevelOf(link, fallback)
    if link and C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, lvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and lvl and lvl > 0 then return lvl end
    end
    return fallback
end

-- "empty": slot is empty, "worse": worse than everything worn in these slots, nil: not worse.
local function CompareEquipped(it)
    local slots = SLOTS[it.equipLoc or ""]
    if not slots then return nil end
    local mine = ItemLevelOf(it.link, it.itemLevel)
    if not mine then return nil end
    local worse = true
    for _, s in ipairs(slots) do
        local link = GetInventoryItemLink("player", s)
        if not link then return "empty" end
        local lvl = ItemLevelOf(link, select(4, C_Item.GetItemInfo(link)))
        if not lvl or mine >= lvl then worse = false end
    end
    return worse and "worse" or nil
end

local function Add(it, kind, text, guard)
    it.notes[#it.notes + 1] = { kind = kind, text = text, guard = guard }
end

function BB.Annotate(it)
    it.notes = {}
    local plevel = UnitLevel("player") or 1

    if it.aucWins and it.ahNet then
        local gain = it.ahNet - (it.vendor or 0) - BB.Deposit(it.sellPrice, it.count)
        if gain > 0 then Add(it, "auc", L("auction +%s", BB.Money(gain))) end
    end

    if it.isQuest or it.classID == CLASS_QUEST then
        Add(it, "guard", it.isQuest and L("for a quest") or L("quest item"), "quest")
    end
    if IsPvPMark(it) then
        Add(it, "guard", L("honor mark"), "pvp")
    elseif it.classID == CLASS_CURRENCY then
        Add(it, "guard", L("currency"), "pvp")
    end
    if it.hasLoot then Add(it, "guard", L("can be opened"), "container") end
    if it.classID == CLASS_KEY then Add(it, "guard", L("key"), "key") end
    local tool = TOOL[it.itemID] or (it.classID == CLASS_WEAPON and it.subclassID == WEAPON_FISHING and 356)
    if tool then Add(it, known[tool] and "good" or "guard", L("tool: %s", known[tool] or ProfName(tool)), "tool") end
    if it.inSet then Add(it, "guard", L("equipment set")) end

    if it.classID == CLASS_TRADEGOODS then
        local r = REAGENT[it.subclassID or -1]
        if r then
            local mine
            for _, line in ipairs(r[2]) do if known[line] then mine = known[line]; break end end
            if mine then Add(it, "good", L("for: %s", mine), "reagent")
            else Add(it, "info", L(r[1])) end
        end
    end

    local isGear = (it.classID == CLASS_ARMOR or it.classID == CLASS_WEAPON) and SLOTS[it.equipLoc or ""] and not tool
    if isGear then
        if BB.ClassCanUse and not BB.ClassCanUse(it) then
            Add(it, "bad", L("not for your class"))
        elseif (it.reqLevel or 0) > plevel then
            Add(it, "info", L("from lvl %d", it.reqLevel))
        else
            local cmp = CompareEquipped(it)
            if cmp == "empty" then
                Add(it, "good", L("empty slot - can equip"))
            elseif cmp == "worse" then
                local old = (it.reqLevel or 0) > 0 and (it.reqLevel + 10) <= plevel
                Add(it, "bad", old and L("outdated") or L("worse than equipped"))
            end
        end
    end

    if it.classID == CLASS_CONSUMABLE and (it.subclassID == 5 or it.subclassID == 1) then
        local lvl = math.max(it.reqLevel or 0, it.itemLevel or 0)
        if lvl > 0 and (lvl + 10) <= plevel then Add(it, "bad", it.subclassID == 5 and L("weak food") or L("weak potion")) end
    end
end

function BB.GuardOf(it)
    if not it.notes then return nil end
    local g = BB.P.guard or {}
    for _, n in ipairs(it.notes) do
        if n.guard and g[n.guard] then return n end
        if n.kind == "guard" and not n.guard then return n end
    end
    return nil
end

function BB.NoteColor(kind) return COLOR[kind] or COLOR.info end

-- Notes joined with " · ". skip: a note not to repeat.
function BB.NotesText(it, skip)
    if not it.notes or #it.notes == 0 then return "" end
    local t = {}
    for _, n in ipairs(it.notes) do
        if n ~= skip then t[#t + 1] = "|cff" .. (COLOR[n.kind] or COLOR.info) .. n.text .. "|r" end
    end
    return table.concat(t, "|cff606060  ·  |r")
end

function BB.AddNotesToTooltip(tt, it)
    if not it or not it.notes or #it.notes == 0 then return end
    tt:AddLine(" ")
    tt:AddLine("BagBroker", 0.83, 0.66, 0.42)
    local guard = BB.GuardOf(it)
    for _, n in ipairs(it.notes) do
        local hex = COLOR[n.kind] or COLOR.info
        local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
        local suffix = (n == guard) and L(" - not offered") or ""
        tt:AddLine(n.text .. suffix, r, g, b, true)
    end
end

BB.On("PLAYER_LOGIN", RefreshProfessions)
BB.On("SKILL_LINES_CHANGED", function() RefreshProfessions(); BB.Refresh() end)
BB.On("PLAYER_EQUIPMENT_CHANGED", function() BB.Refresh() end)
BB.On("PLAYER_LEVEL_UP", function() BB.Refresh() end)

-- Offer list filter: "all" | "vendor" (sell to vendor) | "auc" (better at auction).
function BB.FilterOffers(list, f)
    if f ~= "vendor" and f ~= "auc" then return list end
    local out = {}
    for _, it in ipairs(list) do
        if (f == "auc") == (it.aucWins and true or false) then out[#out + 1] = it end
    end
    return out
end

function BB.CountAuc(list)
    local n = 0
    for _, it in ipairs(list) do if it.aucWins then n = n + 1 end end
    return n
end
