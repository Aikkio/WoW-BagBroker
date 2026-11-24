local _, BB = ...

local tables = {}
local map

BB.locale = "enUS"
BB.LOCALES = { "enUS", "esES", "ruRU" }

function BB.RegisterLocale(code, t)
    tables[code] = t
end

function BB.ResolveLocale(setting)
    if tables[setting] or setting == "enUS" then return setting end
    local client = GetLocale()
    if client == "ruRU" then return "ruRU" end
    if client == "esES" or client == "esMX" then return "esES" end
    return "enUS"
end

function BB.SetLocale(setting)
    BB.locale = BB.ResolveLocale(setting)
    map = tables[BB.locale]
end

function BB.L(key, ...)
    local text = map and map[key] or key
    if select("#", ...) > 0 then return text:format(...) end
    return text
end
