--[[----------------------------------------------------------------------------

    LiteNamePlates
    Copyright 2023 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local addonName, addonTable = ...

local C_NamePlate = C_NamePlate
local GetSpecialization = GetSpecialization
local GetSpecializationRole = GetSpecializationRole
local IsInGroup = IsInGroup
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasMana = UnitHasMana
local UnitIsBossMob = UnitIsBossMob
local UnitIsFriend = UnitIsFriend
local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
local UnitIsPlayer = UnitIsPlayer
local UnitIsTapDenied = UnitIsTapDenied
local UnitReaction = UnitReaction
local UnitName = UnitName
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

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
                checks = { "group:frontal" },
                colorHealthBar = true,
                colorName = true,
                color = { 0, 1, 1, 1 },
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

-- UnitName(unit .. "-target") isn't always available right away so this
-- retries updates. From observation it's never doing more than a tick or two.

local TargetTextUpdater = CreateFrame("FRAME")
TargetTextUpdater.pendingTexts = {}

function TargetTextUpdater:RescanPending()
    for unit, fontString in pairs(self.pendingTexts) do
        if fontString:IsVisible() then
            local targetName = UnitName(unit..'-target')
            if targetName then
                fontString:SetText(targetName)
                self.pendingTexts[unit] = nil
            end
        else
            self.pendingTexts[unit] = nil
        end
    end
    return next(self.pendingTexts) == nil
end

function TargetTextUpdater:OnUpdate(elapsed)
    self.totalElapsed = ( self.totalElapsed or 1 ) + elapsed
    if self.totalElapsed > 0.05 then
        local isDone = self:RescanPending()
        if isDone then
            self.totalElapsed = nil
            self:SetScript('OnUpdate', nil)
        else
            self.totalElapsed = 0
        end
    end
end

function TargetTextUpdater:SetUnit(unit, fontString)
    self.pendingTexts[unit] = fontString
    self:SetScript('OnUpdate', self.OnUpdate)
end


--[[------------------------------------------------------------------------]]--

LiteNamePlatesMixin = {}

function LiteNamePlatesMixin:OnLoad()
    self:RegisterEvent("ADDON_LOADED")
end

function LiteNamePlatesMixin:Initialize()
    self.db = LibStub("AceDB-3.0"):New("LiteNamePlatesDB", Defaults, true)

    self.targetTexts = {}

    local function UpdateHook(unitFrame)
        if self:ShouldColorUnit(unitFrame.unit) then
            self:UpdateUnitFrameColor(unitFrame)
        end
    end

    hooksecurefunc('CompactUnitFrame_UpdateName', UpdateHook)
    hooksecurefunc('CompactUnitFrame_UpdateHealthColor', UpdateHook)
    hooksecurefunc('CompactUnitFrame_UpdateHealthBorder', UpdateHook)

    -- ApplyFrameOptions ends up doing a separate version of setting the
    -- height outside the OnSizeChanged handler.
    hooksecurefunc(NamePlateDriverFrame, 'ApplyFrameOptions',
        function (_, nameplate)
            local unit = nameplate.UnitFrame.unit
            if unit and C_NamePlate.GetNamePlateForUnit(unit) then
                self:StyleUnitFrameHeight(nameplate.UnitFrame)
                self:StyleUnitFrameCastBar(nameplate.UnitFrame)
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
                        self:StyleUnitFrameCastBar(nameplate.UnitFrame)
                    end)
                self:StyleUnitFrameTexture(nameplate.UnitFrame)
            end
        end)

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

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

function LiteNamePlatesMixin:StyleUnitFrameCastBar(unitFrame)
    -- Move the spell name text left instead of SetAllPoints
    local fontFile, height, flags = unitFrame.castBar.Text:GetFont()
    unitFrame.castBar.Text:ClearAllPoints()
    unitFrame.castBar.Text:SetPoint("LEFT", unitFrame.castBar, "LEFT", 4, 0)
    unitFrame.castBar.Text:SetFont(fontFile, 6, flags)
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
        if not handler or not handler(self, unit, arg) then
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

function LiteNamePlatesMixin:SaveUnitAsInterrupt(unit)
    if not UnitIsPlayer(unit)
    and not UnitIsOtherPlayersPet(unit)
    and not UnitIsFriend(unit, 'player')
    and not UnitIsBossMob(unit) then
        local npcID = UnitNPCID(unit)
        self.db.global.groups.interrupt[npcID] = UnitName(unit)
    end
end

function LiteNamePlatesMixin:GetTargetFontString(nameplate)
    if not self.targetTexts[nameplate] then
        local castBar = nameplate.UnitFrame.castBar
        -- Spell bar is moved left in ApplyFrameOptions hook
        -- Add spell target text on right
        local text = self:CreateFontString()
        -- Not sure if SetParent will cause issues. So far so good.
        text:SetParent(castBar)
        local fontFile, _, flags = castBar.Text:GetFont()
        text:SetFont(fontFile, 6, flags)
        text:SetPoint("RIGHT", castBar, "RIGHT", 0, 0)
        text:Hide()
        self.targetTexts[nameplate] = text
    end
    return self.targetTexts[nameplate]
end

local function UnitIsTankingUnit(srcUnit, destUnit)
    local srcGUID = UnitGUID(srcUnit)
    if srcGUID then
        srcUnit = UnitTokenFromGUID(srcGUID)
        if srcUnit then
            return UnitDetailedThreatSituation(srcUnit, destUnit) == true
        end
    end
end

function LiteNamePlatesMixin:UpdateCastingTarget(unit, isCasting)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        local targetUnit = unit.."-target"
        local targetUnitName = UnitName(targetUnit)
        local fontString = self:GetTargetFontString(nameplate)
        if isCasting and targetUnitName and not UnitIsTankingUnit(targetUnit, unit) then
            fontString:Show()
            fontString:SetText(targetUnitName)
        else
            fontString:Hide()
        end
    end
end

function LiteNamePlatesMixin:HideAllCastingTargets()
    for _, text in pairs(self.targetTexts) do
        text:Hide()
    end
end

function LiteNamePlatesMixin:OnCombatStart()
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    if C_EventUtils.IsEventValid("UNIT_SPELLCAST_EMPOWER_START") then
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    end
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
end

function LiteNamePlatesMixin:OnCombatStop()
    self:UnregisterEvent("UNIT_SPELLCAST_START")
    self:UnregisterEvent("UNIT_SPELLCAST_STOP")
    self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    if C_EventUtils.IsEventValid("UNIT_SPELLCAST_EMPOWER_START") then
        self:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_START")
        self:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    end
    self:UnregisterEvent("UNIT_SPELLCAST_FAILED")
    self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    self:HideAllCastingTargets()
end

function LiteNamePlatesMixin:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            self:Initialize()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:OnCombatStop()
    elseif event == "UNIT_SPELLCAST_START" then
        local unit = ...
        local notInterruptible = select(8, UnitCastingInfo(unit))
        if notInterruptible == false then
            self:SaveUnitAsInterrupt(unit)
        end
        self:UpdateCastingTarget(unit, true)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        local notInterruptible = select(7, UnitChannelInfo(unit))
        if notInterruptible == false then
            self:SaveUnitAsInterrupt(unit)
        end
        self:UpdateCastingTarget(unit, true)
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        local unit = ...
        self:SaveUnitAsInterrupt(unit)
    elseif event == "UNIT_SPELLCAST_STOP" or
           event == "UNIT_SPELLCAST_CHANNEL_STOP" or
           event == "UNIT_SPELLCAST_EMPOWER_STOP" or
           event == "UNIT_SPELLCAST_FAILED" or
           event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        self:UpdateCastingTarget(unit, false)
    end
end
