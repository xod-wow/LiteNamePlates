--[[----------------------------------------------------------------------------

    LiteNamePlates
    Copyright 2023 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local addonName, addonTable = ...

local IsInGroup = IsInGroup
local UnitIsFriend = UnitIsFriend
local UnitHasMana = UnitHasMana
local UnitIsBossMob = UnitIsBossMob

local Defaults = {
    global = {
        rules = {
            {
                checks = { "lostthreat" },
                color = { 1, 1, 0, 0.6 },
                colorHealthBar = false,
                colorName = true,
                enabled = true,
            },
            {
                checks = { "interrupt" },
                colorHealthBar = true,
                colorName = true,
                color = { 1, 0, 1, 1 },
                enabled = true,
            },
            {
                checks = { "group:frontal" },
                colorHealthBar = true,
                colorName = true,
                color = { 0, 1, 1, 1 },
                enabled = true,
            },
            {
                checks = { "hasmana" },
                colorHealthBar = true,
                colorName = true,
                color = { 1, 0.5, 1, 1 },
                enabled = true,
            },
        },
        groups = {
            interrupt = {}
        }
    }
}


--[[------------------------------------------------------------------------]]--

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

local function IsPlayerEffectivelyTank()
    local assignedRole = UnitGroupRolesAssigned("player")
    if assignedRole == "NONE" then
        local spec = GetSpecialization()
        return spec and GetSpecializationRole(spec) == "TANK"
    end
    return assignedRole == "TANK"
end


--[[------------------------------------------------------------------------]]--

local Checks = {
    ["hasmana"] = 
        function (self, unit)
            return UnitHasMana(unit)
        end,
    ["interrupt"] = 
        function (self, unit)
            local npcID = UnitNPCID(unit)
            return self.db.global.groups.interrupt[npcID] ~= nil
        end,
    ["lostthreat"] =
        function (self, unit)
            if IsPlayerEffectivelyTank() and IsInGroup() then
                local isTanking, threatStatus = UnitDetailedThreatSituation("player", unit)
                return not isTanking and threatStatus ~= nil
            end
        end,
    ["group"] =
        function (self, unit, group)
            if self.db.global.groups[group] then
                local npcID = UnitNPCID(unit)
                return self.db.global.groups[group][npcID] ~= nil
            end
        end,
    ["id"] =
        function (self, unit, id)
            local npcID = UnitNPCID(unit)
            return npcID == id
        end,
}


--[[------------------------------------------------------------------------]]--

LiteNamePlatesMixin = {}

function LiteNamePlatesMixin:OnLoad()
    self:RegisterEvent("ADDON_LOADED")
end

function LiteNamePlatesMixin:Initialize()
    self.db = LibStub("AceDB-3.0"):New("LiteNamePlatesDB", Defaults, true)

    hooksecurefunc('CompactUnitFrame_UpdateHealthColor',
        function (unitFrame)
            if self:ShouldColorUnit(unitFrame.unit) then
                self:UpdateUnitFrameColor(unitFrame)
            end
        end)
    hooksecurefunc('CompactUnitFrame_UpdateName',
        function (unitFrame)
            if self:ShouldColorUnit(unitFrame.unit) then
                self:UpdateUnitFrameColor(unitFrame)
            end
        end)
    hooksecurefunc('CompactUnitFrame_UpdateHealthBorder',
        function (unitFrame)
            if self:ShouldColorUnit(unitFrame.unit) then
                self:UpdateUnitFrameColor(unitFrame)
            end
        end)

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    SlashCmdList["LiteNamePlates"] = self.OpenOptions
    _G.SLASH_LiteNamePlates1 = "/litenameplates"
    _G.SLASH_LiteNamePlates2 = "/lnp"
end

function LiteNamePlatesMixin:ShouldColorUnit(unit)
    if not unit then
        return false
    elseif UnitIsPlayer(unit) then
        return false
    elseif UnitIsBossMob(unit) then
        return false
    elseif unit:sub(1,9) ~= 'nameplate' then
        return false
    elseif not IsHostileWithPlayer(unit) then
        return false
    else
        return true
    end
end

function LiteNamePlatesMixin:CheckRule(rule, unit)
    if not rule.enabled then
        return false
    end
    for _, check in ipairs(rule.checks) do
        local check, arg = string.split(':', check, 2)
        local handler = Checks[check]
        if not handler or not handler(self, unit, arg) then
            return false
        end
    end
    return true
end

function LiteNamePlatesMixin:UpdateUnitFrameColor(unitFrame)
    for _, rule in ipairs(self.db.global.rules) do
        if self:CheckRule(rule, unitFrame.unit) then
            if rule.colorHealthBar then
                unitFrame.healthBar:SetStatusBarColor(unpack(rule.color))
            end
            if rule.colorName then
                unitFrame.name:SetTextColor(unpack(rule.color))
            end
            return
        end
    end
end

function LiteNamePlatesMixin:SaveUnitAsInterrupt(unit)
    if not UnitIsPlayer(unit)
    and not UnitIsOtherPlayersPet(unit)
    and not UnitIsFriend(unit, 'player')
    and not UnitIsBossMob(unit) then
        local npcID = UnitNPCID(unit)
        self.db.global.groups.interrupt[npcID] = UnitName(unit)
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
            self:SaveUnitAsInterrupt(unit)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        local notInterruptible = select(7, UnitChannelInfo(unit))
        if notInterruptible == false then
            self:SaveUnitAsInterrupt(unit)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        local unit = ...
        self:SaveUnitAsInterrupt(unit)
    end
end

