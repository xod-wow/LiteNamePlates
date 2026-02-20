exclude_files = {
    ".luacheckrc",
    "Libs/",
}

-- https://luacheck.readthedocs.io/en/stable/warnings.html

ignore = {
    "211/_.*",      -- Unused local variable
    "212/_.*",      -- Unused argument
    "212/self",     -- Unused argument
    "213/_.*",      -- Unused loop variable
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
    "COLOR",
    "C_NamePlate",
    "C_SpecializationInfo",
    "Enum",
    "GetCVarNumberOrDefault",
    "GetSpecialization",
    "GetSpecializationRole",
    "IsInGroup",
    "LibStub",
    "NamePlateDriverFrame",
    "PixelUtil",
    "Settings",
    "UnitGroupRolesAssigned",
    "UnitIsBossMob",
    "UnitIsPlayer",
    "UnitIsTapDenied",
    "UnitPowerType",
    "UnitReaction",
    "UnitThreatSituation",
    "ValueToBoolean",
    "WOW_PROJECT_ID",
    "hooksecurefunc",
    "strsplit",
}
