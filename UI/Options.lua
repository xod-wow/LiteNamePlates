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
        GroupsGroup = {
            type = "group",
            name = "NPC Groups",
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

    local groupsTable = {}
    local groupNames = GetKeysArray(db.global.groups)
    table.sort(groupNames)
    for _, groupName in ipairs(groupNames) do
        groupsTable[groupName] = {
            type = "group",
            name = groupName,
            order = order(),
            args = {
                ["groupAdd"] = {
                    type = "group",
                    inline = true,
                    name = "",
                    width = 'full',
                    order = 1,
                    args = {
                        ["npcid"] = {
                            order = 2,
                            type = "input",
                            name = "",
                            pattern = "^%d+$",
                            width = 0.4,
                            get = addState.Get,
                            set = addState.Set,
                        },
                        ["npcname"] = {
                            order = 3,
                            type = "input",
                            name = "",
                            width = 1.5,
                            get = addState.Get,
                            set = addState.Set,
                        },
                        ["npcadd"] = {
                            order = 4,
                            type = "execute",
                            name = ADD,
                            func =
                                function (info, ...)
                                    info[#info] = 'npcid'
                                    local npcID = tonumber(addState.GetAndRemove(info))
                                    info[#info] = 'npcname'
                                    local npcName = addState.GetAndRemove(info)
                                    db.global.groups[groupName][npcID] = npcName
                                end,
                            width = 0.5,
                        },
                    },
                },
            },
        }

        local npcIDs = GetKeysArraySortedByValue(db.global.groups[groupName])
        for i, id in ipairs(npcIDs) do
            -- fake groups force lines in list
            groupsTable[groupName].args["group"..i] = {
                type = "group",
                inline = true,
                name = "",
                width = 'full',
                order = i*10+1,
                args = {
                    ["npcid"..i] = {
                        order = i*10+2,
                        type = "description",
                        name = tostring(id),
                        width = 0.4,
                    },
                    ["npcname"..i] = {
                        order = i*10+3,
                        type = "description",
                        name = db.global.groups[groupName][id],
                        width = 1.5,
                    },
                    ["npcdelete"..i] = {
                        order = i*10+4,
                        type = "execute",
                        name = DELETE,
                        desc = db.global.groups[groupName][id],
                        func = function () db.global.groups[groupName][id] = nil end,
                        width = 0.5,
                    },
                }
            }
        end
    end

    options.args.GroupsGroup.plugins.groups = groupsTable

    --[[
    local auraMapList = LBA.GetAuraMapList()
    local auraMaps = { }
    for i, entry in ipairs(auraMapList) do
        auraMaps["mapAura"..i] = {
            order = 10*i+1,
            name = LBA.SpellString(entry[1], entry[2]),
            type = "description",
            image = C_Spell.GetSpellTexture(entry[1] or entry[2]),
            imageWidth = 22,
            imageHeight = 22,
            width = 1.4,
        }
        auraMaps["onText"..i] = {
            order = 10*i+2,
            name = GRAY_FONT_COLOR:WrapTextInColorCode(L["on"]),
            type = "description",
            width = 0.15,
        }
        auraMaps["mapAbility"..i] = {
            order = 10*i+3,
            name = LBA.SpellString(entry[3], entry[4]),
            type = "description",
            image = C_Spell.GetSpellTexture(entry[3] or entry[4]),
            imageWidth = 22,
            imageHeight = 22,
            width = 1.4,
        }
        auraMaps["delete"..i] = {
            order = 10*i+4,
            name = DELETE,
            type = "execute",
            func = function () LBA.RemoveAuraMap(entry[1], entry[3]) end,
            width = 0.45,
        }
    end
    options.args.MappingGroup.args.Mappings.plugins.auraMaps = auraMaps

    local ignoreSpellList = {}
    local cc = ContinuableContainer:Create()
    for spellID in pairs(LBA.db.profile.denySpells) do
        local spell = Spell:CreateFromSpellID(spellID)
        if not spell:IsSpellEmpty() then
            if WOW_PROJECT_ID ~= 1 then
                spell.IsDataEvictable = function () return true end
                spell.IsItemDataCached = spell.IsSpellDataCached
                spell.ContinueWithCancelOnItemLoad = spell.ContinueWithCancelOnSpellLoad
            end
            cc:AddContinuable(spell)
            table.insert(ignoreSpellList, spell)
        end
    end

    local ignoreAbilities = {}
    cc:ContinueOnLoad(
        function ()
            table.sort(ignoreSpellList, function (a, b) return a:GetSpellName() < b:GetSpellName() end)
            for i, spell in ipairs(ignoreSpellList) do
                ignoreAbilities["ability"..i] = {
                    name = format("%s (%d)",
                                NORMAL_FONT_COLOR:WrapTextInColorCode(spell:GetSpellName()),
                                spell:GetSpellID()),
                    type = "description",
                    image = C_Spell.GetSpellTexture(spell.spellID),
                    imageWidth = 22,
                    imageHeight = 22,
                    width = 2.5,
                    order = 10*i+1,
                }
                ignoreAbilities["delete"..i] = {
                    name = DELETE,
                    type = "execute",
                    func = function () LBA.RemoveIgnoreSpell(spell:GetSpellID()) end,
                    width = 0.5,
                    order = 10*i+2,
                }
            end
            options.args.IgnoreGroup.args.Abilities.plugins.ignoreAbilites = ignoreAbilities
        end)
    ]]
    return options
end

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions =  LibStub("AceDBOptions-3.0")

-- AddOns are listed in the Blizzard panel in the order they are
-- added, not sorted by name. In order to mostly get them to
-- appear in the right order, add the main panel when loaded.

AceConfig:RegisterOptionsTable(addonName, GenerateOptions)
local optionsPanel, category = AceConfigDialog:AddToBlizOptions(addonName)

function LiteNamePlates.OpenOptions()
    Settings.OpenToCategory(category)
end
