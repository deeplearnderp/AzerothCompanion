-------------------------------------------------------------------------------
-- Azeroth Companion
-- Localization: enUS (English)
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

AC.Locales = AC.Locales or {}

AC.Locales.enUS =
{
    -----------------------------------------------------------------------
    -- App
    -----------------------------------------------------------------------

    ["App.Title"] = "Azeroth Companion",

    -----------------------------------------------------------------------
    -- Settings
    -----------------------------------------------------------------------

    ["Settings.General"] = "General",
    ["Settings.Language"] = "Language",
    ["Settings.LanguageAutomatic"] = "Automatic (Game Language)",
    ["Settings.LanguageTooltip"] = "Choose the language Azeroth Companion displays. Automatic follows your game client's language.",

    -----------------------------------------------------------------------
    -- Dashboard (Home)
    -----------------------------------------------------------------------

    ["Dashboard.Settings"] = "Settings",
    ["Dashboard.Back"] = "< Back",
    ["Dashboard.Version"] = "Version %s",
    ["Dashboard.CaughtUp"] = "You're all caught up.",
    ["Dashboard.Loading"] = "Loading...",

    ["Dashboard.RecommendedNextStep"] = "Recommended Next Step",
    ["Dashboard.Profile"] = "Profile",
    ["Dashboard.Inventory"] = "Inventory",
    ["Dashboard.Achievements"] = "Achievements",
    ["Dashboard.Recommendations"] = "Recommendations",

    ["Dashboard.NoCharacterData"] = "No character data",
    ["Dashboard.InventoryUnavailable"] = "Inventory unavailable",
    ["Dashboard.AchievementsUnavailable"] = "Achievements unavailable",

    ["Dashboard.AchievementPointsFormat"] = "%s Achievement Points",
    ["Dashboard.SlotsUsedFormat"] = "%d / %d Slots Used",
    ["Dashboard.PercentFullFormat"] = "%.0f%% Full",
    ["Dashboard.EquippedItemLevelFormat"] = "Equipped Item Level: %s",
    ["Dashboard.LevelClassFormat"] = "Level %d %s",
    ["Dashboard.LevelSpecClassFormat"] = "Level %d %s %s",
    ["Dashboard.RecommendationMetaFormat"] = "Priority: %s   Category: %s",

    ["Dashboard.StatusHealthy"] = "Healthy",
    ["Dashboard.StatusFilling"] = "Filling",
    ["Dashboard.StatusFull"] = "Full",

    ["Dashboard.FutureFeatures"] = "Future Features",
    ["Dashboard.RecentLoot"] = "Recent Loot",
    ["Dashboard.InterestingItems"] = "Interesting Items",
    ["Dashboard.VendorSuggestions"] = "Vendor Suggestions",
    ["Dashboard.Milestones"] = "Milestones",
    ["Dashboard.ExpansionProgress"] = "Expansion Progress",
    ["Dashboard.CategoryBreakdown"] = "Category Breakdown",
    ["Dashboard.RecentHistory"] = "Recent History",

    -----------------------------------------------------------------------
    -- Profile Page
    -----------------------------------------------------------------------

    ["Profile.SectionCharacter"] = "Character",
    ["Profile.SectionEquipment"] = "Equipment",
    ["Profile.SectionLocation"] = "Location",
    ["Profile.SectionSession"] = "Session",

    ["Profile.Name"] = "Name",
    ["Profile.Level"] = "Level",
    ["Profile.Race"] = "Race",
    ["Profile.Class"] = "Class",
    ["Profile.Specialization"] = "Current Specialization",
    ["Profile.EquippedItemLevel"] = "Equipped Item Level",
    ["Profile.AverageItemLevel"] = "Average Item Level",
    ["Profile.Zone"] = "Zone",
    ["Profile.Subzone"] = "Subzone",
    ["Profile.BindLocation"] = "Bind Location",
    ["Profile.Guild"] = "Guild",
    ["Profile.Faction"] = "Faction",
    ["Profile.Money"] = "Money",
    ["Profile.PlayedTime"] = "Played Time",
    ["Profile.LoginTime"] = "Login Time",
    ["Profile.SessionDuration"] = "Current Session Duration",
    ["Profile.ItemLevelGainedSession"] = "Item Level Gained This Session",
    ["Profile.LevelsGainedSession"] = "Levels Gained This Session",

    -----------------------------------------------------------------------
    -- Inventory Page
    -----------------------------------------------------------------------

    ["Inventory.SectionBagSummary"] = "Bag Summary",
    ["Inventory.SectionEquipment"] = "Equipment",
    ["Inventory.SectionImportantItems"] = "Important Items",
    ["Inventory.SectionSession"] = "Session",

    ["Inventory.UsedSlots"] = "Used Slots",
    ["Inventory.FreeSlots"] = "Free Slots",
    ["Inventory.TotalSlots"] = "Total Slots",
    ["Inventory.PercentFull"] = "Percent Full",
    ["Inventory.EquippedSlots"] = "Equipped Slots",
    ["Inventory.EmptyEquipmentSlots"] = "Empty Equipment Slots",
    ["Inventory.AverageItemLevel"] = "Average Item Level",
    ["Inventory.Hearthstone"] = "Hearthstone",
    ["Inventory.RepairStatus"] = "Repair Status",
    ["Inventory.ItemsAdded"] = "Items Added",
    ["Inventory.ItemsRemoved"] = "Items Removed",
    ["Inventory.BagUsageChange"] = "Bag Usage Change",

    ["Inventory.HearthstoneInBags"] = "In Bags",
    ["Inventory.HearthstoneMissing"] = "Missing",
    ["Inventory.RepairsNeeded"] = "Repairs needed",
    ["Inventory.NoRepairsNeeded"] = "No repairs needed",

    -----------------------------------------------------------------------
    -- Achievements Page
    -----------------------------------------------------------------------

    ["Achievements.SectionSummary"] = "Summary",
    ["Achievements.SectionSession"] = "Session",

    ["Achievements.Points"] = "Achievement Points",
    ["Achievements.Earned"] = "Achievements Earned",
    ["Achievements.Recent"] = "Recent Achievement",
    ["Achievements.EarnedThisSession"] = "Achievements Earned This Session",
    ["Achievements.PointsThisSession"] = "Points Earned This Session",

    -----------------------------------------------------------------------
    -- Common
    -----------------------------------------------------------------------

    ["Common.Unknown"] = "Unknown",

    -----------------------------------------------------------------------
    -- Recommendations
    -----------------------------------------------------------------------

    ["Recommendation.VisitVendor.Title"] = "Visit a Vendor",
    ["Recommendation.VisitVendor.Description"] = "Your bags are almost full. Visit a vendor before your next activity.",

    ["Recommendation.ConsiderVendorSoon.Title"] = "Consider Vendor Soon",
    ["Recommendation.ConsiderVendorSoon.Description"] = "Your bags are filling up. Consider visiting a vendor soon.",

    ["Recommendation.AcquireHearthstone.Title"] = "Acquire Hearthstone",
    ["Recommendation.AcquireHearthstone.Description"] = "You don't have a Hearthstone. Visit an innkeeper to get one.",

    ["Recommendation.UseRestedXP.Title"] = "Use Rested XP",
    ["Recommendation.UseRestedXP.Description"] = "You have rested XP available. Leveling an alt would make efficient use of it.",

    ["Recommendation.ContinueLeveling.Title"] = "Continue Leveling",
    ["Recommendation.ContinueLeveling.Description"] = "You leveled up this session. Continue leveling while momentum is high.",

    ["Recommendation.TryHarderContent.Title"] = "Try Harder Content",
    ["Recommendation.TryHarderContent.Description"] = "Your item level improved this session. Consider trying harder content.",

    ["Recommendation.ContinueAchievementHunting.Title"] = "Continue Achievement Hunting",
    ["Recommendation.ContinueAchievementHunting.Description"] = "You earned an achievement. Continue hunting while you're motivated.",

    ["Recommendation.ReachNextMilestone.Title"] = "Reach Next Milestone",
    ["Recommendation.ReachNextMilestone.Description"] = "You gained significant achievement points. Complete one more to reach your next milestone.",
}
