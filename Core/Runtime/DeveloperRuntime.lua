-------------------------------------------------------------------------------
-- Azeroth Companion
-- Developer Runtime
--
-- The long-lived host for developer-facing runtime tooling -- Error Capture
-- is the first capability; Warning Capture, Runtime Diagnostics, Performance
-- Metrics, Verification Results, Event Statistics, and Export Tools are
-- expected to follow as their own self-contained capability files, each
-- registering here the same way Services register with ServiceManager and
-- Modules register with ModuleManager. This file owns none of their data --
-- only the shared plumbing every capability would otherwise reimplement on
-- its own: the capability registry itself, Developer Mode integration
-- (install/remove wired to AC.DeveloperModeService's DEVELOPER_MODE_CHANGED
-- event, never a dependency the other direction), and combat-aware update
-- notification (so "don't disrupt gameplay in combat" is a Runtime-level
-- guarantee, not something each capability reimplements separately).
--
-- Ownership boundary: Developer Runtime owns captured developer data and
-- runtime diagnostics (via its capabilities). Developer Mode
-- (DeveloperModeService) owns only the enable/disable flag -- this file
-- reads it through the existing public IsEnabled() getter, never mutates
-- it, never duplicates it, and DeveloperModeService never needs to know
-- this file exists (identical to how it already doesn't know DeveloperPanel
-- exists). Developer Panel owns presentation; nothing here renders
-- anything. Logger stays log-only; this file may call AC.Logger:Debug/Error
-- to note its own activity, exactly as DeveloperModeService already does,
-- but never treats Logger as a data store.
--
-- Capability contract (all optional except Name, set automatically by
-- RegisterCapability):
--   { Name = "ErrorCapture",
--     Initialize = function(self) end,  -- called once at framework boot, resets internal state
--     Install    = function(self) end,  -- called when Developer Mode turns on
--     Remove     = function(self) end } -- called when Developer Mode turns off
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DeveloperRuntime =
{
    Name = "DeveloperRuntime",
}

AC.DeveloperRuntime = DeveloperRuntime

-------------------------------------------------------------------------------
-- Capability Registry
--
-- Same "ordered array + name-keyed lookup" idiom ServiceManager/
-- ModuleManager already use. Capabilities self-register at their own
-- file's bottom -- this file must load first in the .toc, the same
-- load-order contract every other Manager/registrant pair in this
-- codebase already follows.
-------------------------------------------------------------------------------

DeveloperRuntime.Capabilities = {}
DeveloperRuntime.CapabilityOrder = {}

function DeveloperRuntime:RegisterCapability(name, capability)

    assert(type(name) == "string", "Developer Runtime capability name must be a string.")
    assert(type(capability) == "table", "Developer Runtime capability must be a table.")

    if self.Capabilities[name] then
        error(("Developer Runtime capability '%s' is already registered."):format(name))
    end

    capability.Name = name

    self.Capabilities[name] = capability
    table.insert(self.CapabilityOrder, capability)

end

function DeveloperRuntime:GetCapability(name)

    return self.Capabilities[name]

end

function DeveloperRuntime:GetCapabilities()

    return self.CapabilityOrder

end

-------------------------------------------------------------------------------
-- Combat-Aware Update Notification
--
-- Current combat state is never cached -- InCombatLockdown() is cheap and
-- always current, so IsInCombat() just wraps it (a documented, named entry
-- point rather than every capability needing to know the raw Blizzard
-- global). PLAYER_REGEN_ENABLED is the one thing that genuinely needs a
-- registered listener -- detecting the MOMENT combat ends, to flush
-- whatever capabilities queued an update while it was unsafe to disturb
-- the player. Installed/removed symmetrically with Developer Mode, never
-- running while it's off.
-------------------------------------------------------------------------------

function DeveloperRuntime:IsInCombat()

    return InCombatLockdown() == true

end

function DeveloperRuntime:NotifyUpdate(capabilityName)

    if self:IsInCombat() then

        self.PendingUpdates[capabilityName] = true

        if AC.Logger then
            AC.Logger:Debug(("Developer Runtime: update from '%s' queued (in combat)."):format(capabilityName), "Framework")
        end

        return

    end

    if AC.Logger then
        AC.Logger:Debug(("Developer Runtime: firing DEVELOPER_RUNTIME_UPDATED for '%s'."):format(capabilityName), "Framework")
    end

    AC.Events:Fire("DEVELOPER_RUNTIME_UPDATED", capabilityName)

end

function DeveloperRuntime:OnPlayerRegenEnabled()

    for capabilityName in pairs(self.PendingUpdates) do

        if AC.Logger then
            AC.Logger:Debug(("Developer Runtime: flushing queued update for '%s' (combat ended)."):format(capabilityName), "Framework")
        end

        AC.Events:Fire("DEVELOPER_RUNTIME_UPDATED", capabilityName)

    end

    self.PendingUpdates = {}

end

-------------------------------------------------------------------------------
-- Developer Mode Integration
--
-- Reacts to AC.DeveloperModeService's own DEVELOPER_MODE_CHANGED event.
-- Each capability decides for itself (inside its own Install()) whether
-- its own sub-setting is on; this file's job is only to call
-- Install()/Remove() at the right moment, never to know what any
-- individual capability's settings mean. Every call is pcall-isolated --
-- one misbehaving capability can never block another's install/remove,
-- matching this subsystem's own "never a single point of failure" rule.
-------------------------------------------------------------------------------

local function SafeCall(capability, methodName)

    local method = capability[methodName]

    if not method then
        return
    end

    local ok, err = pcall(method, capability)

    if not ok and AC.Logger then
        AC.Logger:Error(("Developer Runtime capability '%s' failed during %s(): %s"):format(capability.Name or "?", methodName, tostring(err)))
    end

end

function DeveloperRuntime:OnDeveloperModeChanged(enabled)

    if enabled then

        AC.Events:Register("PLAYER_REGEN_ENABLED", self, "OnPlayerRegenEnabled")

        for _, capability in ipairs(self.CapabilityOrder) do
            SafeCall(capability, "Install")
        end

    else

        for _, capability in ipairs(self.CapabilityOrder) do
            SafeCall(capability, "Remove")
        end

        AC.Events:Unregister("PLAYER_REGEN_ENABLED", self, "OnPlayerRegenEnabled")

    end

end

-------------------------------------------------------------------------------
-- Initialize
--
-- Registered in Initialize() (not Enable()) so this listener is guaranteed
-- active before DeveloperModeService:Enable() (which restores the
-- persisted flag and fires DEVELOPER_MODE_CHANGED) runs -- ServiceManager
-- completes a full Initialize() pass over every service before its own
-- Enable() pass begins, so this ordering holds regardless of .toc order
-- between the two files.
-------------------------------------------------------------------------------

function DeveloperRuntime:Initialize()

    self.PendingUpdates = {}

    AC.Events:Register("DEVELOPER_MODE_CHANGED", self, "OnDeveloperModeChanged")

    for _, capability in ipairs(self.CapabilityOrder) do
        SafeCall(capability, "Initialize")
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("DeveloperRuntime", DeveloperRuntime)

return DeveloperRuntime
