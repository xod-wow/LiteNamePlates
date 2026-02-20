--[[----------------------------------------------------------------------------

    LiteNamePlates
    Copyright 2023 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local addonName, _addonTable = ...

local C_NamePlate = C_NamePlate
local GetSpecialization = GetSpecialization
local GetSpecializationRole = GetSpecializationRole
local IsInGroup = IsInGroup
local UnitThreatSituation = UnitThreatSituation
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitPowerType = UnitPowerType
local UnitIsBossMob = UnitIsBossMob
local UnitIsPlayer = UnitIsPlayer
local UnitIsTapDenied = UnitIsTapDenied
local UnitReaction = UnitReaction

local strsplit = strsplit

if not UnitIsBossMob then
    UnitIsBossMob = function () return false end
end

if not GetSpecialization then
    local C_SpecializationInfo = C_SpecializationInfo
    GetSpecialization = function () return C_SpecializationInfo.GetActiveSpecGroup() end
end

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
                checks = { "hasmana" },
                colorHealthBar = true,
                colorName = true,
                color = { 1, 0.5, 1, 1 },
                enabled = true,
            },
        },
    }
}


--[[------------------------------------------------------------------------]]--

local function IsHostileWithPlayer(unit)
    if UnitReaction(unit, 'player') == 2 then
        return true
    else
        local threatStatus = UnitThreatSituation("player", unit)
        return threatStatus ~= nil
    end
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
        function (unit)
            return UnitPowerType(unit) == Enum.PowerType.Mana
        end,
    ["lostthreat"] =
        function (unit)
            if IsPlayerEffectivelyTank() and IsInGroup() then
                local threatStatus = UnitThreatSituation("player", unit)
                return threatStatus == 0 or threatStatus == 2 or threatStatus == 3
            end
        end,
}


--[[------------------------------------------------------------------------]]--

LiteNamePlatesMixin = {}

function LiteNamePlatesMixin:OnLoad()
    self:RegisterEvent("ADDON_LOADED")
end

function LiteNamePlatesMixin:Initialize()
    self.db = LibStub("AceDB-3.0"):New("LiteNamePlatesDB", Defaults, true)

    local function UpdateHook(unitFrame)
        if self:ShouldColorUnit(unitFrame.unit) then
            self:UpdateUnitFrameColor(unitFrame)
        end
    end

    hooksecurefunc('CompactUnitFrame_UpdateName', UpdateHook)
    hooksecurefunc('CompactUnitFrame_UpdateHealthColor', UpdateHook)
    hooksecurefunc('CompactUnitFrame_UpdateHealthBorder', UpdateHook)

    if WOW_PROJECT_ID ~= 1 then
        -- ApplyFrameOptions ends up doing a separate version of setting the
        -- height outside the OnSizeChanged handler.
        hooksecurefunc(NamePlateDriverFrame, 'ApplyFrameOptions',
            function (_, nameplate)
                local unit = nameplate.UnitFrame.unit
                if unit and C_NamePlate.GetNamePlateForUnit(unit) then
                    self:StyleUnitFrameHeight(nameplate.UnitFrame)
                end
            end)

        -- Every time OnNamePlateAdded -> AcquireUnitFrame is called the
        -- OnSizeChanged script is replaced so we need to re-hook. Carefully
        -- checking for forbidden nameplates with C_UnitFrame.
        hooksecurefunc(NamePlateDriverFrame, 'OnNamePlateAdded',
            function (_, unit)
                local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
                if nameplate then
                    nameplate:HookScript('OnSizeChanged',
                        function ()
                            self:StyleUnitFrameHeight(nameplate.UnitFrame)
                        end)
                    self:StyleUnitFrameTexture(nameplate.UnitFrame)
                end
            end)
    end

    SlashCmdList["LiteNamePlates"] =
        function ()
            LibStub("AceConfigDialog-3.0"):Open(addonName)
            return true
        end
    _G.SLASH_LiteNamePlates1 = "/litenameplates"
    _G.SLASH_LiteNamePlates2 = "/lnp"
end

function LiteNamePlatesMixin:StyleUnitFrameHeight(unitFrame)
    if unitFrame and unitFrame.unit and C_NamePlate.GetNamePlateForUnit(unitFrame.unit) then
        if not NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
            local h = 8 * GetCVarNumberOrDefault("NamePlateVerticalScale")
            PixelUtil.SetHeight(unitFrame.HealthBarsContainer, h)
        end
    end
end

function LiteNamePlatesMixin:StyleUnitFrameTexture(unitFrame)
    unitFrame.healthBar:SetStatusBarTexture("mixingpool-frame-fill-white")
end

function LiteNamePlatesMixin:ShouldColorUnit(unit, includeBoss)
    -- Forbidden nameplates don't work, but will still have their unitframes
    -- passed to the hook. Because you can't call any functions on them you
    -- can't tie them back to their nameplate to tell it's forbidden. I
    -- think this check works.
    if not unit then
        return false
    elseif unit:sub(1, 5) == 'arena' then
        -- C_NamePlate.GetNamePlateForUnit errors on arena in retail
        return false
    elseif C_NamePlate.GetNamePlateForUnit(unit) == nil then
        return false
    elseif unit:sub(1,9) ~= 'nameplate' then
        return false
    elseif UnitIsPlayer(unit) then
        return false
    elseif not includeBoss and UnitIsBossMob(unit) then
        return false
    elseif UnitIsTapDenied(unit) then
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
    for _, checkAndArg in ipairs(rule.checks) do
        local check, arg = strsplit(':', checkAndArg, 2)
        local handler = Checks[check]
        if not handler or not handler(unit, arg) then
            return false
        end
    end
    return true
end

function LiteNamePlatesMixin:UpdateUnitFrameColor(unitFrame)
    local todo = { name = true, healthBar = true }
    for _, rule in ipairs(self.db.global.rules) do
        if self:CheckRule(rule, unitFrame.unit) then
            if todo.healthBar and rule.colorHealthBar then
                unitFrame.healthBar:SetStatusBarColor(unpack(rule.color))
                todo.healthBar = nil
            end
            if todo.name and rule.colorName then
                unitFrame.name:SetTextColor(unpack(rule.color))
                todo.name = nil
            end
        end
        if next(todo) == nil then
            return
        end
    end
end

function LiteNamePlatesMixin:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            self:Initialize()
        end
    end
end
