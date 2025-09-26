# Arena Switching

This document describes how the arena switching feature works.

## Overview
Players can open the Edit Arena UI (by touching the "Edit Arena" object on their arena) and press a `SwitchArenaButton` inside frames such as `GrassArenaFrame` or `VolcanicArenaFrame`. Clicking one of these buttons requests the server to swap the player's current arena to the selected theme **without removing their existing units**.

## Flow
1. Client clicks SwitchArenaButton.
2. Client fires RemoteEvent `SwitchArena` with the requested arena template name.
3. Server validates the template exists in `ReplicatedStorage.Arenas`.
4. Server updates `PlayerData.selectedArenaName` and calls `ArenaSpawner:switchArenaForPlayer`.
5. `ArenaSpawner` clones the new template, positions it where the old arena was, transfers unit models from matching Hex_*_* and Bench_* parts, rebinds the Edit Arena interaction, and destroys the old arena.
6. Server re-sends updated player data so client can update checkmark UI.
7. Client displays a green checkmark on the selected arena frame.

## Adding New Arenas
1. Add your new arena model under `ReplicatedStorage/Arenas` and ensure its name ends with `Arena` (e.g., `Ice Arena`).
2. Make sure it contains the same board hex part naming pattern `Hex_<row>_<col>` and bench parts `Bench_<index>` so unit transfer works.
3. Optional: Include an `Edit Arena` part/model for opening the Edit UI.
4. In the EditArenaFrame, add a new Frame (e.g., `IceArenaFrame`) with a `SwitchArenaButton` and set an `ArenaName` attribute (recommended) to the exact arena model name.

## UI Checkmark Logic
The client caches all frames under `EditArenaFrame` whose name contains `ArenaFrame` and attaches click handlers. When player data updates arrive, the client calls `UI.updateArenaSelection(selectedArenaName)` which:
- Removes any existing checkmark (`SelectedArenaMark`)
- Adds a green checkmark to the matching frame (match is by `ArenaName` attribute or frame name minus trailing `Frame`).

## Server-Side Validation
The server ignores invalid arena names (missing templates) and prints a warning. No change occurs.

## Edge Cases
- If player selects the same arena they already have, server returns early (no duplication or flicker).
- If unit parts/hex names don't match in new arena, affected units will not move (they remain unparented); verify templates for consistency.
- If `Arenas` folder or template is removed, switching logs a warning and aborts gracefully.

## Future Improvements
- Explicit success/failure response to client to show error UI.
- Animation or fade transition when swapping arenas.
- Persist per-arena cosmetics beyond board (e.g., ambient lighting customization).

---
Last updated: 2025-09-18
