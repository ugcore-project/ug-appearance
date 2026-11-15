--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Appearance to natives, and what the game offers for a ped. Natives take native ids: names map through the enums.

---@class UgAp.Internal.Ped
local Ped = {}
UgAp.Internal.Ped = Ped

local Appearance = UgAp.Internal.Appearance
local same = Appearance.Same

local RESOURCE = GetCurrentResourceName()
local HAIR_COMPONENT = 2
local NO_OVERLAY = 255
-- Freemode tattoo character types of GET_NUM_TATTOO_SHOP_DLC_ITEMS.
local TATTOO_MALE, TATTOO_FEMALE = 3, 4
-- Drawables listed per slot at most. Addon packs MAY add hundreds; the page pages through them.
local MAX_DRAWABLES = 4096

---@param ped integer
---@param model string
---@return boolean
function Ped.HasModel(ped, model)
    return GetEntityModel(ped) == joaat(model)
end

---Swaps the player's model. Returns the new player ped, or nil when the model fails to load. MUST run in a thread.
---@param model string
---@return integer?
function Ped.SetPlayerModel(model)
    if not UgLib.Streaming.Model(model) then
        return nil
    end

    SetPlayerModel(PlayerId(), joaat(model))
    UgLib.Streaming.Release(UgLib.Enums.Asset.Model, model)

    local ped = PlayerPedId()

    SetPedDefaultComponentVariation(ped)

    return ped
end

---@param ped integer
---@param blend UgApHeadBlend
local function applyHeadBlend(ped, blend)
    SetPedHeadBlendData(ped, blend.shapeFirst, blend.shapeSecond, blend.shapeThird, blend.skinFirst, blend.skinSecond, blend.skinThird,
        blend.shapeMix, blend.skinMix, blend.thirdMix, false)
end

---@param ped integer
---@param features table<string, number>
local function applyFeatures(ped, features)
    for _, feature in ipairs(Appearance.FaceFeatures) do
        SetPedFaceFeature(ped, feature.id, features[feature.key] or 0.0)
    end
end

---@param ped integer
---@param key string
---@param id integer
---@param overlay UgApOverlayValue
local function applyOverlay(ped, key, id, overlay)
    SetPedHeadOverlay(ped, id, overlay.style < 0 and NO_OVERLAY or overlay.style, overlay.opacity)

    local colorType = Appearance.OverlayColorType[key]

    if colorType then
        SetPedHeadOverlayColor(ped, id, colorType, overlay.color, overlay.secondColor)
    end
end

---@param ped integer
---@param hair UgApHair
local function applyHair(ped, hair)
    SetPedComponentVariation(ped, HAIR_COMPONENT, hair.style, hair.texture, 0)
    SetPedHairTint(ped, hair.color, hair.highlight)
end

---@param ped integer
---@param id integer
---@param part UgApAppearancePart
local function applyProp(ped, id, part)
    if part.drawable < 0 then
        ClearPedProp(ped, id)
    else
        SetPedPropIndex(ped, id, part.drawable, part.texture, true)
    end
end

---@param ped integer
---@param tattoos UgApTattoo[]
local function applyTattoos(ped, tattoos)
    ClearPedDecorations(ped)

    for _, tattoo in ipairs(tattoos) do
        AddPedDecorationFromHashes(ped, tattoo.collection, tattoo.overlay)
    end
end

---Applies what changed from `from` to `to`. With no `from`, applies everything. The model is not changed here.
---@param ped integer
---@param from UgApAppearance?
---@param to UgApAppearance
function Ped.ApplyDiff(ped, from, to)
    local freemode = Appearance.Freemode[to.model] == true

    ---@param key string
    ---@return boolean
    local function changed(key)
        return from == nil or not same(from[key], to[key])
    end

    if freemode then
        if changed('headBlend') then
            applyHeadBlend(ped, to.headBlend)
        end

        if changed('faceFeatures') then
            applyFeatures(ped, to.faceFeatures)
        end

        for _, overlay in ipairs(Appearance.Overlays) do
            if from == nil or not same(from.headOverlays[overlay.key], to.headOverlays[overlay.key]) then
                applyOverlay(ped, overlay.key, overlay.id, to.headOverlays[overlay.key])
            end
        end

        if changed('hair') then
            applyHair(ped, to.hair)
        end

        if changed('eyeColor') then
            SetPedEyeColor(ped, to.eyeColor)
        end

        if changed('tattoos') then
            applyTattoos(ped, to.tattoos)
        end
    end

    for _, component in ipairs(Appearance.Components) do
        local part = to.components[component.key]

        if from == nil or not same(from.components[component.key], part) then
            SetPedComponentVariation(ped, component.id, part.drawable, part.texture, 0)
        end
    end

    for _, prop in ipairs(Appearance.Props) do
        local part = to.props[prop.key]

        if from == nil or not same(from.props[prop.key], part) then
            applyProp(ped, prop.id, part)
        end
    end
end

---Dresses a ped. For the player, a different model is loaded first and the new ped returned. Other peds keep their
---model: callers create them with the right one. MUST run in a thread.
---@param ped integer
---@param appearance UgApAppearance
---@return integer ped the ped that was dressed
function Ped.Apply(ped, appearance)
    if ped == PlayerPedId() and not Ped.HasModel(ped, appearance.model) then
        ped = Ped.SetPlayerModel(appearance.model) or ped
    end

    Ped.ApplyDiff(ped, nil, appearance)

    return ped
end

---@param count integer
---@param read fun(index: integer): integer
---@return integer[]
local function counts(count, read)
    local list = {}

    for index = 0, math.min(count, MAX_DRAWABLES) - 1 do
        list[#list + 1] = read(index)
    end

    return list
end

---@param total integer
---@param read fun(index: integer): integer, integer, integer
---@return integer[][] `{ r, g, b }` per color
local function palette(total, read)
    local list = {}

    for index = 0, total - 1 do
        local r, g, b = read(index)

        list[#list + 1] = { r, g, b }
    end

    return list
end

---What the game offers for this ped: texture counts per drawable for every slot, overlay styles, color palettes and
---tattoos. Drawable counts are the lengths of the texture lists.
---@param ped integer
---@param model string
---@return table
function Ped.Catalog(ped, model)
    local catalog = {
        components = {},
        props = {},
        overlays = {},
        freemode = Appearance.Freemode[model] == true,
    }

    for _, component in ipairs(Appearance.Components) do
        catalog.components[component.key] = counts(GetNumberOfPedDrawableVariations(ped, component.id), function(drawable)
            return GetNumberOfPedTextureVariations(ped, component.id, drawable)
        end)
    end

    for _, prop in ipairs(Appearance.Props) do
        catalog.props[prop.key] = counts(GetNumberOfPedPropDrawableVariations(ped, prop.id), function(drawable)
            return GetNumberOfPedPropTextureVariations(ped, prop.id, drawable)
        end)
    end

    if not catalog.freemode then
        return catalog
    end

    catalog.hair = counts(GetNumberOfPedDrawableVariations(ped, HAIR_COMPONENT), function(drawable)
        return GetNumberOfPedTextureVariations(ped, HAIR_COMPONENT, drawable)
    end)

    for _, overlay in ipairs(Appearance.Overlays) do
        catalog.overlays[overlay.key] = GetPedHeadOverlayNum(overlay.id)
    end

    catalog.hairColors = palette(GetNumHairColors(), GetPedHairRgbColor)
    catalog.makeupColors = palette(GetNumMakeupColors(), GetPedMakeupRgbColor)

    local ok, tattoos = pcall(function()
        return exports[RESOURCE]:TattooCatalog(model == 'mp_f_freemode_01' and TATTOO_FEMALE or TATTOO_MALE)
    end)

    catalog.tattoos = ok and type(tattoos) == 'table' and tattoos or {}

    return catalog
end
