--[[----------------------------------------------------------------------------

    LiteNamePlates
    Copyright 2023 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--
local addonName, addonTable = ...

local UnitIsFriend = UnitIsFriend
local UnitHasMana = UnitHasMana

LiteNamePlatesMixin = {}

local Defaults = {
    castersWithoutMana = { }
}

local function IsHostileWithPlayer(unit)
    if UnitReaction(unit, 'player') == 2 then
        return true
    else
        local _, threatStatus = UnitDetailedThreatSituation("player", unit)
        return threatStatus ~= nil
    end
end

local function UnitNPCID(unit)
    local npcID = select(6, strsplit("-", UnitGUID(unit)))
    return tonumber(npcID)
end

local Conditions = {
    {
        r = 0, g = 1, b = 1, a = 1,
        check =
            function (self, unit)
                if UnitHasMana(unit) then
                    return true
                else
                    local npcID = UnitNPCID(unit)
                    return self.db.castersWithoutMana[npcID] or false
                end
            end,
    },
}


function LiteNamePlatesMixin:OnLoad()
    self:RegisterEvent("ADDON_LOADED")
end

function LiteNamePlatesMixin:Initialize()
    LiteNameplatesDB = LiteNamePlatesDB or CopyTable(Defaults)
    self.db = LiteNamePlatesDB

    hooksecurefunc('CompactUnitFrame_UpdateHealthColor',
        function (unitFrame)
            if self:ShouldColorUnit(unitFrame.unit) then
                self:UpdateUnitFrameBarColor(unitFrame)
            end
        end)
    hooksecurefunc('CompactUnitFrame_UpdateName',
        function (unitFrame)
            if self:ShouldColorUnit(unitFrame.unit) then
                self:UpdateUnitFrameTextColor(unitFrame)
            end
        end)

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function LiteNamePlatesMixin:ShouldColorUnit(unit)
    if not unit then
        return false
    elseif UnitIsPlayer(unit) then
        return false
    elseif unit:sub(1,9) ~= 'nameplate' then
        return false
    elseif not IsHostileWithPlayer(unit) then
        return false
    else
        return true
    end
end

function LiteNamePlatesMixin:UpdateUnitFrameBarColor(unitFrame)
    for _, cond in ipairs(Conditions) do
        if cond.check(self, unitFrame.unit) then
            unitFrame.healthBar:SetStatusBarColor(cond.r, cond.g, cond.b, cond.a or 1)
            return
        end
    end
end

function LiteNamePlatesMixin:UpdateUnitFrameTextColor(unitFrame)
    for _, cond in ipairs(Conditions) do
        if cond.check(self, unitFrame.unit) then
            unitFrame.name:SetTextColor(cond.r, cond.g, cond.b, cond.a or 1)
            return
        end
    end
end

function LiteNamePlatesMixin:SaveAsCaster(unit)
    if not UnitHasMana(unit) and not UnitIsPlayer(unit) then
        local npcID = UnitNPCID(unit)
        self.db.castersWithoutMana[npcID] = true
    end
end

function LiteNamePlatesMixin:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            self:Initialize()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:RegisterEvent("UNIT_SPELLCAST_START")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("UNIT_SPELLCAST_START")
        self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    elseif event == "UNIT_SPELLCAST_START" then
        local unit = ...
        local notInterruptible = select(8, UnitCastingInfo(unit))
        if notInterruptible == false then
            self:SaveAsCaster(unit)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        local notInterruptible = select(7, UnitChannelInfo(unit))
        if notInterruptible == false then
            self:SaveAsCaster(unit)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        local unit = ...
        self:SaveAsCaster(unit)
    end
end

