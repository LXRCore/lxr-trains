# Changelog

## 3.0.0 — 2026-09-19
* Ticket offices are lxr-interact cards instead of native prompts.
* LXRCore v3 release line: every resource ships as 3.0.0 from here (the entries below are the road to it).

## 1.0.2 — 2026-09-19
* RDR3 native: the host keeps its train through `PREVENT_NETWORK_ID_MIGRATION` — `SetNetworkIdCanMigrate` is GTA V only and was a nil call on every train spawn.

## 1.0.1 — 2026-09-17
* Managed trains are pinned to their host (`Config.Managed.pinOwnership`): no OneSync migration, which on current builds teleports a train to the first track node and drops its carriages. Lost control or a shrunken consist hands the line back for a clean respawn.
 — lxr-trains

## [1.0.0] — 2026-09-17
### Added
- Ambient rail traffic + trolley switch (`Config.Ambient`).
- Server-managed lines with host hand-over, station stops, whistles, blips, robbery hook.
- Stations, tickets (`train_ticket` catalog item), refunds, fast travel, boarding checks.
- Locales en/ka, admin `/train` command, security rate limits and host validation.
