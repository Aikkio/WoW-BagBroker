-- Minimap button (LibDBIcon). EllesmereUI collects such buttons into its own minimap panel;
-- without EUI it sits on the minimap edge like other addons.
local _, BB = ...
local L = BB.L

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
        tt:AddDoubleLine(L("Free bag slots"), L("%d of %d", free, total), 0.8, 0.8, 0.8, free == 0 and 1 or 1, free == 0 and 0.42 or 1, free == 0 and 0.29 or 1)
        tt:AddDoubleLine(L("Will sell at vendor"), L("%d items, %s", #queue, BB.Money(sum)), 0.8, 0.8, 0.8, 1, 1, 1)
        tt:AddDoubleLine(L("Suggestions"), tostring(#list), 0.8, 0.8, 0.8, 1, 1, 1)
        if list[1] then
            local r, g, b = C_Item.GetItemQualityColor(list[1].quality or 1)
            tt:AddDoubleLine(L("Cheapest"), list[1].name, 0.8, 0.8, 0.8, r, g, b)
        end
    end)
    if not ok then tt:AddLine(tostring(err), 1, 0.3, 0.3) end
    tt:AddLine(" ")
    tt:AddLine("|cffffd100" .. L("Left click") .. "|r - " .. L("BagBroker window"), 0.8, 0.8, 0.8)
    tt:AddLine("|cffffd100" .. L("Shift + left click") .. "|r - " .. L("compact window"), 0.8, 0.8, 0.8)
    tt:AddLine("|cffffd100" .. L("Right click") .. "|r - " .. L("settings"), 0.8, 0.8, 0.8)
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

