--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Owner config: config.lua, copied from server/config.default.lua on the first start and never overwritten.
-- Owner values merge over the defaults: tables merge per key, arrays and other values replace.

---@class UgAp.Internal.Config
local Config = {}
UgAp.Internal.Config = Config

local Schema = UgCore.Schema
local Enums = UgAp.Enums
local Appearance = UgAp.Internal.Appearance

local RESOURCE = GetCurrentResourceName()
local OWNER_FILE = 'config.lua'
-- To verify live: the store coordinates (shop doors) and the sound names in server/config.default.lua.
local DEFAULT_FILE = 'server/config.default.lua'
local MAX_COORD = 100000
local ID_PATTERN = '^[%w_%-]+$'

---@param enum table<string, string>
---@param skip? table<string, boolean>
---@return string[]
local function valuesOf(enum, skip)
    local values = {}

    for _, value in pairs(enum) do
        if not (skip and skip[value]) then
            values[#values + 1] = value
        end
    end

    table.sort(values)

    return values
end

local NAME = Schema.String({
    min = 1,
    max = 64,
})
local ID = Schema.String({
    min = 1,
    max = 32,
    pattern = ID_PATTERN,
})
local MS = Schema.Integer({
    min = 0,
    max = 60000,
})
local PRICE = Schema.Integer({
    min = 0,
    max = 10000000,
})
-- Kinds an owner MAY place in the world. Creator and admin sessions only come from code.
local PLACED_KINDS = valuesOf(Enums.StoreKind, {
    [Enums.StoreKind.Creator] = true,
    [Enums.StoreKind.Admin] = true,
})

local PRICE_FIELDS = {
    'component',
    'prop',
    'overlay',
    'hair',
    'heritage',
    'features',
    'eyes',
    'skin',
    'tattoo',
    'tattooRemoval',
}

---@param optional boolean
---@return UgSchemaRule
local function pricesRule(optional)
    local fields = {}

    for _, key in ipairs(PRICE_FIELDS) do
        fields[key] = optional and Schema.Optional(PRICE) or PRICE
    end

    return Schema.Object(fields)
end

local BLIP = Schema.Object({
    sprite = Schema.Integer({
        min = 0,
        max = 1000,
    }),
    color = Schema.Integer({
        min = 0,
        max = 100,
    }),
    scale = Schema.Optional(Schema.Number({
        min = 0.1,
        max = 3,
    })),
})

-- A store blip: `true` (filled from `blips` here), `false`, or fields that replace the kind's.
local STORE_BLIP = Schema.Object({
    sprite = Schema.Optional(Schema.Integer({
        min = 0,
        max = 1000,
    })),
    color = Schema.Optional(Schema.Integer({
        min = 0,
        max = 100,
    })),
    scale = Schema.Optional(Schema.Number({
        min = 0.1,
        max = 3,
    })),
    label = Schema.Optional(NAME),
})

---@param value { dict?: string, name?: string, scenario?: string }
---@param shapes string the accepted shapes, for the message
---@return boolean ok
---@return string? message
local function isAnimation(value, shapes)
    local isAnim = value.dict ~= nil or value.name ~= nil

    if isAnim and (value.dict == nil or value.name == nil) then
        return false, 'MUST have both dict and name'
    end

    return not (isAnim and value.scenario ~= nil), 'MUST be ' .. shapes
end

local ANIMATION = Schema.Object({
    dict = Schema.Optional(NAME),
    name = Schema.Optional(NAME),
    flag = Schema.Optional(Schema.Integer({
        min = 0,
        max = 1048575,
    })),
    scenario = Schema.Optional(NAME),
}, {
    validate = function(value)
        if value.dict == nil and value.scenario == nil then
            return false, 'MUST be { dict, name, flag? } or { scenario }'
        end

        return isAnimation(value, '{ dict, name, flag? } or { scenario }')
    end,
})

local MODEL = Schema.String({
    min = 1,
    max = 64,
    pattern = '^[%w_]+$',
})
local HSL = Schema.String({
    min = 5,
    max = 24,
    pattern = '^%d+%.?%d* %d+%.?%d*%% %d+%.?%d*%%$',
})
local GAME_NAME = Schema.String({
    min = 1,
    max = 64,
    pattern = '^[%w_%-]+$',
})
local BYTE = Schema.Integer({
    min = 0,
    max = 255,
})
local SOUNDS = valuesOf(Enums.Sound)

-- ug-lib's theme tokens, then a color per editor tab and the heritage mix bar.
local THEME_TOKENS = {
    'background', 'foreground', 'card', 'cardForeground', 'popover', 'popoverForeground',
    'primary', 'primaryForeground', 'secondary', 'secondaryForeground', 'muted', 'mutedForeground',
    'accent', 'accentForeground', 'destructive', 'destructiveForeground', 'success', 'successForeground',
    'warning', 'warningForeground', 'border', 'input', 'ring',
}

for _, token in ipairs(valuesOf(Enums.Category)) do
    THEME_TOKENS[#THEME_TOKENS + 1] = token
end

for _, token in ipairs({ 'outfits', 'mixFirst', 'mixSecond' }) do
    THEME_TOKENS[#THEME_TOKENS + 1] = token
end

---@param value string
---@return boolean ok
---@return string? message
local function size(value)
    if value:find('^%d*%.?%d+rem$') or value:find('^%d*%.?%d+px$') then
        return true, nil
    end

    return false, 'MUST be a size in rem or px'
end

---@return UgSchemaRule
local function featuresRule()
    local fields = {}

    for _, feature in ipairs(valuesOf(Enums.Feature)) do
        fields[feature] = Schema.Boolean()
    end

    return Schema.Object(fields)
end

local LAMP = Schema.Object({
    angle = Schema.Number({
        min = -360,
        max = 360,
    }),
    distance = Schema.Number({
        min = 0,
        max = 10,
    }),
    height = Schema.Number({
        min = -5,
        max = 5,
    }),
    color = Schema.Array(BYTE, {
        min = 3,
        max = 3,
    }),
    range = Schema.Number({
        min = 0,
        max = 50,
    }),
    intensity = Schema.Number({
        min = 0,
        max = 50,
    }),
})

-- The NPC of a kind: the model and animation every store ped of that kind starts from.
local KIND_PED = Schema.Object({
    model = MODEL,
    animation = Schema.Optional(ANIMATION),
})

-- A store NPC: `true` (the kind's ped at the store coords), `false`, or fields that replace the kind's.
local STORE_PED = Schema.Object({
    model = Schema.Optional(MODEL),
    coords = Schema.Optional(Schema.Vector4({
        maxComponent = MAX_COORD,
    })),
    animation = Schema.Optional(ANIMATION),
})

local STORE = Schema.Object({
    id = ID,
    kind = Schema.Enum(PLACED_KINDS),
    coords = Schema.Vector3({
        maxComponent = MAX_COORD,
    }),
    radius = Schema.Optional(Schema.Number({
        min = 0.5,
        max = 50,
    })),
    -- Without a label, clients read stores.<kind> from locales/<code>.json.
    label = Schema.Optional(NAME),
    blip = Schema.Optional(STORE_BLIP),
    ped = Schema.Optional(STORE_PED),
    job = Schema.Optional(NAME),
    gang = Schema.Optional(NAME),
    prices = Schema.Optional(pricesRule(true)),
})

local POSE = Schema.Object({
    id = ID,
    dict = Schema.Optional(NAME),
    name = Schema.Optional(NAME),
    flag = Schema.Optional(Schema.Integer({
        min = 0,
        max = 1048575,
    })),
    scenario = Schema.Optional(NAME),
}, {
    validate = function(pose)
        return isAnimation(pose, '{ id }, { id, dict, name, flag? } or { id, scenario }')
    end,
})

local SHOT = Schema.Object({
    distance = Schema.Number({
        min = 0.2,
        max = 10,
    }),
    height = Schema.Number({
        min = -2,
        max = 2,
    }),
    fov = Schema.Number({
        min = 10,
        max = 120,
    }),
})

local UNIFORM = Schema.Object({
    label = NAME,
    grades = Schema.Optional(Schema.Array(Schema.Integer({
        min = 0,
        max = 100,
    }), {
        min = 1,
        max = 50,
    })),
    male = Schema.Optional(Appearance.PartialOutfitRule),
    female = Schema.Optional(Appearance.PartialOutfitRule),
})

---Turns a Schema detail into a config path: `value[1].kind: ...` under `stores` becomes `stores[1].kind: ...`.
---@param key string
---@param detail string?
---@return string
local function pathOf(key, detail)
    local text = (detail or 'is invalid'):gsub('^value', '')
    local first = text:sub(1, 1)

    return key .. ((first == ':' or first == '.' or first == '[') and '' or ': ') .. text
end

---@param list table[]
---@param key string
---@return boolean ok
---@return string? message
local function unique(list, key)
    local seen = {}

    for _, entry in ipairs(list) do
        if seen[entry[key]] then
            return false, ('%s "%s" is used twice'):format(key, tostring(entry[key]))
        end

        seen[entry[key]] = true
    end

    return true
end

---Rules per top-level key. `alternatives` are plain values allowed besides the rule, such as `false` to turn a feature off.
---@type { key: string, rule: UgSchemaRule, alternatives?: any[] }[]
local RULES = {
    {
        key = 'models',
        rule = Schema.Array(Schema.String({
            min = 1,
            max = 64,
            pattern = '^[%w_]+$',
        }), {
            min = 1,
            max = 50,
            validate = function(list)
                local seen = {}

                for _, model in ipairs(list) do
                    if seen[model] then
                        return false, ('model "%s" is listed twice'):format(model)
                    end

                    seen[model] = true
                end

                return true
            end,
        }),
    },
    {
        key = 'stores',
        rule = Schema.Array(STORE, {
            max = 500,
            validate = function(list)
                return unique(list, 'id')
            end,
        }),
    },
    {
        key = 'blips',
        rule = Schema.Object({
            [Enums.StoreKind.Clothing] = BLIP,
            [Enums.StoreKind.Barber] = BLIP,
            [Enums.StoreKind.Tattoo] = BLIP,
            [Enums.StoreKind.Surgeon] = BLIP,
            [Enums.StoreKind.Wardrobe] = BLIP,
        }),
    },
    {
        key = 'peds',
        rule = Schema.Object({
            [Enums.StoreKind.Clothing] = Schema.Optional(KIND_PED),
            [Enums.StoreKind.Barber] = Schema.Optional(KIND_PED),
            [Enums.StoreKind.Tattoo] = Schema.Optional(KIND_PED),
            [Enums.StoreKind.Surgeon] = Schema.Optional(KIND_PED),
            [Enums.StoreKind.Wardrobe] = Schema.Optional(KIND_PED),
        }),
    },
    {
        key = 'prices',
        rule = pricesRule(false),
    },
    {
        key = 'payment',
        rule = Schema.Object({
            accounts = Schema.Array(Schema.String({
                min = 1,
                max = 32,
                pattern = ID_PATTERN,
            }), {
                min = 1,
                max = 5,
            }),
        }),
    },
    {
        key = 'storeRadius',
        rule = Schema.Number({
            min = 0.5,
            max = 50,
        }),
    },
    {
        key = 'maxOutfits',
        rule = Schema.Integer({
            min = 0,
            max = 100,
        }),
    },
    {
        key = 'maxTattoos',
        rule = Schema.Integer({
            min = 0,
            max = 200,
        }),
    },
    {
        key = 'tattooOutfit',
        rule = Schema.Object({
            male = Appearance.PartialOutfitRule,
            female = Appearance.PartialOutfitRule,
        }),
        alternatives = { false },
    },
    {
        key = 'uniforms',
        rule = Schema.Map(Schema.String({
            min = 1,
            max = 64,
        }), Schema.Array(UNIFORM, {
            min = 1,
            max = 50,
        }), {
            max = 200,
        }),
    },
    {
        key = 'poses',
        rule = Schema.Array(POSE, {
            min = 1,
            max = 20,
            validate = function(list)
                return unique(list, 'id')
            end,
        }),
    },
    {
        key = 'camera',
        rule = Schema.Object({
            duration = MS,
            ease = Schema.Enum(valuesOf(Enums.Ease)),
            minDistance = Schema.Number({
                min = 0.2,
                max = 10,
            }),
            maxDistance = Schema.Number({
                min = 0.2,
                max = 10,
            }),
            zoomDuration = MS,
            presets = Schema.Object({
                [Enums.Camera.Face] = SHOT,
                [Enums.Camera.Upper] = SHOT,
                [Enums.Camera.Lower] = SHOT,
                [Enums.Camera.Feet] = SHOT,
                [Enums.Camera.Full] = SHOT,
            }),
        }, {
            validate = function(camera)
                return camera.minDistance <= camera.maxDistance, 'minDistance MUST NOT be greater than maxDistance'
            end,
        }),
    },
    {
        key = 'adminCommand',
        rule = Schema.String({
            min = 1,
            max = 32,
            pattern = ID_PATTERN,
        }),
        alternatives = { false },
    },
    {
        key = 'interactKey',
        rule = Schema.String({
            min = 1,
            max = 16,
            pattern = '^[%w_]+$',
        }),
    },
    {
        key = 'interaction',
        rule = Schema.Enum(valuesOf(Enums.Interaction)),
    },
    {
        key = 'theme',
        rule = Schema.Object({
            mode = Schema.Optional(Schema.Enum({ 'dark', 'light' })),
            colors = Schema.Optional(Schema.Map(Schema.Enum(THEME_TOKENS), HSL, {
                max = #THEME_TOKENS,
            })),
            radius = Schema.Optional(Schema.String({
                min = 3,
                max = 16,
                validate = size,
            })),
            font = Schema.Optional(Schema.Enum({ 'Inter' })),
            scale = Schema.Optional(Schema.Number({
                min = 0.75,
                max = 1.5,
            })),
        }),
    },
    {
        key = 'layout',
        rule = Schema.Object({
            side = Schema.Enum(valuesOf(Enums.Side)),
            width = Schema.Number({
                min = 16,
                max = 40,
            }),
            opacity = Schema.Number({
                min = 0,
                max = 1,
            }),
            blur = Schema.Boolean(),
            toolbar = Schema.Enum(valuesOf(Enums.Place)),
            hint = Schema.Boolean(),
            animations = Schema.Boolean(),
            resultDuration = Schema.Integer({
                min = 500,
                max = 60000,
            }),
        }),
    },
    {
        key = 'features',
        rule = featuresRule(),
    },
    {
        key = 'controls',
        rule = Schema.Object({
            dragSpeed = Schema.Number({
                min = 0.01,
                max = 5,
            }),
            zoomSpeed = Schema.Number({
                min = 0.0001,
                max = 0.1,
            }),
            keyRotate = Schema.Number({
                min = 0,
                max = 180,
            }),
            rotateStep = Schema.Number({
                min = 1,
                max = 180,
            }),
        }),
    },
    {
        key = 'lights',
        rule = Schema.Array(Schema.Enum(valuesOf(Enums.Light)), {
            min = 1,
            max = 4,
            validate = function(list)
                local seen = {}

                for _, light in ipairs(list) do
                    if seen[light] then
                        return false, ('light "%s" is listed twice'):format(light)
                    end

                    seen[light] = true
                end

                return true
            end,
        }),
    },
    {
        key = 'studio',
        rule = Schema.Object({
            dayHour = Schema.Integer({
                min = 0,
                max = 23,
            }),
            nightHour = Schema.Integer({
                min = 0,
                max = 23,
            }),
            lights = Schema.Array(LAMP, {
                max = 8,
            }),
        }),
    },
    {
        key = 'soundEffects',
        rule = Schema.Map(Schema.Enum(SOUNDS), Schema.Object({
            name = GAME_NAME,
            set = GAME_NAME,
        }), {
            max = #SOUNDS,
        }),
    },
}

-- Maps where a key left out turns that entry off: the owner's table replaces the default instead of merging.
local REPLACED = {
    soundEffects = true,
}

---@param value any
---@return boolean
local function isArray(value)
    return type(value) == 'table' and (next(value) == nil or value[1] ~= nil)
end

---@param base table
---@param owner table
---@return table
local function merge(base, owner)
    for key, value in pairs(owner) do
        if type(value) == 'table' and type(base[key]) == 'table' and not isArray(value) and not isArray(base[key]) then
            merge(base[key], value)
        else
            base[key] = value
        end
    end

    return base
end

---Runs owner code in a sandbox with only what a config needs.
---@param content string
---@param name? string file name in errors, config.lua by default
---@return boolean ok
---@return table? values
---@return string? message
local function run(content, name)
    local env = {
        vector2 = vector2, vector3 = vector3, vector4 = vector4,
        vec2 = vec2, vec3 = vec3, vec4 = vec4,
        tonumber = tonumber, tostring = tostring, type = type, pairs = pairs, ipairs = ipairs,
        math = setmetatable({}, {
            __index = math,
        }),
        string = setmetatable({}, {
            __index = string,
        }),
        table = setmetatable({}, {
            __index = table,
        }),
    }

    local chunk, syntaxError = load(content, '@' .. (name or OWNER_FILE), 't', env)

    if not chunk then
        return false, nil, tostring(syntaxError)
    end

    local ok, result = pcall(chunk)

    if not ok then
        return false, nil, tostring(result)
    end

    if type(result) ~= 'table' then
        return false, nil, 'MUST return a table'
    end

    return true, result, nil
end

---A fresh copy of the defaults, read from server/config.default.lua: the only place they live.
---@return table
function UgAp.Internal.Defaults()
    local ok, values, message = run(LoadResourceFile(RESOURCE, DEFAULT_FILE) or '', DEFAULT_FILE)

    if not ok or not values then
        error(('[ug-appearance] %s: %s'):format(DEFAULT_FILE, tostring(message)), 2)
    end

    return values
end

---Store blips and peds are `true`, `false` or a table. Booleans become a table or nothing before the schema check.
---@param values table
local function prepareStores(values)
    if type(values.stores) ~= 'table' then
        return
    end

    for _, store in ipairs(values.stores) do
        if type(store) == 'table' then
            for _, key in ipairs({ 'blip', 'ped' }) do
                if store[key] == true then
                    store[key] = {}
                elseif store[key] == false then
                    store[key] = nil
                end
            end
        end
    end
end

---Checks merged values. Returns clean copies of every valid key.
---@param values table
---@return table clean
---@return string[] errors
function Config.Validate(values)
    local errors = {}
    local clean = {}
    local known = {}

    prepareStores(values)

    for _, entry in ipairs(RULES) do
        known[entry.key] = true

        local value = values[entry.key]
        local allowed = false

        for _, alternative in ipairs(entry.alternatives or {}) do
            if value == alternative then
                allowed = true
            end
        end

        if allowed then
            clean[entry.key] = value
        else
            local ok, checked, detail = Schema.Check(entry.rule, value)

            if ok then
                clean[entry.key] = checked
            else
                errors[#errors + 1] = pathOf(entry.key, detail)
            end
        end
    end

    local names = {}

    for key in pairs(known) do
        names[#names + 1] = key
    end

    for key in pairs(values) do
        if not known[key] then
            local suggestion = type(key) == 'string' and UgLib.String.Suggest(key, names) or nil

            errors[#errors + 1] = ('unknown key "%s".%s'):format(tostring(key), suggestion and (' Did you mean "%s"?'):format(suggestion) or '')
        end
    end

    -- Store blips take the kind's sprite, color and scale for every field they leave out.
    if clean.stores and clean.blips then
        for _, store in ipairs(clean.stores) do
            if store.blip then
                local base = clean.blips[store.kind]

                store.blip = {
                    sprite = store.blip.sprite or base.sprite,
                    color = store.blip.color or base.color,
                    scale = store.blip.scale or base.scale or 0.7,
                    label = store.blip.label,
                }
            end
        end
    end

    -- Store peds take the kind's model and animation, and stand at the store coords unless they set their own.
    if clean.stores and clean.peds then
        for index, store in ipairs(clean.stores) do
            if store.ped then
                local base = clean.peds[store.kind] or {}
                local model = store.ped.model or base.model

                if model then
                    local at = store.coords

                    store.ped = {
                        model = model,
                        coords = store.ped.coords or vector4(at.x, at.y, at.z, 0.0),
                        animation = store.ped.animation or base.animation,
                    }
                else
                    errors[#errors + 1] = ('stores[%d].ped: MUST set a model, peds.%s has none'):format(index, store.kind)
                end
            end
        end
    end

    return clean, errors
end

---@type table?
local current = nil

---Reads, merges and checks config.lua. Generates it from the example when missing.
---@return boolean ok
---@return string[] errors
function Config.Load()
    local content = LoadResourceFile(RESOURCE, OWNER_FILE)

    if content == nil then
        local example = LoadResourceFile(RESOURCE, DEFAULT_FILE)

        if example and SaveResourceFile(RESOURCE, OWNER_FILE, example, -1) then
            UgCore.Logger.Info('Generated %s.', OWNER_FILE)
        end

        content = example
    end

    local values = UgAp.Internal.Defaults()

    if content then
        local ok, owner, message = run(content)

        if not ok or not owner then
            current = nil

            return false, { ('%s: %s'):format(OWNER_FILE, tostring(message)) }
        end

        for key in pairs(REPLACED) do
            if owner[key] ~= nil then
                values[key] = owner[key]
            end
        end

        merge(values, owner)
    end

    local clean, errors = Config.Validate(values)

    for index, message in ipairs(errors) do
        errors[index] = ('%s: %s'):format(OWNER_FILE, message)
    end

    current = #errors == 0 and clean or nil

    return #errors == 0, errors
end

---The loaded config. Raises before a successful Load.
---@return table
function Config.Get()
    if not current then
        error('[ug-appearance] Config.Get before a successful Config.Load', 2)
    end

    return current
end

---Runs owner code like Load does, for tests that compare server/config.default.lua with the defaults.
Config.Run = run
