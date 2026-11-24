-- Страница BagBroker в «Параметрах» игры: сами настройки живут во вкладке «Настройки»
-- окна BagBroker, здесь только переход туда.
local _, BB = ...

function BB.InitOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BagBroker |cff888888" .. tostring(BB.version) .. "|r")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(220, 26)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    open:SetText("Открыть настройки BagBroker")
    open:SetScript("OnClick", function() BB.OpenOptions(true) end)
    panel:SetScript("OnShow", function() if not InCombatLockdown() then BB.OpenOptions(true) end end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "BagBroker")
    Settings.RegisterAddOnCategory(category)
end
