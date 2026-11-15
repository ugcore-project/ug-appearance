--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local MALE, FEMALE = 'mp_m_freemode_01', 'mp_f_freemode_01'

---@param path string
---@return string
local function read(path)
    local handle = assert(io.open(path, 'rb'))
    local source = handle:read('a')

    handle:close()

    return source
end

---Decodes the JSON subset the locale files use: objects and strings. The json global is a mock in tests.
---@param source string
---@return table
local function decodeLocale(source)
    local position = 1

    local function skip()
        position = source:find('[^%s]', position) or #source + 1
    end

    local function expect(char)
        skip()
        assert(source:sub(position, position) == char, ('expected %s at %d'):format(char, position))
        position = position + 1
    end

    local function str()
        expect('"')

        local parts = {}

        while true do
            local char = source:sub(position, position)

            assert(char ~= '', 'unterminated string')

            if char == '"' then
                position = position + 1

                return table.concat(parts)
            elseif char == '\\' then
                parts[#parts + 1] = source:sub(position + 1, position + 1)
                position = position + 2
            else
                parts[#parts + 1] = char
                position = position + 1
            end
        end
    end

    local object

    local function value()
        skip()

        return source:sub(position, position) == '{' and object() or str()
    end

    function object()
        expect('{')

        local result = {}

        skip()

        if source:sub(position, position) == '}' then
            position = position + 1

            return result
        end

        while true do
            local key = str()

            expect(':')
            assert(result[key] == nil, 'duplicate key ' .. key)
            result[key] = value()
            skip()

            local char = source:sub(position, position)

            position = position + 1

            if char == '}' then
                return result
            end

            assert(char == ',', 'expected , or }')
        end
    end

    return object()
end

---Dotted keys of a decoded locale group, sorted.
---@param group table
---@param prefix? string
---@param keys? string[]
---@return string[]
local function flatKeys(group, prefix, keys)
    keys = keys or {}

    for key, value in pairs(group) do
        if type(value) == 'table' then
            flatKeys(value, (prefix or '') .. key .. '.', keys)
        else
            keys[#keys + 1] = (prefix or '') .. key
        end
    end

    if not prefix then
        table.sort(keys)
    end

    return keys
end

---Reads `export const <name> = { ... }` of protocol.ts.
---@param source string
---@param name string
---@return table<string, string>
local function tsEnum(source, name)
    local block = assert(source:match('export const ' .. name .. ' = (%b{})'), name .. ' missing in protocol.ts')
    local values = {}

    for key, value in block:gmatch('(%w+): "([^"]+)"') do
        values[key] = value
    end

    return values
end

---@param extra? table owner values added to the Setup answer
local function start(extra)
    H.Reset()
    H.Respond.Setup = function()
        local answer = {
            ok = true,
            stores = {},
            models = { MALE, FEMALE },
            maxTattoos = 2,
            poses = {
                {
                    id = 'idle',
                },
                {
                    id = 'handsUp',
                    dict = 'missminuteman_1ig_2',
                    name = 'handsup_base',
                },
            },
            camera = {
                duration = 600, ease = 'inOut', minDistance = 0.5, maxDistance = 4.0,
                presets = {
                    face = {
                        distance = 0.8,
                        height = 0.65,
                        fov = 35,
                    },
                    upper = {
                        distance = 1.5,
                        height = 0.3,
                        fov = 40,
                    },
                    lower = {
                        distance = 1.6,
                        height = -0.45,
                        fov = 40,
                    },
                    feet = {
                        distance = 1.2,
                        height = -0.85,
                        fov = 40,
                    },
                    full = {
                        distance = 2.8,
                        height = 0.0,
                        fov = 45,
                    },
                },
            },
            interactKey = 'E',
        }

        for key, value in pairs(extra or {}) do
            answer[key] = value
        end

        return answer
    end
    H.Load('client')
end

---Opens a clothing session with the page ready.
local function open()
    start()
    H.PostNui('ready', {})
    H.ClientEvents.Open({
        ok = true,
        kind = 'clothing',
        prices = {
            component = 60,
            prop = 40,
            overlay = 30,
            hair = 80,
            heritage = 1500,
            features = 1000,
            eyes = 300,
            skin = 200,
            tattoo = 150,
            tattooRemoval = 50,
        },
        free = false,
        appearance = UgAp.Internal.Appearance.Default(MALE),
        outfits = {
            {
                id = 3,
                name = 'Gym',
            },
        },
        uniforms = { 'Police' },
    })
    H.Advance(1000)
end

print('nui')

H.Test('Lua and the page agree on every enum they share', function()
    start()

    local source = read('web/src/types/protocol.ts')

    for _, name in ipairs({
        'NuiAction',
        'NuiCallback',
        'Category',
        'StoreKind',
        'Camera',
        'Light',
        'ResultKind',
        'Side',
        'Place',
        'Feature',
    }) do
        H.Equal(tsEnum(source, name), UgAp.Enums[name], name)
    end
end)

H.Test('locales/en.json has exactly the labels the page uses', function()
    start()

    local expected = { table.unpack(UgAp.Internal.Nui.LabelKeys) }

    table.sort(expected)
    H.Equal(flatKeys(decodeLocale(read('locales/en.json')).page), expected)
end)

H.Test('every locale has the same keys as English', function()
    local english = flatKeys(decodeLocale(read('locales/en.json')))

    H.Equal(flatKeys(decodeLocale(read('locales/pt.json'))), english)
end)

H.Test('messages wait for the page, then config comes first with labels', function()
    start()
    H.ClientEvents.Open({
        ok = true,
        kind = 'barber',
        prices = {},
        free = true,
        appearance = UgAp.Internal.Appearance.Default(MALE),
    })
    H.Advance(16)
    H.Equal(#H.PageMessages(), 0, 'nothing sent before ready')

    H.Equal(H.PostNui('ready', {}), {
        ok = true,
    })

    local messages = H.PageMessages()

    H.Equal(messages[1].action, 'config')
    H.Equal(messages[1].payload.labels['camera.face'], 'label:page.camera.face')
    H.Equal(messages[1].payload.locale, 'en')
    H.Equal(messages[2].action, 'open')
end)

H.Test('the page gets the owner look, the theme merged onto ug-lib', function()
    start({
        theme = {
            colors = {
                clothing = '200 80% 55%',
            },
        },
        layout = {
            side = 'right',
        },
        features = {
            zoom = false,
        },
        controls = {
            keyRotate = 0,
        },
        lights = { 'studio' },
    })
    H.PostNui('ready', {})
    H.Advance(16)

    local config = H.LastPage('config')

    H.Equal(config.theme.colors.clothing, '200 80% 55%')
    H.Equal(config.layout, {
        side = 'right',
    })
    H.Equal(config.features, {
        zoom = false,
    })
    H.Equal(config.controls, {
        keyRotate = 0,
    })
    H.Equal(config.lights, { 'studio' })
    H.Equal(UgAp.Internal.Nui.Theme({
        colors = {
            primary = '1 1% 1%',
        },
    }, {
        colors = {
            eyes = '2 2% 2%',
        },
    }).colors, {
        primary = '1 1% 1%',
        eyes = '2 2% 2%',
    })
    H.Equal(UgAp.Internal.Nui.Theme(nil, {
        colors = {
            eyes = '2 2% 2%',
        },
    }).colors, {
        eyes = '2 2% 2%',
    })
end)

H.Test('the page never receives prices or coordinates', function()
    open()

    local payload = H.LastPage('open')

    H.Equal(payload.prices, nil)
    H.Equal(payload.uniforms, { 'Police' })
    H.Equal(payload.poses[2], {
        id = 'handsUp',
        label = 'label:poses.handsUp',
    }, 'no animation names')
end)

H.Test('forged callback bodies are refused', function()
    open()

    local function look(edit)
        local value = UgAp.Internal.Appearance.Default(MALE)

        edit(value)

        return {
            appearance = value,
        }
    end

    for label, case in pairs({
        cameraUnknown = {
            'camera',
            {
                preset = 'drone',
            },
        },
        rotateHuge = {
            'rotate',
            {
                delta = 1000,
            },
        },
        rotateString = {
            'rotate',
            {
                delta = '10',
            },
        },
        rotateNaN = {
            'rotate',
            {
                delta = 0 / 0,
            },
        },
        zoomHuge = {
            'zoom',
            {
                delta = -50,
            },
        },
        poseUnknown = {
            'pose',
            {
                id = 'dance',
            },
        },
        poseNumber = {
            'pose',
            {
                id = 1,
            },
        },
        lightUnknown = {
            'light',
            {
                light = 'disco',
            },
        },
        compareString = {
            'compare',
            {
                active = 'yes',
            },
        },
        outfitEmpty = {
            'outfitSave',
            {
                name = '',
            },
        },
        outfitLong = {
            'outfitSave',
            {
                name = ('a'):rep(33),
            },
        },
        outfitControl = {
            'outfitSave',
            {
                name = 'a\0b',
            },
        },
        wearZero = {
            'outfitWear',
            {
                id = 0,
            },
        },
        wearFraction = {
            'outfitWear',
            {
                id = 1.5,
            },
        },
        deleteString = {
            'outfitDelete',
            {
                id = '3',
            },
        },
        replaceString = {
            'outfitReplace',
            {
                id = 'x',
            },
        },
        renameNoName = {
            'outfitRename',
            {
                id = 1,
            },
        },
        renameLong = {
            'outfitRename',
            {
                id = 1,
                name = ('a'):rep(33),
            },
        },
        renameExtra = {
            'outfitRename',
            {
                id = 1,
                name = 'A',
                owner = 2,
            },
        },
        uniformHuge = {
            'uniformWear',
            {
                index = 101,
            },
        },
        changeNotTable = { 'change', 'mp_m_freemode_01' },
        changeExtraKey = { 'change', look(function(a) a.admin = true end) },
        changeTattoos = { 'change', look(function(a)
            a.tattoos = {
                {
                    collection = 1,
                    overlay = 1,
                },
                {
                    collection = 1,
                    overlay = 2,
                },
                {
                    collection = 1,
                    overlay = 3,
                },
            }
        end) },
        changeBadModel = { 'change', look(function(a) a.model = 'bad model!' end) },
        changeHugeDrawable = { 'change', look(function(a) a.components.top.drawable = 1e9 end) },
    }) do
        H.Equal(H.PostNui(case[1], case[2]), {
            ok = false,
        }, label)
    end

    H.Equal(#H.Requests, 1, 'only Setup reached the server')
end)

H.Test('valid bodies pass', function()
    open()

    H.Equal(H.PostNui('camera', {
        preset = 'face',
    }), {
        ok = true,
    })
    H.Equal(H.PostNui('rotate', {
        delta = -45,
    }), {
        ok = true,
    })
    H.Equal(H.PostNui('pose', {
        id = 'handsUp',
    }), {
        ok = true,
    })
    H.Equal(H.PostNui('compare', {
        active = false,
    }), {
        ok = true,
    }, 'false is a value')
    H.Equal(H.PostNui('outfitSave', {
        name = 'Noite',
    }), {
        ok = true,
    })
    H.Equal(H.PostNui('outfitReplace', {
        id = 3,
    }), {
        ok = true,
    })
    H.Equal(H.PostNui('outfitRename', {
        id = 3,
        name = 'Dia',
    }), {
        ok = true,
    })
end)

H.Test('too many callbacks in one second are refused', function()
    open()

    local refused = 0

    for _ = 1, 40 do
        if not H.PostNui('rotate', {
            delta = 1,
        }).ok then
            refused = refused + 1
        end
    end

    H.Equal(refused, 10)

    H.Advance(1000)
    H.Equal(H.PostNui('rotate', {
        delta = 1,
    }), {
        ok = true,
    }, 'the next second has a new budget')
end)

H.Done()
