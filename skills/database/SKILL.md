---
name: database
description: Store and read data in MySQL from a UgCore resource through oxmysql. Use when a feature needs to persist data across restarts, such as owned items, records or cooldowns.
---

# Database

ug-core's own database layer is internal. Feature resources use oxmysql directly, the way ug-appearance does in
`ug-appearance/server/database.lua`. Read that file first.

## Setup

```lua
-- fxmanifest.lua
dependencies { '/onesync', 'ug-core', 'ug-lib', 'oxmysql' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/database.lua',
    -- ...
    'server/boot.lua',
}
```

## Rules

- One file, `server/database.lua`, `UgAp.Internal.Database`. Nothing else calls `MySQL`.
- Prepared statements only: `?` placeholders with a params array. Never concatenate values into SQL.
  The only exception is an `IN (?, ?, ?)` list built from the count of validated ids, as ug-appearance's `GetMany`.
- Every call runs in a thread (`MySQL.*.await` yields). Never call it from a NUI callback or key handler directly.
- Wrap each call in `pcall`, log failures with `UgCore.Logger.Error`, return `ok, result`. Never raise to the caller.
- Tables are prefixed with the resource, `ug_<name>_...` or your own prefix. Create them at boot with
  `CREATE TABLE IF NOT EXISTS`, after `UgCore.Lifecycle.Await(Ready)`. Abort boot when it fails.
- Key rows by `characterId` (from `UgCore.Players.Get(source).characterId`), not by source or license, unless the
  data belongs to the player across characters.
- Store structured data as JSON in `LONGTEXT`: MySQL and MariaDB return the `JSON` type differently.
- Decode stored JSON through a schema too. A row edited by hand is input.
- Every `UPDATE` and `DELETE` of player data includes `AND character_id = ?`, so one player can never touch another's.
- Money never lives in your tables. Use `UgCore.Accounts`.

## Shape

```lua
---@param fn fun(): any
---@param what string
---@return boolean ok
---@return any result
local function try(fn, what)
    local ok, result = pcall(fn)

    if not ok then
        UgCore.Logger.Error('Database: %s failed: %s', what, tostring(result))

        return false, nil
    end

    return true, result
end

---@param characterId integer
---@param outfitId integer
---@param name string
---@return boolean ok
function Database.RenameOutfit(characterId, outfitId, name)
    local ok = try(function()
        return MySQL.update.await('UPDATE `ug_outfits` SET `name` = ? WHERE `id` = ? AND `character_id` = ?', { name, outfitId, characterId })
    end, 'renaming an outfit')

    return ok
end
```

Use `os.time()` (Unix seconds) for times that survive restarts. `GetGameTimer()` restarts with the server.

## Tests

Mock `MySQL` in `tests/helpers.lua` with in-memory rows, as ug-appearance's helpers do (`H.Rows`, `H.FailWrite`).
Test a failed write: the feature MUST undo what it changed and answer `internal_error`.

## Docs

- https://ugcore.urging.ch/owners/database
