--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Saved outfits and uniforms. They need a clothing, wardrobe or admin session, and only ever use the saved
-- appearance, so an unpaid preview cannot become a free outfit.

---@class UgAp.Internal.Outfits
local Outfits = {}
UgAp.Internal.Outfits = Outfits

local Config = UgAp.Internal.Config
local Database = UgAp.Internal.Database
local Sessions = UgAp.Internal.Sessions
local Appearance = UgAp.Internal.Appearance
local Schema = UgCore.Schema
local Errors = UgCore.Enums.Errors
local Kind = UgAp.Enums.StoreKind
local fail = Sessions.Fail

local WARDROBE_KINDS = {
    [Kind.Clothing] = true,
    [Kind.Wardrobe] = true,
    [Kind.Admin] = true,
}

---@param source integer
---@return boolean ok
---@return UgApAppearance? appearance
---@return integer? characterId
---@return UgErrorCode? errorCode
local function wardrobe(source)
    local session = Sessions.Get(source)

    if not session or not WARDROBE_KINDS[session.kind] then
        return false, nil, nil, Errors.NoPermission
    end

    local ok, appearance, characterId = Sessions.Saved(source)

    if not ok then
        return false, nil, nil, Errors.NotLoaded
    end

    return true, appearance, characterId, nil
end

---@param characterId integer
---@return table
local function listOf(characterId)
    local ok, outfits = Database.ListOutfits(characterId)

    if not ok then
        return fail(Errors.InternalError)
    end

    return {
        ok = true,
        outfits = outfits,
    }
end

---Saves the saved clothing and accessories as a named outfit.
---@param source integer
---@param name string
---@return table
function Outfits.Save(source, name)
    local ok, appearance, characterId, errorCode = wardrobe(source)

    if not ok or not appearance or not characterId then
        return fail(errorCode or Errors.NotLoaded)
    end

    local read, outfits = Database.ListOutfits(characterId)

    if not read then
        return fail(Errors.InternalError)
    end

    if #outfits >= Config.Get().maxOutfits then
        return fail(Errors.NoPermission)
    end

    if not Database.AddOutfit(characterId, name, appearance) then
        return fail(Errors.InternalError)
    end

    return listOf(characterId)
end

---Wears a saved outfit for free.
---@param source integer
---@param outfitId integer
---@return table
function Outfits.Wear(source, outfitId)
    local ok, appearance, characterId, errorCode = wardrobe(source)

    if not ok or not appearance or not characterId then
        return fail(errorCode or Errors.NotLoaded)
    end

    local read, outfits = Database.ListOutfits(characterId)

    if not read then
        return fail(Errors.InternalError)
    end

    for _, outfit in ipairs(outfits) do
        if outfit.id == outfitId then
            -- Outfits written by older versions MAY miss parts: the schema keeps garbage out of the saved row.
            local checked, clean = Schema.Check(Appearance.PartialOutfitRule, {
                components = outfit.components,
                props = outfit.props,
            })

            if not checked then
                return fail(Errors.InternalError)
            end

            local worn = Appearance.Wear(appearance, clean)

            if not Sessions.Store(source, characterId, worn) then
                return fail(Errors.InternalError)
            end

            return {
                ok = true,
                appearance = worn,
            }
        end
    end

    return fail(Errors.NotFound)
end

---Runs `write` on an outfit the player's character owns, then answers the new list.
---Ownership is checked first: MySQL MAY report 0 affected rows for an update that changes nothing.
---@param source integer
---@param outfitId integer
---@param write fun(characterId: integer, appearance: UgApAppearance): boolean
---@return table
local function change(source, outfitId, write)
    local ok, appearance, characterId, errorCode = wardrobe(source)

    if not ok or not appearance or not characterId then
        return fail(errorCode or Errors.NotLoaded)
    end

    local read, outfits = Database.ListOutfits(characterId)

    if not read then
        return fail(Errors.InternalError)
    end

    for _, outfit in ipairs(outfits) do
        if outfit.id == outfitId then
            if not write(characterId, appearance) then
                return fail(Errors.InternalError)
            end

            return listOf(characterId)
        end
    end

    return fail(Errors.NotFound)
end

---Replaces an outfit with the saved clothing and accessories.
---@param source integer
---@param outfitId integer
---@return table
function Outfits.Replace(source, outfitId)
    return change(source, outfitId, function(characterId, appearance)
        return Database.ReplaceOutfit(characterId, outfitId, appearance)
    end)
end

---@param source integer
---@param outfitId integer
---@param name string
---@return table
function Outfits.Rename(source, outfitId, name)
    return change(source, outfitId, function(characterId)
        return Database.RenameOutfit(characterId, outfitId, name)
    end)
end

---@param source integer
---@param outfitId integer
---@return table
function Outfits.Delete(source, outfitId)
    local ok, _, characterId, errorCode = wardrobe(source)

    if not ok or not characterId then
        return fail(errorCode or Errors.NotLoaded)
    end

    local written, deleted = Database.DeleteOutfit(characterId, outfitId)

    if not written then
        return fail(Errors.InternalError)
    end

    if not deleted then
        return fail(Errors.NotFound)
    end

    return listOf(characterId)
end

---Wears a uniform of the player's job or gang for free. `index` is the position in the list the session sent.
---@param source integer
---@param index integer
---@return table
function Outfits.WearUniform(source, index)
    local ok, appearance, characterId, errorCode = wardrobe(source)

    if not ok or not appearance or not characterId then
        return fail(errorCode or Errors.NotLoaded)
    end

    local uniform = Sessions.Uniforms(source, appearance.model)[index]

    if not uniform then
        return fail(Errors.NotFound)
    end

    local worn = Appearance.Wear(appearance, uniform.outfit)

    if not Sessions.Store(source, characterId, worn) then
        return fail(Errors.InternalError)
    end

    return {
        ok = true,
        appearance = worn,
    }
end

---Registers the callbacks. Runs once after a clean boot.
function Outfits.Register()
    local Callback = UgCore.Callback
    local ID = Schema.Integer({
        min = 1,
        max = 2147483647,
    })
    local rate = {
        max = 5,
        per = 10000,
    }

    local NAME = Schema.String({
        min = 1,
        max = 32,
    })

    Callback.Register('SaveOutfit', {
        schema = Schema.Define({ NAME }),
        rate = rate,
        requirePlayer = true,
    }, Outfits.Save)

    Callback.Register('WearOutfit', {
        schema = Schema.Define({ ID }),
        rate = rate,
        requirePlayer = true,
    }, Outfits.Wear)
    Callback.Register('DeleteOutfit', {
        schema = Schema.Define({ ID }),
        rate = rate,
        requirePlayer = true,
    }, Outfits.Delete)
    Callback.Register('ReplaceOutfit', {
        schema = Schema.Define({ ID }),
        rate = rate,
        requirePlayer = true,
    }, Outfits.Replace)
    Callback.Register('RenameOutfit', {
        schema = Schema.Define({ ID, NAME }),
        rate = rate,
        requirePlayer = true,
    }, Outfits.Rename)

    Callback.Register('WearUniform', {
        schema = Schema.Define({
            Schema.Integer({
                min = 1,
                max = 100,
            }),
        }),
        rate = rate,
        requirePlayer = true,
    }, Outfits.WearUniform)
end
