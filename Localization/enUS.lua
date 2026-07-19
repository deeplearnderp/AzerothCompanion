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
    ["App.Back"] = "Back",

    -----------------------------------------------------------------------
    -- Settings
    -----------------------------------------------------------------------

    ["Settings.General"] = "General",
    ["Settings.Language"] = "Language",
    ["Settings.LanguageAutomatic"] = "Automatic (Game Language)",
    ["Settings.LanguageTooltip"] = "Choose the language Azeroth Companion displays. Automatic follows your game client's language.",

    -----------------------------------------------------------------------
    -- Data Management
    -----------------------------------------------------------------------

    ["DataManagement.Title"] = "Data Management",
    ["DataManagement.Clear"] = "Clear",
    ["DataManagement.ClearAll"] = "Clear All",
    ["DataManagement.ClearAllTitle"] = "Clear All Module Data",
    ["DataManagement.ClearAllDescription"] = "Remove historical and cached module data. Settings, preferences, profiles, and window positions are preserved.",
    ["DataManagement.ConfirmAllTitle"] = "Clear ALL Module Data?",
    ["DataManagement.ConfirmAllDescription"] = "This will permanently remove historical and cached data from every registered module. Settings and preferences will NOT be removed.",
    ["DataManagement.ConfirmProviderTitle"] = "Clear module data?",
    ["DataManagement.ConfirmProviderDescription"] = "This data will be permanently removed.",
    ["DataManagement.StatusActivities"] = "%d activities recorded",
    ["DataManagement.StatusRuns"] = "%d runs recorded",
    ["DataManagement.StatusJournalEntries"] = "%d journal entries",
    ["DataManagement.StatusLastScan"] = "Last scan: %s",
    ["DataManagement.StatusNoCache"] = "No inventory cache",
    ["DataManagement.StatusNoSnapshots"] = "No storage snapshots",

    ["DataManagement.ActivityHistory.Name"] = "Activity History",
    ["DataManagement.ActivityHistory.Description"] = "All recorded activities for the current character.",
    ["DataManagement.ActivityHistory.Action"] = "Clear History",
    ["DataManagement.ActivityHistory.ConfirmTitle"] = "Clear Activity History?",
    ["DataManagement.ActivityHistory.ConfirmDescription"] = "This will permanently remove all recorded activities for the current character.",

    ["DataManagement.MythicPlus.Name"] = "Mythic+",
    ["DataManagement.MythicPlus.Description"] = "Recorded Mythic+ runs for the current character.",
    ["DataManagement.MythicPlus.Action"] = "Clear Mythic+ History",
    ["DataManagement.MythicPlus.ConfirmTitle"] = "Clear Mythic+ History?",
    ["DataManagement.MythicPlus.ConfirmDescription"] = "This will permanently remove recorded Mythic+ runs for the current character.",

    ["DataManagement.Delves.Name"] = "Delves",
    ["DataManagement.Delves.Description"] = "Recorded Delve runs for the current character.",
    ["DataManagement.Delves.Action"] = "Clear Delve History",
    ["DataManagement.Delves.ConfirmTitle"] = "Clear Delve History?",
    ["DataManagement.Delves.ConfirmDescription"] = "This will permanently remove recorded Delve runs for the current character.",

    ["DataManagement.Inventory.Name"] = "Inventory",
    ["DataManagement.Inventory.Description"] = "Cached bag and equipment snapshot for the current character.",
    ["DataManagement.Inventory.Action"] = "Clear Inventory Cache",
    ["DataManagement.Inventory.ConfirmTitle"] = "Clear Inventory Cache?",
    ["DataManagement.Inventory.ConfirmDescription"] = "This will remove the current character's cached inventory data.",

    ["DataManagement.Storage.Name"] = "Storage",
    ["DataManagement.Storage.Description"] = "Cached bank, reagent bank, and Warband Bank snapshots for the current character.",
    ["DataManagement.Storage.Action"] = "Clear Storage Snapshots",
    ["DataManagement.Storage.ConfirmTitle"] = "Clear Storage Snapshots?",
    ["DataManagement.Storage.ConfirmDescription"] = "This will remove all cached storage snapshots for the current character.",

    ["DataManagement.PlayerJournal.Name"] = "Player Journal",
    ["DataManagement.PlayerJournal.Description"] = "Account-wide journal entries, notes, tags, and recorded group history.",
    ["DataManagement.PlayerJournal.Action"] = "Clear Journal",
    ["DataManagement.PlayerJournal.ConfirmTitle"] = "Clear Player Journal?",
    ["DataManagement.PlayerJournal.ConfirmDescription"] = "This will permanently remove all Player Journal entries, notes, tags, and recorded group history. Community Observations are not removed.",

    -----------------------------------------------------------------------
    -- Dashboard (Home)
    -----------------------------------------------------------------------

    ["Dashboard.Settings"] = "Settings",
    ["Dashboard.Back"] = "Back",
    ["Dashboard.Version"] = "Version %s",
    ["Dashboard.CaughtUp"] = "You're all caught up.",
    ["Dashboard.Loading"] = "Loading...",

    ["Dashboard.RecommendedNextStep"] = "Recommended Next Step",
    ["Dashboard.HighestPriority"] = "Highest Priority",
    ["Dashboard.Profile"] = "Character",
    ["Dashboard.Inventory"] = "Inventory",
    ["Dashboard.Accomplishments"] = "Accomplishments",
    ["Dashboard.Journey"] = "Journey",
    ["Dashboard.Recommendations"] = "Recommendations",

    -----------------------------------------------------------------------
    -- Forecast
    -----------------------------------------------------------------------

    ["Forecast.Title"] = "Forecast",
    ["Forecast.Tooltip"] = "Plan the most valuable things to do next",
    ["Forecast.HomePrimary"] = "Plan your next session",
    ["Forecast.HomeSecondary"] = "Review upcoming opportunities",
    ["Forecast.HeroHeadline"] = "Today's Outlook",
    ["Forecast.SectionUpcoming"] = "Upcoming Opportunities",
    ["Forecast.EmptyTitle"] = "Nothing urgent right now",
    ["Forecast.EmptyDescription"] = "New opportunities will appear here as they become available.",
    ["Forecast.GreatVault.Title"] = "Great Vault",
    ["Forecast.GreatVault.Description"] = "Weekly reward planning will appear here.",
    ["Forecast.GreatVault.Action"] = "Review weekly rewards",
    ["Forecast.WeeklyReset.Title"] = "Weekly Reset",
    ["Forecast.WeeklyReset.Description"] = "Reset timing and weekly deadlines will appear here.",
    ["Forecast.WeeklyReset.Action"] = "Plan the week",
    ["Forecast.Delves.Title"] = "Delves",
    ["Forecast.Delves.Description"] = "Delve opportunities and companion planning will appear here.",
    ["Forecast.Delves.Action"] = "Review Delves",
    ["Forecast.MythicPlus.Title"] = "Mythic+",
    ["Forecast.MythicPlus.Description"] = "Keystone and dungeon planning will appear here.",
    ["Forecast.MythicPlus.Action"] = "Review Mythic+",
    ["Forecast.WorldActivities.Title"] = "World Activities",
    ["Forecast.WorldActivities.Description"] = "Relevant world opportunities will appear here.",
    ["Forecast.WorldActivities.Action"] = "Review world activities",
    ["Forecast.Reputation.Title"] = "Reputation",
    ["Forecast.Reputation.Description"] = "Upcoming reputation milestones will appear here.",
    ["Forecast.Reputation.Action"] = "Review reputations",
    ["Forecast.Events.Title"] = "Events",
    ["Forecast.Events.Description"] = "Limited-time event opportunities will appear here.",
    ["Forecast.Events.Action"] = "Review events",

    -- Daily Briefing (Companion Intelligence Part 5)
    ["Dashboard.GreetingMorning"] = "Good Morning.",
    ["Dashboard.GreetingAfternoon"] = "Good Afternoon.",
    ["Dashboard.GreetingEvening"] = "Good Evening.",
    ["Dashboard.GreetingNight"] = "Still up?",
    ["Dashboard.GreetingGeneric"] = "Welcome Back.",

    ["Dashboard.VaultProgress"] = "Vault Progress",
    ["Dashboard.TooltipVaultProgress"] = "Great Vault (Mythic+) reward-slot progress this week",
    ["Dashboard.VaultSlotsFormat"] = "%d / %d Slots",
    ["Dashboard.VaultRewardReady"] = "A reward is ready to claim.",
    ["Dashboard.VaultUnavailable"] = "Vault progress unavailable",

    ["Dashboard.TooltipRecentActivity"] = "View your most recent dungeon or Delve",
    ["Dashboard.NoRecentActivity"] = "No recent dungeon or Delve activity",

    ["Dashboard.EvidenceLineFormat"] = "%s: %s",

    ["Dashboard.NoCharacterData"] = "No character data",
    ["Dashboard.InventoryUnavailable"] = "Inventory unavailable",
    ["Dashboard.AccomplishmentsUnavailable"] = "Accomplishments unavailable",
    ["Dashboard.JourneyUnavailable"] = "Journey unavailable",

    ["Dashboard.AccomplishmentPointsFormat"] = "%s Accomplishment Points",
    ["Dashboard.SlotsUsedFormat"] = "%d / %d Slots Used",
    ["Dashboard.PercentFullFormat"] = "%.0f%% Full",
    ["Dashboard.EquippedItemLevelFormat"] = "Equipped Item Level: %s",
    ["Dashboard.LevelClassFormat"] = "Level %d %s",
    ["Dashboard.LevelSpecClassFormat"] = "Level %d %s %s",
    ["Dashboard.RecommendationMetaFormat"] = "Priority: %s",
    ["Dashboard.ConfidenceHigh"] = "High",
    ["Dashboard.ConfidenceMedium"] = "Medium",
    ["Dashboard.ConfidenceLow"] = "Low",
    ["Dashboard.PriorityHigh"] = "High",
    ["Dashboard.PriorityMedium"] = "Medium",
    ["Dashboard.PriorityLow"] = "Low",
    ["Dashboard.RecentAccomplishmentFormat"] = "Recent: %s",
    ["Dashboard.JourneyEntryCountFormat"] = "%d Moments",
    ["Dashboard.RecentJourneyEntryFormat"] = "Recent: %s",
    ["Dashboard.MythicPlusSeasonFormat"] = "Season %d",

    ["Dashboard.StatusHealthy"] = "Healthy",
    ["Dashboard.StatusFilling"] = "Filling",
    ["Dashboard.StatusFull"] = "Full",

    ["Dashboard.FutureFeatures"] = "Future Features",
    ["Dashboard.RecentLoot"] = "Recent Loot",
    ["Dashboard.InterestingItems"] = "Interesting Items",
    ["Dashboard.VendorSuggestions"] = "Vendor Suggestions",
    ["Dashboard.Milestones"] = "Milestones",
    ["Dashboard.ExpansionProgress"] = "Expansion Progress",
    ["Dashboard.RecentHistory"] = "Recent History",

    ["Dashboard.MythicPlus"] = "Mythic+",
    ["Dashboard.TooltipMythicPlus"] = "View Mythic+ details",
    ["Dashboard.MythicPlusNoKeystone"] = "No Keystone",
    ["Dashboard.MythicPlusKeystoneFormat"] = "Keystone: %s, Level %d",
    ["Dashboard.MythicPlusActiveRunFormat"] = "Run In Progress: Level %d",
    ["Dashboard.MythicPlusRatingFormat"] = "Rating: %s",
    ["Dashboard.MythicPlusBestFormat"] = "Best: +%d",
    ["Dashboard.MythicPlusUnavailable"] = "Mythic+ unavailable",
    ["Dashboard.StatusActive"] = "Active",

    ["Dashboard.Delves"] = "Delves",
    ["Dashboard.TooltipDelves"] = "View your Delves progression and history",
    ["Dashboard.DelvesJourneyRankFormat"] = "Journey Rank %d",
    ["Dashboard.DelvesProgress"] = "Progress",
    ["Dashboard.DelvesProgressFormat"] = "%d / %d",
    ["Dashboard.DelvesCompanion"] = "Companion",
    ["Dashboard.DelvesCompanionLevelFormat"] = "%s - Level %d",
    ["Dashboard.DelvesHistory"] = "History",
    ["Dashboard.DelvesHighestTierFormat"] = "Highest Tier %d",
    ["Dashboard.DelvesHistoryFormat"] = "Highest Tier %d - Completed %d",
    ["Dashboard.DelvesCompletionsFormat"] = "Completed %d",
    ["Dashboard.DelvesNoProgress"] = "Begin your Delves journey to see progress here.",
    ["Dashboard.Dungeons"] = "Dungeons",
    ["Dashboard.ActivityLog"] = "Activity Log",
    ["Dashboard.TooltipActivityLog"] = "View your complete recorded activity history",
    ["Dashboard.ActivityLogCountFormat"] = "Recorded Activities: %d",
    ["Dashboard.ActivitySubtitleFormat"] = "%s - %s",
    ["Dashboard.ActivityLineFormat"] = "%s %s%s  |cff999999%s|r",
    ["Dashboard.ActivityTimelineTitleFormat"] = "%s %s%s",

    ["Dungeons.SectionRecentActivity"] = "Recent Activity",
    ["Dungeons.SectionDelves"] = "Delves",
    ["Dungeons.SectionOverview"] = "Dungeon Overview",
    ["Dungeons.HeroCurrentDungeon"] = "Current Dungeon",
    ["Dungeons.HeroActiveDelve"] = "Active Delve",
    ["Dungeons.HeroActiveDelveTier"] = "Active Delve Tier",
    ["Dungeons.HeroNoActiveDungeon"] = "No active dungeon",
    ["Dungeons.NoActiveDelve"] = "No active Delve",
    ["Dungeons.NoRecentActivity"] = "No general dungeon or Delve activity recorded yet.",
    ["Dungeons.OverviewUnavailable"] = "Normal, Heroic, Mythic 0, Story Dungeon, and Dungeon Finder progress is not currently recorded.",
    ["Dungeons.WeeklyProgressUnavailable"] = "Not currently tracked",
    ["Dungeons.StatActiveDelve"] = "Active Delve",
    ["Dungeons.StatRecentDungeon"] = "Recent Dungeon",
    ["Dungeons.StatWeeklyProgress"] = "Weekly Dungeon Progress",
    ["Dungeons.StatTrackedCompletions"] = "Tracked Delve Completions",
    ["Dungeons.StatHighestTrackedTier"] = "Highest Tracked Delve Tier",
    ["Dungeons.DelveTierFormat"] = "%s (Tier %d)",
    ["Dungeons.DungeonDifficultyFormat"] = "%s (%s)",
    ["Dungeons.ActivityDungeonFormat"] = "%s",
    ["Dungeons.ActivityDungeonDifficultyFormat"] = "%s (%s)",

    ["Delves.JourneyRank"] = "Journey Rank",
    ["Delves.JourneyProgress"] = "Journey Progress",
    ["Delves.JourneyOnboarding"] = "Your seasonal Delves progress will appear here.",
    ["Delves.SectionCurrentRun"] = "Current Run",
    ["Delves.CurrentRunTierFormat"] = "Tier %s",
    ["Delves.CurrentRunLives"] = "Lives Remaining",
    ["Delves.CurrentRunAffixes"] = "Active Affixes",
    ["Delves.CurrentRunAffixStackFormat"] = "%s (%d)",
    ["Delves.CurrentRunReward"] = "Reward State",
    ["Delves.CurrentRunRewardAvailable"] = "Available",
    ["Delves.CurrentRunRewardUnavailable"] = "Unavailable",
    ["Delves.SectionCompanion"] = "Companion",
    ["Delves.SectionProgress"] = "Progress",
    ["Delves.SectionGreatVault"] = "Great Vault",
    ["Delves.CompanionLevelFormat"] = "Level %d",
    ["Delves.CompanionXPFormat"] = "%d / %d XP",
    ["Delves.CompanionMaximumLevel"] = "Maximum Level",
    ["Delves.CombatCurio"] = "Combat Curio",
    ["Delves.UtilityCurio"] = "Utility Curio",
    ["Delves.CurioRankFormat"] = "Rank %d/%d",
    ["Delves.HighestTier"] = "Highest Tier",
    ["Delves.Completed"] = "Completed Delves",
    ["Delves.VaultDungeons"] = "Dungeons",
    ["Delves.VaultWorld"] = "World",
    ["Delves.VaultRewardTitleFormat"] = "%s Reward",
    ["Delves.VaultUnlocked"] = "Unlocked",
    ["Delves.VaultLocked"] = "Locked",
    ["Delves.VaultItemLevel"] = "Item Level",
    ["Delves.VaultProgress"] = "Progress",
    ["Delves.VaultQualifyingLevel"] = "Qualifying Level",
    ["Delves.VaultDungeonLevelFormat"] = "Mythic +%d",
    ["Delves.VaultWorldTierFormat"] = "Tier %d",
    ["Delves.RecentRunTierFormat"] = "%s   Tier %d   %s",
    ["Delves.RecentRunFormat"] = "%s   %s",

    ["Dashboard.TooltipRecommendations"] = "View all recommendations",
    ["Dashboard.TooltipProfile"] = "View full character details",
    ["Dashboard.TooltipInventory"] = "View full inventory details",
    ["Dashboard.TooltipAccomplishments"] = "View your character's defining accomplishments",
    ["Dashboard.TooltipJourney"] = "View the story of this character over time",
    ["Dashboard.TooltipStorage"] = "View storage readiness and open the Inventory Manager",

    ["Dashboard.Storage"] = "Storage",
    ["Dashboard.StorageReady"] = "Ready to go.",
    ["Dashboard.StorageMissingFormat"] = "%d item(s) need attention",
    ["Dashboard.StorageNoProfile"] = "No storage profile selected",
    ["Dashboard.StorageUnavailable"] = "Storage unavailable",
    ["Dashboard.StorageNoScan"] = "No storage scan",
    ["Dashboard.StorageStatusReady"] = "Storage: Ready",
    ["Dashboard.StorageStatusNeedsRestock"] = "Storage: Needs Restock",

    ["Dashboard.Weekly"] = "Weekly",

    ["Dashboard.StatusRested"] = "Rested",
    ["Dashboard.PreparationNotReady"] = "Not Ready",

    ["Dashboard.PercentFullFreeFormat"] = "%.0f%% full, %d free",

    ["Dashboard.LastUpdatedFormat"] = "Updated %s",

    ["Dashboard.ExecuteResultFormat"] = "Storage: withdrew %d, deposited %d.",
    ["Dashboard.ExecuteFailedGeneric"] = "Storage: nothing was moved.",
    ["Dashboard.ExecuteFailedCombat"] = "Storage: can't move items in combat.",
    ["Dashboard.ExecuteFailedBankClosed"] = "Storage: open your bank first.",

    -----------------------------------------------------------------------
    -- Home Dashboard Evolution -- Detail Section labels/formats. Each
    -- "Section*" key is a standalone caption (rendered above its own
    -- value by DashboardCard:SetDetailSections), distinct from the
    -- older "Recommendation*Format" keys above which combine a label
    -- and value on one line -- those stay in use by the Recommendations
    -- page's list rows, unchanged; these are for Home's cards, which
    -- now separate label from value visually instead of merging them.
    -----------------------------------------------------------------------

    ["Dashboard.SectionPriority"] = "Priority",
    ["Dashboard.SectionConfidence"] = "Confidence",
    ["Dashboard.SectionReason"] = "Reason",
    ["Dashboard.SectionExpectedBenefit"] = "Expected Benefit",
    ["Dashboard.SectionEstimatedTime"] = "Estimated Time",
    ["Dashboard.SectionSupportingEvidence"] = "Supporting Evidence",

    ["Dashboard.SectionItemLevel"] = "Item Level",
    ["Dashboard.LocationFormat"] = "%s - %s",

    ["Dashboard.SectionSessionChange"] = "This Session",
    ["Dashboard.ItemLevelGainedSessionFormat"] = "Item Level %s",
    ["Dashboard.LevelsGainedSessionFormat"] = "Reached level %d",

    ["Dashboard.SectionMissing"] = "Missing",

    ["Dashboard.SectionHighestReward"] = "Highest Reward",
    ["Dashboard.HighestRewardFormat"] = "Item Level %d",
    ["Dashboard.SectionRemaining"] = "Remaining",
    ["Dashboard.VaultRemainingFormat"] = "%d objective(s) remaining",

    ["Dashboard.SectionItemsMissing"] = "Items Missing",
    ["Dashboard.StorageWithdrawCountFormat"] = "%d item(s) in your bank",
    ["Dashboard.SectionShoppingList"] = "Shopping List",
    ["Dashboard.StorageShoppingCountFormat"] = "%d item(s) to buy",

    ["Dashboard.FeedMythicPlusTimedFormat"] = "Timed +%d %s",
    ["Dashboard.FeedMythicPlusFailedFormat"] = "Not Timed +%d %s",
    ["Dashboard.FeedAchievementFormat"] = "Earned %s",
    ["Dashboard.FeedDelveTierFormat"] = "Completed Tier %d %s",
    ["Dashboard.FeedDelveFormat"] = "Completed %s",

    -----------------------------------------------------------------------
    -- Profile Page
    -----------------------------------------------------------------------

    ["Profile.SectionCharacter"] = "Character",
    ["Profile.SectionGuildAndCurrency"] = "Guild & Currency",
    ["Profile.SectionEquipment"] = "Equipment",
    ["Profile.SectionLocation"] = "Location",
    ["Profile.SectionProgress"] = "Progress",
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
    ["Profile.GuildRank"] = "Guild Rank",
    ["Profile.Faction"] = "Faction",
    ["Profile.Money"] = "Money",
    ["Profile.PlayedTime"] = "Played Time",
    ["Profile.MaxLevel"] = "Max Level",
    ["Profile.RestedXP"] = "Rested XP",
    ["Profile.TimeAtCurrentLevel"] = "Time at Current Level",
    ["Profile.LoginTime"] = "Login Time",
    ["Profile.SessionDuration"] = "Current Session Duration",
    ["Profile.ItemLevelGainedSession"] = "Item Level Gained This Session",
    ["Profile.LevelsGainedSession"] = "Levels Gained This Session",

    ["Dashboard.WarbandOverview"] = "Warband Overview",

    -----------------------------------------------------------------------
    -- Inventory Page
    -----------------------------------------------------------------------

    ["Inventory.SectionBagSummary"] = "Bag Summary",
    ["Inventory.SectionEquipment"] = "Equipment",
    ["Inventory.SectionImportantItems"] = "Important Items",
    ["Inventory.SectionEquipmentHealth"] = "Equipment Health",
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
    ["Inventory.OverallDurability"] = "Overall Durability",
    ["Inventory.WorstItemDurability"] = "Worst Item",
    ["Inventory.RepairCost"] = "Repair Cost",
    ["Inventory.ItemsAdded"] = "Items Added",
    ["Inventory.ItemsRemoved"] = "Items Removed",
    ["Inventory.BagUsageChange"] = "Bag Usage Change",

    ["Inventory.HearthstoneInBags"] = "In Bags",
    ["Inventory.HearthstoneMissing"] = "Missing",
    ["Inventory.RepairsNeeded"] = "Repairs needed",
    ["Inventory.NoRepairsNeeded"] = "No repairs needed",
    ["Inventory.EquipmentBroken"] = "Equipment broken!",
    ["Inventory.RepairCostUnavailable"] = "Visit a repair vendor to see cost",
    ["Inventory.EquipmentHealthExcellent"] = "Excellent",
    ["Inventory.EquipmentHealthGood"] = "Good",
    ["Inventory.EquipmentHealthFair"] = "Fair",
    ["Inventory.EquipmentHealthCritical"] = "Critical",

    ["Inventory.SectionRecommendations"] = "Recommendations",
    ["Inventory.SectionInsights"] = "Insights",
    ["Inventory.NoRecommendations"] = "No inventory recommendations right now.",
    ["Inventory.NoInsights"] = "Nothing noteworthy right now.",

    -----------------------------------------------------------------------
    -- Accomplishments Page (formerly Achievements -- redesigned from a
    -- flat every-achievement cache into a curated "what defines this
    -- character" view; see Modules/Accomplishments/AccomplishmentsModule.lua)
    -----------------------------------------------------------------------

    ["Accomplishments.HeroHeadline"] = "Accomplishments",
    ["Accomplishments.HeroCaptionFormat"] = "%s points -- %s to next milestone",

    ["Accomplishments.SectionExpansionProgress"] = "Expansion Progress",
    ["Accomplishments.CampaignLineFormat"] = "%s — %s",
    ["Accomplishments.CampaignStateComplete"] = "Complete",
    ["Accomplishments.CampaignStateInProgress"] = "In Progress",
    ["Accomplishments.CampaignStateStalled"] = "Stalled",
    ["Accomplishments.RenownLineFormat"] = "%s — Renown %d",
    ["Accomplishments.RenownCappedSuffix"] = " (Weekly Capped)",
    ["Accomplishments.RenownMaxSuffix"] = " (Max)",
    ["Accomplishments.NoCampaignOrRenownProgress"] = "No campaign or Renown progress to show yet.",
    -- Accordion Redesign -- reworded/narrowed: this empty state now covers
    -- only the ExpansionProgress-category accomplishment rows, since
    -- Campaign/Renown got their own empty line above. Was "No expansion
    -- progress to show yet." -- a real, visible string change.
    ["Accomplishments.NoExpansionAccomplishments"] = "No expansion accomplishments yet.",

    ["Accomplishments.SectionRaiding"] = "Raiding",
    ["Accomplishments.NoRaidingAccomplishments"] = "No raiding accomplishments yet.",

    ["Accomplishments.SectionMythicPlus"] = "Mythic+",
    ["Accomplishments.NoMythicPlusAccomplishments"] = "No Mythic+ accomplishments yet.",

    ["Accomplishments.SectionFeatsOfStrength"] = "Feats of Strength",
    ["Accomplishments.NoFeatsOfStrength"] = "No Feats of Strength yet.",

    ["Accomplishments.SectionCharacterMilestones"] = "Character Milestones",
    ["Accomplishments.NoCharacterMilestones"] = "No character milestones yet.",

    ["Accomplishments.SectionLegacy"] = "Legacy Accomplishments",
    ["Accomplishments.LegacyComingSoon"] = "Coming in a future update.",

    -- Accordion Redesign -- expanded-detail field labels.
    ["Accomplishments.FieldEarned"] = "Earned",
    ["Accomplishments.FieldCategory"] = "Category",
    ["Accomplishments.FieldExpansion"] = "Expansion",

    ["Accomplishments.SectionRecentHistory"] = "Recent History",
    ["Accomplishments.NoRecentHistory"] = "No accomplishments recorded yet.",
    ["Accomplishments.RecentHistoryLineFormat"] = "%s — %s",

    ["Accomplishments.SectionRecommendations"] = "Recommendations",
    ["Accomplishments.NoRecommendations"] = "You're all caught up.",

    ["Accomplishments.SectionInsights"] = "Insights",
    ["Accomplishments.NoInsights"] = "No accomplishment insights right now.",

    -----------------------------------------------------------------------
    -- Journey Page (Character Journey)
    -----------------------------------------------------------------------

    ["Journey.HeroHeadline"] = "Character Journey",
    ["Journey.HeroCaptionFormat"] = "Most recent: %s",
    ["Journey.EmptyHeroCaption"] = "Your story is just beginning.",
    ["Journey.EmptyStateBody"] = "As you earn signature achievements, complete campaigns, and reach personal milestones, they'll appear here as the story of this character.",
    ["Journey.EntryLineFormat"] = "%s — %s",
    ["Journey.UndatedSectionLabel"] = "Undated",
    ["Journey.FieldRecorded"] = "Recorded",
    ["Journey.CategoryPersonalMilestone"] = "Personal Milestone",
    ["Journey.SortNewestFirst"] = "Newest First",
    ["Journey.SortOldestFirst"] = "Oldest First",

    -----------------------------------------------------------------------
    -- MythicPlus Page
    -----------------------------------------------------------------------

    ["MythicPlus.SectionKeystone"] = "Keystone",
    ["MythicPlus.SectionRating"] = "Rating",
    ["MythicPlus.SectionCurrentRun"] = "Current Run",

    ["MythicPlus.CurrentSeason"] = "Current Season",
    ["MythicPlus.HasKeystone"] = "Has Keystone",
    ["MythicPlus.CurrentDungeon"] = "Current Dungeon",
    ["MythicPlus.KeystoneLevel"] = "Keystone Level",
    ["MythicPlus.Rating"] = "Overall Rating",
    ["MythicPlus.BestCompleted"] = "Best Completed",
    ["MythicPlus.BestTimed"] = "Best Timed",
    ["MythicPlus.ActiveStatus"] = "Active Status",
    ["MythicPlus.ActiveLevel"] = "Run Level",
    ["MythicPlus.Deaths"] = "Deaths",

    ["MythicPlus.SectionRecentRuns"] = "Recent Runs",
    ["MythicPlus.SectionSeasonStatistics"] = "Season Statistics",
    ["MythicPlus.SectionRecommendations"] = "Recommendations",
    ["MythicPlus.SectionInsights"] = "Insights",
    ["MythicPlus.ComingSoon"] = "Coming in Phase 2",
    ["MythicPlus.NoRecommendations"] = "No Mythic+ recommendations right now.",
    ["MythicPlus.NoInsights"] = "Nothing noteworthy right now.",
    ["MythicPlus.NoRunsRecorded"] = "No Mythic+ runs recorded this season.",
    ["MythicPlus.NoSeasonStatistics"] = "Season statistics will appear after your first completed run.",

    ["MythicPlus.HeroCurrentKeystone"] = "Current Keystone",
    ["MythicPlus.HeroRunInProgress"] = "Run In Progress",
    ["MythicPlus.HeroNoKeystone"] = "No keystone slotted",

    ["MythicPlus.StatRating"] = "Overall Rating",
    ["MythicPlus.StatSeason"] = "Current Season",
    ["MythicPlus.StatBestTimed"] = "Best Timed",
    ["MythicPlus.StatBestCompleted"] = "Best Completed",

    ["MythicPlus.StatRunsCompleted"] = "Runs Completed",
    ["MythicPlus.StatTimedRuns"] = "Timed Runs",
    ["MythicPlus.StatFailedRuns"] = "Failed Runs",
    ["MythicPlus.StatSuccessRate"] = "Success Rate",
    ["MythicPlus.StatAverageKeyLevel"] = "Average Key Level",
    ["MythicPlus.StatRatingChange"] = "Rating Change",
    ["MythicPlus.StatFastestRun"] = "Fastest Run",
    ["MythicPlus.StatAverageDeaths"] = "Average Deaths",
    ["MythicPlus.StatAverageCompletionTime"] = "Average Completion Time",

    ["MythicPlus.SectionPerformanceTrends"] = "Performance Trends",
    ["MythicPlus.SectionConsumables"] = "Consumables",
    ["MythicPlus.NoPerformanceTrends"] = "Performance trends will appear after your first completed run.",
    ["MythicPlus.NoConsumableData"] = "Consumable usage will appear after your first tracked run.",

    ["MythicPlus.FastestRunFormat"] = "%s  +%d  %s  %s",
    ["MythicPlus.RatingNoChange"] = "No Change",
    ["MythicPlus.ConsumablePotion"] = "Potions",
    ["MythicPlus.ConsumableFlask"] = "Flasks",
    ["MythicPlus.ConsumableFood"] = "Food Buffs",
    ["MythicPlus.ConsumableHealthstone"] = "Healthstones",
    ["MythicPlus.ConsumableItemEnhancement"] = "Weapon Enhancements",
    ["MythicPlus.ConsumablesTrackedFormat"] = "Based on %d tracked run(s)",

    ["MythicPlus.RunDetailOutcome"] = "Outcome: %s",
    ["MythicPlus.OutcomeNotTimed"] = "Not Timed",
    ["MythicPlus.RunDetailTime"] = "Completion Time: %s",
    ["MythicPlus.RunDetailDeaths"] = "Deaths: %d",
    ["MythicPlus.RunDetailStarted"] = "Started: %s",
    ["MythicPlus.RunDetailFinished"] = "Finished: %s",
    ["MythicPlus.RunDetailRatingChange"] = "Rating Change: %s",

    -----------------------------------------------------------------------
    -- Delve presentation
    -----------------------------------------------------------------------

    ["Delves.SectionRecentDelves"] = "Recent Delves",
    ["Delves.OpenActivityTooltip"] = "Open in Activity History",
    ["Delves.NoDelvesRecorded"] = "No Delves completed yet.",

    -----------------------------------------------------------------------
    -- Activity Log Page
    -----------------------------------------------------------------------

    ["ActivityLog.HeroHeadline"] = "Total Recorded Activities",
    ["ActivityLog.HeroCaption"] = "Across your tracked history",
    ["ActivityLog.HeroEmptyCaption"] = "Your recorded history will appear below",
    ["ActivityLog.StatOldest"] = "First Recorded",
    ["ActivityLog.StatNewest"] = "Most Recent",
    ["ActivityLog.StatActivityTypes"] = "Activity Types",
    ["ActivityLog.StatCharacters"] = "Characters Represented",
    ["ActivityLog.SectionFilters"] = "Filters",
    ["ActivityLog.SectionTimeline"] = "Timeline",
    ["ActivityLog.FilterActivityType"] = "Activity Type",
    ["ActivityLog.FilterSort"] = "Sort",
    ["ActivityLog.FilterAll"] = "All",
    ["ActivityLog.FilterMythicPlus"] = "Mythic+",
    ["ActivityLog.FilterDelves"] = "Delves",
    ["ActivityLog.FilterHeroic"] = "Heroic",
    ["ActivityLog.FilterMythic0"] = "Mythic 0",
    ["ActivityLog.FilterAchievements"] = "Achievements",
    ["ActivityLog.FilterOther"] = "Other",
    ["ActivityLog.SortNewest"] = "Newest First",
    ["ActivityLog.SortOldest"] = "Oldest First",
    ["ActivityLog.ContextMythicPlusFormat"] = "+%d %s %s",
    ["ActivityLog.ContextMythicPlus"] = "Mythic+",
    ["ActivityLog.ContextNotTimed"] = "Not Timed",
    ["ActivityLog.ContextDelveTierFormat"] = "Tier %d Delve",
    ["ActivityLog.ContextDelveTierSummaryFormat"] = "Tier %d",
    ["ActivityLog.ContextDelveDurationFormat"] = "Time %s",
    ["ActivityLog.ContextDelve"] = "Delve",
    ["ActivityLog.ContextHeroic"] = "Heroic Dungeon",
    ["ActivityLog.ContextMythic0"] = "Mythic 0",
    ["ActivityLog.ContextDungeonDifficultyFormat"] = "%s Dungeon",
    ["ActivityLog.ContextDungeon"] = "Dungeon",
    ["ActivityLog.ContextAchievement"] = "Achievement Earned",
    ["ActivityLog.UnknownDate"] = "Unknown Date",
    ["ActivityLog.NoActivities"] = "Complete an activity to begin your log.",
    ["ActivityLog.NoMatchingActivities"] = "No activities match the selected filter.",

    -----------------------------------------------------------------------
    -- Storage Page
    -----------------------------------------------------------------------

    -- Storage presentation shared by the Dashboard summary and Inventory
    -- Manager. Legacy labels remain available to existing consumers.
    ["Storage.SectionStorageSummary"] = "Storage Summary",
    ["Storage.StatBagSlotsUsed"] = "Bag Slots Used",
    ["Storage.StatBagSlotsFree"] = "Bag Slots Free",
    ["Storage.NotAtBank"] = "Visit a banker to scan your bank.",
    ["Storage.StatBankSlotsScanned"] = "Bank Slots Used",
    ["Storage.StatBankDistinctItems"] = "Distinct Items in Bank",

    ["Storage.SectionSupplyHealth"] = "Supply Health",
    ["Storage.SupplyHealthReady"] = "Ready to Play",
    ["Storage.SupplyHealthMissingFormat"] = "Missing %d %s",
    ["Storage.SupplyHealthMultipleMissing"] = "Multiple Required Consumables Missing",
    ["Storage.SupplyHealthTransfersFormat"] = "Ready after %d Bank Transfer(s)",

    ["Storage.SectionCurrentProfile"] = "Current Profile",
    ["Storage.NoProfileSelected"] = "No storage profile selected.",
    ["Storage.FieldActiveProfile"] = "Active Profile",
    ["Storage.FieldRuleCount"] = "Rule Count",

    ["Storage.SectionBankTransfers"] = "Bank Transfers",
    ["Storage.AmountWithdrawFormat"] = "Withdraw %d",
    ["Storage.AmountDepositFormat"] = "Deposit %d",
    ["Storage.NoBankTransfersNeeded"] = "Nothing to move between bags and bank right now.",

    ["Storage.SectionShoppingList"] = "Shopping List",
    ["Storage.NothingToBuy"] = "Nothing to buy right now.",
    ["Storage.ShoppingListNeedFormat"] = "Need %d",
    ["Storage.ShoppingListItemFormat"] = "%s (have %d)",
    ["Storage.ShoppingListNoneHeld"] = "None currently held -- check a vendor or the Auction House.",

    ["Storage.SectionConsumables"] = "Consumables",
    ["Storage.NoConsumablesTracked"] = "No tracked consumables found in your bags or bank.",
    ["Storage.ConsumableCountFormat"] = "%d total (%d bag, %d bank)",
    ["Storage.Category.potion"] = "Potions",
    ["Storage.Category.flask"] = "Flasks",
    ["Storage.Category.food"] = "Food",
    ["Storage.Category.itemEnhancement"] = "Weapon Enhancements",
    ["Storage.Category.healthstone"] = "Healthstones",

    ["Storage.SectionSupplyForecast"] = "Supply Forecast",
    ["Storage.NoSupplyForecast"] = "Not enough Mythic+ history yet to forecast supply usage.",
    ["Storage.SupplyForecastFormat"] = "Approximately %d Mythic+ runs remaining",

    ["Storage.SectionInsights"] = "Storage Insights",
    ["Storage.NoInsights"] = "No storage insights right now.",

    ["Storage.Profile.MythicPlus"] = "Mythic+",
    ["Storage.Profile.Raid"] = "Raid",
    ["Storage.Profile.Questing"] = "Questing",
    ["Storage.Profile.Delves"] = "Delves",
    ["Storage.Profile.PvP"] = "PvP",
    ["Storage.Profile.Custom"] = "Custom",

    ["Storage.Rule.Potions"] = "Potions",
    ["Storage.Rule.Flasks"] = "Flasks",
    ["Storage.Rule.Food"] = "Food",
    ["Storage.Rule.Hearthstone"] = "Hearthstone",
    ["Storage.Rule.QuestItems"] = "Quest Items",
    ["Storage.Rule.CurrentEquipment"] = "Current Equipment",
    ["Storage.Rule.CraftingMaterials"] = "Crafting Materials",

    ["Storage.ExecuteButton"] = "Execute Restock",
    ["Storage.ExecuteConfirmFormat"] = "This will attempt %d withdrawal(s) and %d deposit(s) using whole item stacks. Continue?",

    -----------------------------------------------------------------------
    -- Inventory Manager
    -----------------------------------------------------------------------

    ["InventoryManager.Title"] = "Inventory Manager",
    ["InventoryManager.Description"] = "Manage your bags, banks, consumables, and storage preparation.",
    ["InventoryManager.PageCaption"] = "A dedicated workspace for storage management.",
    ["InventoryManager.DashboardCaption"] = "Open the Inventory Manager for detailed storage work.",

    ["InventoryManager.NavOverview"] = "Overview",
    ["InventoryManager.NavCategories"] = "Categories",
    ["InventoryManager.NavSearch"] = "Search",
    ["InventoryManager.NavTransfers"] = "Transfers",
    ["InventoryManager.NavShoppingList"] = "Shopping List",
    ["InventoryManager.NavConsumables"] = "Consumables",
    ["InventoryManager.NavLoadouts"] = "Loadouts",
    ["InventoryManager.NavExplorer"] = "Explorer",
    ["InventoryManager.NavForecast"] = "Forecast",
    ["InventoryManager.NavSettings"] = "Settings",

    ["InventoryManager.StatStorageReadiness"] = "Storage Readiness",
    ["InventoryManager.StatCurrentProfile"] = "Current Profile",
    ["InventoryManager.StatLastScan"] = "Last Scan",
    ["InventoryManager.StatItemsScanned"] = "Bank Item Types",
    ["InventoryManager.LastScanUnknown"] = "Not tracked",
    ["InventoryManager.SourceUnavailable"] = "Unavailable",
    ["InventoryManager.SourceBags"] = "Bags",
    ["InventoryManager.SourceCharacterBank"] = "Character Bank",
    ["InventoryManager.SourceWarbandBank"] = "Warband Bank",
    ["InventoryManager.SourceStateCurrent"] = "Current",
    ["InventoryManager.SourceStateLastScanFormat"] = "Last scanned %s",
    ["InventoryManager.SourceCountFormat"] = "%d of %d available",
    ["InventoryManager.SourceLineFormat"] = "%s — %s • %d slots • %d item types",
    ["InventoryManager.Ready"] = "Ready",
    ["InventoryManager.ReadinessFormat"] = "%.0f%% Ready",
    ["InventoryManager.BankNotConnected"] = "Bank Not Connected",

    ["InventoryManager.OverviewHeroTitle"] = "Inventory Preparation",
    ["InventoryManager.OverviewHeroCaption"] = "Based on your latest storage snapshot.",
    ["InventoryManager.NoSnapshotTitle"] = "No Storage Snapshot",
    ["InventoryManager.NoSnapshotDescription"] = "Visit a supported bank once so Azeroth Companion can learn your storage.",

    ["InventoryManager.LiveStatusSectionTitle"] = "Live Storage Status",
    ["InventoryManager.LiveStatusConnectedFormat"] = "%s Live Bank Connected",
    ["InventoryManager.LiveStatusDisconnectedFormat"] = "%s Bank Not Connected",
    ["InventoryManager.LiveStatusDisconnectedDescription"] = "Using your latest storage snapshot. Open your bank to refresh live storage information.",

    ["InventoryManager.RecommendationsCaption"] = "Based on your latest storage snapshot.",
    ["InventoryManager.ProfileMismatchFormat"] = "Analysis was generated using the %s profile. Current profile: %s. Open your bank to refresh.",

    ["InventoryManager.NoScanTitle"] = "No Storage Scan",
    ["InventoryManager.NoScanDescription"] = "Open a supported bank, then scan your inventory to begin.",
    ["InventoryManager.DataRequiresScan"] = "Open a supported bank before evaluating this information.",
    ["InventoryManager.StorageDisabled"] = "The Storage module is disabled.",
    ["InventoryManager.LiveDataAvailable"] = "Current bank data is available.",
    ["InventoryManager.StaleDataAvailable"] = "Showing the last storage snapshot from %s. Open a supported bank to refresh it.",
    ["InventoryManager.OpenBankPrompt"] = "Open a supported bank to make storage data available.",
    ["InventoryManager.ScanInventory"] = "Scan Inventory",
    ["InventoryManager.ScanComplete"] = "Inventory scan refreshed.",
    ["InventoryManager.ScanFailed"] = "The storage scan could not be completed. The last successful snapshot was preserved.",
    ["InventoryManager.ScanUnavailable"] = "Inventory scanning is currently unavailable.",

    ["InventoryManager.SectionRecommendations"] = "Current Recommendations",
    ["InventoryManager.SectionStorageSources"] = "Storage Sources",
    ["InventoryManager.NoSources"] = "No supported storage source has been scanned yet.",

    ["InventoryManager.CategoriesHeroTitle"] = "Stored Items",
    ["InventoryManager.CategoriesHeroCaption"] = "Browse authoritative items across bags and available bank snapshots.",
    ["InventoryManager.StatCategories"] = "Categories",
    ["InventoryManager.StatAggregateItemTypes"] = "Item Types",
    ["InventoryManager.StatAggregateStacks"] = "Stacks",
    ["InventoryManager.StatAggregateSources"] = "Sources Available",
    ["InventoryManager.SectionCategories"] = "Categories",
    ["InventoryManager.CategoriesEmpty"] = "No items are available from bags or scanned storage sources.",
    ["InventoryManager.CategoryItemCountFormat"] = "%d item types",
    ["InventoryManager.CategoryStackCountFormat"] = "%d items across %d stacks",
    ["InventoryManager.CategoryLocationFormat"] = "%s: %d stacks / %d items",
    ["InventoryManager.CategoryEquipment"] = "Equipment",
    ["InventoryManager.CategoryConsumables"] = "Consumables",
    ["InventoryManager.CategoryReagents"] = "Reagents",
    ["InventoryManager.CategoryTradeGoods"] = "Trade Goods",
    ["InventoryManager.CategoryQuestItems"] = "Quest Items",
    ["InventoryManager.CategoryMounts"] = "Mounts",
    ["InventoryManager.CategoryBattlePets"] = "Battle Pets",
    ["InventoryManager.CategoryMiscellaneous"] = "Miscellaneous",
    ["InventoryManager.CategoryUnknown"] = "Unknown",
    ["InventoryManager.AggregateBagsAndBanks"] = "Showing live bags and recorded bank snapshots.",
    ["InventoryManager.AggregateBagsOnly"] = "Showing live bags. Open a supported bank to include stored items.",
    ["InventoryManager.AggregateBanksOnly"] = "Showing recorded bank snapshots. Live bags are unavailable.",
    ["InventoryManager.AggregateUnavailable"] = "No authoritative inventory or storage data is currently available.",

    ["InventoryManager.SearchHeroTitle"] = "Search Storage",
    ["InventoryManager.SearchHeroValue"] = "Find Items",
    ["InventoryManager.SearchHeroCaption"] = "Find items across live bags and recorded bank snapshots.",
    ["InventoryManager.SectionSearch"] = "Search",
    ["InventoryManager.SectionSearchFilters"] = "Filters",
    ["InventoryManager.SectionSearchSummary"] = "Result Summary",
    ["InventoryManager.SectionSearchResults"] = "Search Results",
    ["InventoryManager.SearchItemName"] = "Item Name",
    ["InventoryManager.SearchInputTooltip"] = "Enter part of an item's name. Matching is case-insensitive.",
    ["InventoryManager.SearchButton"] = "Search",
    ["InventoryManager.SearchClear"] = "Clear",
    ["InventoryManager.SearchFilterCategory"] = "Category",
    ["InventoryManager.SearchFilterSource"] = "Storage Source",
    ["InventoryManager.SearchFilterOwner"] = "Owner",
    ["InventoryManager.SearchFilterQuality"] = "Quality",
    ["InventoryManager.SearchSort"] = "Sort By",
    ["InventoryManager.FilterAllCategories"] = "All Categories",
    ["InventoryManager.FilterAllSources"] = "All Sources",
    ["InventoryManager.FilterAllOwners"] = "All Owners",
    ["InventoryManager.FilterAllQualities"] = "All Qualities",
    ["InventoryManager.OwnerNameRealmFormat"] = "%s-%s",
    ["InventoryManager.SortName"] = "Name",
    ["InventoryManager.SortQuantity"] = "Quantity",
    ["InventoryManager.SortCategory"] = "Category",
    ["InventoryManager.SortSource"] = "Source",
    ["InventoryManager.QualityPoor"] = "Poor",
    ["InventoryManager.QualityCommon"] = "Common",
    ["InventoryManager.QualityUncommon"] = "Uncommon",
    ["InventoryManager.QualityRare"] = "Rare",
    ["InventoryManager.QualityEpic"] = "Epic",
    ["InventoryManager.QualityLegendary"] = "Legendary",
    ["InventoryManager.QualityArtifact"] = "Artifact",
    ["InventoryManager.QualityHeirloom"] = "Heirloom",
    ["InventoryManager.QualityWoWToken"] = "WoW Token",
    ["InventoryManager.QualityUnknown"] = "Unknown Quality",
    ["InventoryManager.SearchNeverSearched"] = "Enter an item name to begin searching your storage.",
    ["InventoryManager.SearchPending"] = "Press Search or Enter to search using the current name and filters.",
    ["InventoryManager.SearchSearching"] = "Searching the current aggregate storage snapshot...",
    ["InventoryManager.SearchEmptyQuery"] = "Enter a non-blank item name before searching.",
    ["InventoryManager.SearchNoResults"] = "No stored items match the current name and filters.",
    ["InventoryManager.SearchNoStorageData"] = "No authoritative bag or bank snapshot is available to search.",
    ["InventoryManager.SearchStorageUnavailable"] = "Storage search is unavailable while the Storage module is disabled.",
    ["InventoryManager.SearchSuccessStatus"] = "%d storage result(s) found.",
    ["InventoryManager.SearchResultsTitleFormat"] = "Search Results (%d)",
    ["InventoryManager.StatSearchItemTypes"] = "Item Types",
    ["InventoryManager.StatSearchQuantity"] = "Total Items",
    ["InventoryManager.StatSearchStacks"] = "Stacks",
    ["InventoryManager.StatSearchSources"] = "Sources",
    ["InventoryManager.SearchUnknownItemFormat"] = "Item %d",
    ["InventoryManager.SearchQuantityFormat"] = "%d items",
    ["InventoryManager.SearchResultContextFormat"] = "%s • %s • %d stacks",
    ["InventoryManager.SearchOwnerFormat"] = "Owner: %s",
    ["InventoryManager.SearchFreshnessCurrent"] = "Current",
    ["InventoryManager.SearchFreshnessRecorded"] = "Recorded %s",
    ["InventoryManager.SearchFreshnessUnknown"] = "Unknown freshness",

    ["InventoryManager.ShoppingHeroTitle"] = "Shopping List",
    ["InventoryManager.ShoppingHeroCaption"] = "See what your active preparation profile still needs before you play.",
    ["InventoryManager.ShoppingUnavailableValue"] = "Unavailable",
    ["InventoryManager.ShoppingNoRequirementsValue"] = "No Requirements",
    ["InventoryManager.SectionShoppingSummary"] = "Shopping Summary",
    ["InventoryManager.SectionShoppingMissing"] = "Items to Acquire",
    ["InventoryManager.SectionShoppingAvailable"] = "Available in Storage",
    ["InventoryManager.StatShoppingReadiness"] = "Preparation Readiness",
    ["InventoryManager.StatShoppingMissing"] = "Need to Acquire",
    ["InventoryManager.StatShoppingAvailable"] = "Available in Storage",
    ["InventoryManager.ShoppingMissingContext"] = "Still needed after checking current bags and storage.",
    ["InventoryManager.ShoppingAvailableContext"] = "Already in scanned storage; move it to your bags.",
    ["InventoryManager.ShoppingMissingStatus"] = "Missing",
    ["InventoryManager.ShoppingAvailableStatus"] = "In Storage",
    ["InventoryManager.ShoppingUnavailable"] = "Shopping information is currently unavailable.",
    ["InventoryManager.ShoppingUnknown"] = "Open a supported character bank and scan before evaluating what is missing.",
    ["InventoryManager.ShoppingStale"] = "The last bank snapshot is stale. Open a supported character bank to refresh the shopping list.",
    ["InventoryManager.ShoppingCharacterBankRequired"] = "Open a supported character bank before evaluating what still needs to be acquired.",
    ["InventoryManager.ShoppingInventoryRequired"] = "A current bag snapshot is required before evaluating what still needs to be acquired.",
    ["InventoryManager.ShoppingNoRequirements"] = "The active profile has no tracked shopping requirements.",
    ["InventoryManager.ShoppingReadyStatus"] = "All tracked preparation requirements are already in your bags.",
    ["InventoryManager.ShoppingFooterFormat"] = "%d items to acquire | %d available in storage",

    -- Consumables Page
    ["InventoryManager.ConsumablesHeroTitle"] = "Consumables",
    ["InventoryManager.ConsumablesHeroCaption"] = "See what consumables you currently have available across bags and storage.",
    ["InventoryManager.ConsumablesUnavailableValue"] = "Unavailable",
    ["InventoryManager.SectionConsumableSummary"] = "Consumable Summary",
    ["InventoryManager.StatConsumableTypes"] = "Item Types",
    ["InventoryManager.StatConsumableTotal"] = "Total Quantity",
    ["InventoryManager.StatConsumableInBags"] = "In Bags",
    ["InventoryManager.StatConsumableInBank"] = "In Bank",
    ["InventoryManager.SectionReadyConsumables"] = "Ready Consumables",
    ["InventoryManager.SectionMissingConsumables"] = "Missing Consumables",
    ["InventoryManager.ConsumablesEmpty"] = "No consumables found in your bags or scanned storage.",
    ["InventoryManager.ConsumablesMissingEmpty"] = "No missing consumables for your active profile.",
    ["InventoryManager.ConsumablesDisabled"] = "Consumable information is unavailable while the Storage module is disabled.",
    ["InventoryManager.ConsumablesNoSnapshot"] = "Open a supported bank and scan to see your consumable inventory.",
    ["InventoryManager.ConsumablesStale"] = "Showing the last consumable snapshot from %s. Open a supported bank to refresh.",
    ["InventoryManager.ConsumablesCurrent"] = "Bag and storage quantities reflect the current bank connection.",
    ["InventoryManager.SectionConsumableFreshness"] = "Storage Freshness",
    ["InventoryManager.SectionConsumableReadiness"] = "Preparation Readiness",
    ["InventoryManager.StatConsumableReadiness"] = "Readiness",
    ["InventoryManager.StatConsumableMissingRequirements"] = "Missing Requirements",
    ["InventoryManager.ConsumablesReadinessUnavailable"] = "Open a supported character bank for a current readiness check. Use Shopping List for acquisition details.",
    ["InventoryManager.ConsumablesOpenShoppingList"] = "Open Shopping List",
    ["InventoryManager.ConsumableQuantityFormat"] = "%d total",
    ["InventoryManager.ConsumableLocationFormat"] = "%d in bags • %d in bank",
    ["InventoryManager.ConsumableSubclass.potion"] = "Potions",
    ["InventoryManager.ConsumableSubclass.flask"] = "Flasks",
    ["InventoryManager.ConsumableSubclass.food"] = "Food",
    ["InventoryManager.ConsumableSubclass.itemEnhancement"] = "Weapon Enhancements",
    ["InventoryManager.ConsumableSubclass.healthstone"] = "Healthstones",
    ["InventoryManager.ConsumableSubclass.unknown"] = "Other Consumables",
    ["InventoryManager.ConsumableItemFormat"] = "%d items",
    ["InventoryManager.ConsumableSourceBags"] = "In Bags",
    ["InventoryManager.ConsumableSourceBank"] = "In Bank",
    ["InventoryManager.ConsumableSourceBoth"] = "Bags & Bank",
    ["InventoryManager.ConsumableMissingFormat"] = "Need %d more",
    ["InventoryManager.ConsumableMissingContext"] = "Required by your active preparation profile.",
    ["InventoryManager.ConsumablesReadyStatus"] = "All tracked consumables are in your bags.",
    ["InventoryManager.ConsumablesFooterFormat"] = "%d consumable types | %d total items",
    ["InventoryManager.ConsumablesFooterMissingFormat"] = "%d consumable types | %d total | %d missing",

    ["InventoryManager.ForecastHeroTitle"] = "Supply Forecast",
    ["InventoryManager.ForecastHeroCaption"] = "Estimate how many Mythic+ runs your tracked consumable stock can support.",
    ["InventoryManager.ForecastLearningValue"] = "Learning",
    ["InventoryManager.ForecastUnavailableValue"] = "Unavailable",
    ["InventoryManager.ForecastRunsValueFormat"] = "%d Runs",
    ["InventoryManager.SectionSupplyForecast"] = "Mythic+ Supply Forecast",
    ["InventoryManager.StatForecastTrackedRuns"] = "Tracked Runs",
    ["InventoryManager.StatForecastCategories"] = "Forecast Categories",
    ["InventoryManager.StatForecastShortestSupply"] = "Shortest Supply",
    ["InventoryManager.ForecastInsufficientHistory"] = "Complete more tracked Mythic+ runs before a supply forecast is available.",
    ["InventoryManager.ForecastUnavailable"] = "Mythic+ supply history is currently unavailable.",
    ["InventoryManager.ForecastValidEmpty"] = "No tracked Mythic+ consumable usage is available to forecast.",
    ["InventoryManager.ForecastRunsRemainingFormat"] = "About %d runs remaining",
    ["InventoryManager.ForecastCurrentStockFormat"] = "Known stock: %d",
    ["InventoryManager.ForecastAverageUseFormat"] = "Historical average: %.1f per tracked run",
    ["InventoryManager.ForecastFooterLearningFormat"] = "%d of %d tracked runs available for forecasting",
    ["InventoryManager.ForecastFooterFormat"] = "%d forecast categories | based on %d tracked runs",
    ["InventoryManager.ForecastFooterStaleFormat"] = "%d forecast categories | %d tracked runs | storage last scanned %s",
    ["InventoryManager.ForecastFooterNoSnapshotFormat"] = "%d forecast categories | %d tracked runs | bag stock only until storage is scanned",

    ["InventoryManager.TransfersHeroTitle"] = "Preparation Transfers",
    ["InventoryManager.TransfersHeroCaption"] = "Preview what your active preparation profile will move between bags and scanned storage.",
    ["InventoryManager.TransfersUnavailableValue"] = "Unavailable",
    ["InventoryManager.TransfersReadyValue"] = "Ready",
    ["InventoryManager.TransfersActionsValueFormat"] = "%d Actions",
    ["InventoryManager.StatTransferReadiness"] = "Readiness",
    ["InventoryManager.StatTransferActions"] = "Planned Actions",
    ["InventoryManager.StatTransferWithdrawals"] = "Withdrawals",
    ["InventoryManager.StatTransferDeposits"] = "Deposits",
    ["InventoryManager.SectionTransferPlan"] = "Transfer Plan",
    ["InventoryManager.SectionTransferWithdrawals"] = "Withdrawals",
    ["InventoryManager.SectionTransferDeposits"] = "Deposits",
    ["InventoryManager.SectionTransferResult"] = "Last Execution",
    ["InventoryManager.TransferSourceStorage"] = "Scanned Storage",
    ["InventoryManager.TransferSourceBags"] = "Bags",
    ["InventoryManager.TransferDestinationStorage"] = "Scanned Storage",
    ["InventoryManager.TransferDestinationBags"] = "Bags",
    ["InventoryManager.TransferRouteFormat"] = "%s → %s",
    ["InventoryManager.TransferQuantityFormat"] = "%d planned",
    ["InventoryManager.TransferWithdrawStatus"] = "Withdraw",
    ["InventoryManager.TransferDepositStatus"] = "Deposit",
    ["InventoryManager.TransfersScanRequired"] = "Open a supported character bank and complete a current scan to preview and execute preparation transfers.",
    ["InventoryManager.TransfersNothingPlanned"] = "Nothing needs to move for the active preparation profile.",
    ["InventoryManager.TransfersExecuteButton"] = "Execute Preparation",
    ["InventoryManager.TransfersExecuteTooltip"] = "Move the currently previewed whole stacks between bags and scanned storage.",
    ["InventoryManager.TransfersExecuteResultFormat"] = "Moved %d from storage to bags and %d from bags to storage.",
    ["InventoryManager.TransfersExecuteFailedCombat"] = "Transfers cannot run while you are in combat.",
    ["InventoryManager.TransfersExecuteFailedBankClosed"] = "Open a supported bank before executing preparation transfers.",
    ["InventoryManager.TransfersExecuteFailedScan"] = "A current successful bank scan is required before transfers can run.",
    ["InventoryManager.TransfersExecuteFailedInventory"] = "Current bag information is unavailable, so no transfer was attempted.",
    ["InventoryManager.TransfersExecuteFailedGeneric"] = "Preparation transfers could not be executed.",
    ["InventoryManager.TransfersFooterFormat"] = "%d planned actions | %d withdrawals | %d deposits",

    -- Explorer Page
    ["InventoryManager.ExplorerHeroTitle"] = "Explorer",
    ["InventoryManager.ExplorerHeroCaption"] = "Browse every recorded item across bags and storage snapshots.",
    ["InventoryManager.ExplorerUnavailableValue"] = "Unavailable",
    ["InventoryManager.ExplorerEmpty"] = "No items are available from bags or scanned storage sources.",
    ["InventoryManager.ExplorerDisabled"] = "Explorer is unavailable while the Storage module is disabled.",
    ["InventoryManager.ExplorerNeedsScan"] = "Open a supported bank and scan to browse your stored items.",
    ["InventoryManager.ExplorerItemCountFormat"] = "%d Items",
    ["InventoryManager.ExplorerQuantityFormat"] = "%d Total Quantity",
    ["InventoryManager.ExplorerSnapshotCurrent"] = "Snapshot Today",
    ["InventoryManager.ExplorerSnapshotStaleFormat"] = "Snapshot %s",
    ["InventoryManager.ExplorerSnapshotNeedsScan"] = "Needs Scan",
    ["InventoryManager.ExplorerSubclassFormat"] = "%s (%d)",
    ["InventoryManager.ExplorerFooterFormat"] = "%d categories | %d item types | %d total items",
    ["InventoryManager.ExplorerFooterStaleFormat"] = "%d categories | %d item types | %d total items | Snapshot %s",
    ["InventoryManager.LoadoutsHeroTitle"] = "Loadouts",
    ["InventoryManager.LoadoutsHeroCaption"] = "Create repeatable inventory workflows for your current activity.",
    ["InventoryManager.LoadoutsHeroValueReady"] = "Library",
    ["InventoryManager.LoadoutsHeroValueEmpty"] = "Ready",
    ["InventoryManager.LoadoutDefaultName"] = "New Loadout",
    ["InventoryManager.LoadoutsNew"] = "+ New Loadout",
    ["InventoryManager.LoadoutsEmpty"] = "Create a loadout to begin preparing for an activity.",
    ["InventoryManager.LoadoutsFooterFormat"] = "%d loadout(s)",
    ["InventoryManager.LoadoutsStatusEmpty"] = "Create a loadout to get started",
    ["InventoryManager.LoadoutsStatusFormat"] = "%d loadout(s) ready",
    ["InventoryManager.SectionLoadoutList"] = "Loadout Library",
    ["InventoryManager.SectionLoadoutDetails"] = "Selected Loadout",
    ["InventoryManager.LoadoutLibraryTitle"] = "Loadout Library",
    ["InventoryManager.LoadoutsCreatePrimary"] = "Create Loadout",
    ["InventoryManager.LoadoutsLibrarySummaryFormat"] = "%d loadout(s) ready",
    ["InventoryManager.LoadoutsLibraryHint"] = "No loadouts created.",
    ["InventoryManager.LoadoutEditorEmptyTitle"] = "No loadout selected",
    ["InventoryManager.LoadoutEditorSubtitle"] = "Choose a loadout to review and edit its items.",
    ["InventoryManager.LoadoutEditorEmptySubtitle"] = "Create reusable inventory kits for your favorite activities.",
    ["InventoryManager.LoadoutsEmptyTitle"] = "Create Your First Loadout",
    ["InventoryManager.LoadoutsEmptyDescription"] = "Create reusable inventory kits so you're always prepared for your favorite activities.",
    ["InventoryManager.LoadoutNameLabel"] = "Name",
    ["InventoryManager.LoadoutDescriptionLabel"] = "Description",
    ["InventoryManager.LoadoutAddItemLabel"] = "Add Item",
    ["InventoryManager.LoadoutAddItemButton"] = "Remove",
    ["InventoryManager.LoadoutWithdrawButton"] = "Withdraw Loadout",
    ["InventoryManager.LoadoutDepositButton"] = "Deposit Extras",
    ["InventoryManager.LoadoutItemsHeader"] = "Items",
    ["InventoryManager.LoadoutItemSummaryFormat"] = "Desired: %d • Bags: %d • Bank: %d",
    ["InventoryManager.LoadoutStatusReady"] = "Ready",
    ["InventoryManager.LoadoutStatusInBank"] = "In Bank",
    ["InventoryManager.LoadoutStatusMissing"] = "Missing",
    ["InventoryManager.LoadoutActionReady"] = "Ready",
    ["InventoryManager.LoadoutActionWithdrawFormat"] = "Withdraw %d",
    ["InventoryManager.LoadoutActionMissingFormat"] = "Missing %d",
    ["InventoryManager.LoadoutLocationBoth"] = "Bags & Bank",
    ["InventoryManager.LoadoutLocationBags"] = "In Bags",
    ["InventoryManager.LoadoutLocationBank"] = "In Bank",
    ["InventoryManager.LoadoutLocationMissing"] = "Missing",

    ["InventoryManager.PlannedSection"] = "Planned",
    ["InventoryManager.SettingsPlanned"] = "Inventory Manager settings are planned for a later phase. Existing addon settings remain unchanged.",

    ["InventoryManager.WorkspaceSection"] = "Inventory Workspace",
    ["InventoryManager.WorkspaceDescription"] = "Open the dedicated Inventory Manager for storage readiness and future inventory workflows.",
    ["InventoryManager.OpenButton"] = "Open Inventory Manager",

    -----------------------------------------------------------------------
    -- Weekly Page
    -----------------------------------------------------------------------

    ["Weekly.NoVaultData"] = "No Great Vault data available.",
    ["Weekly.RewardReady"] = "GREAT VAULT REWARD READY",
    ["Weekly.CategoryDungeons"] = "Dungeons",
    ["Weekly.CategoryDelves"] = "Delves",
    ["Weekly.CategoryRaid"] = "Raid",
    ["Weekly.ChestLabel"] = "Chest %d",
    ["Weekly.StateUnlocked"] = "UNLOCKED",
    ["Weekly.StateInProgress"] = "IN PROGRESS",
    ["Weekly.StateLocked"] = "LOCKED",
    ["Weekly.StateUpgradeAvailable"] = "UPGRADE AVAILABLE",
    ["Weekly.ProgressFormat"] = "%d / %d",
    ["Weekly.NeedMoreFormat"] = "Need %d More",
    ["Weekly.RemainingFormat"] = "Complete %d more %s",
    ["Weekly.DungeonLevelFormat"] = "Qualifying level: +%d",
    ["Weekly.DelveLevelFormat"] = "Qualifying tier: %d",
    ["Weekly.ActivityLevelFormat"] = "Qualifying level: %d",
    ["Weekly.UpgradeLevelFormat"] = "+%d",
    ["Weekly.UpgradeRewardFormat"] = "Next upgrade: %s rewards item level %s",
    ["Weekly.UpgradeOnlyFormat"] = "Next upgrade: %s",
    ["Weekly.UpgradeItemLevelOnlyFormat"] = "Next reward item level: %s",
    ["Weekly.TooltipProgress"] = "Weekly Progress",
    ["Weekly.TooltipItemLevel"] = "Current Item Level",
    ["Weekly.TooltipNextUpgrade"] = "Next Upgrade",
    ["Weekly.UnitDungeon"] = "dungeon",
    ["Weekly.UnitDungeons"] = "dungeons",
    ["Weekly.UnitDelve"] = "delve",
    ["Weekly.UnitDelves"] = "delves",
    ["Weekly.UnitRaidBoss"] = "raid boss",
    ["Weekly.UnitRaidBosses"] = "raid bosses",

    ["Weekly.NoRecommendations"] = "You're all caught up.",

    -----------------------------------------------------------------------
    -- Common
    -----------------------------------------------------------------------

    ["Common.Unknown"] = "Unknown",
    ["Common.Yes"] = "Yes",
    ["Common.No"] = "No",
    ["Common.EmDash"] = "—",
    ["Common.Timed"] = "Timed",
    ["Common.Failed"] = "Failed",

    -----------------------------------------------------------------------
    -- Presentation Layer (Core/Presentation/Presentation.lua)
    -----------------------------------------------------------------------

    ["Presentation.RelativeToday"] = "Today",
    ["Presentation.RelativeYesterday"] = "Yesterday",
    ["Presentation.RelativeDaysAgoFormat"] = "%d days ago",

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

    ["Recommendation.ContinueAchievementHunting.Title"] = "Continue Your Pursuit",
    ["Recommendation.ContinueAchievementHunting.Description"] = "You earned a signature accomplishment. Continue while you're motivated.",

    ["Recommendation.ReachNextMilestone.Title"] = "Reach Next Milestone",
    ["Recommendation.ReachNextMilestone.Description"] = "You gained significant accomplishment points. Complete one more to reach your next milestone.",
    ["Recommendation.ReachNextMilestone.Reason"] = "%d points to your next milestone at %d.",

    ["Recommendation.ExploreEndgameContent.Title"] = "Explore Endgame Content",
    ["Recommendation.ExploreEndgameContent.Description"] = "You've reached the maximum level. Explore dungeons, raids, and other endgame content.",

    ["Recommendation.RepairYourGear.Title"] = "Repair Your Gear",
    ["Recommendation.RepairYourGear.Description"] = "Your equipment needs repair. Take care of it while you're at a vendor.",
    ["Recommendation.RepairYourGear.DescriptionBroken"] = "Some of your gear is completely broken and providing no benefit. Repair before your next Mythic+ run or raid.",

    ["Recommendation.RetrieveKeystone.Title"] = "Retrieve Your Keystone",
    ["Recommendation.RetrieveKeystone.Description"] = "You don't have a keystone slotted. Pick one up before your next Mythic+ run.",

    ["Recommendation.PushFurther.Title"] = "Push Further",
    ["Recommendation.PushFurther.Description"] = "You set a new personal best. Consider pushing an even higher key.",
    ["Recommendation.PushFurther.Reason"] = "You set a new personal best at level %d.",
    ["Recommendation.PushFurther.ReasonWithDungeon"] = "You set a new personal best at level %d in %s.",

    ["Recommendation.KeepClimbing.Title"] = "Keep Climbing",
    ["Recommendation.KeepClimbing.Description"] = "Your Mythic+ rating is climbing. Keep running keys to push it further.",

    ["Recommendation.ConsiderLowerKeyLevel.Title"] = "Consider a Lower Key Level",
    ["Recommendation.ConsiderLowerKeyLevel.Description"] = "You've missed the timer on several recent runs. A lower key level may time more reliably.",
    ["Recommendation.ConsiderLowerKeyLevel.Reason"] = "You've timed %d of your last %d runs.",

    ["Recommendation.PracticeWeakestDungeon.Title"] = "Practice Your Weakest Dungeon",
    ["Recommendation.PracticeWeakestDungeon.Description"] = "One dungeon is holding back your timed rate this season. A few extra runs there tend to pay off the most.",
    ["Recommendation.PracticeWeakestDungeon.Reason"] = "%s has your lowest timed rate this season.",

    ["Recommendation.BringConsumables.Title"] = "Bring a Flask and Food",
    ["Recommendation.BringConsumables.Description"] = "You've started several recent runs without a flask or food buff active. Both are easy, low-cost performance gains.",

    -----------------------------------------------------------------------
    -- Recommendation Engine V2 -- Cross-Module Recommendations
    -----------------------------------------------------------------------

    ["Recommendation.CompleteYourKeystone.Title"] = "Complete Your Keystone",
    ["Recommendation.CompleteYourKeystone.Description"] = "You have an owned keystone that isn't being run yet.",
    ["Recommendation.CompleteYourKeystone.Reason"] = "Your %s +%d keystone is ready to run.",
    ["Recommendation.CompleteYourKeystone.ReasonNoName"] = "Your +%d keystone is ready to run.",
    ["Recommendation.CompleteYourKeystone.ExpectedBenefit"] = "+%s Rating (your season average for a timed run)",

    ["Recommendation.ClaimVaultReward.Title"] = "Claim Your Great Vault Reward",
    ["Recommendation.ClaimVaultReward.Description"] = "You have an unclaimed Great Vault reward waiting.",

    -----------------------------------------------------------------------
    -- Supporting Evidence Labels (Companion Intelligence Part 3)
    -----------------------------------------------------------------------

    ["Evidence.CurrentRating"] = "Current Rating",
    ["Evidence.HistoricalSuccessRate"] = "Historical Success Rate",
    ["Evidence.HistoricalCompletionTime"] = "Historical Completion Time",
    ["Evidence.CurrentItemLevel"] = "Current Item Level",
    ["Evidence.VaultProgress"] = "Vault Progress",

    -----------------------------------------------------------------------
    -- Storage Recommendations & Preparation Evidence
    -----------------------------------------------------------------------

    ["Recommendation.RestockYourBags.Title"] = "Restock Your Bags",
    ["Recommendation.RestockYourBags.Description"] = "You're missing items your active storage profile expects you to carry.",

    ["Recommendation.DepositCraftingMaterials.Title"] = "Deposit Crafting Materials",
    ["Recommendation.DepositCraftingMaterials.Description"] = "You're carrying more crafting materials than your active storage profile wants in your bags.",

    ["Evidence.Preparation"] = "Preparation",
    ["Evidence.PreparationReady"] = "Ready",
    ["Evidence.PreparationMissingFormat"] = "Missing %d",
    ["Evidence.PreparationWithdrawFormat"] = "Withdraw %d",

    -----------------------------------------------------------------------
    -- Recommendation Engine V3 -- Companion Intelligence
    -----------------------------------------------------------------------

    ["Recommendation.RestockAndPrepare.Title"] = "Restock & Prepare",
    ["Recommendation.RestockAndPrepare.DescriptionFormat"] = "%d things need attention before your next activity.",

    ["Evidence.VaultSlotOneRunAway"] = "Almost There",
    ["Evidence.VaultSlotOneRunAwayFormat"] = "One more run unlocks Vault Slot %d",
    ["Evidence.RepairStatus"] = "Repair Status",

    -----------------------------------------------------------------------
    -- Companion Intelligence vNext -- Personal Recommendations
    -----------------------------------------------------------------------

    ["Recommendation.PracticeUntimedDungeon.Title"] = "Practice This Dungeon",
    ["Recommendation.PracticeUntimedDungeon.Description"] = "You've attempted your current dungeon this season without timing it yet.",
    ["Recommendation.PracticeUntimedDungeon.Reason"] = "You've attempted %s %d time(s) this season without timing it.",

    ["Recommendation.RunWithFrequentCompanion.Title"] = "Run With Your Frequent Companion",
    ["Recommendation.RunWithFrequentCompanion.Description"] = "Your most frequent Mythic+ companion is in your current party.",

    ["Recommendation.ReconnectWithFavorite.Title"] = "Reconnect With a Favorite",
    ["Recommendation.ReconnectWithFavorite.Description"] = "A player you've marked as a Favorite hasn't grouped with you in a while.",

    ["Evidence.PlayerJournalRunsTogetherFormat"] = "%d runs together",

    -----------------------------------------------------------------------
    -- Companion Intelligence V4 -- Player Briefing & Notifications
    -----------------------------------------------------------------------

    ["Dashboard.TodaysBriefing"] = "Today's Briefing",
    ["Dashboard.TooltipTodaysBriefing"] = "A short, curated summary of what matters most right now",
    ["Dashboard.NoBriefing"] = "Nothing to report right now.",

    -----------------------------------------------------------------------
    -- Companion Intelligence vNext -- Companion Memory (BriefingService)
    -- and Today's Companion Notes (SessionNotesService)
    -----------------------------------------------------------------------

    ["Briefing.FrequentCompanionFormat"] = "You frequently run with %s (%d runs together).",
    ["Briefing.TypicalConsumablesFormat"] = "You typically use %s consumables per Mythic+ run.",

    ["Dashboard.TodaysCompanionNotes"] = "Today's Companion Notes",
    ["Dashboard.TooltipTodaysCompanionNotes"] = "Real, session-relative facts about tonight's play",
    ["Dashboard.NoCompanionNotes"] = "Nothing to note yet this session.",

    ["SessionNotes.WelcomeBack"] = "Welcome back.",
    ["SessionNotes.RunsThisSessionFormat"] = "This session you've completed %d Mythic+ dungeon(s).",
    ["SessionNotes.AchievementsThisSessionFormat"] = "You've earned %d achievement(s) this session.",
    ["SessionNotes.VaultSlotsGainedFormat"] = "Your Great Vault gained %d slot(s) this session.",

    -----------------------------------------------------------------------
    -- Companion Intelligence vNext -- Dismiss (Recommendations page rows,
    -- Home's Highest Priority card)
    -----------------------------------------------------------------------

    ["Dashboard.DismissButtonGlyph"] = "\195\151",
    ["Dashboard.DismissButtonTooltip"] = "Dismiss for now -- this may reappear if the situation is still true next refresh.",

    ["Dashboard.RecentMilestones"] = "Recent Milestones",
    ["Dashboard.TooltipRecentMilestones"] = "Personal milestones you've recently achieved",
    ["Dashboard.NoMilestones"] = "No milestones achieved yet.",

    ["Dashboard.RecentNotifications"] = "Recent Notifications",
    ["Dashboard.TooltipRecentNotifications"] = "Recently shown notifications",
    ["Dashboard.NoNotifications"] = "No recent notifications.",

    ["Notification.RecommendationChanged"] = "Recommendation Changed",

    -----------------------------------------------------------------------
    -- Personal Milestones (account history, independent of Blizzard's
    -- own achievement system)
    -----------------------------------------------------------------------

    ["Milestone.FirstMythicPlus.Title"] = "First Mythic+",
    ["Milestone.FirstMythicPlus.Description"] = "You completed your first Mythic+ dungeon.",

    ["Milestone.FirstKeyLevel10.Title"] = "First +10",
    ["Milestone.FirstKeyLevel10.Description"] = "You completed a Mythic+10 dungeon for the first time.",

    ["Milestone.FirstKeyLevel15.Title"] = "First +15",
    ["Milestone.FirstKeyLevel15.Description"] = "You completed a Mythic+15 dungeon for the first time.",

    ["Milestone.FirstKeyLevel20.Title"] = "First +20",
    ["Milestone.FirstKeyLevel20.Description"] = "You completed a Mythic+20 dungeon for the first time.",

    ["Milestone.TimedRuns100.Title"] = "100 Timed Runs",
    ["Milestone.TimedRuns100.Description"] = "You've timed 100 Mythic+ runs.",

    ["Milestone.Rating1000.Title"] = "1000 Rating",
    ["Milestone.Rating1000.Description"] = "Your Mythic+ rating reached 1000.",

    ["Milestone.Rating2000.Title"] = "2000 Rating",
    ["Milestone.Rating2000.Description"] = "Your Mythic+ rating reached 2000.",

    ["Milestone.NoDeathRun.Title"] = "Flawless Run",
    ["Milestone.NoDeathRun.Description"] = "You completed a Mythic+ dungeon without a single death.",

    ["Milestone.WinStreak10.Title"] = "10-Run Win Streak",
    ["Milestone.WinStreak10.Description"] = "You timed 10 Mythic+ runs in a row.",

    ["Milestone.BigRatingGain20.Title"] = "Big Rating Gain",
    ["Milestone.BigRatingGain20.Description"] = "You gained at least 20 rating from a single Mythic+ run.",

    ["Milestone.Consumables100.Title"] = "100 Consumables Used",
    ["Milestone.Consumables100.Description"] = "You've used 100 potions, flasks, food, or item enhancements across your Mythic+ runs.",

    ["Milestone.Interrupts100.Title"] = "100 Successful Interrupts",
    ["Milestone.Interrupts100.Description"] = "You've landed 100 successful interrupts across your Mythic+ runs.",

    -----------------------------------------------------------------------
    -- Progress Dashboard (flagship analytics)
    -----------------------------------------------------------------------

    ["Dashboard.Progress"] = "Progress",
    ["Dashboard.TooltipProgress"] = "See how your Mythic+ performance is improving over time",
    ["Dashboard.ProgressRatingFormat"] = "%s Rating",
    ["Dashboard.ProgressSeasonSummaryFormat"] = "Highest Key: +%d   Timed: %.0f%%",

    -----------------------------------------------------------------------
    -- Statistics Page (Companion Intelligence vNext) -- how effective the
    -- Companion's own recommendations have been
    -----------------------------------------------------------------------

    ["Dashboard.Statistics"] = "Statistics",
    ["Dashboard.TooltipStatistics"] = "How effective the Companion's recommendations have actually been",
    ["Dashboard.StatisticsGeneratedFormat"] = "%d Generated",
    ["Dashboard.StatisticsNoDataYet"] = "No recommendation history yet.",

    ["Statistics.HeroHeadline"] = "Recommendations Generated",
    ["Statistics.HeroCaptionFormat"] = "%s%% completion rate",

    ["Statistics.SectionOverview"] = "Overview",
    ["Statistics.NoHistoryYet"] = "No recommendation history yet.",
    ["Statistics.StatTotalGenerated"] = "Generated",
    ["Statistics.StatTotalCompleted"] = "Likely Completed",
    ["Statistics.StatTotalDismissed"] = "Dismissed",
    ["Statistics.StatTotalNotAcknowledged"] = "Not Acknowledged",
    ["Statistics.StatAverageCompletionTime"] = "Average Time to Resolve",
    ["Statistics.StatMostUsefulCategory"] = "Most Useful Category",

    ["Statistics.SectionCategoryBreakdown"] = "By Category",
    ["Statistics.NoCategoryData"] = "No category data yet.",
    ["Statistics.CategoryLineFormat"] = "%s -- %d completed / %d generated",

    ["Progress.HeroHeadline"] = "Mythic+ Rating",
    ["Progress.TrendDirectionImproving"] = "Improving",
    ["Progress.TrendDirectionDeclining"] = "Declining",
    ["Progress.TrendDirectionStable"] = "Stable",

    ["Progress.SectionOverview"] = "Overview",
    ["Progress.StatCurrentSeason"] = "Current Season",
    ["Progress.StatHighestKey"] = "Highest Key",
    ["Progress.StatTimedPercent"] = "Timed %",
    ["Progress.StatRunsCompleted"] = "Runs Completed",

    ["Progress.PreparationReady"] = "Preparation: Ready",
    ["Progress.PreparationPercentFormat"] = "Preparation: %.0f%% Ready",

    ["Progress.SectionLast7Days"] = "Last 7 Days",
    ["Progress.SectionLast30Days"] = "Last 30 Days",
    ["Progress.NoRecentData"] = "No Mythic+ runs recorded in this period.",

    ["Progress.StatRatingGain"] = "Rating Gain",
    ["Progress.StatAverageKey"] = "Average Key",
    ["Progress.StatDeaths"] = "Deaths",
    ["Progress.StatInterrupts"] = "Interrupts",
    ["Progress.StatConsumables"] = "Consumables",

    ["Progress.SectionLifetime"] = "Lifetime",
    ["Progress.NoLifetimeData"] = "No Mythic+ runs recorded yet.",
    ["Progress.StatLargestRatingGain"] = "Largest Rating Gain",
    ["Progress.StatBestDungeon"] = "Best Dungeon",
    ["Progress.StatStrongestDungeon"] = "Strongest Dungeon",
    ["Progress.StatTotalRuns"] = "Total Runs",
    ["Progress.StatTotalTimedRuns"] = "Total Timed Runs",
    ["Progress.StatTotalDeaths"] = "Total Deaths",
    ["Progress.StatTotalConsumables"] = "Total Consumables",
    ["Progress.StatTotalInterrupts"] = "Total Interrupts",
    ["Progress.DungeonRateFormat"] = "%s (%.0f%%)",

    ["Progress.SectionPersonalRecords"] = "Personal Records",
    ["Progress.NoPersonalRecords"] = "No personal records yet.",
    ["Progress.StatFastestCompletion"] = "Fastest Completion",
    ["Progress.FastestCompletionFormat"] = "%s +%d (%s)",
    ["Progress.StatLongestWinStreak"] = "Longest Win Streak",
    ["Progress.StatMostSuccessfulDungeon"] = "Most Successful Dungeon",
    ["Progress.StatFewestDeaths"] = "Fewest Deaths",
    ["Progress.StatBestTimedPercent"] = "Best Timed %",

    ["Progress.SectionRecentMilestones"] = "Recent Milestones",
    ["Progress.NoRecentMilestones"] = "No milestones achieved yet.",
    ["Progress.MilestoneLineFormat"] = "%s \226\128\148 %s: %s",

    ["Progress.SectionCurrentTrends"] = "Current Trends",
    ["Progress.NoTrendsAvailable"] = "Not enough recent history to show trends yet.",
    ["Progress.TrendRuns"] = "Runs",
    ["Progress.TrendRatingGain"] = "Rating Gain",
    ["Progress.TrendAverageKey"] = "Average Key",
    ["Progress.TrendTimedPercent"] = "Timed %",
    ["Progress.TrendDeaths"] = "Deaths",
    ["Progress.TrendConsumables"] = "Consumables",
    ["Progress.TrendInterrupts"] = "Interrupts",

    -----------------------------------------------------------------------
    -- Recommendation Inspector ("Why?")
    -----------------------------------------------------------------------

    ["Dashboard.ClickForWhy"] = "Why?",

    ["Inspector.Title"] = "Recommendation Details",
    ["Inspector.WhyButton"] = "Why?",
    ["Inspector.Priority"] = "Priority",
    ["Inspector.OpportunityScore"] = "Opportunity Score",
    ["Inspector.ContributingModules"] = "Contributing Modules",
    ["Inspector.Timestamp"] = "Generated",

    ["Inspector.ConfidenceExplanationHigh"] = "Based on multiple modules with complete data.",
    ["Inspector.ConfidenceExplanationMedium"] = "Based on some real supporting data, but not corroborated by multiple modules.",
    ["Inspector.ConfidenceExplanationLow"] = "Limited evidence is available for this recommendation.",

    ["Inspector.NoSupportingEvidence"] = "No supporting evidence was recorded for this recommendation.",
    ["Inspector.NoContributingModules"] = "No specific module data contributed to this recommendation.",
    ["Inspector.ModuleLinkTooltipFormat"] = "View the %s page",

    ["Inspector.ScoreBreakdown"] = "Score Breakdown (Developer Mode)",
    ["Inspector.NoScoreBreakdown"] = "No score factors recorded.",

    -----------------------------------------------------------------------
    -- Recommendation History (Companion Intelligence vNext) -- see
    -- RecommendationHistoryService.lua's own header for what "Likely
    -- Completed"/"Not Acknowledged" honestly do and don't mean.
    -----------------------------------------------------------------------

    ["Inspector.LastGenerated"] = "Last Generated",
    ["Inspector.TimesGenerated"] = "Times Generated",
    ["Inspector.CompletionHistory"] = "Completion History",
    ["Inspector.CompletionHistoryFormat"] = "Likely Completed: %d   Dismissed: %d   Not Acknowledged: %d",
    ["Inspector.CompletionRate"] = "Completion Rate",
    ["Inspector.ScoreHistory"] = "Score History",
    ["Inspector.NoScoreHistory"] = "No score history recorded yet.",
    ["Inspector.ScoreHistoryScoreLabel"] = "Score:",
    ["Inspector.FutureSuggestedActions"] = "Suggested Actions",

    ["ScoreFactor.BasePriority"] = "Base Priority",
    ["ScoreFactor.HistoricalSuccessHigh"] = "Historical Success Rate >= 70%",
    ["ScoreFactor.HistoricalSuccessLow"] = "Historical Success Rate < 40%",
    ["ScoreFactor.VaultSlotsRemaining"] = "Vault Slots Remaining",
    ["ScoreFactor.BelowGearAverage"] = "Below Personal Gear Average",
    ["ScoreFactor.VaultSlotOneRunAway"] = "Vault Slot One Run Away",
    ["ScoreFactor.PreparationReady"] = "Preparation Ready",
    ["ScoreFactor.PreparationLacking"] = "Preparation Lacking",
    ["ScoreFactor.AverageRatingGain"] = "Average Rating Gain",

    -----------------------------------------------------------------------
    -- Developer Mode & Live Verification Suite
    -----------------------------------------------------------------------

    ["Developer.Title"] = "Developer Panel",
    ["Developer.Yes"] = "Yes",
    ["Developer.No"] = "No",
    ["Developer.Clear"] = "Clear",
    ["Developer.Reset"] = "Reset",
    ["Developer.Refresh"] = "Refresh",
    ["Developer.NoError"] = "None",
    ["Developer.OpenTooltip"] = "Open Developer Panel",
    ["Developer.EnableTooltip"] = "Enable Developer Mode and open Developer Panel",

    ["Developer.TabOverview"] = "Overview",
    ["Developer.TabModules"] = "Modules",
    ["Developer.TabEvents"] = "Events",
    ["Developer.TabErrors"] = "Errors",
    ["Developer.TabSecretValues"] = "Secret Values",
    ["Developer.TabLiveAPI"] = "Live API",
    ["Developer.TabHistory"] = "History",
    ["Developer.TabChecklist"] = "Checklist",
    ["Developer.TabMaintenance"] = "Maintenance",

    ["Developer.CopyJSON"] = "Copy JSON",
    ["Developer.CopyText"] = "Copy Text",
    ["Developer.CopySummary"] = "Copy Summary",
    ["Developer.CopyHint"] = "Click a Copy button, then press Ctrl+C.",

    ["Developer.ClearNotifications"] = "Clear Notifications",
    ["Developer.ForceRefresh"] = "Force Refresh",
    ["Developer.ActionsDeveloper"] = "Developer",
    ["Developer.ActionsTracing"] = "Tracing",
    ["Developer.ActionsDiagnostics"] = "Diagnostics",
    ["Developer.ActionsNavigation"] = "Navigation",
    ["Developer.ActionDeveloperMode"] = "Developer Mode",
    ["Developer.ActionDebugLogging"] = "Debug Logging",
    ["Developer.ActionTraceAll"] = "All Traces",
    ["Developer.ActionTraceMythicPlus"] = "Mythic+",
    ["Developer.ActionOpenLog"] = "Open Log",
    ["Developer.ActionCopyLog"] = "Copy Log",
    ["Developer.ActionClearLog"] = "Clear Log",
    ["Developer.ActionDashboard"] = "Dashboard",
    ["Developer.ActionSettings"] = "Settings",
    ["Developer.TracingOn"] = "Tracing: On",
    ["Developer.TracingOff"] = "Tracing: Off",
    ["Developer.ClearHistory"] = "Clear History",

    ["Developer.HeroHeadline"] = "Azeroth Companion Engineering",
    ["Developer.HeroValue"] = "Developer Mode",
    ["Developer.HeroCaption"] = "Live diagnostics, verification, and internal maintenance tools.",
    ["Developer.HeroModules"] = "Modules",
    ["Developer.HeroEvents"] = "Events",
    ["Developer.HeroErrors"] = "Captured Errors",
    ["Developer.HeroMode"] = "Developer Mode",

    ["Developer.MaintenanceActivityHistory"] = "Activity History",
    ["Developer.MaintenanceAnalytics"] = "Analytics",
    ["Developer.MaintenanceTelemetry"] = "Telemetry",
    ["Developer.MaintenanceCache"] = "Cache",
    ["Developer.MaintenanceDeveloperData"] = "Developer Data",
    ["Developer.MaintenanceDangerZone"] = "Danger Zone",
    ["Developer.MaintenanceHistoryCountFormat"] = "Total Stored Records: %d",
    ["Developer.MaintenanceHistoryDescription"] = "Clears every recorded activity type for the current character.",
    ["Developer.ClearActivityHistory"] = "Clear Activity History",
    ["Developer.MaintenanceAnalyticsUnavailable"] = "No analytics data store",
    ["Developer.MaintenanceAnalyticsPlaceholder"] = "Reserved for a future analytics system. No persistent analytics exist today.",
    ["Developer.MaintenanceTelemetryUnavailable"] = "No telemetry data store",
    ["Developer.MaintenanceTelemetryPlaceholder"] = "Reserved for future Equipment Wear Telemetry.",
    ["Developer.MaintenanceCacheUnavailable"] = "No developer-managed cache",
    ["Developer.MaintenanceCachePlaceholder"] = "Gameplay caches remain owned and refreshed by their gameplay modules.",
    ["Developer.MaintenanceErrorCountFormat"] = "Captured Errors: %d",
    ["Developer.MaintenanceErrorsDescription"] = "Removes persisted Developer Runtime error records.",
    ["Developer.MaintenanceDiagnosticCountFormat"] = "Temporary Diagnostics: %d",
    ["Developer.MaintenanceDiagnosticsDescription"] = "Clears the Blizzard event log and secret-value diagnostic events.",
    ["Developer.ClearRuntimeDiagnostics"] = "Clear Diagnostics",
    ["Developer.MaintenanceVerificationTitle"] = "Verification & Checklist Results",
    ["Developer.MaintenanceVerificationDescription"] = "Clears human-recorded API verification and guided-checklist results.",
    ["Developer.ClearVerification"] = "Clear Verification",
    ["Developer.MaintenanceExportsTitle"] = "Exported Data",
    ["Developer.MaintenanceExportsDescription"] = "Exports are generated on demand and are not stored by Azeroth Companion.",
    ["Developer.ResetEverything"] = "Reset Everything",
    ["Developer.MaintenanceResetDescription"] = "Clears Activity History, captured errors, verification records, and temporary diagnostics.",

    ["Developer.ConfirmClearActivityHistory"] = "Clear Activity History?\n\nThis will permanently remove:\n\n• Mythic+ history\n• Delve history\n• Dungeon history\n• Raid history\n• Any recorded activities\n\nThis cannot be undone.",
    ["Developer.ConfirmClearErrors"] = "Clear all captured runtime errors?\n\nPersisted error records and occurrence history will be permanently removed. This cannot be undone.",
    ["Developer.ConfirmClearEvents"] = "Clear the captured Blizzard event log?\n\nThis session's recorded events will be permanently removed.",
    ["Developer.ConfirmClearSecretValues"] = "Clear all secret-value diagnostic events?\n\nThis session's recorded secure-callback diagnostics will be permanently removed.",
    ["Developer.ConfirmClearNotifications"] = "Clear active, queued, and recent notifications?\n\nThis session's notification history will be permanently removed.",
    ["Developer.ConfirmClearRuntimeDiagnostics"] = "Clear temporary runtime diagnostics?\n\nThis will permanently remove the current Blizzard event log and secret-value diagnostic events.",
    ["Developer.ConfirmClearVerification"] = "Clear verification and checklist results?\n\nAll human-recorded live API results and completed checklist scenarios will be permanently removed. This cannot be undone.",
    ["Developer.ConfirmResetEverything"] = "Reset all developer-managed data?\n\nThis will permanently remove:\n\n• All recorded Activity History\n• Captured runtime errors\n• Verification and checklist results\n• Temporary runtime diagnostics\n\nSettings, gameplay modules, and Player Journal data will not be changed. This cannot be undone.",

    ["Developer.FieldCharacter"] = "Current Character",
    ["Developer.FieldZone"] = "Current Zone",
    ["Developer.FieldSpec"] = "Current Specialization",
    ["Developer.FieldItemLevel"] = "Current Item Level",
    ["Developer.FieldKey"] = "Current Mythic+ Key",
    ["Developer.FieldRating"] = "Current Rating",
    ["Developer.FieldVault"] = "Vault State",
    ["Developer.FieldStorageReadiness"] = "Storage Readiness",
    ["Developer.FieldRecommendationCount"] = "Recommendation Count",
    ["Developer.FieldNotificationQueue"] = "Notification Queue",
    ["Developer.FieldBriefing"] = "Briefing",
    ["Developer.FieldCurrentRecommendation"] = "Current Recommendation",
    ["Developer.FieldOpportunityScore"] = "Current Opportunity Score",
    ["Developer.FieldConfidence"] = "Current Confidence",
    ["Developer.FieldLoadedModules"] = "Loaded Modules",
    ["Developer.FieldLastRefresh"] = "Last Refresh Time",
    ["Developer.FieldLastEvent"] = "Last Blizzard Event",
    ["Developer.FieldFrameRate"] = "Frame Rate",

    ["Developer.LabelInitialized"] = "Initialized",
    ["Developer.LabelEnabled"] = "Enabled",
    ["Developer.LabelLastRefresh"] = "Last Refresh",
    ["Developer.LabelDuration"] = "Duration",
    ["Developer.LabelInsightCount"] = "Insights",
    ["Developer.LabelRecommendationCount"] = "Recommendations",
    ["Developer.LabelHistoryCount"] = "History",
    ["Developer.LabelLastError"] = "Last Error",

    ["Developer.NoEvents"] = "No events recorded yet.",

    ["Developer.ClearErrors"] = "Clear Errors",
    ["Developer.GenerateTestError"] = "Generate Test Error",
    ["Developer.ExportAllErrors"] = "Export All Errors",
    ["Developer.CaptureOn"] = "ON",
    ["Developer.CaptureOff"] = "OFF",
    ["Developer.InstalledYes"] = "YES",
    ["Developer.InstalledNo"] = "NO",
    ["Developer.ErrorsStatusFormat"] = "Capture: %s   Installed: %s   |   Errors: %d",
    ["Developer.ErrorMetaFormat"] = "Occurrences: %d   Last Seen: %s",
    ["Developer.NoErrorsCaptured"] = "No runtime errors have been captured.\n\nDeveloper Mode is monitoring the addon.",
    ["Developer.ErrorFieldMessage"] = "Full Message",
    ["Developer.ErrorFieldSignature"] = "Signature",
    ["Developer.ErrorFieldOrigin"] = "Origin",
    ["Developer.ErrorFieldOriginThirdPartyFormat"] = "Third Party (Addon: %s)",
    ["Developer.ErrorFieldFirstSeen"] = "First Seen",
    ["Developer.ErrorFieldLastSeen"] = "Last Seen",
    ["Developer.ErrorFieldOccurrences"] = "Occurrence Count",
    ["Developer.ErrorFieldStackTrace"] = "Stack Trace",
    ["Developer.ErrorNoStackTrace"] = "(not captured -- Capture Stack Traces was off, or unavailable for this error)",

    ["Developer.ClearSecretValues"] = "Clear Events",
    ["Developer.SecretValuesStatusFormat"] = "Recording: %s   |   Events: %d",
    ["Developer.SecretValueContextFormat"] = "%s   [%s]",
    ["Developer.SecretValueMetaFormat"] = "Occurrences: %d   Last Seen: %s",
    ["Developer.NoSecretValueEvents"] = "No secret-value events have been recorded.\n\nDeveloper Mode is monitoring this addon's Blizzard secure-callback boundaries (tooltip/menu hooks).",
    ["Developer.SecretValueFieldMessage"] = "Full Message",
    ["Developer.SecretValueFieldSource"] = "Source",
    ["Developer.SecretValueFieldStatus"] = "Status",
    ["Developer.SecretValueFieldFirstSeen"] = "First Seen",
    ["Developer.SecretValueFieldLastSeen"] = "Last Seen",
    ["Developer.SecretValueFieldOccurrences"] = "Occurrence Count",
    ["Developer.SecretValueFieldStackTrace"] = "Stack Trace",
    ["Developer.SecretValueNoStackTrace"] = "(not captured)",

    ["Developer.ProbeWeekly"] = "Inspect Weekly/Vault",
    ["Developer.ProbeStorage"] = "Inspect Storage/Bank",
    ["Developer.ProbeMythicPlus"] = "Inspect Mythic+",
    ["Developer.ProbeAffixes"] = "Inspect Affixes",
    ["Developer.ProbeFailed"] = "Probe failed. See chat for the error.",
    ["Developer.NoProbeResults"] = "Click a button above to inspect that system's live Blizzard data.",
    ["Developer.LabelRaw"] = "Raw",
    ["Developer.LabelFinal"] = "Final",

    ["Developer.FilterModule"] = "Module",
    ["Developer.FilterType"] = "Type",
    ["Developer.FilterDateRange"] = "Date",
    ["Developer.DateRangeAll"] = "All Time",
    ["Developer.DateRangeToday"] = "Today",
    ["Developer.DateRangeLast7"] = "Last 7 Days",
    ["Developer.DateRangeLast30"] = "Last 30 Days",
    ["Developer.NoHistoryRecords"] = "No history records match these filters.",

    -----------------------------------------------------------------------
    -- Live Verification & Framework Hardening sprint
    -----------------------------------------------------------------------

    ["Developer.StatusSource"] = "Verified by Blizzard Source",
    ["Developer.StatusWiki"] = "Verified by Warcraft Wiki",
    ["Developer.StatusLive"] = "Verified in Live Game",
    ["Developer.StatusNeedsLive"] = "Needs Live Verification",
    ["Developer.StatusIncorrect"] = "Incorrect Implementation",

    ["Developer.LabelExpected"] = "Expected",
    ["Developer.LabelConfidence"] = "Confidence",
    ["Developer.LabelSource"] = "Source",
    ["Developer.LabelLastVerified"] = "Last Verified",
    ["Developer.LabelNeverVerified"] = "Never (source/docs only)",
    ["Developer.LabelPass"] = "Pass",
    ["Developer.LabelFail"] = "Fail",
    ["Developer.LabelNotComparable"] = "Not directly comparable",

    ["Developer.MarkVerified"] = "Mark Verified",
    ["Developer.MarkFailed"] = "Mark Failed",
    ["Developer.RunProbeFirst"] = "Run the Inspect button above at least once this session before marking a result.",

    ["Developer.SummaryHeader"] = "Verification Summary",
    ["Developer.FullRegistryHeader"] = "Full Verification Registry",
    ["Developer.SummaryFormat"] = "%s Source: %d   %s Wiki: %d   %s Live: %d   %s Needs Live: %d   %s Incorrect: %d",

    ["Developer.ChecklistIntro"] = "Guided scenarios for the items above still marked Needs Live Verification. Perform the scenario in-game, then mark it done here -- this only records that you did it and when; it does not change any API's status by itself.",
    ["Developer.ChecklistMarkDone"] = "Mark Done",
    ["Developer.ChecklistMarkUndone"] = "Mark Not Done",
    ["Developer.ChecklistNoAPI"] = "No flagged API in this addon depends on this scenario -- nothing to check.",
    ["Developer.ChecklistRelatedAPIs"] = "Related APIs",
    ["Developer.ChecklistLastDone"] = "Last completed",
    ["Developer.ChecklistNeverDone"] = "Not yet done",

    ["Developer.ChecklistLogin"] = "Login",
    ["Developer.ChecklistReloadUI"] = "Reload UI",
    ["Developer.ChecklistCharacterSelect"] = "Character Select",
    ["Developer.ChecklistSpecSwap"] = "Spec Swap",
    ["Developer.ChecklistHearthstone"] = "Hearthstone",
    ["Developer.ChecklistZoneChange"] = "Zone Change",
    ["Developer.ChecklistFlightPath"] = "Flight Path",
    ["Developer.ChecklistDeath"] = "Death",
    ["Developer.ChecklistResurrection"] = "Resurrection",
    ["Developer.ChecklistDungeonEnter"] = "Dungeon Enter",
    ["Developer.ChecklistDungeonLeave"] = "Dungeon Leave",
    ["Developer.ChecklistKeystoneInsert"] = "Keystone Insert",
    ["Developer.ChecklistKeystoneComplete"] = "Keystone Complete",
    ["Developer.ChecklistKeystoneFail"] = "Keystone Fail",
    ["Developer.ChecklistGreatVault"] = "Great Vault",
    ["Developer.ChecklistBank"] = "Bank",
    ["Developer.ChecklistReagentBank"] = "Reagent Bank",
    ["Developer.ChecklistWarbandBank"] = "Warband Bank",
    ["Developer.ChecklistMailbox"] = "Mailbox",
    ["Developer.ChecklistVendor"] = "Vendor",
    ["Developer.ChecklistAuctionHouse"] = "Auction House",
    ["Developer.ChecklistAchievementEarned"] = "Achievement Earned",
    ["Developer.ChecklistInventoryFull"] = "Inventory Full",
    ["Developer.ChecklistEquipmentChange"] = "Equipment Change",
    ["Developer.ChecklistCurrencyGain"] = "Currency Gain",
    ["Developer.ChecklistWeeklyReset"] = "Weekly Reset",

    -----------------------------------------------------------------------
    -- Player Journal & Community Observations
    -----------------------------------------------------------------------

    ["Developer.PlayerJournalStoredPlayers"] = "Player Journal: Stored Players",
    ["Developer.PlayerJournalIncidentalPlayers"] = "Player Journal: Legacy Entries",
    ["Developer.PlayerJournalFavoritePlayers"] = "Player Journal: Favorite Players",
    ["Developer.PlayerJournalTotalNotes"] = "Player Journal: Total Notes",
    ["Developer.PlayerJournalCommunityObservations"] = "Player Journal: Community Observations",
    ["Developer.PlayerJournalOldestEntry"] = "Player Journal: Oldest Entry",
    ["Developer.PlayerJournalNewestEntry"] = "Player Journal: Newest Entry",
    ["Developer.PlayerJournalDatabaseSize"] = "Player Journal: Database Size",
    ["Developer.PlayerJournalPrunedEntries"] = "Player Journal: Pruned Entries",

    ["Developer.ChecklistPlayerJournalRun"] = "Player Journal: Run",
    ["Developer.ChecklistPlayerJournalLeave"] = "Player Journal: Party Member Leaves",
    ["Developer.ChecklistPlayerJournalContextMenu"] = "Player Journal: Context Menu",
    ["Developer.ChecklistPlayerJournalTooltip"] = "Player Journal: Tooltip",

    ["PlayerJournal.WindowTitle"] = "Player Journal",
    ["PlayerJournal.ContextMenuTitle"] = "Azeroth Companion",

    ["PlayerJournal.TabOverview"] = "Overview",
    ["PlayerJournal.TabHistory"] = "History",
    ["PlayerJournal.TabStatistics"] = "Statistics",
    ["PlayerJournal.TabPersonalNotes"] = "Notes",
    ["PlayerJournal.TabCommunityObservations"] = "Community",
    ["PlayerJournal.TabTimeline"] = "Timeline",
    ["PlayerJournal.TabSearch"] = "Search",

    ["PlayerJournal.NoPlayerSelected"] = "No player selected. Use Search to find someone in your journal.",
    ["PlayerJournal.NoPlayerSelectedTitle"] = "No Player Selected",
    ["PlayerJournal.NoPlayerSelectedDescription"] = "Search your journal to find someone you've played with, or right-click a player in-game and choose Open Player Journal.",
    ["PlayerJournal.GoToSearch"] = "Go to Search",
    ["PlayerJournal.UntrackedTitle"] = "Not Yet in Your Journal",
    ["PlayerJournal.UntrackedDescription"] = "This player has not been added. Add them only if this is someone you want to remember.",
    ["PlayerJournal.UntrackedNoteDescription"] = "Saving this note will add the player to your journal.",
    ["PlayerJournal.AddToJournal"] = "Add to Journal",
    ["PlayerJournal.RealmSuffixFormat"] = "-%s",
    ["PlayerJournal.FavoriteOn"] = "%s Favorite",
    ["PlayerJournal.FavoriteOff"] = "Add Favorite",

    ["PlayerJournal.SectionOverview"] = "Overview",
    ["PlayerJournal.SectionStatistics"] = "Statistics",
    ["PlayerJournal.SectionTags"] = "Tags",
    ["PlayerJournal.SectionDungeonBreakdown"] = "Dungeon Breakdown",
    ["PlayerJournal.SectionRoleBreakdown"] = "Role Breakdown",

    ["PlayerJournal.FieldClass"] = "Class: %s",
    ["PlayerJournal.FieldGuild"] = "Guild: %s",
    ["PlayerJournal.FieldFirstSeen"] = "First Seen: %s",
    ["PlayerJournal.FieldLastSeen"] = "Last Seen: %s",

    ["PlayerJournal.StatRunsTogether"] = "Runs Together: %d",
    ["PlayerJournal.StatRunsCompleted"] = "Runs Completed: %d",
    ["PlayerJournal.StatRunsTimed"] = "Runs Timed: %d",
    ["PlayerJournal.StatRunsLeftEarly"] = "Runs Left Early: %d",
    ["PlayerJournal.StatAverageDeaths"] = "Average Deaths: %s",
    ["PlayerJournal.StatAverageRatingGain"] = "Average Rating Gain: %s",
    ["PlayerJournal.StatTotalInterrupts"] = "Total Interrupts: %d",
    ["PlayerJournal.StatFavoriteDungeon"] = "Most Played Dungeon Together: %s",
    ["PlayerJournal.StatFavoriteRole"] = "Favorite Role: %s",
    ["PlayerJournal.StatWinRate"] = "Win Rate: %s",

    ["PlayerJournal.RoleTANK"] = "Tank",
    ["PlayerJournal.RoleHEALER"] = "Healer",
    ["PlayerJournal.RoleDAMAGER"] = "Damage",

    ["PlayerJournal.NoDungeonBreakdown"] = "No dungeon runs recorded together yet.",
    ["PlayerJournal.DungeonBreakdownLineFormat"] = "%s: %d run(s)",
    ["PlayerJournal.RoleBreakdownLineFormat"] = "%s: %d run(s)",

    ["PlayerJournal.NoRunHistory"] = "No run history with this player yet.",
    ["PlayerJournal.RunLeftEarly"] = "Left Early",
    ["PlayerJournal.HistoryLineFormat"] = "%s -- %s +%d -- %s (%s rating, %s)",

    ["PlayerJournal.AddNote"] = "Add Note",
    ["PlayerJournal.SaveEdit"] = "Save",
    ["PlayerJournal.CancelEdit"] = "Cancel",
    ["PlayerJournal.EditNote"] = "Edit",
    ["PlayerJournal.DeleteNote"] = "Delete",
    ["PlayerJournal.NoNotes"] = "No personal notes yet.",
    ["PlayerJournal.EditedSuffixFormat"] = "(edited %s)",

    ["PlayerJournal.NoTimelineEvents"] = "No timeline events yet.",
    ["PlayerJournal.TimelineMetFormat"] = "%s -- You met this player.",
    ["PlayerJournal.TimelineRunFormat"] = "%s -- +%d %s (%s)",
    ["PlayerJournal.TimelineNoteFormat"] = "%s -- You added a note.",
    ["PlayerJournal.TimelineTagAddedFormat"] = "%s -- Tagged: %s",
    ["PlayerJournal.TimelineTagRemovedFormat"] = "%s -- Untagged: %s",
    ["PlayerJournal.TimelineUnknownFormat"] = "%s",

    ["PlayerJournal.FilterAllRelationships"] = "All Relationships",
    ["PlayerJournal.NoSearchResults"] = "No players match your search.",
    ["PlayerJournal.RelationshipFavorite"] = "Favorite",
    ["PlayerJournal.RelationshipPersonalNote"] = "Personal Note",
    ["PlayerJournal.RelationshipCommunityObservation"] = "Community Observation",
    ["PlayerJournal.RelationshipPersonalTag"] = "Personal Tags",
    ["PlayerJournal.RelationshipFriend"] = "Friend",
    ["PlayerJournal.RelationshipGuild"] = "Guild",
    ["PlayerJournal.RelationshipMythicPlus"] = "Mythic+",
    ["PlayerJournal.RelationshipRaid"] = "Raid",
    ["PlayerJournal.RelationshipDelve"] = "Delve",
    ["PlayerJournal.RelationshipDungeon"] = "Dungeon",
    ["PlayerJournal.RelationshipRandomQueue"] = "Random Queue",
    ["PlayerJournal.RelationshipParty"] = "Party",
    ["PlayerJournal.RelationshipWhisper"] = "Whispered",
    ["PlayerJournal.RelationshipExplicit"] = "Added to Journal",
    ["PlayerJournal.RelationshipLegacy"] = "Legacy Entry",
    ["PlayerJournal.RelationshipRunsFormat"] = "%s - %d runs",
    ["PlayerJournal.RelationshipActivitiesFormat"] = "%s - %d activities",
    ["PlayerJournal.RelationshipNotesFormat"] = "%d Personal Notes",
    ["PlayerJournal.RelationshipObservationsFormat"] = "%d Community Observations",

    ["PlayerJournal.TooltipFavorite"] = "%s Favorite Player",
    ["PlayerJournal.TooltipRunsTogether"] = "Runs Together",
    ["PlayerJournal.TooltipLastSeen"] = "Last Seen",
    ["PlayerJournal.TooltipNotePreviewFormat"] = "\"%s\"",
    ["PlayerJournal.TooltipCommunityObservations"] = "Community Observations",

    ["PlayerJournal.EndOfRunPromptText"] = "Would you like to add a note about anyone from this run?",

    ["PlayerJournal.MenuOpenJournal"] = "Open Player Journal",
    ["PlayerJournal.MenuCommunityObservations"] = "Community Observations",
    ["PlayerJournal.MenuViewObservations"] = "View Observations",
    ["PlayerJournal.MenuViewMyObservations"] = "View My Observations",
    ["PlayerJournal.MenuAddObservation"] = "Add Observation",
    ["PlayerJournal.MenuAddObservationAboutMyself"] = "Add Observation About Myself",
    ["PlayerJournal.MenuHideObservationsFormat"] = "Hide %s's Observations",
    ["PlayerJournal.MenuPersonalNotes"] = "Personal Notes",
    ["PlayerJournal.MenuAddToJournal"] = "Add to Journal",
    ["PlayerJournal.MenuFavoritePlayer"] = "Favorite Player",
    ["PlayerJournal.MenuCopyCharacterLink"] = "Copy Character Link",

    ["PlayerJournal.TagFriendly"] = "Friendly",
    ["PlayerJournal.TagPatient"] = "Patient",
    ["PlayerJournal.TagReliable"] = "Reliable",
    ["PlayerJournal.TagGreatLeader"] = "Great Leader",
    ["PlayerJournal.TagGoodCommunication"] = "Good Communication",
    ["PlayerJournal.TagGreatTeacher"] = "Great Teacher",
    ["PlayerJournal.TagGoodTank"] = "Good Tank",
    ["PlayerJournal.TagGoodHealer"] = "Good Healer",
    ["PlayerJournal.TagGoodDPS"] = "Good DPS",
    ["PlayerJournal.TagGoodInterrupts"] = "Good Interrupts",
    ["PlayerJournal.TagFavoritePlayer"] = "Favorite Player",

    ["Community.Disabled"] = "Community Observations are disabled. Enable them in Settings.",
    ["Community.NoObservationsTitle"] = "No Observations Yet",
    ["Community.NoObservationsDescription"] = "Community Observations are firsthand notes about players you've grouped with -- always attributed to you, never anonymous.",
    ["Community.NoObservationsExample"] = "For example: \"Excellent tank, very patient with new players.\"",
    ["Community.NoObservationsCallToAction"] = "Use Add Observation above to write your first one.",
    ["Community.HiddenForPlayer"] = "Community Observations are hidden for this player. Change this from the player's right-click menu.",
    ["Community.AddObservation"] = "Add Observation",
    ["Community.AddObservationTitle"] = "Add Community Observation",
    ["Community.FieldPlayerFormat"] = "Player: %s",
    ["Community.CharacterCountFormat"] = "%d / %d",
    ["Community.ObservationMetaFormat"] = "Observed by: %s -- %s",

    ["Community.CodeOfConductText"] = "Before sharing a Community Observation, please confirm you understand the Code of Conduct:\n\n- No hate speech, racism, or sexism\n- No harassment or threats\n- No doxxing or other personal information\n- No impersonation\n- No spam or advertising\n\nCommunity Observations are fully local this version -- there is no shared backend yet, so this observation is only ever visible to you. This confirmation is required once, in case that changes in the future.",
}
