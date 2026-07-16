-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Data Page Schemas
--
-- Purely presentation layouts for the two static-schema pages (Profile,
-- Inventory). Every "label"/"title" here is a Localization
-- key, not display text -- it is resolved through AC.L:Get() when the rows
-- are built in Home.lua's Create(), which runs after LocalizationService
-- has already loaded the active locale. The actual field VALUES are
-- resolved separately from a gameplay module's public API in the matching
-- GetXFieldValues() function in Pages/*.lua.
--
-- A section may declare "divider = true" to render a thin separator above
-- it. (Presentation System v2: the "emptyText" section field previously
-- documented here was confirmed dead -- no section in this file ever set
-- it -- and its BuildFieldRows branch was removed.)
--
-- MythicPlus/Storage/Weekly/Recommendations no longer use this static
-- schema system -- they are fully dynamic pages rebuilt fresh on every
-- show, since most of their content is inherently dynamic rather than a
-- fixed set of label/value rows. See Pages/MythicPlus.lua etc.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DashboardSchemas = {}
AC.DashboardSchemas = DashboardSchemas

DashboardSchemas.PROFILE_SECTIONS =
{
    {
        title = "Profile.SectionCharacter",
        fields =
        {
            { key = "name", label = "Profile.Name" },
            { key = "level", label = "Profile.Level" },
            { key = "race", label = "Profile.Race" },
            { key = "class", label = "Profile.Class" },
            { key = "spec", label = "Profile.Specialization" },
        },
    },
    {
        title = "Profile.SectionEquipment",
        fields =
        {
            { key = "equippedItemLevel", label = "Profile.EquippedItemLevel" },
            { key = "averageItemLevel", label = "Profile.AverageItemLevel" },
        },
    },
    {
        title = "Profile.SectionLocation",
        fields =
        {
            { key = "zone", label = "Profile.Zone" },
            { key = "subZone", label = "Profile.Subzone" },
            { key = "bindLocation", label = "Profile.BindLocation" },
        },
    },
    {
        -- Was incorrectly titled "Profile.SectionCharacter" a second time
        -- (a copy/paste bug from this section's original authoring) --
        -- rendered as two sections both headed "Character" on the
        -- Profile page. Guild/faction/money/played-time genuinely aren't
        -- "Character" facts in the same sense as name/race/class/spec.
        title = "Profile.SectionGuildAndCurrency",
        fields =
        {
            { key = "guild", label = "Profile.Guild" },
            { key = "guildRank", label = "Profile.GuildRank" },
            { key = "faction", label = "Profile.Faction" },
            { key = "money", label = "Profile.Money" },
            { key = "playedTime", label = "Profile.PlayedTime" },
        },
    },
    {
        title = "Profile.SectionProgress",
        fields =
        {
            { key = "maxLevel", label = "Profile.MaxLevel" },
            { key = "restedXP", label = "Profile.RestedXP" },
            { key = "timeAtCurrentLevel", label = "Profile.TimeAtCurrentLevel" },
        },
    },
    {
        title = "Profile.SectionSession",
        fields =
        {
            { key = "loginTime", label = "Profile.LoginTime" },
            { key = "sessionDuration", label = "Profile.SessionDuration" },
            { key = "itemLevelGained", label = "Profile.ItemLevelGainedSession" },
            { key = "levelsGained", label = "Profile.LevelsGainedSession" },
        },
    },
}

DashboardSchemas.PROFILE_FUTURE_FEATURES =
{
    "Dashboard.WarbandOverview",
}

DashboardSchemas.INVENTORY_SECTIONS =
{
    {
        title = "Inventory.SectionBagSummary",
        fields =
        {
            { key = "usedSlots", label = "Inventory.UsedSlots" },
            { key = "freeSlots", label = "Inventory.FreeSlots" },
            { key = "totalSlots", label = "Inventory.TotalSlots" },
            { key = "percentFull", label = "Inventory.PercentFull" },
        },
    },
    {
        title = "Inventory.SectionEquipment",
        fields =
        {
            { key = "equippedSlots", label = "Inventory.EquippedSlots" },
            { key = "emptyEquipmentSlots", label = "Inventory.EmptyEquipmentSlots" },
            { key = "averageItemLevel", label = "Inventory.AverageItemLevel" },
        },
    },
    {
        title = "Inventory.SectionImportantItems",
        fields =
        {
            { key = "hearthstone", label = "Inventory.Hearthstone" },
        },
    },
    {
        title = "Inventory.SectionEquipmentHealth",
        fields =
        {
            { key = "overallDurability", label = "Inventory.OverallDurability" },
            { key = "worstDurability", label = "Inventory.WorstItemDurability" },
            { key = "repairStatus", label = "Inventory.RepairStatus" },
            { key = "repairCost", label = "Inventory.RepairCost" },
        },
    },
    {
        title = "Inventory.SectionSession",
        fields =
        {
            { key = "itemsAdded", label = "Inventory.ItemsAdded" },
            { key = "itemsRemoved", label = "Inventory.ItemsRemoved" },
            { key = "bagUsageChange", label = "Inventory.BagUsageChange" },
        },
    },
}

DashboardSchemas.INVENTORY_FUTURE_FEATURES =
{
    "Dashboard.RecentLoot",
    "Dashboard.InterestingItems",
    "Dashboard.VendorSuggestions",
}

-- Accomplishments (formerly Achievements) has no static field schema --
-- the Accomplishments redesign made this page fully dynamic (one section
-- per curated category, each a real filtered list), the same shape
-- MythicPlus/Storage/Weekly/Progress/Statistics already use. See
-- Core/UI/Dashboard/Pages/Accomplishments.lua.

return DashboardSchemas
