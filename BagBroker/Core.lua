-- BagBroker: core, saved data, profiles, shared utilities.
local ADDON, BB = ...
_G.BagBroker = BB

BB.name = ADDON
BB.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "0.1"
local _, _, _, interfaceVersion = GetBuildInfo()
BB.isForever = interfaceVersion and interfaceVersion >= 16000 and interfaceVersion < 17000

BB.QUALITY_MAX_LISTED = 2          -- listed items go up to Uncommon quality
BB.HEARTHSTONE = 6948
BB.OWN = "__own"

local DEFAULT_SETTINGS = {
    ahCut = 0.05,            -- auction house cut
    depositHours = 8,        -- auction deposit duration used for the estimate
    minGainSilver = 5,       -- auction wins if it pays at least N silver more
    minGainPct = 10,         -- ... and at least N% of the vendor price
    staleDays = 7,           -- auction price is stale after N days
    autoCompact = true,      -- compact window when bags are full
    showInCombat = true,
    confirmDeleteQuality = 2,-- quality from which Delete needs a second click
    confirmSellQuality = 3,  -- quality from which a sale waits for a decision in the panel
    merchantPanel = true,
    style = "auto",          -- auto | native | eui
    locale = "auto",         -- auto | enUS | esES | ruRU
}

local DEFAULT_RULES = { junk = true, junkGear = false, unusable = true, lowGear = false, food = false }
local DEFAULT_GUARD = { quest = true, pvp = true, container = true, key = true, tool = true, reagent = false }
BB.DEFAULT_GUARD = DEFAULT_GUARD

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then dst[k] = {}; CopyDefaults(dst[k], v) else dst[k] = v end
        end
    end
    return dst
end
BB.CopyDefaults = CopyDefaults

function BB.CharKey()
    local name, realm = UnitFullName("player")
    realm = realm or GetRealmName() or ""
    return (name or "?") .. " - " .. realm
end

function BB.NewProfile()
    return CopyDefaults({ always = {}, protect = {}, rules = {}, guard = {} }, { rules = DEFAULT_RULES, guard = DEFAULT_GUARD })
end

function BB.InitDB()
    BagBrokerDB = BagBrokerDB or {}
    BagBrokerCharDB = BagBrokerCharDB or {}
    local db, cdb = BagBrokerDB, BagBrokerCharDB
    db.settings = CopyDefaults(db.settings or {}, DEFAULT_SETTINGS)
    BB.SetLocale(db.settings.locale)
    db.profiles = db.profiles or {}
    db.chars = db.chars or {}
    db.newCharProfile = db.newCharProfile or BB.OWN
    db.minimap = db.minimap or {}
    cdb.once = cdb.once or {}
    cdb.pos = cdb.pos or {}
    cdb.mode = cdb.mode or "wide"

    local key = BB.CharKey()
    local prof = db.chars[key]
    if not prof or not db.profiles[prof] then
        if db.newCharProfile ~= BB.OWN and db.profiles[db.newCharProfile] then
            prof = db.newCharProfile
        else
            prof = key
            db.profiles[prof] = db.profiles[prof] or BB.NewProfile()
        end
        db.chars[key] = prof
    end
    for _, p in pairs(db.profiles) do
        p.always = p.always or {}; p.protect = p.protect or {}
        p.rules = CopyDefaults(p.rules or {}, DEFAULT_RULES)
        p.guard = CopyDefaults(p.guard or {}, DEFAULT_GUARD)
    end
    BB.db, BB.cdb, BB.S = db, cdb, db.settings
    BB.P = db.profiles[prof]
    BB.profileName = prof
end

function BB.SetProfile(name)
    local db = BB.db
    if not db.profiles[name] then return end
    db.chars[BB.CharKey()] = name
    BB.P, BB.profileName = db.profiles[name], name
    BB.Refresh()
end

function BB.ProfileUsers(name)
    local n = 0
    for _, p in pairs(BB.db.chars) do if p == name then n = n + 1 end end
    return n
end

function BB.ProfileList()
    local t = {}
    for k in pairs(BB.db.profiles) do t[#t + 1] = k end
    table.sort(t)
    return t
end

function BB.Money(c)
    c = math.floor(c or 0)
    if c <= 0 then return "0" .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
    return GetMoneyString(c)
end

function BB.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4a86aBagBroker:|r " .. tostring(msg))
end

local pending
function BB.Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        if BB.RefreshUI then BB.RefreshUI() end
        if BB.RefreshMerchantPanel then BB.RefreshMerchantPanel() end
    end)
end

local ev = CreateFrame("Frame")
BB.eventFrame = ev
local handlers = {}
function BB.On(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    ev:RegisterEvent(event)
end
ev:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end)

BB.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    BB.InitDB()
end)

BB.On("PLAYER_LOGIN", function()
    if not BB.db then BB.InitDB() end
    if BB.InitPrices then BB.InitPrices() end
    if BB.InitUI then BB.InitUI() end
    if BB.InitMerchant then BB.InitMerchant() end
    if BB.InitMinimap then BB.InitMinimap() end
    if BB.InitOptions then BB.InitOptions() end
end)

SLASH_BAGBROKER1 = "/bb"
SLASH_BAGBROKER2 = "/bagbroker"
SlashCmdList.BAGBROKER = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "mini" or msg == "compact" then
        BB.ShowWindow("compact")
    elseif msg == "opt" or msg == "options" or msg == "config" then
        BB.OpenOptions()
    elseif msg == "reset" then
        BB.cdb.pos = {}
        BB.ResetPositions()
        BB.Print(BB.L("window positions reset"))
    else
        BB.ToggleWindow()
    end
end
