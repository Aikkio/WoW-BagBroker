-- Кнопка у миникарты (LibDBIcon). EllesmereUI сам собирает такие кнопки в свою панель
-- у миникарты, без EUI она висит на краю карты, как у остальных аддонов.
local _, BB = ...

local ICON = "Interface\\Icons\\INV_Misc_Bag_08"
local dbicon

local function Tooltip(tt)
    tt:AddLine("BagBroker")
    local ok, err = pcall(function()
        local items = BB.ScanBags()
        local list, prot, guarded = BB.Candidates(items)
        local queue = BB.SellQueue(items)
        local sum = 0
        for _, it in ipairs(queue) do sum = sum + (it.vendor or 0) end
        local free, total = BB.FreeSlots()
        tt:AddDoubleLine("Свободно в сумках", ("%d из %d"):format(free, total), 0.8, 0.8, 0.8, free == 0 and 1 or 1, free == 0 and 0.42 or 1, free == 0 and 0.29 or 1)
        tt:AddDoubleLine("У торговца уйдёт", ("%d предм., %s"):format(#queue, BB.Money(sum)), 0.8, 0.8, 0.8, 1, 1, 1)
        tt:AddDoubleLine("Предложений", tostring(#list), 0.8, 0.8, 0.8, 1, 1, 1)
        if list[1] then
            local r, g, b = C_Item.GetItemQualityColor(list[1].quality or 1)
            tt:AddDoubleLine("Самый дешёвый", list[1].name, 0.8, 0.8, 0.8, r, g, b)
        end
    end)
    if not ok then tt:AddLine(tostring(err), 1, 0.3, 0.3) end
    tt:AddLine(" ")
    tt:AddLine("|cffffd100ЛКМ|r - окно BagBroker", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffd100Shift + ЛКМ|r - компактное окно", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffd100ПКМ|r - настройки", 0.8, 0.8, 0.8)
end

local function OnClick(_, button)
    if button == "RightButton" then
        BB.OpenOptions()
    elseif IsShiftKeyDown() then
        BB.ShowWindow("compact")
    else
        BB.ToggleWindow()
    end
end

function BB.InitMinimap()
    if not LibStub then return end
    local ldb = LibStub("LibDataBroker-1.1", true)
    dbicon = LibStub("LibDBIcon-1.0", true)
    if not (ldb and dbicon) then return end
    local obj = ldb:NewDataObject("BagBroker", {
        type = "launcher",
        text = "BagBroker",
        icon = ICON,
        OnClick = OnClick,
        OnTooltipShow = Tooltip,
    })
    dbicon:Register("BagBroker", obj, BB.db.minimap)
end

function BB.MinimapShown() return not (BB.db.minimap and BB.db.minimap.hide) end

function BB.SetMinimapShown(on)
    BB.db.minimap.hide = not on
    if not dbicon then return end
    if on then dbicon:Show("BagBroker") else dbicon:Hide("BagBroker") end
end

