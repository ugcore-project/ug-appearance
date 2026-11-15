--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---Starts the server side with an owner config.lua, or none.
---@param owner? string
---@return string[] lines
local function start(owner)
    H.Reset()

    if owner then
        H.Files['config.lua'] = owner
    end

    return H.Load('server')
end

---@param lines string[]
---@return string[] errors without the file prefix
local function errorsOf(lines)
    local errors = {}

    for _, line in ipairs(lines) do
        local message = line:match('%[ERROR%] config%.lua: (.+)$')

        if message then
            errors[#errors + 1] = message
        end
    end

    return errors
end

---@param body string the inside of `return { ... }`
---@return string[] errors
local function errorsFor(body)
    return errorsOf(start('return { ' .. body .. ' }'))
end

print('config')

H.Test('generates config.lua from the example on the first start and starts', function()
    local lines = start()

    H.Assert(H.Saved['config.lua'] ~= nil, 'config.lua not generated')
    H.ExpectLine(lines, '[ug-appearance] v1.0.0 ready: 28 stores, 2 models.')
    H.Assert(UgAp.Internal.Ready)
end)

H.Test('an empty owner file uses every default', function()
    local lines = start('return {}')

    H.ExpectLine(lines, 'ready: 28 stores')
end)

H.Test('store blips take the kind defaults, false hides them', function()
    start([[return { stores = {
        { id = 'a', kind = 'barber', coords = vector3(1.0, 2.0, 3.0), blip = true },
        { id = 'b', kind = 'barber', coords = vector3(1.0, 2.0, 3.0), blip = { color = 5, label = 'Cuts' } },
        { id = 'c', kind = 'wardrobe', coords = vector3(1.0, 2.0, 3.0), blip = false, job = 'police' },
    } }]])

    local stores = UgAp.Internal.Config.Get().stores

    H.Equal(stores[1].blip, {
        sprite = 71,
        color = 0,
        scale = 0.7,
    })
    H.Equal(stores[2].blip, {
        sprite = 71,
        color = 5,
        scale = 0.7,
        label = 'Cuts',
    })
    H.Equal(stores[3].blip, nil)
end)

H.Test('store peds take the kind defaults and stand at the store unless they set coords', function()
    start([[return { stores = {
        { id = 'a', kind = 'barber', coords = vector3(1.0, 2.0, 3.0), ped = true },
        { id = 'b', kind = 'tattoo', coords = vector3(1.0, 2.0, 3.0), ped = { model = 'a_m_y_hipster_01', coords = vector4(4.0, 5.0, 6.0, 90.0) } },
        { id = 'c', kind = 'clothing', coords = vector3(1.0, 2.0, 3.0), ped = false },
    } }]])

    local stores = UgAp.Internal.Config.Get().stores

    H.Equal(stores[1].ped, {
        model = 's_f_m_fembarber',
        coords = vector4(1.0, 2.0, 3.0, 0.0),
        animation = {
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
    })
    H.Equal(stores[2].ped, {
        model = 'a_m_y_hipster_01',
        coords = vector4(4.0, 5.0, 6.0, 90.0),
        animation = {
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
    })
    H.Equal(stores[3].ped, nil)
end)

H.Test('a store ped needs a model, and animations are well formed', function()
    H.ExpectLine(errorsFor([[stores = { { id = 'w', kind = 'wardrobe', coords = vector3(0.0, 0.0, 0.0), ped = true } }]]),
        'stores[1].ped: MUST set a model, peds.wardrobe has none')
    H.ExpectLine(errorsFor("peds = { barber = { model = 'x', animation = { name = 'n' } } }"), 'MUST have both dict and name')
    H.ExpectLine(errorsFor("peds = { barber = { model = 'x', animation = {} } }"), 'MUST be { dict, name, flag? } or { scenario }')
    H.ExpectLine(errorsFor("tattooOutfit = { male = { components = { cape = { drawable = 1, texture = 0 } } }, female = {} }"), 'tattooOutfit.male')
    H.Equal(errorsFor('tattooOutfit = false'), {})
end)

H.Test('reports every bad value with its path and stays idle', function()
    local lines = start([[return {
        models = {},
        stores = { { id = 'x', kind = 'creator', coords = vector3(0.0, 0.0, 0.0) } },
        prices = { component = -1 },
        maxOutfits = 500,
        adminCommand = 'two words',
    }]])
    local errors = errorsOf(lines)

    H.Equal(#errors, 5)
    H.ExpectLine(errors, 'models')
    H.ExpectLine(errors, 'stores[1].kind')
    H.ExpectLine(errors, 'prices.component')
    H.ExpectLine(errors, 'maxOutfits')
    H.ExpectLine(errors, 'adminCommand')
    H.ExpectLine(lines, 'Config invalid: 5 error(s). ug-appearance stays idle.')
    H.Assert(not UgAp.Internal.Ready)
end)

H.Test('unknown keys get a suggestion', function()
    H.ExpectLine(errorsFor("maxOutfit = 3"), 'unknown key "maxOutfit". Did you mean "maxOutfits"?')
end)

H.Test('interaction is the key or ug-target', function()
    H.ExpectLine(errorsFor("interaction = 'eye'"), 'interaction')
    H.Equal(#errorsFor("interaction = 'target'"), 0)
end)

H.Test('store ids are unique and poses are well formed', function()
    H.ExpectLine(errorsFor([[stores = {
        { id = 'a', kind = 'barber', coords = vector3(0.0, 0.0, 0.0) },
        { id = 'a', kind = 'tattoo', coords = vector3(0.0, 0.0, 0.0) },
    }]]), 'id "a" is used twice')
    H.ExpectLine(errorsFor("poses = { { id = 'x', dict = 'd' } }"), 'MUST have both dict and name')
    H.ExpectLine(errorsFor("poses = { { id = 'x', dict = 'd', name = 'n', scenario = 's' } }"), 'MUST be { id }')
end)

H.Test('uniform outfits MUST use known parts', function()
    H.ExpectLine(errorsFor("uniforms = { police = { { label = 'Patrol', male = { components = { hats = { drawable = 1, texture = 0 } } } } } }"), 'uniforms')
    H.Equal(errorsFor("uniforms = { police = { { label = 'Patrol', grades = { 1, 2 }, male = { components = { top = { drawable = 55, texture = 0 } } } } } }"), {})
end)

H.Test('camera distances MUST be in order', function()
    H.ExpectLine(errorsFor('camera = { minDistance = 3.0, maxDistance = 2.0 }'), 'minDistance MUST NOT be greater than maxDistance')
end)

H.Test('look tables merge onto the defaults, sounds replace', function()
    start([[return {
        layout = { side = 'right' },
        features = { zoom = false },
        controls = { keyRotate = 0 },
        studio = { nightHour = 1 },
        camera = { zoomDuration = 0 },
        soundEffects = { error = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' } },
        lights = { 'studio' },
        theme = { colors = { clothing = '200 80% 55%' } },
    }]])

    local config = UgAp.Internal.Config.Get()
    local defaults = UgAp.Internal.Defaults()

    H.Equal(config.layout.side, 'right')
    H.Equal(config.layout.width, defaults.layout.width)
    H.Equal(config.features.zoom, false)
    H.Equal(config.features.undo, true)
    H.Equal(config.controls.keyRotate, 0)
    H.Equal(config.controls.dragSpeed, defaults.controls.dragSpeed)
    H.Equal(config.studio.nightHour, 1)
    H.Equal(#config.studio.lights, 3)
    H.Equal(config.camera.zoomDuration, 0)
    H.Equal(config.soundEffects, {
        error = {
            name = 'ERROR',
            set = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
        },
    })
    H.Equal(config.lights, { 'studio' })
    H.Equal(config.theme.colors.clothing, '200 80% 55%')
end)

H.Test('bad look values are reported', function()
    local errors = errorsFor([[
        layout = { side = 'top' },
        features = { zoom = 'no' },
        lights = { 'disco' },
        studio = { lights = { { angle = 0, distance = 1, height = 0, color = { 1, 2 }, range = 1, intensity = 1 } } },
        soundEffects = { open = { name = 'A', set = 'B' } },
        theme = { colors = { clothing = '#ff0000' } },
    ]])

    for _, key in ipairs({ 'layout', 'features', 'lights', 'studio', 'soundEffects', 'theme' }) do
        H.ExpectLine(errors, key)
    end

    H.ExpectLine(errorsFor("lights = { 'day', 'day' }"), 'light "day" is listed twice')
end)

H.Test('a syntax error is one error', function()
    local errors = errorsOf(start('return {'))

    H.Equal(#errors, 1)
end)

H.Test('stays idle when ug-core is not ready or characters are disabled', function()
    H.Reset()
    H.CoreReady = false
    H.ExpectLine(H.Load('server'), 'ug-core did not become ready')

    H.Reset()
    H.Modules = {}
    H.ExpectLine(H.Load('server'), "characters module is disabled")
end)

H.Done()
