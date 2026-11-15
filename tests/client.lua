--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local MALE, FEMALE = 'mp_m_freemode_01', 'mp_f_freemode_01'

---The server's Setup answer.
---@param stores? table[]
---@return table
local function setupAnswer(stores)
    return {
        ok = true,
        stores = stores or {
            {
                id = 'clothing1',
                kind = 'clothing',
                coords = vector3(1.0, 2.0, 3.0),
                radius = 2.0,
                blip = {
                    sprite = 73,
                    color = 47,
                    scale = 0.7,
                },
            },
            {
                id = 'cops',
                kind = 'wardrobe',
                coords = vector3(4.0, 5.0, 6.0),
                radius = 2.0,
            },
        },
        models = { MALE, FEMALE },
        maxTattoos = 5,
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
end

---@param edit? fun(appearance: table)
---@return table
local function appearance(edit)
    local value = UgAp.Internal.Appearance.Default(MALE)

    if edit then
        edit(value)
    end

    return value
end

---@param extra? table owner values added to the Setup answer
local function start(extra)
    H.Reset()
    H.Respond.Setup = function()
        local answer = setupAnswer()

        for key, value in pairs(extra or {}) do
            answer[key] = value
        end

        return answer
    end
    H.Load('client')
    H.PostNui('ready', {})
end

---A server Open answer for a kind.
---@param kind string
---@param saved? table
---@return table
local function session(kind, saved)
    return {
        ok = true,
        kind = kind,
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
        appearance = saved or appearance(),
        outfits = {},
        uniforms = {},
    }
end

---Opens a store session from the server's push.
---@param kind string
---@param saved? table
local function open(kind, saved)
    H.ClientEvents.Open(session(kind, saved))
    H.Advance(16)
end

---@param name string
---@return { name: string, args: any[] }[]
local function calls(name)
    return H.CallsOf(name)
end

print('client')

H.Test('boot reads the setup, places blips and points, and binds the key once', function()
    start()

    H.Equal(H.Requests[1].name, 'Setup')
    H.Equal(#calls('AddBlipForCoord'), 1)
    H.Equal(#H.Points, 2)
    H.Equal(#H.Keybinds, 1)
    H.Equal(H.Keybinds[1].defaultKey, 'E')
end)

H.Test('walking into a store shows the prompt; the key opens it through the server', function()
    start()
    H.Respond.Open = function(id)
        H.Equal(id, 'clothing1')

        return session('clothing')
    end

    H.Points[1].options.onEnter()
    H.Equal(#calls('TextUI.Show'), 1)
    H.Equal(calls('TextUI.Show')[1].args[1].key, 'E')

    -- The player rebinds the key: the next prompt shows it.
    H.BoundKeys.interact = 'G'
    H.Points[1].options.onExit()
    H.Points[1].options.onEnter()
    H.Equal(calls('TextUI.Show')[2].args[1].key, 'G')

    H.Keybinds[1].onPressed()
    H.Advance(16)

    H.Assert(UgAp.Internal.Editor.IsOpen())
    H.Equal(H.LastPage('open').kind, 'clothing')
    H.Equal(H.LastPage('open').categories, { 'clothing', 'accessories' })
    H.Equal(calls('SetNuiFocus')[1].args, { true, true })
end)

H.Test('stores with a ped get a clerk, hidden while an editor runs', function()
    H.Reset()
    H.Respond.Setup = function()
        return setupAnswer({
            { id = 'barber1', kind = 'barber', coords = vector3(1.0, 2.0, 3.0), radius = 2.0,
                ped = {
                    model = 's_f_m_fembarber',
                    coords = vector4(1.0, 2.0, 3.0, 90.0),
                    animation = {
                        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
                    },
                } },
            {
                id = 'barber2',
                kind = 'barber',
                coords = vector3(9.0, 9.0, 9.0),
                radius = 2.0,
            },
        })
    end
    H.Load('client')
    H.PostNui('ready', {})

    H.Equal(#H.Npcs, 1)

    local npc = H.Npcs[1]

    H.Equal(npc.options.model, 's_f_m_fembarber')
    H.Equal(npc.options.coords, vector4(1.0, 2.0, 3.0, 90.0))
    H.Equal(npc.options.animation, {
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    })

    npc.ped = 77
    npc.options.onSpawn(npc)
    H.Natives = {}

    open('barber')
    H.Equal(calls('SetEntityVisible')[1].args, { 77, false })
    H.Equal(calls('SetEntityCollision')[1].args, { 77, false })

    H.Natives = {}
    H.PostNui('cancel', {})
    H.Advance(16)
    H.Equal(calls('SetEntityVisible')[1].args, { 77, true })

    UgAp.Internal.Stores.Clear()
    H.Assert(npc.removed, 'the clerk is removed with the stores')
end)

---A ug-target stand-in that records zones and clerk options.
---@return table
local function fakeTarget()
    local fake = {
        zones = {},
        entities = {},
        removed = {},
        nextZone = 0,
    }

    H.NativeReturns.GetResourceState = function(name)
        return name == 'ug-target' and 'started' or 'missing'
    end
    H.Remote['ug-target'] = {
        AddSphereZone = function(_, input)
            fake.nextZone = fake.nextZone + 1
            fake.zones[fake.nextZone] = input

            return fake.nextZone
        end,
        RemoveZone = function(_, id)
            fake.removed[#fake.removed + 1] = id
            fake.zones[id] = nil
        end,
        AddLocalEntity = function(_, ped, option)
            fake.entities[ped] = option
        end,
        RemoveLocalEntity = function(_, ped)
            fake.entities[ped] = nil
        end,
    }

    return fake
end

---Boots with interaction = 'target'.
---@param stores? table[]
local function startTarget(stores)
    H.Reset()

    local fake = fakeTarget()

    H.Respond.Setup = function()
        local answer = setupAnswer(stores)

        answer.interaction = 'target'

        return answer
    end
    H.Load('client')
    H.PostNui('ready', {})

    return fake
end

H.Test('with ug-target, stores are zones: no prompt, no key', function()
    local fake = startTarget()

    H.Equal(#H.Points, 0)
    H.Equal(#H.Keybinds, 0)
    H.Equal(#calls('AddBlipForCoord'), 1, 'blips stay')

    local zone = fake.zones[1]

    H.Equal(zone.name, 'ug-appearance:clothing1')
    H.Equal(zone.coords, vector3(1.0, 2.0, 3.0))
    H.Equal(zone.radius, 2.0)
    H.Equal(zone.options.name, 'store:clothing1')
    H.Equal(zone.options.icon, 'shirt')
    H.Equal(fake.zones[2].options.name, 'store:cops')
end)

H.Test('the target option opens the store through the server, only within its radius', function()
    local fake = startTarget()
    local option = fake.zones[1].options

    H.Respond.Open = function(id)
        H.Equal(id, 'clothing1')

        return session('clothing')
    end
    H.Entities[1] = {
        coords = vector3(20.0, 2.0, 3.0),
    }

    H.Equal(option.canInteract(), false, 'too far from the store')

    H.Entities[1] = {
        coords = vector3(1.5, 2.0, 3.0),
    }

    H.Equal(option.canInteract(), true)

    option.onSelect({})
    H.Advance(16)

    H.Assert(UgAp.Internal.Editor.IsOpen())
    H.Equal(option.canInteract(), false, 'hidden while the editor runs')
end)

H.Test('clerks get the store option while spawned', function()
    local fake = startTarget({
        { id = 'barber1', kind = 'barber', coords = vector3(1.0, 2.0, 3.0), radius = 2.0,
            ped = {
                model = 's_f_m_fembarber',
                coords = vector4(1.0, 2.0, 3.0, 90.0),
            } },
    })
    local npc = H.Npcs[1]

    H.Equal(next(fake.zones), nil, 'a store with a clerk has no zone')

    npc.ped = 77
    npc.options.onSpawn(npc)

    H.Equal(fake.entities[77].name, 'store:barber1')
    H.Equal(fake.entities[77].icon, 'scissors')

    npc.options.onDespawn(npc)

    H.Equal(fake.entities[77], nil)

    npc.options.onSpawn(npc)
    UgAp.Internal.Stores.Clear()

    H.Equal(fake.entities[77], nil, 'cleared with the stores')
    H.Equal(fake.removed, {})
end)

H.Test('target mode falls back to the key without ug-target, and rebuilds when it starts', function()
    H.Reset()
    H.NativeReturns.GetResourceState = 'missing'
    H.Respond.Setup = function()
        local answer = setupAnswer()

        answer.interaction = 'target'

        return answer
    end

    local lines = H.Load('client')

    H.PostNui('ready', {})

    H.Assert(H.Contains(lines, 'ug-target is not started. Using the interact key.'), 'warns once')
    H.Equal(#H.Points, 2)
    H.Equal(#H.Keybinds, 1)

    local fake = fakeTarget()

    H.TriggerEvent('onClientResourceStart', nil, 'ug-target')

    H.Equal(fake.nextZone, 2)
    H.Equal(#calls('Point.Remove'), 2, 'the prompt points go')
end)

H.Test('a refused Open shows the reason and opens nothing', function()
    start()
    H.Respond.Open = function()
        return {
            ok = false,
            error = 'insufficient_funds',
        }
    end

    H.Points[1].options.onEnter()
    H.Keybinds[1].onPressed()
    H.Advance(16)

    H.Assert(not UgAp.Internal.Editor.IsOpen())
    H.Equal(H.Notified[1].message, 'label:page.errorFunds')
end)

H.Test('the studio freezes the ped and frames it', function()
    start()
    open('clothing')

    H.Equal(calls('FreezeEntityPosition')[1].args, { 1, true })
    H.Equal(calls('SetEntityInvincible')[1].args, { 1, true })
    H.Assert(#calls('CreateCamWithParams') == 1)
    H.Assert(#calls('DisableAllControlActions') > 0)
end)

H.Test('changes inside the session apply live, only what changed, and update the bill', function()
    start()
    open('clothing')
    H.Natives = {}

    H.Equal(H.PostNui('change', {
        appearance = appearance(function(a) a.components.top.drawable = 4 end),
    }), {
        ok = true,
    })

    local applied = calls('SetPedComponentVariation')

    H.Equal(#applied, 1)
    H.Equal(applied[1].args, { 1, 11, 4, 0, 0 })
    H.Equal(H.LastPage('bill').total, 60)
end)

H.Test('changes outside the session are dropped', function()
    start()
    open('barber')
    H.Natives = {}

    H.PostNui('change', { appearance = appearance(function(a)
        a.components.top.drawable = 4
        a.hair.style = 3
    end) })

    H.Equal(#calls('SetPedComponentVariation'), 1)
    H.Equal(calls('SetPedComponentVariation')[1].args[2], 2)
    H.Equal(H.LastPage('bill').total, 80)
end)

H.Test('save sends the edit to the server and closes without reverting', function()
    start()
    open('clothing')

    local edited = appearance(function(a) a.props.hat.drawable = 2 end)

    H.Respond.Save = function(value)
        return {
            ok = true,
            appearance = value,
            total = 40,
        }
    end
    H.PostNui('change', {
        appearance = edited,
    })
    H.Natives = {}
    H.PostNui('save', {})
    H.Advance(16)

    H.Equal(H.Requests[#H.Requests].args[1], edited)
    H.Assert(not UgAp.Internal.Editor.IsOpen())
    H.Equal(#calls('SetPedPropIndex'), 0)
    H.Equal(calls('SetNuiFocus')[1].args, { false, false })
    H.Assert(H.LastPage('close') == nil and #H.PageMessages() > 0)
end)

H.Test('a refused save keeps the editor open with the reason', function()
    start()
    open('clothing')
    H.Respond.Save = function()
        return {
            ok = false,
            error = 'insufficient_funds',
        }
    end

    H.PostNui('save', {})
    H.Advance(16)

    H.Assert(UgAp.Internal.Editor.IsOpen())
    H.Equal(H.LastPage('result'), {
        kind = 'save',
        ok = false,
        message = 'label:page.errorFunds',
    })
end)

H.Test('cancel puts the saved appearance back and tells the server', function()
    start()
    open('clothing')
    H.Respond.Close = function()
        return {
            ok = true,
        }
    end

    H.PostNui('change', {
        appearance = appearance(function(a) a.components.top.drawable = 4 end),
    })
    H.Natives = {}
    H.PostNui('cancel', {})
    H.Advance(16)

    H.Assert(not UgAp.Internal.Editor.IsOpen())
    H.Equal(H.Requests[#H.Requests].name, 'Close')
    H.Assert(#calls('SetPedComponentVariation') >= 10)
    H.Equal(calls('FreezeEntityPosition')[1].args, { 1, false })
end)

H.Test('tattoo stores undress the ped and dress it again on save', function()
    start()

    local answer = session('tattoo')

    answer.undress = {
        components = {
            top = {
                drawable = 15,
                texture = 0,
            },
        },
        props = {
            hat = {
                drawable = -1,
                texture = 0,
            },
        },
    }
    H.Natives = {}
    H.ClientEvents.Open(answer)
    H.Advance(16)

    local tops = calls('SetPedComponentVariation')

    H.Equal(tops[#tops].args, { 1, 11, 15, 0, 0 }, 'the top comes off')
    H.Equal(H.LastPage('open').appearance.components.top.drawable, 0, 'the page keeps the real clothes')
    H.Equal(H.LastPage('bill').total, 0, 'undressing is free')

    H.Respond.Save = function(value)
        return {
            ok = true,
            appearance = value,
            total = 0,
        }
    end
    H.Natives = {}
    H.PostNui('save', {})
    H.Advance(16)

    tops = calls('SetPedComponentVariation')
    H.Assert(not UgAp.Internal.Editor.IsOpen())
    H.Equal(tops[#tops].args, { 1, 11, 0, 0, 0 }, 'dressed again')
end)

H.Test('compare shows the saved look while held', function()
    start()
    open('clothing')
    H.PostNui('change', {
        appearance = appearance(function(a) a.components.top.drawable = 4 end),
    })
    H.Natives = {}

    H.PostNui('compare', {
        active = true,
    })
    H.Equal(calls('SetPedComponentVariation')[1].args, { 1, 11, 0, 0, 0 })

    H.PostNui('compare', {
        active = false,
    })
    H.Equal(calls('SetPedComponentVariation')[2].args, { 1, 11, 4, 0, 0 })
end)

H.Test('camera, zoom, turn, pose and light reach the studio', function()
    start()
    open('clothing')
    H.Natives = {}

    H.PostNui('rotate', {
        delta = 45,
    })
    H.Equal(calls('SetEntityHeading')[1].args, { 1, 135.0 })

    H.PostNui('light', {
        light = 'night',
    })
    H.Equal(calls('NetworkOverrideClockTime')[1].args, { 23, 0, 0 })

    H.PostNui('pose', {
        id = 'handsUp',
    })
    H.Advance(16)
    H.Equal(calls('Animation.Play')[1].args[3], 'handsup_base')

    H.PostNui('camera', {
        preset = 'face',
    })
    H.PostNui('zoom', {
        delta = -10,
    })
    H.Advance(1000)
    H.Assert(#calls('SetCamCoord') > 0)
end)

H.Test('tools the owner turned off are refused, not only hidden', function()
    start({
        features = {
            rotate = false,
            zoom = false,
            compare = false,
            poses = false,
        },
    })
    open('clothing')
    H.Natives = {}

    H.Equal(H.PostNui('rotate', {
        delta = 45,
    }), {
        ok = false,
    })
    H.Equal(H.PostNui('zoom', {
        delta = 1,
    }), {
        ok = false,
    })
    H.Equal(H.PostNui('compare', {
        active = true,
    }), {
        ok = false,
    })
    H.Equal(H.PostNui('pose', {
        id = 'handsUp',
    }), {
        ok = false,
    })
    H.Equal(#calls('SetEntityHeading'), 0)
    H.Equal(H.PostNui('camera', {
        preset = 'face',
    }), {
        ok = true,
    })
end)

H.Test('the studio opens on the first owner light, with the owner clock and lamps', function()
    start({
        lights = { 'night', 'studio' },
        studio = {
            dayHour = 10,
            nightHour = 2,
            lights = {
                {
                    angle = 0,
                    distance = 1.0,
                    height = 0.5,
                    color = { 1, 2, 3 },
                    range = 2.0,
                    intensity = 1.0,
                },
            },
        },
    })
    open('clothing')

    H.Equal(calls('NetworkOverrideClockTime')[1].args, { 2, 0, 0 })
    H.Equal(H.PostNui('light', {
        light = 'day',
    }), {
        ok = false,
    })

    H.PostNui('light', {
        light = 'studio',
    })
    H.Advance(16)

    local lamps = calls('DrawLightWithRangeAndShadow')

    H.Assert(#lamps > 0, 'no lamps drawn')
    H.Equal({ lamps[#lamps].args[4], lamps[#lamps].args[5], lamps[#lamps].args[6] }, { 1, 2, 3 })
end)

H.Test('saving and refusals play the owner sounds, and a sound left out is silent', function()
    start({
        soundEffects = {
            save = {
                name = 'BUY',
                set = 'SHOP',
            },
        },
    })
    open('clothing')

    H.Respond.Save = function()
        return {
            ok = false,
            error = 'insufficient_funds',
        }
    end
    H.PostNui('save', {})
    H.Advance(16)
    H.Equal(#calls('PlaySoundFrontend'), 0)

    H.Respond.Save = function(value)
        return {
            ok = true,
            appearance = value,
            total = 0,
        }
    end
    H.PostNui('save', {})
    H.Advance(16)
    H.Equal(calls('PlaySoundFrontend')[1].args, { -1, 'BUY', 'SHOP', true })
end)

H.Test('closing restores the clock', function()
    start()
    open('clothing')
    H.PostNui('light', {
        light = 'day',
    })
    H.Respond.Close = function()
        return {
            ok = true,
        }
    end
    H.PostNui('cancel', {})

    H.Equal(#calls('NetworkClearClockTimeOverride'), 1)
end)

H.Test('wearing an outfit replaces the saved clothing and keeps the editor open', function()
    start()
    open('clothing')

    local worn = appearance(function(a) a.components.top.drawable = 9 end)

    H.Respond.WearOutfit = function(id)
        H.Equal(id, 3)

        return {
            ok = true,
            appearance = worn,
        }
    end
    H.PostNui('outfitWear', {
        id = 3,
    })
    H.Advance(16)

    H.Assert(UgAp.Internal.Editor.IsOpen())
    H.Equal(H.LastPage('appearance').saved, worn)
    H.Equal(H.LastPage('bill').total, 0)
end)

H.Test('the creator edits its own ped, sends Pending and returns the result', function()
    start()
    H.Respond.Pending = function()
        return {
            ok = true,
        }
    end

    local original = CreatePed(4, MALE, 0.0, 0.0, 0.0, 0.0, false, false)
    ---@type any
    local result = 'unset'

    CreateThread(function()
        result = UgAp.Internal.Editor.OpenCreator(original, {
            models = { MALE, FEMALE },
        })
    end)

    H.Advance(16)
    H.Equal(H.Entities[original].visible, false)
    H.Equal(H.LastPage('open').kind, 'creator')
    H.Equal(H.LastPage('open').models, { MALE, FEMALE })

    local edited = appearance(function(a) a.hair.style = 7 end)

    H.PostNui('change', {
        appearance = edited,
    })
    H.PostNui('save', {})
    H.Advance(32)

    H.Equal(result, edited)
    H.Equal(H.Requests[#H.Requests].name, 'Pending')
    H.Equal(H.Entities[original].visible, true)
    H.Assert(H.Entities[original + 1].deleted)
end)

H.Test('the creator swaps the model on a new ped with a fresh catalog', function()
    start()

    local original = CreatePed(4, MALE, 0.0, 0.0, 0.0, 0.0, false, false)
    ---@type any
    local result = 'unset'

    CreateThread(function()
        result = UgAp.Internal.Editor.OpenCreator(original, {})
    end)
    H.Advance(16)

    H.PostNui('change', {
        appearance = appearance(function(a) a.model = FEMALE end),
    })
    H.Advance(16)

    H.Equal(H.Entities[original + 2].model, FEMALE)
    H.Assert(H.Entities[original + 1].deleted)
    H.Equal(H.LastPage('catalog').appearance.model, FEMALE)

    H.PostNui('cancel', {})
    H.Advance(16)
    H.Equal(result, nil)
end)

H.Test('store sessions never change the model', function()
    start()
    open('clothing')
    H.Natives = {}

    H.PostNui('change', {
        appearance = appearance(function(a) a.model = FEMALE end),
    })
    H.Advance(16)

    H.Equal(#calls('SetPlayerModel'), 0)
end)

H.Test('the server Apply dresses the player', function()
    start()
    H.ClientEvents.Apply(appearance(function(a) a.eyeColor = 4 end))
    H.Advance(16)

    H.Equal(calls('SetPedEyeColor')[1].args, { 1, 4 })
end)

H.Test('the Apply export checks the appearance first', function()
    start()

    local ped = CreatePed(4, MALE, 0.0, 0.0, 0.0, 0.0, false, false)

    H.Equal(H.Exports.Apply(ped, {
        model = MALE,
    }), false)
    H.Equal(H.Exports.Apply(ped, appearance()), true)
end)

H.Test('a job change reads the setup again', function()
    start()

    local handler = calls('AddStateBagChangeHandler')[1].args[3]

    handler()
    H.Advance(600)

    H.Equal(#H.Requests, 2)
    H.Equal(#calls('RemoveBlip'), 1)
end)

H.Done()
