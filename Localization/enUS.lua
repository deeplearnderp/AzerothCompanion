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
    ["Dashboard.Back"] = "Back",
    ["Dashboard.Version"] = "Version %s",
    ["Dashboard.CaughtUp"] = "You're all caught up.",
    ["Dashboard.Loading"] = "Loading...",

    ["Dashboard.RecommendedNextStep"] = "Recommended Next Step",
    ["Dashboard.HighestPriority"] = "Highest Priority",
    ["Dashboard.Profile"] = "Profile",
    ["Dashboard.Inventory"] = "Inventory",
    ["Dashboard.Accomplishments"] = "Accomplishments",
    ["Dashboard.Journey"] = "Journey",
    ["Dashboard.Recommendations"] = "Recommendations",

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

    ["Dashboard.RecentActivity"] = "Recent Activity",
    ["Dashboard.TooltipRecentActivity"] = "View details for your most recent activity",
    ["Dashboard.NoRecentActivity"] = "No recent Mythic+ activity",

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

    ["Dashboard.TooltipRecommendations"] = "View all recommendations",
    ["Dashboard.TooltipProfile"] = "View full character details",
    ["Dashboard.TooltipInventory"] = "View full inventory details",
    ["Dashboard.TooltipAccomplishments"] = "View your character's defining accomplishments",
    ["Dashboard.TooltipJourney"] = "View the story of this character over time",
    ["Dashboard.TooltipStorage"] = "View bank, restock status, and shopping list",

    ["Dashboard.Storage"] = "Storage",
    ["Dashboard.StorageReady"] = "Ready to go.",
    ["Dashboard.StorageMissingFormat"] = "%d item(s) need attention",
    ["Dashboard.StorageNoProfile"] = "No storage profile selected",
    ["Dashboard.StorageUnavailable"] = "Storage unavailable",
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
    ["Dashboard.SectionExecute"] = "Execute",
    ["Dashboard.StorageExecuteAvailable"] = "Ready to move items",

    ["Dashboard.FeedMythicPlusTimedFormat"] = "Timed +%d %s",
    ["Dashboard.FeedMythicPlusFailedFormat"] = "Not Timed +%d %s",
    ["Dashboard.FeedAchievementFormat"] = "Earned %s",

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
    ["MythicPlus.StatRatingGained"] = "Rating Gained",
    ["MythicPlus.StatFastestRun"] = "Fastest Run",
    ["MythicPlus.StatAverageDeaths"] = "Average Deaths",
    ["MythicPlus.StatAverageCompletionTime"] = "Average Completion Time",

    ["MythicPlus.SectionPerformanceTrends"] = "Performance Trends",
    ["MythicPlus.SectionConsumables"] = "Consumables",
    ["MythicPlus.NoPerformanceTrends"] = "Performance trends will appear after your first completed run.",
    ["MythicPlus.NoConsumableData"] = "Consumable usage will appear after your first tracked run.",

    ["MythicPlus.FastestRunFormat"] = "%s (+%d) in %s",
    ["MythicPlus.ConsumablePotion"] = "Potions",
    ["MythicPlus.ConsumableFlask"] = "Flasks",
    ["MythicPlus.ConsumableFood"] = "Food Buffs",
    ["MythicPlus.ConsumableHealthstone"] = "Healthstones",
    ["MythicPlus.ConsumableItemEnhancement"] = "Weapon Enhancements",
    ["MythicPlus.ConsumablesTrackedFormat"] = "Based on %d tracked run(s)",

    ["MythicPlus.RunDetailLevel"] = "Level: +%d",
    ["MythicPlus.RunDetailTime"] = "Completion Time: %s",
    ["MythicPlus.RunDetailDeaths"] = "Deaths: %d",
    ["MythicPlus.RunDetailStarted"] = "Started: %s",
    ["MythicPlus.RunDetailFinished"] = "Finished: %s",
    ["MythicPlus.RunDetailRatingChange"] = "Rating Change: %s",
    ["MythicPlus.RunDetailAffixes"] = "Affixes: %s",

    -----------------------------------------------------------------------
    -- Storage Page
    -----------------------------------------------------------------------

    -- Storage Supply Manager Sprint -- Inventory Summary + Storage Health
    -- merged into one Storage Summary section (they answered the same
    -- "how much room/stuff do I have" question as two thin sections).
    ["Storage.SectionStorageSummary"] = "Storage Summary",
    ["Storage.StatBagSlotsUsed"] = "Bag Slots Used",
    ["Storage.StatBagSlotsFree"] = "Bag Slots Free",
    ["Storage.NotAtBank"] = "Visit a banker to scan your bank.",
    ["Storage.StatBankSlotsScanned"] = "Bank Slots Used",
    ["Storage.StatBankDistinctItems"] = "Distinct Items in Bank",

    -- Supply Health -- one sentence, hero position. Detailed reasoning
    -- lives in the sections below it, never repeated here.
    ["Storage.SectionSupplyHealth"] = "Supply Health",
    -- UI Polish Pass -- icon-prefixed (code prepends a Ready Check icon
    -- texture keyed off SUPPLY_HEALTH_ICONS depending on state, see
    -- Pages/Storage.lua), so these strings stay icon-free and short/
    -- conversational, never repeating "missing"/"need more" in the same
    -- sentence.
    ["Storage.SupplyHealthReady"] = "Ready to Play",
    ["Storage.SupplyHealthMissingFormat"] = "Missing %d %s",
    ["Storage.SupplyHealthMultipleMissing"] = "Multiple Required Consumables Missing",
    ["Storage.SupplyHealthTransfersFormat"] = "Ready after %d Bank Transfer(s)",

    ["Storage.SectionCurrentProfile"] = "Current Profile",
    ["Storage.NoProfileSelected"] = "No storage profile selected.",
    ["Storage.FieldActiveProfile"] = "Active Profile",
    ["Storage.FieldRuleCount"] = "Rule Count",

    -- Renamed from "Restock Status" -- action-oriented, and now strictly
    -- scoped to what Execute can actually move (withdrawals + deposits
    -- only). Missing items live in Shopping List instead -- see that
    -- section's own comment in Pages/Storage.lua for why these were
    -- merged before and are now deliberately split.
    ["Storage.SectionBankTransfers"] = "Bank Transfers",
    ["Storage.AmountWithdrawFormat"] = "Withdraw %d",
    ["Storage.AmountDepositFormat"] = "Deposit %d",
    ["Storage.NoBankTransfersNeeded"] = "Nothing to move between bags and bank right now.",

    -- Shopping List -- missing only, now itemized (Storage Supply Manager
    -- Sprint): the specific already-held item(s) per shortfall, never a
    -- guessed item name for a category with nothing held.
    ["Storage.SectionShoppingList"] = "Shopping List",
    ["Storage.NothingToBuy"] = "Nothing to buy right now.",
    -- Final Polish -- "Need %d" (dropped "more"), now rendered as its own
    -- right-aligned value FontString next to the category label, not
    -- concatenated into one string.
    ["Storage.ShoppingListNeedFormat"] = "Need %d",
    ["Storage.ShoppingListItemFormat"] = "%s (have %d)",
    ["Storage.ShoppingListNoneHeld"] = "None currently held -- check a vendor or the Auction House.",

    -- Consumables -- the definitive supply-check view: every tracked
    -- consumable by icon/name/bag count/bank count/total, grouped by
    -- category, independent of the active profile (your bags don't
    -- change because you switched profiles).
    ["Storage.SectionConsumables"] = "Consumables",
    ["Storage.NoConsumablesTracked"] = "No tracked consumables found in your bags or bank.",
    ["Storage.ConsumableCountFormat"] = "%d total (%d bag, %d bank)",
    ["Storage.Category.potion"] = "Potions",
    ["Storage.Category.flask"] = "Flasks",
    ["Storage.Category.food"] = "Food",
    ["Storage.Category.itemEnhancement"] = "Weapon Enhancements",
    ["Storage.Category.healthstone"] = "Healthstones",

    -- Supply Forecast -- player-friendly sentences built from real
    -- Mythic+ consumption history (MythicPlusModule), not raw numbers.
    ["Storage.SectionSupplyForecast"] = "Supply Forecast",
    ["Storage.NoSupplyForecast"] = "Not enough Mythic+ history yet to forecast supply usage.",
    ["Storage.SupplyForecastFormat"] = "Approximately %d Mythic+ runs remaining",

    -- Storage Insights only -- the "Recommendations" mini-section
    -- (general RecommendationEngine advice, e.g. "Complete Your
    -- Keystone") is removed entirely; that belongs on the Recommendations
    -- page, not here.
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
    -- Weekly Page
    -----------------------------------------------------------------------

    ["Weekly.SectionVaultProgress"] = "Vault Progress",
    ["Weekly.NoVaultData"] = "No Great Vault data available.",
    ["Weekly.StatUnlockedSlots"] = "Unlocked Slots",
    ["Weekly.StatRewardAvailable"] = "Reward Available",
    ["Weekly.SlotsFormat"] = "%d / %d",
    ["Weekly.SlotLabelFormat"] = "Slot %d",
    ["Weekly.SlotProgressFormat"] = "%d / %d",

    ["Weekly.SectionRecommendations"] = "Recommendations",
    ["Weekly.NoRecommendations"] = "You're all caught up.",

    ["Weekly.SectionInsights"] = "Insights",
    ["Weekly.NoInsights"] = "No vault insights right now.",

    -----------------------------------------------------------------------
    -- Common
    -----------------------------------------------------------------------

    ["Common.Unknown"] = "Unknown",
    ["Common.Yes"] = "Yes",
    ["Common.No"] = "No",
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
    ["Developer.Refresh"] = "Refresh",
    ["Developer.NoError"] = "None",

    ["Developer.TabOverview"] = "Overview",
    ["Developer.TabModules"] = "Modules",
    ["Developer.TabEvents"] = "Events",
    ["Developer.TabErrors"] = "Errors",
    ["Developer.TabSecretValues"] = "Secret Values",
    ["Developer.TabLiveAPI"] = "Live API",
    ["Developer.TabHistory"] = "History",
    ["Developer.TabChecklist"] = "Checklist",

    ["Developer.CopyJSON"] = "Copy JSON",
    ["Developer.CopyText"] = "Copy Text",
    ["Developer.CopySummary"] = "Copy Summary",
    ["Developer.CopyHint"] = "Click a Copy button, then press Ctrl+C.",

    ["Developer.ClearNotifications"] = "Clear Notifications",
    ["Developer.ForceRefresh"] = "Force Refresh",
    ["Developer.TracingOn"] = "Tracing: On",
    ["Developer.TracingOff"] = "Tracing: Off",
    ["Developer.ClearHistory"] = "Clear History",

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
    -- Player Journal & Community Notes
    -----------------------------------------------------------------------

    ["Developer.PlayerJournalStoredPlayers"] = "Player Journal: Stored Players",
    ["Developer.PlayerJournalFavoritePlayers"] = "Player Journal: Favorite Players",
    ["Developer.PlayerJournalTotalNotes"] = "Player Journal: Total Notes",
    ["Developer.PlayerJournalCommunityNotes"] = "Player Journal: Community Notes",
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
    ["PlayerJournal.TabCommunityNotes"] = "Community",
    ["PlayerJournal.TabTimeline"] = "Timeline",
    ["PlayerJournal.TabSearch"] = "Search",

    ["PlayerJournal.NoPlayerSelected"] = "No player selected. Use Search to find someone in your journal.",
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

    ["PlayerJournal.FavoritesOnly"] = "Favorites Only",
    ["PlayerJournal.NoSearchResults"] = "No players match your search.",
    ["PlayerJournal.SearchResultMetaFormat"] = "%d run(s) together -- last seen %s",

    ["PlayerJournal.TooltipFavorite"] = "%s Favorite Player",
    ["PlayerJournal.TooltipRunsTogether"] = "Runs Together",
    ["PlayerJournal.TooltipLastSeen"] = "Last Seen",
    ["PlayerJournal.TooltipNotePreviewFormat"] = "\"%s\"",
    ["PlayerJournal.TooltipCommunityNotes"] = "Community Notes",

    ["PlayerJournal.EndOfRunPromptText"] = "Would you like to add a note about anyone from this run?",

    ["PlayerJournal.MenuOpenJournal"] = "Player Journal",
    ["PlayerJournal.MenuQuickNote"] = "Quick Note...",
    ["PlayerJournal.MenuFavoritePlayer"] = "Favorite Player",
    ["PlayerJournal.MenuHideCommunityNotes"] = "Hide Community Notes",
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

    ["Community.Disabled"] = "Community Notes are disabled. Enable them in Settings.",
    ["Community.NoNotes"] = "No community notes for this player yet.",
    ["Community.HiddenForPlayer"] = "Community Notes are hidden for this player. Change this from the player's right-click menu.",
    ["Community.SubmitNote"] = "Submit Community Note",
    ["Community.NoteMetaFormat"] = "%s -- Visibility: %s",

    ["Community.ButtonHelpful"] = "Helpful",
    ["Community.ButtonNotHelpful"] = "Not Helpful",
    ["Community.ButtonReport"] = "Report",
    ["Community.ButtonHide"] = "Hide",
    ["Community.ComingSoonTooltip"] = "Coming soon -- requires a shared backend that doesn't exist yet.",

    ["Community.VisibilityDisabled"] = "Disabled",
    ["Community.VisibilityFriendsOnly"] = "Friends Only",
    ["Community.VisibilityGuildOnly"] = "Guild Only",
    ["Community.VisibilityFriendsAndGuild"] = "Friends + Guild",
    ["Community.VisibilityEveryone"] = "Everyone",

    ["Community.CodeOfConductText"] = "Before sharing a Community Note, please confirm you understand the Code of Conduct:\n\n- No hate speech, racism, or sexism\n- No harassment or threats\n- No doxxing or other personal information\n- No impersonation\n- No spam or advertising\n\nCommunity Notes are fully local this version -- there is no shared backend yet, so this note is only ever visible to you. This confirmation is required once, in case that changes in the future.",
}
