-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Tags
--
-- The preset personal-tag list every Player Journal record can be tagged
-- with, plus an empty CustomTags extension point for a future "add your
-- own tag" feature. A leaf file (no dependencies) loaded before
-- PlayerJournalModule.lua and every UI/tooltip file that needs to render
-- or offer these tags, so none of them have a load-order dependency on
-- each other for this list.
--
-- "Favorite Player" is one of these tags, not a separate boolean field
-- anywhere -- PlayerJournalModule:IsFavorite(key) is defined as
-- record.tags["FavoritePlayer"] == true. This is the one source of truth
-- the context-menu checkbox, the tooltip glyph, and the Personal Tags
-- tab all read and write; storing a second, independent favorite flag
-- alongside this tag would let the two desync.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalTags = {}
AC.PlayerJournalTags = PlayerJournalTags

-------------------------------------------------------------------------------
-- Preset Tags
--
-- Ordered list (display order), each a { id, labelKey } pair. `id` is the
-- stable key stored in a record's `tags` table; `labelKey` is resolved
-- through AC.L:Get() wherever a tag is displayed, never hardcoded English.
-------------------------------------------------------------------------------

PlayerJournalTags.PRESET_TAGS =
{
    { id = "Friendly", labelKey = "PlayerJournal.TagFriendly" },
    { id = "Patient", labelKey = "PlayerJournal.TagPatient" },
    { id = "Reliable", labelKey = "PlayerJournal.TagReliable" },
    { id = "GreatLeader", labelKey = "PlayerJournal.TagGreatLeader" },
    { id = "GoodCommunication", labelKey = "PlayerJournal.TagGoodCommunication" },
    { id = "GreatTeacher", labelKey = "PlayerJournal.TagGreatTeacher" },
    { id = "GoodTank", labelKey = "PlayerJournal.TagGoodTank" },
    { id = "GoodHealer", labelKey = "PlayerJournal.TagGoodHealer" },
    { id = "GoodDPS", labelKey = "PlayerJournal.TagGoodDPS" },
    { id = "GoodInterrupts", labelKey = "PlayerJournal.TagGoodInterrupts" },
    { id = "FavoritePlayer", labelKey = "PlayerJournal.TagFavoritePlayer" },
}

-- Real, but always empty this version -- a future "type your own tag"
-- feature would append here rather than needing a second list/mechanism.
PlayerJournalTags.CUSTOM_TAGS = {}

-------------------------------------------------------------------------------
-- Lookup
-------------------------------------------------------------------------------

local LABEL_KEY_BY_ID = {}

for _, tag in ipairs(PlayerJournalTags.PRESET_TAGS) do
    LABEL_KEY_BY_ID[tag.id] = tag.labelKey
end

function PlayerJournalTags:GetLabelKey(tagId)

    return LABEL_KEY_BY_ID[tagId]

end

function PlayerJournalTags:GetAllTags()

    local all = {}

    for _, tag in ipairs(self.PRESET_TAGS) do
        table.insert(all, tag)
    end

    for _, tag in ipairs(self.CUSTOM_TAGS) do
        table.insert(all, tag)
    end

    return all

end

return PlayerJournalTags
