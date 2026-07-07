-------------------------------------------------------------------------------
-- Azeroth Companion
-- Character Module
--
-- Authoritative character profile service for the current player.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local tonumber = tonumber

local UnitName = UnitName
local UnitFullName = UnitFullName
local UnitGUID = UnitGUID
local UnitRace = UnitRace
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local UnitFactionGroup = UnitFactionGroup
local GetRealmName = GetRealmName
local GetZoneText = GetZoneText
local GetSubZoneText = GetSubZoneText
local GetMoney = GetMoney
local GetBindLocation = GetBindLocation
local GetXPExhaustion = GetXPExhaustion
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetAverageItemLevel = GetAverageItemLevel
local GetGuildInfo = GetGuildInfo
local RequestTimePlayed = RequestTimePlayed
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion

local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetHearthstone = C_Hearthstone and C_Hearthstone.GetHearthstone
local GetAccountGUID = C_PlayerInfo and C_PlayerInfo.GetAccountGUID

local CharacterModule =
{
    Name = "Character",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function CharacterModule:ResetProfile()

    self.Profile =
    {
        name = "",
        realm = "",
        fullName = "",
        guid = "",

        race = "",
        raceEnglish = "",
        raceID = 0,

        class = "",
        classFile = "",
        classID = 0,

        specID = 0,
        specName = "",
        specRole = "",

        level = 0,
        maxLevel = 0,

        averageItemLevel = 0,
        equippedItemLevel = 0,

        guildName = "",
        guildRank = "",
        guildRankIndex = 0,

        faction = "",
        factionEnglish = "",

        zone = "",
        subZone = "",
        mapID = 0,

        bindLocation = "",
        hearthstoneItemID = 0,

        money = 0,

        playedTimeTotal = 0,
        playedTimeLevel = 0,
        playedTimeAvailable = false,

        restedXP = 0,

        warband =
        {
            accountGUID = "",
        },

        loginTimestamp = 0,
        lastUpdated = 0,
    }

    self.Session =
    {
        initialLevel = 0,
        initialItemLevel = 0,
        levelUpThisSession = false,
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function CharacterModule:Initialize()

    self:ResetProfile()

    AC.ConfigurationManager:Register("Character", Defaults)

    AC.Settings:RegisterPage("Character",
    {
        title = "Character",
        module = "Character",
        order = 10,
    })

    AC.Settings:RegisterSection("Character", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Character", "General",
    {
        key = "enabled",
        text = "Enable Character Module",
        default = true,
        tooltip = "Maintain an authoritative profile of the current character.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function CharacterModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("PLAYER_LEVEL_UP", self)
    AC.Events:Register("PLAYER_GUILD_UPDATE", self)
    AC.Events:Register("PLAYER_MONEY", self)
    AC.Events:Register("PLAYER_XP_UPDATE", self)
    AC.Events:Register("PLAYER_SPECIALIZATION_CHANGED", self)
    AC.Events:Register("PLAYER_EQUIPMENT_CHANGED", self)
    AC.Events:Register("ZONE_CHANGED", self)
    AC.Events:Register("ZONE_CHANGED_NEW_AREA", self)
    AC.Events:Register("TIME_PLAYED_MSG", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then
        self:Refresh()
        RequestTimePlayed()
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function CharacterModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function CharacterModule:Shutdown()

    self:Disable()
    self:ResetProfile()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function CharacterModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Character", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function CharacterModule:OnPlayerEnteringWorld(isInitialLogin)

    if not self:IsModuleEnabled() then
        return
    end

    if isInitialLogin then
        self.Profile.loginTimestamp = time()
    end

    self:Refresh()

    if isInitialLogin then
        self.Session.initialLevel = self.Profile.level
        self.Session.initialItemLevel = self.Profile.equippedItemLevel
        self.Session.levelUpThisSession = false
    end

    RequestTimePlayed()

end

function CharacterModule:OnPlayerLevelUp()

    if self:IsModuleEnabled() then
        self.Session.levelUpThisSession = true
        self:RefreshIdentity()
        self:RefreshProgression()
        RequestTimePlayed()
    end

end

function CharacterModule:OnPlayerGuildUpdate()

    if self:IsModuleEnabled() then
        self:RefreshGuild()
    end

end

function CharacterModule:OnPlayerMoney()

    if self:IsModuleEnabled() then
        self:RefreshEconomy()
    end

end

function CharacterModule:OnPlayerXpUpdate()

    if self:IsModuleEnabled() then
        self:RefreshProgression()
    end

end

function CharacterModule:OnPlayerSpecializationChanged()

    if self:IsModuleEnabled() then
        self:RefreshSpecialization()
        self:RefreshItemLevel()
    end

end

function CharacterModule:OnPlayerEquipmentChanged()

    if self:IsModuleEnabled() then
        self:RefreshItemLevel()
    end

end

function CharacterModule:OnZoneChanged()

    if self:IsModuleEnabled() then
        self:RefreshLocation()
    end

end

function CharacterModule:OnZoneChangedNewArea()

    if self:IsModuleEnabled() then
        self:RefreshLocation()
    end

end

function CharacterModule:OnTimePlayedMsg(totalTimePlayed, timePlayedThisLevel)

    if not self:IsModuleEnabled() then
        return
    end

    self.Profile.playedTimeTotal = tonumber(totalTimePlayed) or 0
    self.Profile.playedTimeLevel = tonumber(timePlayedThisLevel) or 0
    self.Profile.playedTimeAvailable = true
    self.Profile.lastUpdated = time()

end

function CharacterModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Character" then
        return
    end

    if key ~= "enabled" then
        return
    end

    if value then
        self:Refresh()
        RequestTimePlayed()
    else
        self:ResetProfile()
    end

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function CharacterModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshIdentity()
    self:RefreshSpecialization()
    self:RefreshProgression()
    self:RefreshItemLevel()
    self:RefreshGuild()
    self:RefreshFaction()
    self:RefreshLocation()
    self:RefreshTravel()
    self:RefreshEconomy()
    self:RefreshWarband()

    self.Profile.lastUpdated = time()

end

function CharacterModule:RefreshIdentity()

    local profile = self.Profile
    local name = UnitName("player") or ""
    local realm = GetRealmName() or ""
    local fullName = UnitFullName("player")

    profile.name = name
    profile.realm = realm
    profile.fullName = fullName or name
    profile.guid = UnitGUID("player") or ""

    local raceLocalized, raceEnglish, raceID = UnitRace("player")
    local classLocalized, classFile, classID = UnitClass("player")

    profile.race = raceLocalized or ""
    profile.raceEnglish = raceEnglish or ""
    profile.raceID = raceID or 0

    profile.class = classLocalized or ""
    profile.classFile = classFile or ""
    profile.classID = classID or 0

end

function CharacterModule:RefreshSpecialization()

    local profile = self.Profile
    local specIndex = GetSpecialization()

    if not specIndex then
        profile.specID = 0
        profile.specName = ""
        profile.specRole = ""
        return
    end

    local specID, specName, _, _, role = GetSpecializationInfo(specIndex)

    profile.specID = specID or 0
    profile.specName = specName or ""
    profile.specRole = role or ""

end

function CharacterModule:RefreshProgression()

    local profile = self.Profile

    profile.level = UnitLevel("player") or 0
    profile.maxLevel = GetMaxLevelForPlayerExpansion() or profile.level

    local restedXP = GetXPExhaustion()

    if restedXP == nil then
        profile.restedXP = 0
    else
        profile.restedXP = restedXP
    end

end

function CharacterModule:RefreshItemLevel()

    local profile = self.Profile
    local averageItemLevel, equippedItemLevel = GetAverageItemLevel()

    profile.averageItemLevel = averageItemLevel or 0
    profile.equippedItemLevel = equippedItemLevel or 0

end

function CharacterModule:RefreshGuild()

    local profile = self.Profile
    local guildName, guildRank, guildRankIndex = GetGuildInfo("player")

    profile.guildName = guildName or ""
    profile.guildRank = guildRank or ""
    profile.guildRankIndex = guildRankIndex or 0

end

function CharacterModule:RefreshFaction()

    local profile = self.Profile
    local factionLocalized, factionEnglish = UnitFactionGroup("player")

    profile.faction = factionLocalized or ""
    profile.factionEnglish = factionEnglish or ""

end

function CharacterModule:RefreshLocation()

    local profile = self.Profile

    profile.zone = GetZoneText() or ""
    profile.subZone = GetSubZoneText() or ""

    local mapID = GetBestMapForUnit("player")

    profile.mapID = mapID or 0

end

function CharacterModule:RefreshTravel()

    local profile = self.Profile

    profile.bindLocation = GetBindLocation() or ""

    if GetHearthstone then
        profile.hearthstoneItemID = GetHearthstone() or 0
    else
        profile.hearthstoneItemID = 0
    end

end

function CharacterModule:RefreshEconomy()

    self.Profile.money = GetMoney() or 0

end

function CharacterModule:RefreshWarband()

    local warband = self.Profile.warband

    if GetAccountGUID then
        warband.accountGUID = GetAccountGUID() or ""
    else
        warband.accountGUID = ""
    end

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function CharacterModule:GetProfile()

    return self.Profile

end

function CharacterModule:GetValue(key)

    if type(key) ~= "string" or key == "" then
        return nil
    end

    return self.Profile[key]

end

function CharacterModule:IsMaxLevel()

    local profile = self.Profile

    if profile.maxLevel <= 0 then
        return false
    end

    return profile.level >= profile.maxLevel

end

function CharacterModule:GetCurrentSpec()

    local profile = self.Profile

    return
    {
        specID = profile.specID,
        specName = profile.specName,
        specRole = profile.specRole,
    }

end

function CharacterModule:GetCurrentZone()

    local profile = self.Profile

    return
    {
        zone = profile.zone,
        subZone = profile.subZone,
        mapID = profile.mapID,
    }

end

function CharacterModule:GetSessionInfo()

    local profile = self.Profile
    local session = self.Session

    local sessionDuration = 0

    if profile.loginTimestamp and profile.loginTimestamp > 0 then
        sessionDuration = time() - profile.loginTimestamp
    end

    local levelsGained = 0

    if profile.level and session.initialLevel then
        levelsGained = profile.level - session.initialLevel

        if levelsGained < 0 then
            levelsGained = 0
        end
    end

    local itemLevelGained = 0

    if profile.equippedItemLevel and session.initialItemLevel then
        itemLevelGained = profile.equippedItemLevel - session.initialItemLevel
    end

    return
    {
        loginTimestamp = profile.loginTimestamp,
        sessionDuration = sessionDuration,
        initialLevel = session.initialLevel,
        initialItemLevel = session.initialItemLevel,
        levelUpThisSession = session.levelUpThisSession,
        levelsGained = levelsGained,
        itemLevelGained = itemLevelGained,
    }

end

-------------------------------------------------------------------------------
-- Insights
-------------------------------------------------------------------------------

function CharacterModule:GetInsights()

    local insights = {}
    local profile = self.Profile
    local session = self.Session

    if not profile or not session then
        return insights
    end

    -- Rested XP available
    if profile.restedXP and profile.restedXP > 0 then
        table.insert(insights,
        {
            title = "Rested XP Available",
            description = string.format("You have rested XP available to use."),
            priority = 30,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Character is at max level
    if self:IsMaxLevel() then
        table.insert(insights,
        {
            title = "Max Level Reached",
            description = string.format("You are at the maximum level (%d).", profile.level),
            priority = 25,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Character has reached a new level this session
    if session.levelUpThisSession then
        table.insert(insights,
        {
            title = "Level Up This Session",
            description = string.format("You reached level %d this session.", profile.level),
            priority = 50,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Equipped item level changed this session
    local itemLevelChange = profile.equippedItemLevel - session.initialItemLevel
    if itemLevelChange > 1 then
        table.insert(insights,
        {
            title = "Item Level Improved",
            description = string.format("Your equipped item level increased by %.1f this session.", itemLevelChange),
            priority = 40,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Character", CharacterModule)

return CharacterModule
