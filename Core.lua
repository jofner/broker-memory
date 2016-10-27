-- Broker: Memory
-- Author RiskyNet <riskynet@gmail.com>
-- Big thanks to author of StatBlock_Memory AddOn for inspiration

local obj = LibStub("LibDataBroker-1.1"):NewDataObject("BrokerMemory", {
    type = "data source",
    value = "0",
    suffix = "MB",
    text = "0 " .. "MB",
    icon = "Interface\\icons\\Inv_gizmo_02",
})
local LibQTip = LibStub("LibQTip-1.0")
local tooltip
local inCombat = nil
local addTbl, addTblList = {}, {}

local colors = {
    ["GREEN"] = "|cff00ff00",
    ["YELLOW"] = "|cffffd200",
    ["RED"] = "|cffdd3a00"
}

local function formatMemory(n, isSum)
    local isSum = isSum or false

    if type(n) == "number" then
        if n < 0 then
            return "|cffeda55f" .. "not loaded"
        elseif n > 999 then
            local num = n / 1024
            local c = nil
            if isSum == false then
                if num < 11 then
                    c = colors["GREEN"]
                elseif num < 20 then
                    c = colors["YELLOW"]
                else
                    c = colors["RED"]
                end
            else
                if num < 100 then
                    c = colors["GREEN"]
                elseif num < 150 then
                    c = colors["YELLOW"]
                else
                    c = colors["RED"]
                end
            end

            return string.format(c .. "%.1f %s", num, "MB")
        else
            return string.format(colors["GREEN"] .. "%.0f %s", n, "KB")
        end
    else
        return "|cffdd3a00" .. "error (NaN)"
    end
end

local function updateMemory()
    C_Timer.After(20, updateMemory)

    local t = debugprofilestop()
    UpdateAddOnMemoryUsage()
    local shouldBlock = debugprofilestop()-t
    if shouldBlock > 105 then -- Kill if over 105 ms to prevent script too long errors in combat
        inCombat = "block"
    end

    -- Original author of StatBlock_Memory AddOn note:
    -- If a user is running a LOT of addons, the Blizz function 'UpdateAddOnMemoryUsage()' can take a while to process.
    -- It can infact take so long that it gets killed off with a 'script too long' error.
    -- We now detect this per-user and prevent updating in combat if it's taking too long for the user to run Blizz's function.
    if (not inCombat or inCombat == "block") and InCombatLockdown() then
        return
    end

    local total = 0
    for i = 1, GetNumAddOns() do
        total = total + GetAddOnMemoryUsage(i)
    end
    obj.text = formatMemory(total, true)
    if total > 999 then
        obj.suffix = "MB"
        obj.value = string.format("%.1f", total / 1024)
    else
        obj.suffix = "KB"
        obj.value = string.format("%.0f", total)
    end
end
updateMemory()

local function sortByVal(a, b)
    return addTbl[a] > addTbl[b]
end

function obj.OnClick(self, button)
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            ReloadUI()
        else
            GameTooltip:Hide()
            collectgarbage("collect")
            updateMemory()
        end
    else

    end
end

function obj.OnEnter(self)
    local lineNum
    local t = debugprofilestop()
    UpdateAddOnMemoryUsage()
    local shouldBlock = debugprofilestop()-t
    if shouldBlock > 105 then -- Kill if over 105 ms to prevent script too long errors in combat
        inCombat = "block"
    end

    if (not inCombat or inCombat == "block") and InCombatLockdown() then
        return
    end

    if tooltip then
        LibQTip:Release(tooltip)
    end

    local grandtotal = collectgarbage("count")
    local total = 0
    local numLoadedAddOns = GetNumAddOns()
    local numAddOns = GetNumAddOns()

    for i = 1, numAddOns do
        local memused = GetAddOnMemoryUsage(i)
        local isLoaded = IsAddOnLoaded(i)
        local name = GetAddOnInfo(i)

        if memused > 0 then
            total = total + memused
            addTbl[name] = memused
        else
            addTbl[name] = -1
        end
    end

    tooltip = LibQTip:Acquire("BrokerMemoryTooltip", 2, "LEFT", "LEFT")
    tooltip:Clear()
    tooltip:SmartAnchorTo(self)
    tooltip:SetAutoHideDelay(0.1, self)
    tooltip:EnableMouse(true)
    self.tooltip = tooltip

    lineNum = tooltip:AddLine(" ")
    tooltip:SetCell(lineNum, 1, "AddOns: ", nil, "LEFT")
    tooltip:SetCell(lineNum, 2, "|cff00ff00" .. numAddOns, nil, "RIGHT")
    lineNum = tooltip:AddLine(" ")
    tooltip:SetCell(lineNum, 1, "Consumed memory:", nil, "LEFT")
    tooltip:SetCell(lineNum, 2, "|cff00ff00" .. formatMemory(total, true), "RIGHT")
    lineNum = tooltip:AddLine(" ")
    tooltip:SetCell(lineNum, 1, "With Blizzard AddOns:", nil, "LEFT")
    tooltip:SetCell(lineNum, 2, "|cff00ff00" .. formatMemory(grandtotal, true), "RIGHT")
    lineNum = tooltip:AddLine(" ")
    tooltip:SetCell(lineNum, 1, "Time to process your addons:", nil, "LEFT")
    tooltip:SetCell(lineNum, 2, "|cff00ff00" .. string.format("%.0f %s", shouldBlock, MILLISECONDS_ABBR), "RIGHT")
    tooltip:AddLine(" ")
    lineNum = tooltip:AddLine(" ")
    tooltip:SetCell(lineNum, 1, "|cffffd200Click|r to collect garbage", nil, "LEFT", 2)
    lineNum = tooltip:AddLine(" ")
    tooltip:SetCell(lineNum, 1, "|cffffd200Shift-Click|r to reload UI", nil, "LEFT", 2)
    tooltip:AddLine(" ")

    for name, value in pairs(addTbl) do
        addTblList[#addTblList+1] = name
    end
    table.sort(addTblList, sortByVal)

    for i=1, #addTblList do
        lineNum = tooltip:AddLine(" ")
        tooltip:SetCell(lineNum, 1, addTblList[i], "LEFT")
        tooltip:SetCell(lineNum, 2, formatMemory(addTbl[addTblList[i]]), "RIGHT")
    end
    wipe(addTbl)
    wipe(addTblList)

    tooltip:UpdateScrolling()
    tooltip:Show()
end
