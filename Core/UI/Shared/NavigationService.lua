-------------------------------------------------------------------------------
-- Azeroth Companion
-- Navigation Service
--
-- Ownership boundaries -- read this before adding anything navigation-
-- related anywhere else in the addon:
--
--   - AC.WindowManager owns window LIFETIME/VISIBILITY: raw Show/Hide/
--     Toggle/HideAll by frame name. It has no concept of history and never
--     will -- it answers "is this frame shown," not "how did we get here."
--
--   - AC.NavigationService (this file) owns the application's NAVIGATION
--     HISTORY: a single stack of NavigationEntry values describing where
--     the player has been, Push/Replace/GoBack/CanGoBack/Close, and the
--     one shared ESC/Back dispatch. It never renders anything itself --
--     it only ever asks the owning window controller to.
--
--   - Each window controller (Dashboard, PlayerJournalWindow, SettingsWindow,
--     DeveloperPanel, InventoryManager, DiagnosticsWindow,
--     ObservationDialog) owns RENDERING
--     and WORKING CONTEXT. It alone knows how to capture transient view
--     state via CaptureNavigation(entry), and turn a NavigationEntry back
--     into pixels via RestoreNavigation(entry). NavigationService never
--     reaches into a window's internals to do either itself.
--
--   - A NavigationEntry describes WHERE the player is (Window/View/Context)
--     -- never HOW to get there. No closures, no callbacks stored on the
--     stack. This is what makes the stack inspectable/loggable/
--     visualizable (a future Developer Panel tab, analytics, telemetry)
--     instead of a list of anonymous functions nobody can look inside.
--
-- Rule of thumb for future work: deciding "what happens when the player
-- goes back" belongs here. Deciding "how does this specific screen look"
-- belongs on the owning window's own RestoreNavigation. Deciding "is any
-- Azeroth Companion window currently visible" belongs on WindowManager.
--
-- Exactly one AC window is ever visible at a time under this model --
-- every Push/GoBack hides everything (AC.WindowManager:HideAll()) before
-- showing the entry that's now on top. This is deliberate: "going back"
-- should always feel like returning to the one thing that was there
-- before, never like juggling several overlapping windows.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local NavigationService = {}
AC.NavigationService = NavigationService

-------------------------------------------------------------------------------
-- Identifiers
--
-- Named constants instead of raw string literals scattered at every call
-- site -- a typo in a bare "PlayerJourna" string fails silently (falls
-- through every branch, does nothing); a typo referencing
-- Windows.PlayerJourna is a nil-index error at the call site itself.
--
-- Window ids are hand-declared here -- there is no pre-existing list of
-- "every standalone window" anywhere else in the addon to derive them
-- from. View ids are deliberately NOT re-typed here -- Initialize() below
-- derives each window's Views table from that window's own already-
-- existing canonical list (Dashboard's VALID_PAGES, Player Journal's
-- TABS, ...), so there remains exactly one place that actually enumerates
-- a given window's screens.
-------------------------------------------------------------------------------

NavigationService.Windows =
{
    Dashboard = "Dashboard",
    PlayerJournal = "PlayerJournal",
    Settings = "Settings",
    DeveloperPanel = "DeveloperPanel",
    InventoryManager = "InventoryManager",
    Diagnostics = "Diagnostics",
    ObservationDialog = "ObservationDialog",
}

NavigationService.Views =
{
    Dashboard = {},
    PlayerJournal = {},
    Settings = { Root = "Root" },
    DeveloperPanel = {},
    InventoryManager = {},
    Diagnostics = { Log = "Log" },

    -- Only one view exists today -- hand-declared rather than derived
    -- since there is no list to derive it from (a single-purpose popup,
    -- not a tabbed/paged window).
    ObservationDialog = { AddObservation = "AddObservation" },
}

-------------------------------------------------------------------------------
-- Controller Registry
--
-- Maps a Windows.* id to the controller object whose RestoreNavigation(entry)
-- re-renders it. Deliberately separate from AC.WindowManager's own registry
-- (frame name -> raw Frame, used for blanket HideAll) -- these are two
-- different facts about the same window, not one duplicated: WindowManager
-- needs the Frame; this needs the object with the RestoreNavigation method.
-------------------------------------------------------------------------------

NavigationService.Controllers = {}

function NavigationService:RegisterWindow(windowId, controller)

    self.Controllers[windowId] = controller

end

-------------------------------------------------------------------------------
-- Stack
-------------------------------------------------------------------------------

NavigationService.Stack = {}
NavigationService.Suspended = false

local function NewEntry(windowId, viewId, context)

    return { Window = windowId, View = viewId, Context = context }

end

function NavigationService:CaptureCurrent()

    local entry = self.Stack[#self.Stack]
    local controller = entry and self.Controllers[entry.Window]

    if controller and controller.CaptureNavigation then
        controller:CaptureNavigation(entry)
    end

end

function NavigationService:Restore(entry)

    if not entry then
        return
    end

    local controller = self.Controllers[entry.Window]

    if controller and controller.RestoreNavigation then
        controller:RestoreNavigation(entry)
    end

end

-- Every genuine "go deeper" transition -- entering a window fresh, or a
-- real drill-down within one (a different player, a different record, a
-- modal dialog) -- calls this. Sibling view switches within an already-
-- open window (tabs, a page list) call Replace instead; see below.
function NavigationService:Push(windowId, viewId, context)

    self:CaptureCurrent()
    AC.WindowManager:HideAll()
    self.Suspended = false

    local entry = NewEntry(windowId, viewId, context)
    table.insert(self.Stack, entry)

    self:Restore(entry)
    self:UpdateKeyCapture()

end

-- Swaps the top entry in place instead of growing the stack -- what a
-- sibling tab/page click calls, so the stack's own record of "how to get
-- back here" stays accurate for a later cross-window GoBack, without
-- ordinary lateral tab-browsing ever becoming its own back-step.
function NavigationService:Replace(windowId, viewId, context)

    local entry = NewEntry(windowId, viewId, context)

    if #self.Stack == 0 then
        table.insert(self.Stack, entry)
    else
        self.Stack[#self.Stack] = entry
    end

end

function NavigationService:CanGoBack()

    return #self.Stack > 1

end

function NavigationService:IsOpen()

    return #self.Stack > 0 and not self.Suspended

end

function NavigationService:IsSuspended()

    return #self.Stack > 0 and self.Suspended

end

-- Temporarily hides the application without ending its navigation session.
-- Window controllers keep owning their rendered state; the stack keeps owning
-- the path back to it. This is the lifecycle used by an external launcher
-- toggle, where reopening must feel exactly like the window was never closed.
function NavigationService:Suspend()

    if not self:IsOpen() then
        return false
    end

    self:CaptureCurrent()
    AC.WindowManager:HideAll()
    self.Suspended = true
    self:UpdateKeyCapture()

    return true

end

function NavigationService:Resume()

    if not self:IsSuspended() then
        return false
    end

    self.Suspended = false
    AC.WindowManager:HideAll()
    self:Restore(self.Stack[#self.Stack])
    self:UpdateKeyCapture()

    return true

end

-- Shared by BaseWindow:AddCloseButton and any window's own Cancel-style
-- dismissal (ObservationDialog's Cancel/Save) -- "is this specific
-- controller what the stack currently has on top" answered once, so a
-- close/cancel action can safely GoBack() when true and fall back to a
-- plain Hide() when false (a window that was shown outside the navigation
-- system entirely, e.g. DiagnosticsWindow, or is otherwise not the
-- tracked current screen). Returns whether it actually navigated.
function NavigationService:GoBackIfCurrent(owner)

    if self:IsCurrent(owner) then
        self:GoBack()
        return true
    end

    return false

end

function NavigationService:IsCurrent(owner)

    local topEntry = self.Stack[#self.Stack]
    local topController = topEntry and self.Controllers[topEntry.Window]

    return topController ~= nil and topController == owner

end

-- The one function ESC and every Back button both call -- there is no
-- separate "else" branch duplicated at each caller for "nowhere left to
-- go." At the root, going back IS closing Azeroth Companion.
function NavigationService:GoBack()

    if not self:CanGoBack() then
        self:Close()
        return
    end

    table.remove(self.Stack)

    self.Suspended = false
    AC.WindowManager:HideAll()
    self:Restore(self.Stack[#self.Stack])

end

function NavigationService:Close()

    AC.WindowManager:HideAll()
    self.Stack = {}
    self.Suspended = false

    self:UpdateKeyCapture()

end

-------------------------------------------------------------------------------
-- ESC Capture
--
-- One dedicated, addon-wide keyboard listener -- shown whenever the stack
-- is non-empty (some Azeroth Companion window is open), hidden the moment
-- Close() empties it. A frame only receives OnKeyDown while it is shown,
-- which alone is what scopes this to "only while Azeroth Companion has
-- focus" -- no global key capture, nothing intercepted while every AC
-- window is closed. This replaces the hand-rolled EnableKeyboard/OnKeyDown
-- handler Dashboard used to run on its own frame -- there is now exactly
-- one ESC listener for the whole addon, not one per window.
-------------------------------------------------------------------------------

function NavigationService:UpdateKeyCapture()

    if not self.KeyCaptureFrame then
        return
    end

    if self:IsOpen() then
        self.KeyCaptureFrame:Show()
    else
        self.KeyCaptureFrame:Hide()
    end

end

-------------------------------------------------------------------------------
-- Initialize
--
-- Derives Views.* from each window's own already-existing canonical list.
-- Run at Initialize() (after every file has loaded, per ModuleManager),
-- not at file-load time -- those lists don't exist yet at the point this
-- file itself loads (Core/UI/Shared/ loads before Core/UI/Dashboard/ and
-- Core/UI/PlayerJournal/ by design, matching the ScrollFrame precedent).
-------------------------------------------------------------------------------

function NavigationService:Initialize()

    local frame = CreateFrame("Frame", "AzerothCompanionNavigationKeyCapture", UIParent)
    frame:EnableKeyboard(true)
    frame:Hide()

    frame:SetScript("OnKeyDown", function(_, key)

        if key == "ESCAPE" then
            NavigationService:GoBack()
            frame:SetPropagateKeyboardInput(false)
        else
            frame:SetPropagateKeyboardInput(true)
        end

    end)

    self.KeyCaptureFrame = frame

    if AC.DashboardLayout then

        for pageName in pairs(AC.DashboardLayout.VALID_PAGES) do
            self.Views.Dashboard[pageName] = pageName
        end

    end

    if AC.PlayerJournalWindow and AC.PlayerJournalWindow.Tabs then

        for _, tabName in ipairs(AC.PlayerJournalWindow.Tabs) do
            self.Views.PlayerJournal[tabName] = tabName
        end

    end

    if AC.DeveloperPanel and AC.DeveloperPanel.Tabs then

        for _, tabName in ipairs(AC.DeveloperPanel.Tabs) do
            self.Views.DeveloperPanel[tabName] = tabName
        end

    end

    if AC.InventoryManager and AC.InventoryManager.PageDefinitions then

        for _, definition in ipairs(AC.InventoryManager.PageDefinitions) do
            self.Views.InventoryManager[definition.id] = definition.id
        end

    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("NavigationService", NavigationService)

return NavigationService
