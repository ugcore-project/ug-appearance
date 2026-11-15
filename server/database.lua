--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- ug_appearances and ug_outfits through oxmysql. Prepared queries only. Failures are logged and never raise.
-- Every call MUST run in a thread.

---@class UgAp.Internal.Database
local Database = {}
UgAp.Internal.Database = Database

local Logger = UgCore.Logger

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `ug_appearances` (
        `character_id` INT UNSIGNED NOT NULL,
        `appearance` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`character_id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `ug_outfits` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `character_id` INT UNSIGNED NOT NULL,
        `name` VARCHAR(32) NOT NULL,
        `outfit` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `character_id` (`character_id`)
    )]],
}

---@param fn fun(): any
---@param what string
---@return boolean ok
---@return any result
local function try(fn, what)
    local ok, result = pcall(fn)

    if not ok then
        Logger.Error('Database: %s failed: %s', what, tostring(result))

        return false, nil
    end

    return true, result
end

---@param text any
---@return table?
local function decode(text)
    if type(text) ~= 'string' then
        return nil
    end

    local ok, value = pcall(json.decode, text)

    return ok and type(value) == 'table' and value or nil
end

---Creates the tables when missing.
---@return boolean ok
function Database.Init()
    for _, statement in ipairs(TABLES) do
        local ok = try(function()
            return MySQL.query.await(statement)
        end, 'creating tables')

        if not ok then
            return false
        end
    end

    return true
end

---@param characterId integer
---@return boolean ok
---@return UgApAppearance? appearance nil when none is saved
function Database.Get(characterId)
    local ok, row = try(function()
        return MySQL.single.await('SELECT `appearance` FROM `ug_appearances` WHERE `character_id` = ?', { characterId })
    end, 'reading an appearance')

    if not ok then
        return false, nil
    end

    return true, row and decode(row.appearance) or nil
end

---@param characterIds integer[] at most 32
---@return boolean ok
---@return table<integer, UgApAppearance> appearances
function Database.GetMany(characterIds)
    if #characterIds == 0 then
        return true, {}
    end

    local marks = ('?,'):rep(#characterIds):sub(1, -2)
    local ok, rows = try(function()
        return MySQL.query.await(('SELECT `character_id`, `appearance` FROM `ug_appearances` WHERE `character_id` IN (%s)'):format(marks), characterIds)
    end, 'reading appearances')

    local result = {}

    if not ok then
        return false, result
    end

    for _, row in ipairs(rows or {}) do
        result[row.character_id] = decode(row.appearance)
    end

    return true, result
end

---@param characterId integer
---@param appearance UgApAppearance
---@return boolean ok
function Database.Set(characterId, appearance)
    return (try(function()
        return MySQL.prepare.await(
            'INSERT INTO `ug_appearances` (`character_id`, `appearance`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `appearance` = VALUES(`appearance`)',
            { characterId, json.encode(appearance) }
        )
    end, 'saving an appearance'))
end

---@class UgApOutfit
---@field id integer
---@field name string
---@field components table<string, UgApAppearancePart>
---@field props table<string, UgApAppearancePart>

---@param characterId integer
---@return boolean ok
---@return UgApOutfit[] outfits oldest first
function Database.ListOutfits(characterId)
    local ok, rows = try(function()
        return MySQL.query.await('SELECT `id`, `name`, `outfit` FROM `ug_outfits` WHERE `character_id` = ? ORDER BY `id`', {
            characterId,
        })
    end, 'reading outfits')

    local list = {}

    if not ok then
        return false, list
    end

    for _, row in ipairs(rows or {}) do
        local outfit = decode(row.outfit)

        if outfit then
            list[#list + 1] = {
                id = row.id,
                name = row.name,
                components = outfit.components or {},
                props = outfit.props or {},
            }
        end
    end

    return true, list
end

---@param characterId integer
---@param name string
---@param outfit { components: table, props: table }
---@return boolean ok
---@return integer? id
function Database.AddOutfit(characterId, name, outfit)
    local ok, id = try(function()
        return MySQL.insert.await('INSERT INTO `ug_outfits` (`character_id`, `name`, `outfit`) VALUES (?, ?, ?)', {
            characterId, name, json.encode({
                components = outfit.components,
                props = outfit.props,
            }),
        })
    end, 'saving an outfit')

    return ok and id ~= nil, id
end

---Renames an outfit. The caller checks that the character owns it.
---@param characterId integer
---@param outfitId integer
---@param name string
---@return boolean ok
function Database.RenameOutfit(characterId, outfitId, name)
    local ok = try(function()
        return MySQL.update.await('UPDATE `ug_outfits` SET `name` = ? WHERE `id` = ? AND `character_id` = ?', {
            name,
            outfitId,
            characterId,
        })
    end, 'renaming an outfit')

    return ok
end

---Replaces the clothing of an outfit. The caller checks that the character owns it.
---@param characterId integer
---@param outfitId integer
---@param outfit { components: table, props: table }
---@return boolean ok
function Database.ReplaceOutfit(characterId, outfitId, outfit)
    local ok = try(function()
        return MySQL.update.await('UPDATE `ug_outfits` SET `outfit` = ? WHERE `id` = ? AND `character_id` = ?', {
            json.encode({
                components = outfit.components,
                props = outfit.props,
            }), outfitId, characterId,
        })
    end, 'replacing an outfit')

    return ok
end

---@param characterId integer
---@param outfitId integer
---@return boolean ok
---@return boolean deleted false when the character has no such outfit
function Database.DeleteOutfit(characterId, outfitId)
    local ok, affected = try(function()
        return MySQL.update.await('DELETE FROM `ug_outfits` WHERE `id` = ? AND `character_id` = ?', {
            outfitId,
            characterId,
        })
    end, 'deleting an outfit')

    return ok, ok and (affected or 0) > 0
end
