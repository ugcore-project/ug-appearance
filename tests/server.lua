--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local MALE = 'mp_m_freemode_01'
local STORE = vector3(72.3, -1399.1, 29.4)
local BARBER = vector3(-814.3, -183.8, 37.6)

---Starts the server with player 1 loaded as character 1 near the first clothing store.
---@param owner? string config.lua
local function start(owner)
    H.Reset()
    H.Files['config.lua'] = owner or 'return {}'
    H.Modules = {
        characters = true,
        accounts = true,
        jobs = true,
        gangs = true,
    }
    H.Characters = {
        {
            id = 1,
            identifier = 'license:1',
            name = 'A',
            data = {
                model = MALE,
            },
        },
        {
            id = 2,
            identifier = 'license:2',
            name = 'B',
            data = {},
        },
    }
    H.Players[1].characterId = 1
    H.PedCoords[1] = STORE
    H.Load('server')
    H.Assert(UgAp.Internal.Ready, 'did not boot')
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

---@param name string
---@param target integer
---@return table?
local function sent(name, target)
    for _, entry in ipairs(H.Sent) do
        if entry.name == 'ug-appearance:' .. name and entry.target == target then
            return entry
        end
    end

    return nil
end

print('server')

H.Test('boot creates both tables and registers every callback', function()
    start()

    H.Equal(#H.DbCalls, 2)
    H.Assert(H.DbCalls[1]:find('ug_appearances'))
    H.Assert(H.DbCalls[2]:find('ug_outfits'))

    for _, name in ipairs({
        'Setup',
        'Open',
        'Save',
        'Close',
        'Pending',
        'Fetch',
        'SaveOutfit',
        'WearOutfit',
        'DeleteOutfit',
        'ReplaceOutfit',
        'RenameOutfit',
        'WearUniform',
    }) do
        H.Assert(H.Callbacks[name], 'missing ' .. name)
    end

    H.Equal(H.Callbacks.Open.options.requireAlive, true)
end)

H.Test('Setup lists stores only for loaded players, filtered by job', function()
    start([[return { stores = {
        { id = 'a', kind = 'barber', coords = vector3(1.0, 2.0, 3.0), blip = true },
        { id = 'b', kind = 'wardrobe', coords = vector3(1.0, 2.0, 3.0), job = 'police' },
    } }]])

    local result = assert(H.Call('Setup', 1))

    H.Equal(#result.stores, 1)
    H.Equal(result.stores[1].blip, {
        sprite = 71,
        color = 0,
        scale = 0.7,
    })
    H.Equal(result.stores[1].radius, 2.0)
    H.Equal(result.models, { MALE, 'mp_f_freemode_01' })

    H.Jobs[1] = {
        name = 'police',
        grade = 1,
    }
    H.Equal(#assert(H.Call('Setup', 1)).stores, 2)
    H.Equal(#assert(H.Call('Setup', 2)).stores, 0)
end)

H.Test('Open checks the store, the job and the distance', function()
    start([[return { stores = {
        { id = 'shop', kind = 'clothing', coords = vector3(72.3, -1399.1, 29.4) },
        { id = 'cops', kind = 'wardrobe', coords = vector3(72.3, -1399.1, 29.4), job = 'police' },
        { id = 'far', kind = 'barber', coords = vector3(0.0, 0.0, 0.0) },
    } }]])

    H.Equal(H.Call('Open', 1, 'nope'), {
        ok = false,
        error = 'not_found',
    })
    H.Equal(H.Call('Open', 1, 'cops'), {
        ok = false,
        error = 'no_permission',
    })
    H.Equal(H.Call('Open', 1, 'far'), {
        ok = false,
        error = 'no_permission',
    })
    H.Equal(H.Flags[1].violation, 'OutOfRange')

    local result = assert(H.Call('Open', 1, 'shop'))

    H.Equal(result.ok, true)
    H.Equal(result.kind, 'clothing')
    H.Equal(result.categories, { 'clothing', 'accessories' })
    H.Equal(result.appearance, appearance())
    H.Equal(result.outfits, {})
    H.Equal(result.prices.component, 60)
end)

H.Test('Setup sends store clerks, tattoo sessions get the undress outfit', function()
    start([[return { stores = {
        { id = 'ink', kind = 'tattoo', coords = vector3(72.3, -1399.1, 29.4), ped = true },
    } }]])

    H.Equal(assert(H.Call('Setup', 1)).stores[1].ped.model, 'u_m_y_tattoo_01')

    local opened = assert(H.Call('Open', 1, 'ink'))

    H.Equal(opened.undress.components.top, {
        drawable = 15,
        texture = 0,
    })
    H.Equal(opened.undress.props.hat, {
        drawable = -1,
        texture = 0,
    })

    start('return { tattooOutfit = false }')
    H.PedCoords[1] = vector3(1322.6, -1651.9, 52.3)
    H.Equal(assert(H.Call('Open', 1, 'tattoo1')).undress, nil)
end)

H.Test('Save needs a session and keeps locked categories', function()
    start()

    H.Equal(H.Call('Save', 1, appearance()), {
        ok = false,
        error = 'no_permission',
    })

    H.PedCoords[1] = BARBER
    H.Call('Open', 1, 'barber1')

    local result = H.Call('Save', 1, appearance(function(a) a.components.top.drawable = 3 end))

    H.Equal(result, {
        ok = false,
        error = 'invalid_args',
    })
    H.Equal(H.Flags[1].violation, 'InvalidPayload')
    H.Equal(H.Rows[1], nil)
end)

H.Test('Save charges the server price from the first account that holds it', function()
    start()
    H.Call('Open', 1, 'clothing1')

    local edited = appearance(function(a)
        a.components.top.drawable = 3
        a.components.legs.drawable = 4
    end)
    local result = assert(H.Call('Save', 1, edited))

    H.Equal(result.ok, true)
    H.Equal(result.total, 120)
    H.Equal(H.Ledger, {
        {
            target = 1,
            account = 'bank',
            amount = -120,
            reason = 'ug-appearance:clothing',
        },
    })
    H.Equal(H.SavedAppearance(1), edited)
    H.Equal(UgAp.Internal.Sessions.Get(1), nil)
end)

H.Test('Save refuses without money and changes nothing', function()
    start()
    H.Balances[1] = {
        cash = 10,
        bank = 20,
    }
    H.Call('Open', 1, 'clothing1')

    H.Equal(H.Call('Save', 1, appearance(function(a) a.components.top.drawable = 3 end)), {
        ok = false,
        error = 'insufficient_funds',
    })
    H.Equal(H.Rows[1], nil)
    H.Equal(H.Ledger, {})
end)

H.Test('Save refunds when the write fails', function()
    start()
    H.Call('Open', 1, 'clothing1')
    H.FailWrite = true

    H.Equal(H.Call('Save', 1, appearance(function(a) a.props.hat.drawable = 1 end)), {
        ok = false,
        error = 'internal_error',
    })
    H.Equal(#H.Ledger, 2)
    H.Equal(H.Ledger[2].amount, 40)
    H.Equal(H.Balances[1].cash, 100)
end)

H.Test('stores MAY override prices; without accounts everything is free', function()
    start([[return { stores = { { id = 'cheap', kind = 'clothing', coords = vector3(72.3, -1399.1, 29.4), prices = { component = 1 } } } }]])
    H.Call('Open', 1, 'cheap')
    H.Equal(assert(H.Call('Save', 1, appearance(function(a) a.components.top.drawable = 3 end))).total, 1)

    H.Modules.accounts = false
    H.Call('Open', 1, 'cheap')
    H.Call('Save', 1, appearance(function(a) a.components.top.drawable = 9 end))
    H.Equal(#H.Ledger, 1)
end)

H.Test('Save starts from the saved row, not from defaults', function()
    start()
    H.SaveRow(1, appearance(function(a) a.components.top.drawable = 3 end))
    H.Call('Open', 1, 'clothing1')

    H.Equal(assert(H.Call('Save', 1, appearance(function(a) a.components.top.drawable = 3 end))).total, 0)
    H.Equal(H.Ledger, {})
end)

H.Test('outfits come from the saved appearance and are worn for free', function()
    start()
    H.SaveRow(1, appearance(function(a) a.components.top.drawable = 7 end))
    H.Call('Open', 1, 'clothing1')

    local saved = assert(H.Call('SaveOutfit', 1, 'Work'))

    H.Equal(saved.outfits[1].name, 'Work')
    H.Equal(saved.outfits[1].components.top.drawable, 7)

    H.SaveRow(1, appearance())
    UgAp.Internal.Sessions.Forget(1)
    H.Call('Open', 1, 'clothing1')

    local worn = assert(H.Call('WearOutfit', 1, saved.outfits[1].id))

    H.Equal(worn.appearance.components.top.drawable, 7)
    H.Equal(H.SavedAppearance(1).components.top.drawable, 7)
    H.Equal(H.Ledger, {})
end)

H.Test('outfits need a wardrobe session, respect the limit and belong to their character', function()
    start('return { maxOutfits = 1 }')

    H.Equal(H.Call('SaveOutfit', 1, 'A'), {
        ok = false,
        error = 'no_permission',
    })

    H.Call('Open', 1, 'clothing1')
    H.Assert(H.Call('SaveOutfit', 1, 'A').ok)
    H.Equal(H.Call('SaveOutfit', 1, 'B'), {
        ok = false,
        error = 'no_permission',
    })

    H.Outfits[#H.Outfits + 1] = {
        id = 99,
        characterId = 2,
        name = 'Theirs',
        outfit = json.encode({
            components = {},
            props = {},
        }),
    }
    H.Equal(H.Call('WearOutfit', 1, 99), {
        ok = false,
        error = 'not_found',
    })
    H.Equal(H.Call('DeleteOutfit', 1, 99), {
        ok = false,
        error = 'not_found',
    })
    H.Equal(#assert(H.Call('DeleteOutfit', 1, 1)).outfits, 0)
end)

H.Test('outfits are replaced with the saved clothing and renamed, by their owner only', function()
    start()
    H.Call('Open', 1, 'clothing1')

    local id = assert(H.Call('SaveOutfit', 1, 'Old')).outfits[1].id

    H.SaveRow(1, appearance(function(a) a.components.top.drawable = 9 end))
    UgAp.Internal.Sessions.Forget(1)
    H.Call('Open', 1, 'clothing1')

    local replaced = assert(H.Call('ReplaceOutfit', 1, id))

    H.Equal(replaced.outfits[1].components.top.drawable, 9)
    H.Equal(replaced.outfits[1].name, 'Old')

    local renamed = assert(H.Call('RenameOutfit', 1, id, 'New'))

    H.Equal(renamed.outfits[1].name, 'New')
    H.Equal(renamed.outfits[1].components.top.drawable, 9)

    H.Outfits[#H.Outfits + 1] = {
        id = 99,
        characterId = 2,
        name = 'Theirs',
        outfit = json.encode({
            components = {},
            props = {},
        }),
    }
    H.Equal(H.Call('RenameOutfit', 1, 99, 'Mine'), {
        ok = false,
        error = 'not_found',
    })
    H.Equal(H.Call('ReplaceOutfit', 1, 99), {
        ok = false,
        error = 'not_found',
    })
    H.Equal(H.Outfits[2].name, 'Theirs')

    H.FailWrite = true
    H.Equal(H.Call('RenameOutfit', 1, id, 'X'), {
        ok = false,
        error = 'internal_error',
    })
end)

H.Test('uniforms follow the job, the grade and the model', function()
    start([[return { uniforms = { police = {
        { label = 'Cadet', grades = { 0 }, male = { components = { top = { drawable = 1, texture = 0 } } } },
        { label = 'Patrol', male = { components = { top = { drawable = 55, texture = 0 } } } },
        { label = 'Women only', female = { components = { top = { drawable = 48, texture = 0 } } } },
    } } }]])
    H.Jobs[1] = {
        name = 'police',
        grade = 2,
    }

    local opened = assert(H.Call('Open', 1, 'clothing1'))

    H.Equal(opened.uniforms, { 'Patrol' })
    H.Equal(assert(H.Call('WearUniform', 1, 1)).appearance.components.top.drawable, 55)
    H.Equal(H.Call('WearUniform', 1, 2), {
        ok = false,
        error = 'not_found',
    })
end)

H.Test('the creator appearance waits for the new character', function()
    start()

    H.Equal(H.Call('Pending', 1, appearance()), {
        ok = false,
        error = 'no_permission',
    })

    local created = appearance(function(a) a.hair.style = 12 end)

    H.Equal(H.Call('Pending', 2, created), {
        ok = true,
    })
    H.Emit(UgCore.Enums.Events.Characters.Created, 2, 2)
    H.Equal(H.SavedAppearance(2), created)

    H.Call('Pending', 2, created)
    H.Rows[2] = nil
    local time = os.time

    os.time = function()
        return time() + 601
    end
    H.Emit(UgCore.Enums.Events.Characters.Created, 2, 2)
    os.time = time
    H.Equal(H.Rows[2], nil)
end)

H.Test('Pending only takes configured models', function()
    start()

    local _, errorCode = H.Call('Pending', 2, appearance(function(a) a.model = 's_m_y_cop_01' end))

    H.Equal(errorCode, 'invalid_args')
end)

H.Test('Fetch returns only the caller\'s characters', function()
    start()
    H.SaveRow(1, appearance())
    H.SaveRow(2, appearance())

    local result = assert(H.Call('Fetch', 1, { 1, 2 }))

    H.Assert(result.appearances[1] ~= nil)
    H.Equal(result.appearances[2], nil)
end)

H.Test('a loaded character gets its saved appearance, or a default from its model', function()
    start()
    H.Emit(UgCore.Enums.Events.Characters.Loaded, 1, 1)

    local entry = assert(sent('Apply', 1))

    H.Equal(entry.args[1], appearance())
end)

H.Test('the admin command needs the ACE and opens the full editor on the target', function()
    start()

    UgAp.Internal.Commands.Admin(1, {})
    H.Equal(sent('Open', 1), nil)

    H.Aces['1:ug-appearance.admin'] = true
    UgAp.Internal.Commands.Admin(1, {})

    local entry = assert(sent('Open', 1))

    H.Equal(entry.args[1].kind, 'admin')
    H.Equal(entry.args[1].free, true)

    local result = assert(H.Call('Save', 1, appearance(function(a) a.model = 'mp_f_freemode_01' end)))

    H.Equal(result.total, 0)

    UgAp.Internal.Commands.Admin(1, {})
    H.Equal(H.Call('Save', 1, appearance(function(a) a.model = 's_m_y_cop_01' end)), {
        ok = false,
        error = 'invalid_args',
    })
end)

H.Test('the console names a player; a player that is not loaded fails', function()
    start()

    H.Equal(UgAp.Internal.Commands.Admin(0, {}), 'Usage: appearance <player id>')
    H.Assert(UgAp.Internal.Commands.Admin(0, { '2' }):find('not_loaded'))
end)

H.Test('exports open wardrobes and stores for trusted resources, never the creator', function()
    start()

    H.Equal({ H.Exports.OpenWardrobe(1) }, { true })
    H.Equal(UgAp.Internal.Sessions.Get(1).kind, 'wardrobe')
    H.Equal({ H.Exports.OpenStore(1, 'creator') }, { false, 'invalid_args' })
    H.Equal({
        H.Exports.OpenStore(1, 'barber', {
            free = true,
        }),
    }, { true })
    H.Equal(UgAp.Internal.Sessions.Get(1).free, true)
end)

H.Test('trusted resources read and change clothing, never while an editor is open', function()
    start()

    local clothing = H.Exports.GetClothing(1)

    H.Equal(clothing.model, MALE)
    H.Equal(clothing.props.hat, {
        drawable = -1,
        texture = 0,
    })
    H.Equal(clothing.headBlend, nil, 'clothing only')

    H.Equal({
        H.Exports.SetClothing(1, {
            components = {
                top = {
                    drawable = 15,
                    texture = 0,
                },
            },
            props = {
                hat = {
                    drawable = 4,
                    texture = 1,
                },
            },
        }),
    }, { true })
    H.Equal(H.SavedAppearance(1).components.top, {
        drawable = 15,
        texture = 0,
    })
    H.Equal(H.SavedAppearance(1).props.hat, {
        drawable = 4,
        texture = 1,
    })
    H.Equal(sent('Apply', 1).args[1].components.top.drawable, 15, 'the ped is dressed')

    H.Equal({
        H.Exports.SetClothing(1, {
            components = {
                top = {
                    drawable = -2,
                    texture = 0,
                },
            },
        }),
    }, { false, 'invalid_args' })
    H.Equal({
        H.Exports.SetClothing(1, {
            hair = {},
        }),
    }, { false, 'invalid_args' })
    H.Equal({
        H.Exports.SetClothing(2, {
            props = {},
        }),
    }, { false, 'not_loaded' })
    H.Equal(H.Exports.GetClothing(2), nil)

    H.Exports.OpenWardrobe(1)

    H.Equal({
        H.Exports.SetClothing(1, {
            props = {
                hat = {
                    drawable = 1,
                    texture = 0,
                },
            },
        }),
    }, { false, 'no_permission' })
end)

H.Test('a wardrobe session cannot save an appearance', function()
    start()
    H.Exports.OpenWardrobe(1)

    H.Equal(H.Call('Save', 1, appearance()), {
        ok = false,
        error = 'no_permission',
    })
end)

H.Test('unloading and dropping close the session', function()
    start()
    H.Call('Open', 1, 'clothing1')
    H.Emit(UgCore.Enums.Events.Characters.Unloaded, 1, 1)
    H.Equal(UgAp.Internal.Sessions.Get(1), nil)

    H.Call('Open', 1, 'clothing1')
    H.TriggerEvent('playerDropped', 1)
    H.Equal(UgAp.Internal.Sessions.Get(1), nil)
end)

H.Test('ugap status lists open sessions', function()
    start()
    H.Call('Open', 1, 'clothing1')

    local lines = H.RunCommand('ugap', 0, { 'status' })

    H.ExpectLine(lines, 'ug-appearance: 1 open session(s).')
    H.ExpectLine(lines, '1  clothing clothing1')
end)

H.Done()
