--[[----------------------------------------------------------------------------

  LiteButtonAuras/Options.lua

  Copyright 2025 Mike Battersby

----------------------------------------------------------------------------]]--

local addonName, addonTable = ...

local order
do
    local n = 0
    order = function () n = n + 1 return n end
end

local options = {
    type = "group",
    childGroups = "tab",
    args = {
--[[
        GeneralGroup = {
            type = "group",
            name = GENERAL,
            order = order(),
            args = {
            }
        },
]]
        RulesGroup = {
            type = "group",
            name = "Rules",
            inline = false,
            order = order(),
            args = { },
            plugins = { },
        },
    },
}

local addState = { }

function addState.Set(info, v)
    local k = table.concat(info, '.')
    addState[k] = v
end

function addState.Get(info)
    local k = table.concat(info, '.')
    return addState[k]
end

function addState.GetAndRemove(info)
    local k = table.concat(info, '.')
    local v = addState[k]
    addState[k] = nil
    return v
end

local function GenerateOptions()
    local db = LiteNamePlates.db

    local rulesTable = {}
    for i, rule in ipairs(db.global.rules) do
        rulesTable["rule"..i] = {
            type = "group",
            order = 10*i,
            name = "",
            inline = true,
            width = "full",
            args = {
                ["n"..i] = {
                    order = 10*i+1,
                    type = "description",
                    name = tostring(i),
                    width = 0.25,
                },
                ["checks"..i] = {
                    order = 10*i+1,
                    type = "description",
                    name = table.concat(rule.checks, ' + '),
                    width = 1.25,
                },
                ["color"..i] = {
                    order = 10*i+2,
                    type = "color",
                    name = COLOR,
                    hasAlpha = true,
                    get = function() return unpack(rule.color) end,
                    set = function(_, r, g, b, a) rule.color = { r, g, b, a } end,
                    width = 0.67,
                },
                ["colorHealthBar"..i] = {
                    order = 10*i+3,
                    type = "toggle",
                    name = "Bar",
                    get = function() return rule.colorHealthBar end,
                    set = function(_, v) rule.colorHealthBar = ValueToBoolean(v) end,
                    width = 0.67,
                },
                ["colorName"..i] = {
                    order = 10*i+4,
                    type = "toggle",
                    name = "Name",
                    get = function() return rule.colorName end,
                    set = function(_, v) rule.colorName = ValueToBoolean(v) end,
                    width = 0.67,
                }
            }
        }
    end

    options.args.RulesGroup.plugins.rules = rulesTable

    return options
end

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- AddOns are listed in the Blizzard panel in the order they are
-- added, not sorted by name. In order to mostly get them to
-- appear in the right order, add the main panel when loaded.

AceConfig:RegisterOptionsTable(addonName, GenerateOptions)
local optionsPanel, category = AceConfigDialog:AddToBlizOptions(addonName)

function LiteNamePlates.OpenOptions()
    Settings.OpenToCategory(category)
end
