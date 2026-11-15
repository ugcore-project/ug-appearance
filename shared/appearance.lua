--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- The appearance model: schema, defaults, categories, diff and price. Server and client run this same code, so the
-- bill the page shows is the bill the server charges.

---@class UgApAppearancePart
---@field drawable integer
---@field texture integer

---@class UgApOverlayValue
---@field style integer -1 is none
---@field opacity number
---@field color integer
---@field secondColor integer

---@class UgApHeadBlend
---@field shapeFirst integer
---@field shapeSecond integer
---@field shapeThird integer
---@field skinFirst integer
---@field skinSecond integer
---@field skinThird integer
---@field shapeMix number
---@field skinMix number
---@field thirdMix number

---@class UgApHair
---@field style integer
---@field texture integer
---@field color integer
---@field highlight integer

---@class UgApTattoo
---@field collection integer collection hash
---@field overlay integer overlay hash

---@class UgApAppearance
---@field model string
---@field headBlend UgApHeadBlend
---@field faceFeatures table<string, number>
---@field headOverlays table<string, UgApOverlayValue>
---@field hair UgApHair
---@field eyeColor integer
---@field components table<string, UgApAppearancePart>
---@field props table<string, UgApAppearancePart>
---@field tattoos UgApTattoo[]

---One changed unit of an edit, with its price.
---@class UgApPriceLine
---@field category UgApCategory
---@field key string the component, prop, overlay or tattoo, or the category itself
---@field price integer
---@field removed? boolean a removed tattoo

---@class UgApPrices
---@field component integer
---@field prop integer
---@field overlay integer
---@field hair integer
---@field heritage integer
---@field features integer
---@field eyes integer
---@field skin integer
---@field tattoo integer
---@field tattooRemoval integer

---@class UgAp.Internal.Appearance
local Appearance = {}
UgAp.Internal.Appearance = Appearance

local Enums = UgAp.Enums
local Category = Enums.Category
local Kind = Enums.StoreKind
local Schema = UgCore.Schema

local MAX_DRAWABLE = 4095
local MAX_TEXTURE = 255
local MAX_COLOR = 63
local MAX_PARENT = 45
local MAX_EYE_COLOR = 31
local MAX_OVERLAY_STYLE = 254
local MIN_HASH = -2147483648
local MAX_HASH = 4294967295
-- Sliders send floats; a JSON round trip MAY change the last digits.
local EPSILON = 0.0001

---@param name string
---@return string
local function camel(name)
    return name:sub(1, 1):lower() .. name:sub(2)
end

---Data keys of an id enum, ordered by native id.
---@param enum table<string, integer>
---@return { key: string, id: integer }[]
local function keysOf(enum)
    local list = {}

    for name, id in pairs(enum) do
        list[#list + 1] = {
            key = camel(name),
            id = id,
        }
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end

---Components, props, overlays and features as `{ key, id }`, ordered by native id.
Appearance.Components = keysOf(Enums.Component)
Appearance.Props = keysOf(Enums.Prop)
Appearance.Overlays = keysOf(Enums.Overlay)
Appearance.FaceFeatures = keysOf(Enums.FaceFeature)

---The category of each overlay.
---@type table<string, UgApCategory>
Appearance.OverlayCategory = {
    blemishes = Category.Skin,
    beard = Category.FacialHair,
    eyebrows = Category.FacialHair,
    ageing = Category.Skin,
    makeup = Category.Makeup,
    blush = Category.Makeup,
    complexion = Category.Skin,
    sunDamage = Category.Skin,
    lipstick = Category.Makeup,
    moles = Category.Skin,
    chestHair = Category.FacialHair,
    bodyBlemishes = Category.Skin,
    addBodyBlemishes = Category.Skin,
}

---Color type of overlays that take a color: 1 hair palette, 2 makeup palette.
---@type table<string, integer>
Appearance.OverlayColorType = {
    beard = 1,
    eyebrows = 1,
    chestHair = 1,
    makeup = 2,
    blush = 2,
    lipstick = 2,
}

---Categories each session kind MAY change.
---@type table<UgApStoreKind, UgApCategory[]>
Appearance.KindCategories = {
    [Kind.Clothing] = { Category.Clothing, Category.Accessories },
    [Kind.Barber] = { Category.Hair, Category.FacialHair, Category.Makeup },
    [Kind.Tattoo] = { Category.Tattoos },
    [Kind.Surgeon] = { Category.Heritage, Category.Features, Category.Eyes, Category.Skin },
    [Kind.Wardrobe] = {},
    [Kind.Creator] = {
        Category.Model, Category.Heritage, Category.Features, Category.Eyes, Category.Skin, Category.Hair,
        Category.FacialHair, Category.Makeup, Category.Clothing, Category.Accessories, Category.Tattoos,
    },
}
Appearance.KindCategories[Kind.Admin] = Appearance.KindCategories[Kind.Creator]

---Kinds that never cost anything.
---@type table<UgApStoreKind, boolean>
Appearance.FreeKinds = {
    [Kind.Wardrobe] = true,
    [Kind.Creator] = true,
    [Kind.Admin] = true,
}

---Models with head blend, features, overlays and hair.
---@type table<string, boolean>
Appearance.Freemode = {
    mp_m_freemode_01 = true,
    mp_f_freemode_01 = true,
}

---@param model string
---@return UgApAppearance
function Appearance.Default(model)
    local appearance = {
        model = model,
        headBlend = {
            shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
            skinFirst = 0, skinSecond = 0, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        faceFeatures = {},
        headOverlays = {},
        hair = {
            style = 0,
            texture = 0,
            color = 0,
            highlight = 0,
        },
        eyeColor = 0,
        components = {},
        props = {},
        tattoos = {},
    }

    for _, feature in ipairs(Appearance.FaceFeatures) do
        appearance.faceFeatures[feature.key] = 0.0
    end

    for _, overlay in ipairs(Appearance.Overlays) do
        -- Eyebrows on by default: a face without them reads as a bug.
        appearance.headOverlays[overlay.key] = {
            style = overlay.key == 'eyebrows' and 0 or -1,
            opacity = 1.0,
            color = 0,
            secondColor = 0,
        }
    end

    for _, component in ipairs(Appearance.Components) do
        appearance.components[component.key] = {
            drawable = 0,
            texture = 0,
        }
    end

    for _, prop in ipairs(Appearance.Props) do
        appearance.props[prop.key] = {
            drawable = -1,
            texture = 0,
        }
    end

    return appearance
end

local PART = Schema.Object({
    drawable = Schema.Integer({
        min = 0,
        max = MAX_DRAWABLE,
    }),
    texture = Schema.Integer({
        min = 0,
        max = MAX_TEXTURE,
    }),
})
local PROP = Schema.Object({
    drawable = Schema.Integer({
        min = -1,
        max = MAX_DRAWABLE,
    }),
    texture = Schema.Integer({
        min = 0,
        max = MAX_TEXTURE,
    }),
})
local COLOR = Schema.Integer({
    min = 0,
    max = MAX_COLOR,
})
local PARENT = Schema.Integer({
    min = 0,
    max = MAX_PARENT,
})
local MIX = Schema.Number({
    min = 0,
    max = 1,
})

---@param list { key: string }[]
---@param rule UgSchemaRule
---@return table<string, UgSchemaRule>
local function fieldsOf(list, rule)
    local fields = {}

    for _, entry in ipairs(list) do
        fields[entry.key] = rule
    end

    return fields
end

local FIXED = {
    headBlend = Schema.Object({
        shapeFirst = PARENT, shapeSecond = PARENT, shapeThird = PARENT,
        skinFirst = PARENT, skinSecond = PARENT, skinThird = PARENT,
        shapeMix = MIX, skinMix = MIX, thirdMix = MIX,
    }),
    faceFeatures = Schema.Object(fieldsOf(Appearance.FaceFeatures, Schema.Number({
        min = -1,
        max = 1,
    }))),
    headOverlays = Schema.Object(fieldsOf(Appearance.Overlays, Schema.Object({
        style = Schema.Integer({
            min = -1,
            max = MAX_OVERLAY_STYLE,
        }),
        opacity = MIX,
        color = COLOR,
        secondColor = COLOR,
    }))),
    hair = Schema.Object({
        style = Schema.Integer({
            min = 0,
            max = MAX_DRAWABLE,
        }),
        texture = Schema.Integer({
            min = 0,
            max = MAX_TEXTURE,
        }),
        color = COLOR,
        highlight = COLOR,
    }),
    eyeColor = Schema.Integer({
        min = 0,
        max = MAX_EYE_COLOR,
    }),
    components = Schema.Object(fieldsOf(Appearance.Components, PART)),
    props = Schema.Object(fieldsOf(Appearance.Props, PROP)),
}

---@param tattoo UgApTattoo
---@return string
local function tattooKey(tattoo)
    return tattoo.collection .. ':' .. tattoo.overlay
end

---The appearance rule for a model list and a tattoo limit. Strict: unknown keys fail.
---@param models string[]? nil accepts any model name, for callers that check the model themselves
---@param maxTattoos integer
---@return UgSchemaRule
function Appearance.Rule(models, maxTattoos)
    local fields = {
        model = models and Schema.Enum(models) or Schema.String({
            min = 1,
            max = 64,
            pattern = '^[%w_]+$',
        }),
    }

    for key, rule in pairs(FIXED) do
        fields[key] = rule
    end

    fields.tattoos = Schema.Array(Schema.Object({
        collection = Schema.Integer({
            min = MIN_HASH,
            max = MAX_HASH,
        }),
        overlay = Schema.Integer({
            min = MIN_HASH,
            max = MAX_HASH,
        }),
    }), {
        max = maxTattoos,
        validate = function(list)
            local seen = {}

            for _, tattoo in ipairs(list) do
                local key = tattooKey(tattoo)

                if seen[key] then
                    return false, 'MUST NOT hold the same tattoo twice'
                end

                seen[key] = true
            end

            return true
        end,
    })

    return Schema.Object(fields)
end

---@param a any
---@param b any
---@return boolean
local function same(a, b)
    if type(a) == 'number' and type(b) == 'number' then
        return math.abs(a - b) < EPSILON
    end

    if type(a) ~= 'table' or type(b) ~= 'table' then
        return a == b
    end

    for key, value in pairs(a) do
        if not same(value, b[key]) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

Appearance.Same = same

---@param prices UgApPrices
---@param category UgApCategory
---@return integer
local function onceOf(prices, category)
    return prices[category] or 0
end

---Every changed unit from `saved` to `edited`, with its price. Categories in a fixed order, keys in native id order.
---@param saved UgApAppearance
---@param edited UgApAppearance
---@param prices UgApPrices
---@return UgApPriceLine[]
function Appearance.Changes(saved, edited, prices)
    local lines = {}

    ---@param category UgApCategory
    ---@param key string
    ---@param price integer
    ---@param removed? boolean
    local function add(category, key, price, removed)
        lines[#lines + 1] = {
            category = category,
            key = key,
            price = price,
            removed = removed,
        }
    end

    if saved.model ~= edited.model then
        add(Category.Model, Category.Model, 0)
    end

    if not same(saved.headBlend, edited.headBlend) then
        add(Category.Heritage, Category.Heritage, onceOf(prices, Category.Heritage))
    end

    if not same(saved.faceFeatures, edited.faceFeatures) then
        add(Category.Features, Category.Features, onceOf(prices, Category.Features))
    end

    if saved.eyeColor ~= edited.eyeColor then
        add(Category.Eyes, Category.Eyes, onceOf(prices, Category.Eyes))
    end

    local skinChanged = false

    for _, overlay in ipairs(Appearance.Overlays) do
        local category = Appearance.OverlayCategory[overlay.key]

        if not same(saved.headOverlays[overlay.key], edited.headOverlays[overlay.key]) then
            if category == Category.Skin then
                skinChanged = true
            end
        end
    end

    if skinChanged then
        add(Category.Skin, Category.Skin, onceOf(prices, Category.Skin))
    end

    if not same(saved.hair, edited.hair) then
        add(Category.Hair, Category.Hair, onceOf(prices, Category.Hair))
    end

    for _, category in ipairs({ Category.FacialHair, Category.Makeup }) do
        for _, overlay in ipairs(Appearance.Overlays) do
            if Appearance.OverlayCategory[overlay.key] == category and not same(saved.headOverlays[overlay.key], edited.headOverlays[overlay.key]) then
                add(category, overlay.key, prices.overlay)
            end
        end
    end

    for _, component in ipairs(Appearance.Components) do
        if not same(saved.components[component.key], edited.components[component.key]) then
            add(Category.Clothing, component.key, prices.component)
        end
    end

    for _, prop in ipairs(Appearance.Props) do
        if not same(saved.props[prop.key], edited.props[prop.key]) then
            add(Category.Accessories, prop.key, prices.prop)
        end
    end

    local before, after = {}, {}

    for _, tattoo in ipairs(saved.tattoos) do
        before[tattooKey(tattoo)] = true
    end

    for _, tattoo in ipairs(edited.tattoos) do
        local key = tattooKey(tattoo)

        after[key] = true

        if not before[key] then
            add(Category.Tattoos, key, prices.tattoo)
        end
    end

    for _, tattoo in ipairs(saved.tattoos) do
        local key = tattooKey(tattoo)

        if not after[key] then
            add(Category.Tattoos, key, prices.tattooRemoval, true)
        end
    end

    return lines
end

---The bill of an edit. Free kinds cost nothing but still list their lines.
---@param saved UgApAppearance
---@param edited UgApAppearance
---@param kind UgApStoreKind
---@param prices UgApPrices
---@return integer total
---@return UgApPriceLine[] lines
function Appearance.Price(saved, edited, kind, prices)
    local lines = Appearance.Changes(saved, edited, prices)
    local total = 0

    for _, line in ipairs(lines) do
        if Appearance.FreeKinds[kind] then
            line.price = 0
        end

        total = total + line.price
    end

    return total, lines
end

---@param kind UgApStoreKind
---@return table<UgApCategory, boolean>
function Appearance.Allowed(kind)
    local set = {}

    for _, category in ipairs(Appearance.KindCategories[kind] or {}) do
        set[category] = true
    end

    return set
end

---The first category an edit changes that `kind` does not allow, nil when the edit stays inside.
---@param saved UgApAppearance
---@param edited UgApAppearance
---@param kind UgApStoreKind
---@return UgApCategory?
function Appearance.Outside(saved, edited, kind)
    local allowed = Appearance.Allowed(kind)
    local zero = setmetatable({}, {
        __index = function() return 0 end,
    })

    for _, line in ipairs(Appearance.Changes(saved, edited, zero)) do
        if not allowed[line.category] then
            return line.category
        end
    end

    return nil
end

---@param value any
---@return any
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = copy(item)
    end

    return result
end

Appearance.Copy = copy

---A copy of `edited` where every category `kind` does not allow comes from `saved`.
---@param saved UgApAppearance
---@param edited UgApAppearance
---@param kind UgApStoreKind
---@return UgApAppearance
function Appearance.Restrict(saved, edited, kind)
    local allowed = Appearance.Allowed(kind)
    local result = copy(edited)

    ---@param category UgApCategory
    ---@return boolean
    local function locked(category)
        return not allowed[category]
    end

    if locked(Category.Model) then result.model = saved.model end
    if locked(Category.Heritage) then result.headBlend = copy(saved.headBlend) end
    if locked(Category.Features) then result.faceFeatures = copy(saved.faceFeatures) end
    if locked(Category.Eyes) then result.eyeColor = saved.eyeColor end
    if locked(Category.Hair) then result.hair = copy(saved.hair) end
    if locked(Category.Clothing) then result.components = copy(saved.components) end
    if locked(Category.Accessories) then result.props = copy(saved.props) end
    if locked(Category.Tattoos) then result.tattoos = copy(saved.tattoos) end

    for _, overlay in ipairs(Appearance.Overlays) do
        if locked(Appearance.OverlayCategory[overlay.key]) then
            result.headOverlays[overlay.key] = copy(saved.headOverlays[overlay.key])
        end
    end

    return result
end

---An appearance with clothing and accessories from an outfit. Parts the outfit does not list stay as they are, so a
---uniform MAY set only a few.
---@param appearance UgApAppearance
---@param outfit { components?: table<string, UgApAppearancePart>, props?: table<string, UgApAppearancePart> }
---@return UgApAppearance
function Appearance.Wear(appearance, outfit)
    local result = copy(appearance)

    for key, part in pairs(outfit.components or {}) do
        result.components[key] = copy(part)
    end

    for key, part in pairs(outfit.props or {}) do
        result.props[key] = copy(part)
    end

    return result
end

---Rules for a full outfit and for a partial one (uniforms).
Appearance.OutfitRule = Schema.Object({
    components = FIXED.components,
    props = FIXED.props,
})
Appearance.PartialOutfitRule = Schema.Object({
    components = Schema.Optional(Schema.Object((function()
        local fields = {}

        for _, component in ipairs(Appearance.Components) do
            fields[component.key] = Schema.Optional(PART)
        end

        return fields
    end)())),
    props = Schema.Optional(Schema.Object((function()
        local fields = {}

        for _, prop in ipairs(Appearance.Props) do
            fields[prop.key] = Schema.Optional(PROP)
        end

        return fields
    end)())),
})
