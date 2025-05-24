exclude_files = {
    ".luacheckrc",
    "Libs/",
}

-- https://luacheck.readthedocs.io/en/stable/warnings.html

ignore = {
--[[
    "11./BINDING_.*", -- Setting an undefined (Keybinding) global variable
    "11./MOUNT_JOURNAL_FILTER_.*",
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "432/self", -- Shadowing a local variable
    "542", -- empty if branch
    "631", -- line too long
]]
}

globals = {
    "LiteNamePlates",
    "LiteNamePlatesMixin",
    "SlashCmdList",
}

read_globals = {
    "ADD",
    "COLOR",
    "C_NamePlate",
    "C_SpecializationInfo",
    "DELETE",
    "GetKeysArray",
    "GetKeysArraySortedByValue",
    "GetSpecialization",
    "GetSpecializationRole",
    "IsInGroup",
    "LibStub",
    "Settings",
    "UnitCastingInfo",
    "UnitChannelInfo",
    "UnitDetailedThreatSituation",
    "UnitGUID",
    "UnitGroupRolesAssigned",
    "UnitHasMana",
    "UnitIsBossMob",
    "UnitIsFriend",
    "UnitIsOtherPlayersPet",
    "UnitIsPlayer",
    "UnitIsTapDenied",
    "UnitName",
    "UnitReaction",
    "ValueToBoolean",
    "hooksecurefunc",
    "strsplit",
}
