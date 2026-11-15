--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- The page bridge. The page is untrusted: every callback body is checked here before the editor sees it.

---@class UgAp.Internal.Nui
local Nui = {}
UgAp.Internal.Nui = Nui

local Appearance = UgAp.Internal.Appearance
local Enums = UgAp.Enums
local Action = Enums.NuiAction
local Callback = Enums.NuiCallback
local Schema = UgCore.Schema

-- Callbacks per second the page MAY send. Sliders send at most one per animation frame, throttled by the page.
local EVENTS_PER_SECOND = 30

---@param enum table<string, any>
---@return string[]
local function valuesOf(enum)
    local values = {}

    for _, value in pairs(enum) do
        values[#values + 1] = value
    end

    table.sort(values)

    return values
end

---Labels the page shows, from locales/<code>.json under `page`. tests/nui.lua checks the file has exactly these.
---@return string[]
local function labelKeys()
    local keys = {
        'title', 'save', 'pay', 'cancel', 'total', 'free', 'changes', 'noChanges', 'undo', 'redo', 'randomize', 'compare',
        'search', 'favorites', 'none', 'drawable', 'texture', 'color', 'highlight', 'opacity', 'style', 'secondColor',
        'shapeMix', 'skinMix', 'thirdMix', 'shapeFirst', 'shapeSecond', 'shapeThird', 'skinFirst', 'skinSecond', 'skinThird',
        'eyeColor', 'outfits', 'uniforms', 'outfitName', 'outfitSave', 'wear', 'delete', 'replace', 'rename', 'confirm',
        'outfitReplaceTitle', 'outfitReplaceHint', 'outfitDeleteTitle', 'outfitDeleteHint', 'leaveTitle', 'leaveHint', 'leave',
        'stay', 'errorFunds', 'errorDenied', 'errorInvalid', 'errorFailed', 'saved', 'tattooAdd', 'tattooRemove', 'tattoos',
        'hint', 'pose', 'lighting', 'view', 'empty', 'removed', 'modelMale', 'modelFemale',
    }

    for _, group in ipairs({
        {
            prefix = 'category.',
            list = valuesOf(Enums.Category),
        },
        {
            prefix = 'kind.',
            list = valuesOf(Enums.StoreKind),
        },
        {
            prefix = 'camera.',
            list = valuesOf(Enums.Camera),
        },
        {
            prefix = 'light.',
            list = valuesOf(Enums.Light),
        },
        {
            prefix = 'zone.',
            list = { '0', '1', '2', '3', '4', '5', 'other' },
        },
    }) do
        for _, value in ipairs(group.list) do
            keys[#keys + 1] = group.prefix .. value
        end
    end

    for _, group in ipairs({
        {
            prefix = 'component.',
            list = Appearance.Components,
        },
        {
            prefix = 'prop.',
            list = Appearance.Props,
        },
        {
            prefix = 'overlay.',
            list = Appearance.Overlays,
        },
        {
            prefix = 'feature.',
            list = Appearance.FaceFeatures,
        },
    }) do
        for _, entry in ipairs(group.list) do
            keys[#keys + 1] = group.prefix .. entry.key
        end
    end

    return keys
end

Nui.LabelKeys = labelKeys()

local ready = false
---@type table[] messages sent before the page was ready
local queue = {}
local budget = {
    second = -1,
    count = 0,
}
---@type table<UgApNuiCallback, fun(value: any)>
local handlers = {}
---@type table<string, boolean> pose ids the page MAY send
local poseIds = {}
---@type table<string, boolean> light presets the page MAY send
local lightIds = {}
---@type table the owner's page settings from the server's setup
local owner = {}
---@type UgSchemaRule
local appearanceRule = Appearance.Rule(nil, 0)

local translate = nil

---A label in the configured language.
---@param key string such as `page.save`
---@return string
function Nui.Label(key)
    translate = translate or UgLib.Locale.Create()

    return translate(key)
end

---An owner label, or the locale entry, or `fallback` when the locale has none.
---@param label string?
---@param key string
---@param fallback string
---@return string
function Nui.LabelOr(label, key, fallback)
    if label then
        return label
    end

    local text = Nui.Label(key)

    -- ug-lib returns the key itself when no locale has it.
    return text ~= key and text or fallback
end

---Sends a message, or queues it until the page is ready.
---@param action UgApNuiAction
---@param payload? table
function Nui.Send(action, payload)
    local message = {
        action = action,
        payload = payload,
    }

    if ready then
        SendNUIMessage(message)
    else
        queue[#queue + 1] = message
    end
end

---ug-lib's theme with the owner's ug-appearance theme on top. Colors merge token by token.
---@param base table? ug-lib's theme
---@param own table? the ug-appearance theme
---@return table
function Nui.Theme(base, own)
    base = type(base) == 'table' and base or {}
    own = type(own) == 'table' and own or {}

    local colors = {}

    -- Not ipairs over both: it stops at a missing ug-lib table and drops the owner colors.
    for index = 1, 2 do
        local source = index == 1 and base.colors or own.colors

        if type(source) == 'table' then
            for token, color in pairs(source) do
                colors[token] = color
            end
        end
    end

    return {
        mode = own.mode or base.mode,
        colors = colors,
        radius = own.radius or base.radius,
        font = own.font or base.font,
        scale = own.scale or base.scale,
    }
end

---The page config: the theme, labels in the configured language, and the owner's layout, tools and controls.
---@return table
local function config()
    local libConfig = GlobalState[UgLib.Enums.GlobalState.Config]
    local labels = {}

    for _, key in ipairs(Nui.LabelKeys) do
        labels[key] = Nui.Label('page.' .. key)
    end

    return {
        theme = Nui.Theme(type(libConfig) == 'table' and libConfig.theme or nil, owner.theme),
        labels = labels,
        locale = UgLib.Locale.GetCode(),
        layout = owner.layout,
        features = owner.features,
        controls = owner.controls,
        lights = owner.lights,
    }
end

---Whether the owner left a tool on. Tools missing from the setup are on.
---@param feature UgApFeature
---@return boolean
function Nui.HasFeature(feature)
    return not (type(owner.features) == 'table' and owner.features[feature] == false)
end

---What the page MAY send and how it looks, from the server's setup. Sends the page config again once it is ready.
---@param setup { maxTattoos: integer, poses: { id: string }[], lights?: string[], theme?: table, layout?: table, features?: table, controls?: table }
function Nui.Configure(setup)
    appearanceRule = Appearance.Rule(nil, setup.maxTattoos)
    poseIds, lightIds = {}, {}

    for _, pose in ipairs(setup.poses) do
        poseIds[pose.id] = true
    end

    for _, light in ipairs(setup.lights or valuesOf(Enums.Light)) do
        lightIds[light] = true
    end

    owner = {
        theme = setup.theme,
        layout = setup.layout,
        features = setup.features,
        controls = setup.controls,
        lights = setup.lights,
    }

    if ready then
        SendNUIMessage({
            action = Action.Config,
            payload = config(),
        })
    end
end

---Sets who receives a page intent.
---@param callback UgApNuiCallback
---@param handler fun(value: any)
function Nui.On(callback, handler)
    handlers[callback] = handler
end

---@return boolean
local function withinBudget()
    local second = GetGameTimer() // 1000

    if budget.second ~= second then
        budget.second, budget.count = second, 0
    end

    budget.count = budget.count + 1

    return budget.count <= EVENTS_PER_SECOND
end

---A reader that checks one field of the body with a rule.
---@param field string
---@param rule UgSchemaRule
---@return fun(body: any): any
local function fieldOf(field, rule)
    return function(body)
        if type(body) ~= 'table' then
            return nil
        end

        local ok, value = Schema.Check(rule, body[field])

        if not ok then
            return nil
        end

        return value
    end
end

local RENAME = Schema.Object({
    id = Schema.Integer({
        min = 1,
        max = 2147483647,
    }),
    name = Schema.String({
        min = 1,
        max = 32,
    }),
})

local READERS = {
    [Callback.Change] = function(body)
        return fieldOf('appearance', appearanceRule)(body)
    end,
    [Callback.Camera] = fieldOf('preset', Schema.Enum(valuesOf(Enums.Camera))),
    [Callback.Rotate] = fieldOf('delta', Schema.Number({
        min = -180,
        max = 180,
    })),
    [Callback.Zoom] = fieldOf('delta', Schema.Number({
        min = -5,
        max = 5,
    })),
    [Callback.Pose] = function(body)
        local id = type(body) == 'table' and body.id or nil

        return type(id) == 'string' and poseIds[id] and id or nil
    end,
    [Callback.Light] = function(body)
        local light = type(body) == 'table' and body.light or nil

        return type(light) == 'string' and lightIds[light] and light or nil
    end,
    [Callback.Compare] = fieldOf('active', Schema.Boolean()),
    [Callback.Save] = function()
        return true
    end,
    [Callback.Cancel] = function()
        return true
    end,
    [Callback.OutfitSave] = fieldOf('name', Schema.String({
        min = 1,
        max = 32,
    })),
    [Callback.OutfitWear] = fieldOf('id', Schema.Integer({
        min = 1,
        max = 2147483647,
    })),
    [Callback.OutfitDelete] = fieldOf('id', Schema.Integer({
        min = 1,
        max = 2147483647,
    })),
    [Callback.OutfitReplace] = fieldOf('id', Schema.Integer({
        min = 1,
        max = 2147483647,
    })),
    [Callback.OutfitRename] = function(body)
        local ok, value = Schema.Check(RENAME, body)

        return ok and value or nil
    end,
    [Callback.UniformWear] = fieldOf('index', Schema.Integer({
        min = 1,
        max = 100,
    })),
}

-- Callbacks a turned-off tool would send. They are refused, not only hidden.
local GATES = {
    [Callback.Rotate] = Enums.Feature.Rotate,
    [Callback.Zoom] = Enums.Feature.Zoom,
    [Callback.Compare] = Enums.Feature.Compare,
    [Callback.Pose] = Enums.Feature.Poses,
}

for name, read in pairs(READERS) do
    RegisterNUICallback(name, function(body, cb)
        local value = nil

        if withinBudget() and (not GATES[name] or Nui.HasFeature(GATES[name])) then
            value = read(body)
        end

        if value ~= nil and handlers[name] then
            handlers[name](value)
        end

        cb({
            ok = value ~= nil,
        })
    end)
end

RegisterNUICallback(Callback.Ready, function(_, cb)
    ready = true
    SendNUIMessage({
        action = Action.Config,
        payload = config(),
    })

    for _, message in ipairs(queue) do
        SendNUIMessage(message)
    end

    queue = {}
    cb({
        ok = true,
    })
end)
