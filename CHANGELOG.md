# Changelog

## 1.0.1 — 2026-09-17
* Managed trains are pinned to their host (`Config.Managed.pinOwnership`): no OneSync migration, which on current builds teleports a train to the first track node and drops its carriages. Lost control or a shrunken consist hands the line back for a clean respawn.
 — lxr-trains

## [1.0.0] — 2026-09-17
### Added
- Ambient rail traffic + trolley switch (`Config.Ambient`).
- Server-managed lines with host hand-over, station stops, whistles, blips, robbery hook.
- Stations, tickets (`train_ticket` catalog item), refunds, fast travel, boarding checks.
- Locales en/ka, admin `/train` command, security rate limits and host validation.
