# Azeroth Companion — Working Instructions

World of Warcraft Retail addon, Interface 120007. The framework (Service Manager, Module Manager, Event Manager, Database Service, Localization, Developer Panel, Runtime Diagnostics, Error Capture, Secret Value system, Recommendation Engine, Insight Engine, Dashboard, Inspector, Player Journal, and the Character/Inventory/Accomplishments/Mythic+ modules) is considered stable. **Assume it is stable unless proven otherwise** — don't re-litigate framework decisions while working a UI/polish task.

## Current phase

Product Polish, UX, and Information Architecture. The goal is not adding features — it's making the addon feel like a Blizzard-quality system: one purpose per screen, one owner per fact, one explanation per recommendation, consistent layout, reusable components, obvious navigation, minimal visual noise.

The addon's architectural rules — including the design principles this phase runs on (One Fact One Home, Progressive Disclosure, Screen Ownership, Shared Components over Page Fixes, Simplicity over Density) — live in `docs/GameplayModuleArchitecture.md` Section 3. That document is the single source of truth for those rules; don't restate or fork them here.

## Required workflow for any UI/architecture change

Do not write code first. For every requested change, work through this in order and share the results before implementing:

1. Audit the current design.
2. Identify the real problem (not just the symptom described).
3. Explain why the current design evolved the way it did.
4. Identify duplicated information.
5. Identify duplicated widgets.
6. Identify duplicated layout code.
7. Identify unnecessary visual noise.
8. Look for shared-component opportunities.
9. Explain the architectural fix.
10. Identify affected files.
11. Identify affected shared systems.
12. Explain regression risk.
13. Only then implement.

For work that spans many findings at once, reprioritize before implementing: score candidates by player impact, architectural simplicity, risk of regression, shared-infrastructure benefit, and amount of code deletable, then propose a phased plan and wait for sign-off before starting Phase 1. Don't implement an entire roadmap in one pass unless told to.

## Implementation priorities

Prefer, in this order: deleting code, simplifying layouts, consolidating widgets, reducing duplication, improving consistency. Only after those are exhausted: adding features, adding settings, adding information, adding visual complexity. A feature that no longer earns its screen space should be proposed for deletion, not expansion.

## Runtime verification standard

Static analysis and code review are useful for finding *candidate* issues, but the WoW client is the only source of truth on actual runtime behavior. Never claim something is confirmed to work, fixed, or verified in-game unless it was actually run and observed — say what was checked statically vs. what still needs a live client check, and don't blur the two.

## Mindset

Approach requests as a senior software architect, product designer, UX designer, and Blizzard UI engineer would — not as a request-implementer. Challenge assumptions: if a cleaner architecture exists, say so before building the one that was asked for; if a feature should be deleted rather than expanded, say so; if a service should own something instead of a page (or vice versa), explain why. The addon should be easier to use after every change, not simply more capable.
