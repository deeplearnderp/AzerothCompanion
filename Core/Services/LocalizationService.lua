-------------------------------------------------------------------------------
-- Azeroth Companion
-- Localization Service
--
-- Loads locale tables, detects the game client's locale, supports a
-- manual language override, and exposes a single Get/Format API.
-- Gameplay modules and UI code never touch a locale table directly --
-- everything goes through AC.L:Get(key) / AC.L:Format(key, ...).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local GetLocale = GetLocale

local LocalizationService =
{
    Name = "LocalizationService",
}

AC.LocalizationService = LocalizationService
AC.L = LocalizationService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local FALLBACK_LOCALE = "enUS"

local SUPPORTED_LOCALES =
{
    "enUS", "deDE", "esES", "esMX", "frFR", "itIT",
    "koKR", "ptBR", "ruRU", "zhCN", "zhTW",
}

local Defaults =
{
    language = "auto",
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function LocalizationService:ResetState()

    self.Locales = {}
    self.ActiveLocale = FALLBACK_LOCALE

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function LocalizationService:Initialize()

    self:ResetState()

    for _, localeCode in ipairs(SUPPORTED_LOCALES) do
        self.Locales[localeCode] = (AC.Locales and AC.Locales[localeCode]) or {}
    end

    AC.ConfigurationManager:Register("Localization", Defaults)

    self:RefreshActiveLocale()

    -----------------------------------------------------------------------
    -- Language Setting
    --
    -- Language endonyms (Deutsch, Español, ...) are intentionally left
    -- as literal strings rather than routed through Get() -- a language
    -- picker conventionally names each language in its own script,
    -- regardless of the currently active display language.
    -----------------------------------------------------------------------

    AC.Settings:RegisterPage("General",
    {
        title = self:Get("Settings.General"),
        module = "Localization",
        order = 0,
    })

    AC.Settings:RegisterSection("General", "Language",
    {
        title = self:Get("Settings.Language"),
    })

    AC.Settings:AddDropdown("General", "Language",
    {
        key = "language",
        default = "auto",
        tooltip = self:Get("Settings.LanguageTooltip"),
        list =
        {
            { text = self:Get("Settings.LanguageAutomatic"), value = "auto" },
            { text = "English", value = "enUS" },
            { text = "Deutsch", value = "deDE" },
            { text = "Español", value = "esES" },
            { text = "Français", value = "frFR" },
            { text = "Italiano", value = "itIT" },
            { text = "Português (Brasil)", value = "ptBR" },
            { text = "Русский", value = "ruRU" },
            { text = "한국어", value = "koKR" },
            { text = "简体中文", value = "zhCN" },
            { text = "繁體中文", value = "zhTW" },
        },
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function LocalizationService:Enable()

    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function LocalizationService:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function LocalizationService:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function LocalizationService:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Localization" then
        return
    end

    if key ~= "language" then
        return
    end

    self:RefreshActiveLocale()

end

-------------------------------------------------------------------------------
-- Locale Resolution
-------------------------------------------------------------------------------

function LocalizationService:RefreshActiveLocale()

    local override = AC.ConfigurationManager and AC.ConfigurationManager:GetValue("Localization", "language")

    local localeCode

    if override and override ~= "auto" then
        localeCode = override
    else
        localeCode = (GetLocale and GetLocale()) or FALLBACK_LOCALE
    end

    if not self.Locales[localeCode] then
        localeCode = FALLBACK_LOCALE
    end

    self.ActiveLocale = localeCode

end

function LocalizationService:GetActiveLocale()

    return self.ActiveLocale

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function LocalizationService:Get(key)

    if type(key) ~= "string" or key == "" then
        return ""
    end

    local activeTable = self.Locales[self.ActiveLocale]

    if activeTable and activeTable[key] ~= nil then
        return activeTable[key]
    end

    local fallbackTable = self.Locales[FALLBACK_LOCALE]

    if fallbackTable and fallbackTable[key] ~= nil then
        return fallbackTable[key]
    end

    return string.format("<Missing: %s>", key)

end

function LocalizationService:Format(key, ...)

    local template = self:Get(key)

    local ok, result = pcall(string.format, template, ...)

    if ok then
        return result
    end

    return template

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("LocalizationService", LocalizationService)

return LocalizationService
