-------------------------------------------------------------------------------
-- Azeroth Companion
-- Recommendation Engine
--
-- Evaluates insights and produces prioritized, explainable recommendations.
--
-- RecommendationEngine V2 (Companion Intelligence): a recommendation is no
-- longer just a title/description pulled from one Insight. Every
-- recommendation now carries sourceModules (which module(s) contributed to
-- it), supportingEvidence (the concrete facts behind it, for the "Why?"
-- view), and a deterministic score (see ComputeScore) that actually
-- drives ranking instead of the Insight's raw priority.
--
-- Ownership note on cross-module evidence: this engine's TRIGGER for any
-- recommendation still comes exclusively from AC.InsightEngine:GetInsights()
-- -- it does not invent new judgments. But to attach real supporting
-- evidence from OTHER modules (e.g. Character's item level, Weekly's vault
-- progress) to a recommendation whose trigger came from one module's
-- Insight, this engine is allowed to read those other modules' already-
-- public fact getters (GetProfile(), GetSeasonStatistics(), ...) -- the
-- exact same getters Dashboard already reads directly for its own cards.
-- This is a deliberate, narrow exception agreed on before implementation
-- (see docs/GameplayModuleArchitecture.md, "RecommendationEngine V2"): it
-- is a read-only fact lookup, never a new gameplay computation, and every
-- fact read this way already exists as a public getter used elsewhere.
--
-- RecommendationEngine V3 (Companion Intelligence): reasons across the
-- player's whole account instead of one module at a time. Refresh() is
-- now an explicit pipeline:
--
--   1. Collect  -- AC.InsightEngine:GetInsights() (unchanged; InsightEngine
--                  already IS the "gather real evidence from every module"
--                  step -- this engine never re-collects gameplay data
--                  itself, only reasons over what InsightEngine assembled).
--   2. Group    -- GroupInsights() partitions insights into a "Preparation"
--                  group (bag/hearthstone/repair/restock -- the same kind
--                  of "get your stuff together" concern regardless of
--                  which module noticed it) and everything else.
--   3. Merge    -- MergePreparationGroup() collapses 2+ Preparation insights
--                  into one "Restock & Prepare" recommendation instead of
--                  several scattered ones saying overlapping things; a
--                  single Preparation insight is left exactly as
--                  EvaluateInsight already builds it, unchanged.
--   4. Score    -- ComputeScore() (extended, see its own comment) +
--                  ComputeConfidence() (new -- see its own comment), both
--                  applied in AddRecommendation() exactly as V2 already did
--                  for score.
--   5. Prioritize -- SortRecommendations() (unchanged -- sorts by score).
--   6. Present  -- Dashboard's job, not this engine's; nothing changes here.
--
-- Duplicate reduction, concretely: when "Keystone Ready" fires, its own
-- evidence-gathering already surfaces Storage's Mythic+-preset missing/
-- withdrawal items and a real repair check (both added this pass -- see
-- the Keystone Ready branch below). Showing a second, separate "Restock &
-- Prepare" card repeating the same two facts would just be the same
-- information said twice, so GroupInsights() omits "Storage Missing
-- Items"/"Storage Excess Items"/"Repairs Needed" from a fresh's grouping
-- entirely when Keystone Ready is also active that refresh -- not
-- silently dropped, genuinely subsumed into the richer recommendation
-- that already carries the same facts as real evidence.
--
-- Recommendation Inspector: every supportingEvidence entry is now
-- { label, value, module } -- `module` is additive (every existing reader
-- destructures label/value and ignores fields it doesn't know about), and
-- is never guessed -- it's always the same module name already known at
-- the exact call site that builds that evidence entry (the variable name
-- of the module being read, or a merged candidate's own already-real
-- `category`). This lets the Inspector group evidence by contributing
-- module without duplicating this engine's own "which module did this
-- fact come from" knowledge -- see Core/UI/RecommendationInspector.lua.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local time = time

local RecommendationEngine =
{
    Name = "RecommendationEngine",
}

AC.RecommendationEngine = RecommendationEngine

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function RecommendationEngine:ResetState()

    self.Recommendations = {}
    self.LastRefresh = 0

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function RecommendationEngine:Initialize()

    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function RecommendationEngine:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function RecommendationEngine:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function RecommendationEngine:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Merge Groups (Part 2/3 -- Group / Merge)
--
-- "Preparation": bag space, hearthstone possession, repair status, and
-- Storage restock gaps are all the same underlying concern -- "am I
-- ready to go" -- regardless of which module happened to notice it.
-- Grouping them is presentation-level reasoning over already-real
-- Insights, not a new gameplay judgment: every title here is still one
-- module's own Insight, unchanged.
-------------------------------------------------------------------------------

local PREPARATION_INSIGHT_TITLES =
{
    ["Bags Almost Full"] = true,
    ["Bags Filling Up"] = true,
    ["Hearthstone Missing"] = true,
    ["Repairs Needed"] = true,
    ["Storage Missing Items"] = true,
    ["Storage Excess Items"] = true,
}

-- Subsumed into "Complete Your Keystone" once "Keystone Ready" is active
-- this refresh -- see the file header's "Duplicate reduction" note.
local SUBSUMED_BY_KEYSTONE_READY =
{
    ["Storage Missing Items"] = true,
    ["Storage Excess Items"] = true,
    ["Repairs Needed"] = true,
}

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function RecommendationEngine:Refresh()

    self.Recommendations = {}

    if not AC.InsightEngine then
        return
    end

    -- Phase 1: Collect -- InsightEngine already gathered every module's
    -- real evidence; this engine reasons over that list, it never
    -- re-collects gameplay data itself.
    local insights = AC.InsightEngine:GetInsights()

    if not insights or #insights == 0 then
        return
    end

    -- Phase 2: Group
    local preparationGroup, singletons = self:GroupInsights(insights)

    -- Phase 3: Merge (each singleton is evaluated individually, exactly
    -- as V2 already did; the Preparation group is merged into at most
    -- one recommendation instead of one per insight).
    local candidates = {}

    for _, insight in ipairs(singletons) do

        local recommendation = self:EvaluateInsight(insight)

        if recommendation then
            table.insert(candidates, recommendation)
        end

    end

    local merged = self:MergePreparationGroup(preparationGroup)

    if merged then
        table.insert(candidates, merged)
    end

    -- Phase 4: Score (AddRecommendation computes both Score and
    -- Confidence for every candidate, merged or not).
    for _, recommendation in ipairs(candidates) do
        self:AddRecommendation(recommendation)
    end

    -- Phase 5: Prioritize
    self:SortRecommendations()
    self.LastRefresh = time()

    -- Phase 6 (Present) is Dashboard's job -- nothing here renders anything.

end

-------------------------------------------------------------------------------
-- Group Insights (Part 2)
--
-- Partitions the real Insight list into the Preparation group and
-- everything else. Titles subsumed by an active "Keystone Ready" this
-- refresh are omitted entirely -- not added to either list -- since their
-- facts are already carried as real evidence on that richer
-- recommendation (see the Keystone Ready branch and the file header).
-------------------------------------------------------------------------------

function RecommendationEngine:GroupInsights(insights)

    local hasKeystoneReady = false

    for _, insight in ipairs(insights) do

        if insight.title == "Keystone Ready" then
            hasKeystoneReady = true
            break
        end

    end

    local preparationGroup = {}
    local singletons = {}

    for _, insight in ipairs(insights) do

        if hasKeystoneReady and SUBSUMED_BY_KEYSTONE_READY[insight.title] then

            -- Already represented inside Keystone Ready's own evidence
            -- this refresh -- omitted rather than shown twice.

        elseif PREPARATION_INSIGHT_TITLES[insight.title] then
            table.insert(preparationGroup, insight)
        else
            table.insert(singletons, insight)
        end

    end

    return preparationGroup, singletons

end

-------------------------------------------------------------------------------
-- Merge Preparation Group (Part 3)
--
-- Fewer than two real candidates: nothing to merge, so this returns
-- exactly what EvaluateInsight already builds for a single insight (or
-- nil for zero) -- a lone Preparation concern keeps its own specific
-- title/description instead of being renamed into a vaguer merged one it
-- doesn't need. Two or more: one "Restock & Prepare" recommendation,
-- built ONLY from what EvaluateInsight's existing per-title branches
-- already produced for each real insight in the group -- this never
-- re-derives wording or invents a new judgment, it only re-presents
-- exactly what each branch already decided, once, consolidated.
-------------------------------------------------------------------------------

function RecommendationEngine:MergePreparationGroup(insights)

    if #insights == 0 then
        return nil
    end

    if #insights == 1 then
        return self:EvaluateInsight(insights[1])
    end

    local candidates = {}
    local highestPriority = 0
    local sourceModules = {}
    local sourceModuleSet = {}
    local supportingEvidence = {}

    for _, insight in ipairs(insights) do

        local candidate = self:EvaluateInsight(insight)

        if candidate then

            table.insert(candidates, candidate)

            if candidate.priority and candidate.priority > highestPriority then
                highestPriority = candidate.priority
            end

            table.insert(supportingEvidence, { label = candidate.title, value = candidate.description, module = candidate.category })

            local moduleName = candidate.category

            if moduleName and moduleName ~= "" and not sourceModuleSet[moduleName] then
                sourceModuleSet[moduleName] = true
                table.insert(sourceModules, moduleName)
            end

        end

    end

    if #candidates == 0 then
        return nil
    end

    if #candidates == 1 then
        return candidates[1]
    end

    return
    {
        id = "RestockAndPrepare",
        title = AC.L:Get("Recommendation.RestockAndPrepare.Title"),
        description = AC.L:Format("Recommendation.RestockAndPrepare.DescriptionFormat", #candidates),
        priority = highestPriority,
        category = "Preparation",
        timestamp = time(),
        expiresAt = 0,
        dismissible = false,
        data = {},
        sourceModules = sourceModules,
        supportingEvidence = supportingEvidence,
    }

end

-------------------------------------------------------------------------------
-- Insight Evaluation
-------------------------------------------------------------------------------

function RecommendationEngine:EvaluateInsight(insight)

    if not insight or type(insight) ~= "table" then
        return nil
    end

    local title = insight.title or ""
    local category = insight.category or ""
    local priority = insight.priority or 0

    -- Bags Almost Full
    if title == "Bags Almost Full" then
        return
        {
            id = "VisitVendor",
            title = AC.L:Get("Recommendation.VisitVendor.Title"),
            description = AC.L:Get("Recommendation.VisitVendor.Description"),
            priority = priority + 10,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Bags Filling Up
    if title == "Bags Filling Up" then
        return
        {
            id = "ConsiderVendorSoon",
            title = AC.L:Get("Recommendation.ConsiderVendorSoon.Title"),
            description = AC.L:Get("Recommendation.ConsiderVendorSoon.Description"),
            priority = priority - 10,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Hearthstone Missing
    if title == "Hearthstone Missing" then
        return
        {
            id = "AcquireHearthstone",
            title = AC.L:Get("Recommendation.AcquireHearthstone.Title"),
            description = AC.L:Get("Recommendation.AcquireHearthstone.Description"),
            priority = priority,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Rested XP Available
    if title == "Rested XP Available" then
        return
        {
            id = "UseRestedXP",
            title = AC.L:Get("Recommendation.UseRestedXP.Title"),
            description = AC.L:Get("Recommendation.UseRestedXP.Description"),
            priority = priority - 5,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Level Up This Session
    if title == "Level Up This Session" then
        return
        {
            id = "ContinueLeveling",
            title = AC.L:Get("Recommendation.ContinueLeveling.Title"),
            description = AC.L:Get("Recommendation.ContinueLeveling.Description"),
            priority = priority - 10,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Item Level Improved
    if title == "Item Level Improved" then
        return
        {
            id = "TryHarderContent",
            title = AC.L:Get("Recommendation.TryHarderContent.Title"),
            description = AC.L:Get("Recommendation.TryHarderContent.Description"),
            priority = priority - 15,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Achievement Earned
    if title == "Achievement Earned" then
        return
        {
            id = "ContinueAchievementHunting",
            title = AC.L:Get("Recommendation.ContinueAchievementHunting.Title"),
            description = AC.L:Get("Recommendation.ContinueAchievementHunting.Description"),
            priority = priority - 10,
            category = "Accomplishments",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Achievement Milestone
    if title == "Achievement Milestone" then

        local data = insight.data or {}
        local reason

        if data.pointsRemaining and data.nextMilestone then
            reason = AC.L:Format("Recommendation.ReachNextMilestone.Reason", data.pointsRemaining, data.nextMilestone)
        end

        return
        {
            id = "ReachNextMilestone",
            title = AC.L:Get("Recommendation.ReachNextMilestone.Title"),
            description = AC.L:Get("Recommendation.ReachNextMilestone.Description"),
            priority = priority - 5,
            category = "Accomplishments",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = reason,
        }

    end

    -- Max Level Reached
    if title == "Max Level Reached" then
        return
        {
            id = "ExploreEndgameContent",
            title = AC.L:Get("Recommendation.ExploreEndgameContent.Title"),
            description = AC.L:Get("Recommendation.ExploreEndgameContent.Description"),
            priority = priority - 5,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Repairs Needed
    if title == "Repairs Needed" then
        return
        {
            id = "RepairYourGear",
            title = AC.L:Get("Recommendation.RepairYourGear.Title"),
            description = AC.L:Get("Recommendation.RepairYourGear.Description"),
            priority = priority + 5,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- No Keystone
    if title == "No Keystone" then
        return
        {
            id = "RetrieveKeystone",
            title = AC.L:Get("Recommendation.RetrieveKeystone.Title"),
            description = AC.L:Get("Recommendation.RetrieveKeystone.Description"),
            priority = priority,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Keystone Ready -- the flagship cross-module recommendation. The
    -- trigger (an owned keystone, no run active) is MythicPlus's own
    -- Insight; everything below only ATTACHES real supporting evidence
    -- and scoring factors already exposed as public facts by MythicPlus,
    -- Character, Weekly, Storage, and (V3) Inventory -- see the ownership
    -- note at the top of this file. Any fact this module can't find (no
    -- Character profile yet, no Weekly data this session, too few
    -- historical runs) is simply omitted, never guessed at.
    if title == "Keystone Ready" then

        local data = insight.data or {}
        local dungeonID = data.dungeonID
        local level = data.level or 0
        local dungeonName = data.dungeonName or ""

        local sourceModules = { "MythicPlus" }
        local supportingEvidence = {}
        local scoreFactors = {}
        local estimatedTime
        local expectedBenefit

        local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
        local mpProfile = mythicPlusModule and mythicPlusModule:GetProfile()

        if mpProfile then
            table.insert(supportingEvidence, { label = AC.L:Get("Evidence.CurrentRating"), value = AC.Presentation.FormatRating(mpProfile.rating), module = "MythicPlus" })
        end

        local seasonStats = mythicPlusModule and mythicPlusModule:GetSeasonStatistics()

        if mythicPlusModule and dungeonID and dungeonID > 0 then

            local dungeonStats = mythicPlusModule:GetDungeonStatistics(dungeonID)

            if dungeonStats and dungeonStats.runsCompleted >= 2 then

                table.insert(supportingEvidence, { label = AC.L:Get("Evidence.HistoricalSuccessRate"), value = AC.Presentation.FormatPercent(dungeonStats.successRate), module = "MythicPlus" })
                scoreFactors.historicalSuccessRate = dungeonStats.successRate

                if dungeonStats.averageCompletionTime > 0 then
                    -- Goal 9 polish (Companion Intelligence vNext): was a
                    -- locally-duplicated FormatDuration -- removed once
                    -- Statistics.lua's average-completion-time stat gave
                    -- this exact "M:SS" formatting a third real call site,
                    -- crossing the threshold this file's own prior header
                    -- comment named as the reason to finally share it.
                    estimatedTime = AC.DashboardFormat.FormatClock(dungeonStats.averageCompletionTime)
                    table.insert(supportingEvidence, { label = AC.L:Get("Evidence.HistoricalCompletionTime"), value = estimatedTime, module = "MythicPlus" })
                end

            end

        end

        if seasonStats and seasonStats.timedRuns and seasonStats.timedRuns > 0 then

            local averageGain = seasonStats.ratingGained / seasonStats.timedRuns

            if averageGain > 0 then
                expectedBenefit = AC.L:Format("Recommendation.CompleteYourKeystone.ExpectedBenefit", AC.Presentation.FormatRating(averageGain))
                scoreFactors.averageRatingGain = averageGain
            end

        end

        local characterModule = AC.Core and AC.Core:GetModule("Character")
        local characterProfile = characterModule and characterModule:GetProfile()

        if characterProfile and characterProfile.equippedItemLevel and characterProfile.equippedItemLevel > 0 then

            table.insert(supportingEvidence, { label = AC.L:Get("Evidence.CurrentItemLevel"), value = AC.Presentation.FormatItemLevel(characterProfile.equippedItemLevel), module = "Character" })
            table.insert(sourceModules, "Character")

            local averageAtLevel = seasonStats and seasonStats.averageItemLevelByKeyLevel and seasonStats.averageItemLevelByKeyLevel[level]

            if averageAtLevel and characterProfile.equippedItemLevel < averageAtLevel then
                scoreFactors.belowPersonalGearAverage = true
            end

        end

        local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")
        local vaultProgress = weeklyModule and weeklyModule.GetVaultProgress and weeklyModule:GetVaultProgress()

        if vaultProgress and vaultProgress.totalSlots and vaultProgress.totalSlots > 0 then

            table.insert(supportingEvidence, { label = AC.L:Get("Evidence.VaultProgress"), value = string.format("%d / %d", vaultProgress.unlockedSlots or 0, vaultProgress.totalSlots), module = "Weekly" })
            table.insert(sourceModules, "Weekly")

            local slotsRemaining = vaultProgress.totalSlots - (vaultProgress.unlockedSlots or 0)

            if slotsRemaining > 0 then
                scoreFactors.vaultSlotsRemaining = slotsRemaining
            end

            -- "One more run away" -- reads WeeklyModule's own
            -- GetNextLockedSlot() (Companion Intelligence V4) rather than
            -- re-scanning vaultProgress.slots here, so the "which slot is
            -- next, how much more does it need" logic exists in exactly
            -- one place -- shared with WeeklyModule's own "Vault Slot
            -- Progress" Insight. Blizzard's per-slot progress/threshold
            -- for the Mythic+ activity category are counted in whole
            -- dungeons completed, per general knowledge -- the same
            -- unverified-until-spot-checked caveat WeeklyModule's own
            -- header already carries for this entire field shape, not a
            -- new assumption layered on top.
            local nextSlot = weeklyModule.GetNextLockedSlot and weeklyModule:GetNextLockedSlot()

            if nextSlot and nextSlot.remaining == 1 then
                table.insert(supportingEvidence, { label = AC.L:Get("Evidence.VaultSlotOneRunAway"), value = AC.L:Format("Evidence.VaultSlotOneRunAwayFormat", nextSlot.index or 0), module = "Weekly" })
                scoreFactors.vaultSlotOneRunAway = true
            end

        end

        -- Activity Preparation (Storage) -- the fixed "MythicPlus" built-
        -- in preset is read directly (not whatever profile the player
        -- happens to have active elsewhere) since this recommendation is
        -- unambiguously a Mythic+ activity regardless of the player's
        -- current Storage page selection.
        local storageModule = AC.Core and AC.Core:GetModule("Storage")
        local preparation = storageModule and storageModule.GetPreparationStatus and storageModule:GetPreparationStatus("MythicPlus")

        if preparation then

            table.insert(sourceModules, "Storage")

            if preparation.ready then
                table.insert(supportingEvidence, { label = AC.L:Get("Evidence.Preparation"), value = AC.L:Get("Evidence.PreparationReady"), module = "Storage" })
            else

                for _, missing in ipairs(preparation.missing) do
                    table.insert(supportingEvidence, { label = AC.L:Get(missing.label), value = AC.L:Format("Evidence.PreparationMissingFormat", missing.amount), module = "Storage" })
                end

                for _, withdrawal in ipairs(preparation.withdrawals) do
                    table.insert(supportingEvidence, { label = AC.L:Get(withdrawal.label), value = AC.L:Format("Evidence.PreparationWithdrawFormat", withdrawal.amount), module = "Storage" })
                end

            end

            -- Readiness as a real scoring factor (V3) -- previously
            -- informational only ("there's no documented, non-arbitrary
            -- weight for 'unprepared'"); readinessPercent is StorageModule's
            -- own computed number, not a guess, so treating a high/low
            -- reading as a real opportunity/friction signal is a
            -- documented, deterministic term like every other one below,
            -- not an arbitrary one.
            if preparation.readinessPercent then

                if preparation.readinessPercent >= 90 then
                    scoreFactors.preparationReady = true
                elseif preparation.readinessPercent < 50 then
                    scoreFactors.preparationLacking = true
                end

            end

        end

        -- Repair Status (V3) -- read directly from Inventory's own public
        -- getter (the same one the Home Mythic+ card already reads),
        -- since walking into a dungeon unrepaired is genuinely relevant
        -- Mythic+ preparation even though Storage's restock analysis
        -- doesn't track it.
        local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
        local importantItems = inventoryModule and inventoryModule.GetImportantItemsSummary and inventoryModule:GetImportantItemsSummary()

        if importantItems and importantItems.needsRepair then

            table.insert(supportingEvidence, { label = AC.L:Get("Evidence.RepairStatus"), value = AC.L:Get("Inventory.RepairsNeeded"), module = "Inventory" })
            table.insert(sourceModules, "Inventory")

        end

        -- Player Journal (Companion Intelligence vNext) -- who from the
        -- current party this module already knows something real about.
        -- Display only: no scoreFactor is set from this, and nothing here
        -- generates a new opinion about any player -- it only re-presents
        -- PlayerJournalModule's own already-real stats/tags (Rule 6).
        local playerJournalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
        local partyMatches = playerJournalModule and playerJournalModule.GetCurrentPartyJournalMatches and playerJournalModule:GetCurrentPartyJournalMatches()

        if partyMatches and #partyMatches > 0 then

            -- Deliberately NOT added to sourceModules -- that list drives
            -- RecommendationInspector's clickable "Contributing Modules"
            -- buttons, each of which navigates to that module's own
            -- Dashboard page (MODULE_TO_PAGE). PlayerJournal has no
            -- Dashboard page (it's a standalone window), so a
            -- Contributing Modules entry for it would be a dead click.
            -- The evidence itself still groups under its own "Player
            -- Journal" heading in Supporting Evidence via each entry's
            -- own `module` tag below -- unaffected by this.
            for _, match in ipairs(partyMatches) do

                local value = AC.L:Format("Evidence.PlayerJournalRunsTogetherFormat", match.runsTogether or 0)

                if match.isFavorite then
                    value = AC.L:Get("Evidence.PlayerJournalFavoriteGlyph") .. " " .. value
                end

                table.insert(supportingEvidence, { label = match.name, value = value, module = "PlayerJournal" })

            end

        end

        local reason

        if dungeonName ~= "" then
            reason = AC.L:Format("Recommendation.CompleteYourKeystone.Reason", dungeonName, level)
        else
            reason = AC.L:Format("Recommendation.CompleteYourKeystone.ReasonNoName", level)
        end

        return
        {
            id = "CompleteYourKeystone",
            title = AC.L:Get("Recommendation.CompleteYourKeystone.Title"),
            description = AC.L:Get("Recommendation.CompleteYourKeystone.Description"),
            priority = priority,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = reason,
            expectedBenefit = expectedBenefit,
            estimatedTime = estimatedTime,
            sourceModules = sourceModules,
            supportingEvidence = supportingEvidence,
            scoreFactors = scoreFactors,
        }

    end

    -- Personal Best
    if title == "Personal Best" then

        local data = insight.data or {}
        local reason

        if data.level and data.level > 0 then

            if data.dungeonName and data.dungeonName ~= "" then
                reason = AC.L:Format("Recommendation.PushFurther.ReasonWithDungeon", data.level, data.dungeonName)
            else
                reason = AC.L:Format("Recommendation.PushFurther.Reason", data.level)
            end

        end

        return
        {
            id = "PushFurther",
            title = AC.L:Get("Recommendation.PushFurther.Title"),
            description = AC.L:Get("Recommendation.PushFurther.Description"),
            priority = priority - 10,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = reason,
        }
    end

    -- Recent Timed Rate -- only actionable when it's low; a healthy rate
    -- is already covered by the insight itself, not every recommendation
    -- needs a matching card.
    if title == "Recent Timed Rate" then

        local data = insight.data or {}
        local timedCount = data.timedCount or 0
        local totalRuns = data.totalRuns or 0

        if totalRuns > 0 and (timedCount / totalRuns) < 0.5 then
            return
            {
                id = "ConsiderLowerKeyLevel",
                title = AC.L:Get("Recommendation.ConsiderLowerKeyLevel.Title"),
                description = AC.L:Get("Recommendation.ConsiderLowerKeyLevel.Description"),
                priority = priority,
                category = "MythicPlus",
                timestamp = time(),
                expiresAt = 0,
                dismissible = false,
                data = data,
                reason = AC.L:Format("Recommendation.ConsiderLowerKeyLevel.Reason", timedCount, totalRuns),
                scoreFactors = { historicalSuccessRate = (timedCount / totalRuns) * 100 },
            }
        end

        return nil

    end

    -- Weakest Dungeon -- a historical-performance-based recommendation,
    -- not a Blizzard-progression one; the insight itself already gates
    -- this on having enough recorded samples to be meaningful.
    if title == "Weakest Dungeon" then

        local data = insight.data or {}

        return
        {
            id = "PracticeWeakestDungeon",
            title = AC.L:Get("Recommendation.PracticeWeakestDungeon.Title"),
            description = AC.L:Get("Recommendation.PracticeWeakestDungeon.Description"),
            priority = priority,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = AC.L:Format("Recommendation.PracticeWeakestDungeon.Reason", data.dungeonName or ""),
        }

    end

    -- Consumables Reminder -- historical performance (how often the
    -- player actually shows up prepared), not a Blizzard progression
    -- signal.
    if title == "Consumables Reminder" then

        local data = insight.data or {}

        return
        {
            id = "BringConsumables",
            title = AC.L:Get("Recommendation.BringConsumables.Title"),
            description = AC.L:Get("Recommendation.BringConsumables.Description"),
            priority = priority,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
        }

    end

    -- Storage Missing Items
    if title == "Storage Missing Items" then
        return
        {
            id = "RestockYourBags",
            title = AC.L:Get("Recommendation.RestockYourBags.Title"),
            description = AC.L:Get("Recommendation.RestockYourBags.Description"),
            priority = priority,
            category = "Storage",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Storage Excess Items
    if title == "Storage Excess Items" then
        return
        {
            id = "DepositCraftingMaterials",
            title = AC.L:Get("Recommendation.DepositCraftingMaterials.Title"),
            description = AC.L:Get("Recommendation.DepositCraftingMaterials.Description"),
            priority = priority,
            category = "Storage",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Vault Reward Available
    if title == "Vault Reward Available" then
        return
        {
            id = "ClaimVaultReward",
            title = AC.L:Get("Recommendation.ClaimVaultReward.Title"),
            description = AC.L:Get("Recommendation.ClaimVaultReward.Description"),
            priority = priority,
            category = "Weekly",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Rating Increased
    if title == "Rating Increased" then
        return
        {
            id = "KeepClimbing",
            title = AC.L:Get("Recommendation.KeepClimbing.Title"),
            description = AC.L:Get("Recommendation.KeepClimbing.Description"),
            priority = priority - 15,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -----------------------------------------------------------------------
    -- Companion Intelligence vNext -- personal, history-based
    -- recommendations. Each trigger below is still a real Insight from
    -- the module that owns the underlying fact (PlayerJournalModule,
    -- MythicPlusModule); this engine only reasons over it, same as every
    -- branch above.
    -----------------------------------------------------------------------

    -- Untimed This Season -- MythicPlusModule's own real per-dungeon fact
    -- (attempted, never timed, this season).
    if title == "Untimed This Season" then

        local data = insight.data or {}

        return
        {
            id = "PracticeUntimedDungeon",
            title = AC.L:Get("Recommendation.PracticeUntimedDungeon.Title"),
            description = AC.L:Get("Recommendation.PracticeUntimedDungeon.Description"),
            priority = priority,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = AC.L:Format("Recommendation.PracticeUntimedDungeon.Reason", data.dungeonName or "", data.attempts or 0),
        }

    end

    -- Frequent Companion In Party -- PlayerJournalModule's own real fact
    -- (this player is your most-frequent companion AND is currently in
    -- your party) -- display of an existing relationship, not a new
    -- opinion about the player.
    if title == "Frequent Companion In Party" then

        local data = insight.data or {}

        return
        {
            id = "RunWithFrequentCompanion",
            title = AC.L:Get("Recommendation.RunWithFrequentCompanion.Title"),
            description = AC.L:Get("Recommendation.RunWithFrequentCompanion.Description"),
            priority = priority,
            category = "PlayerJournal",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = insight.description,
        }

    end

    -- Reconnect With Favorite -- PlayerJournalModule's own real fact (a
    -- Favorite the player hasn't grouped with in a while).
    if title == "Reconnect With Favorite" then

        local data = insight.data or {}

        return
        {
            id = "ReconnectWithFavorite",
            title = AC.L:Get("Recommendation.ReconnectWithFavorite.Title"),
            description = AC.L:Get("Recommendation.ReconnectWithFavorite.Description"),
            priority = priority,
            category = "PlayerJournal",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = data,
            reason = insight.description,
        }

    end

    return nil

end

-------------------------------------------------------------------------------
-- Recommendation Scoring -- the Opportunity Score (V3)
--
-- Deterministic and documented: every term below is a fixed, named
-- adjustment applied only when a branch actually supplied that factor
-- with real data. A factor a branch didn't supply contributes exactly 0
-- -- never a guessed value -- which is what keeps this generic enough for
-- a future module (Delves, Raids, ...) that won't have vault/gear data
-- at all. No randomness anywhere in this function.
--
--   score = priority                                   (the triggering Insight's own urgency, unchanged)
--         + 15  if historicalSuccessRate >= 70          (genuinely achievable, worth surfacing first)
--         - 15  if historicalSuccessRate <  40          (recommending it anyway would set the player up to fail)
--         + min(vaultSlotsRemaining * 5, 15)             (real, remaining Great Vault upgrade potential this week)
--         + 5   if belowPersonalGearAverage              (player's own gear is below their own historical average at this level)
--         + 10  if vaultSlotOneRunAway                   (V3 -- genuinely one run from a real, countable Vault threshold)
--         + 8   if preparationReady                      (V3 -- already prepared: real, low-friction opportunity)
--         - 8   if preparationLacking                    (V3 -- real friction; still shown, just not first)
--         + min(floor(averageRatingGain / 5), 10)         (V3 -- real historical benefit magnitude, capped)
--
-- Also returns `breakdown`, an ordered list of `{ label, value }` -- one
-- entry per term that actually applied, in the exact order applied above
-- -- for the Recommendation Inspector's Developer Mode score-breakdown
-- section (Developer Mode & Live Verification Suite). This is not new
-- scoring logic, only bookkeeping alongside logic that already existed --
-- every branch below is unchanged from before this pass, it just also
-- records what it did.
-------------------------------------------------------------------------------

function RecommendationEngine:ComputeScore(priority, factors)

    local score = tonumber(priority) or 0
    local breakdown = { { label = "ScoreFactor.BasePriority", value = score } }

    factors = factors or {}

    if factors.historicalSuccessRate then

        if factors.historicalSuccessRate >= 70 then
            score = score + 15
            table.insert(breakdown, { label = "ScoreFactor.HistoricalSuccessHigh", value = 15 })
        elseif factors.historicalSuccessRate < 40 then
            score = score - 15
            table.insert(breakdown, { label = "ScoreFactor.HistoricalSuccessLow", value = -15 })
        end

    end

    if factors.vaultSlotsRemaining and factors.vaultSlotsRemaining > 0 then

        local bonus = math.min(factors.vaultSlotsRemaining * 5, 15)

        score = score + bonus
        table.insert(breakdown, { label = "ScoreFactor.VaultSlotsRemaining", value = bonus })

    end

    if factors.belowPersonalGearAverage then
        score = score + 5
        table.insert(breakdown, { label = "ScoreFactor.BelowGearAverage", value = 5 })
    end

    if factors.vaultSlotOneRunAway then
        score = score + 10
        table.insert(breakdown, { label = "ScoreFactor.VaultSlotOneRunAway", value = 10 })
    end

    if factors.preparationReady then
        score = score + 8
        table.insert(breakdown, { label = "ScoreFactor.PreparationReady", value = 8 })
    elseif factors.preparationLacking then
        score = score - 8
        table.insert(breakdown, { label = "ScoreFactor.PreparationLacking", value = -8 })
    end

    if factors.averageRatingGain and factors.averageRatingGain > 0 then

        local bonus = math.min(math.floor(factors.averageRatingGain / 5), 10)

        score = score + bonus
        table.insert(breakdown, { label = "ScoreFactor.AverageRatingGain", value = bonus })

    end

    return score, breakdown

end

-------------------------------------------------------------------------------
-- Confidence (V3)
--
-- How SUBSTANTIATED a recommendation is -- a separate axis from score/
-- priority, which measure how URGENT it is. Deterministic, derived only
-- from what the recommendation itself actually carries (never a new
-- gameplay judgment): each of the three real signals below contributes
-- one point --
--   - 2+ contributing modules (completeness of module data)
--   - 2+ supporting evidence facts (amount of supporting evidence)
--   - a real historical-success-rate factor present (historical success)
-- 2+ points -> High. 1 point, or at least one evidence fact even without
-- a full point, -> Medium. Otherwise -> Low: still a real recommendation
-- (Rule 6's trigger is always a real Insight), just not independently
-- corroborated by anything else yet.
-------------------------------------------------------------------------------

function RecommendationEngine:ComputeConfidence(sourceModules, supportingEvidence, scoreFactors)

    local moduleCount = sourceModules and #sourceModules or 0
    local evidenceCount = supportingEvidence and #supportingEvidence or 0
    local hasHistoricalData = scoreFactors and scoreFactors.historicalSuccessRate ~= nil

    local strength = 0

    if moduleCount >= 2 then
        strength = strength + 1
    end

    if evidenceCount >= 2 then
        strength = strength + 1
    end

    if hasHistoricalData then
        strength = strength + 1
    end

    if strength >= 2 then
        return "High"
    end

    if strength >= 1 or evidenceCount >= 1 then
        return "Medium"
    end

    return "Low"

end

-------------------------------------------------------------------------------
-- Recommendation Management
-------------------------------------------------------------------------------

function RecommendationEngine:AddRecommendation(recommendation)

    local sourceModules = recommendation.sourceModules or { recommendation.category }
    local supportingEvidence = recommendation.supportingEvidence or {}
    local score, scoreBreakdown = self:ComputeScore(recommendation.priority, recommendation.scoreFactors)

    local recommendationRecord =
    {
        title = recommendation.title,
        description = recommendation.description,
        priority = recommendation.priority,
        category = recommendation.category,
        timestamp = recommendation.timestamp or time(),
        expiresAt = recommendation.expiresAt or 0,
        dismissible = recommendation.dismissible or false,
        data = recommendation.data or {},

        -- Optional "why" fields (nil when a mapping doesn't provide them,
        -- which is most of them today) -- additive to the existing
        -- schema so every mapping above keeps working unchanged. The
        -- Dashboard falls back to the plain title/description card when
        -- these are absent.
        reason = recommendation.reason,
        expectedBenefit = recommendation.expectedBenefit,
        estimatedTime = recommendation.estimatedTime,

        -- RecommendationEngine V2: explainability + scoring. sourceModules
        -- defaults to the recommendation's own category so every
        -- recommendation, old or new, always has a real (non-empty)
        -- source without every existing 1:1 mapping needing to be
        -- hand-edited. supportingEvidence defaults to an empty list, not
        -- nil, so presentation code never needs a separate nil check.
        sourceModules = sourceModules,
        supportingEvidence = supportingEvidence,
        score = score,

        -- Developer Mode & Live Verification Suite: the ordered list of
        -- named terms that produced `score` above -- see ComputeScore's
        -- own comment. Only ever rendered by the Recommendation
        -- Inspector's Developer Mode section; computing it costs nothing
        -- extra here (the same branches that compute `score` already
        -- ran), so this is stored unconditionally rather than gated on
        -- Developer Mode being on, the same way `score`/`confidence`
        -- themselves are always computed regardless of who's looking.
        scoreBreakdown = scoreBreakdown,

        -- RecommendationEngine V3: how substantiated this recommendation
        -- is, computed from the same real sourceModules/supportingEvidence/
        -- scoreFactors every other V3 addition reads -- never a new fact.
        confidence = self:ComputeConfidence(sourceModules, supportingEvidence, recommendation.scoreFactors),
    }

    table.insert(self.Recommendations, recommendationRecord)

end

function RecommendationEngine:SortRecommendations()

    table_sort(self.Recommendations, function(a, b)
        return a.score > b.score
    end)

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function RecommendationEngine:GetRecommendations()

    return self.Recommendations

end

function RecommendationEngine:GetHighestPriority()

    if #self.Recommendations == 0 then
        return nil
    end

    return self.Recommendations[1]

end

function RecommendationEngine:GetLastRefresh()

    return self.LastRefresh

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("RecommendationEngine", RecommendationEngine)

return RecommendationEngine
