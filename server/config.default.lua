--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- ug-appearance config. Copied to config.lua in the resource folder on the first start: edit that file, never this one.
-- Updates never overwrite config.lua. A key you remove uses its default.
-- Store coordinates are the game's shop doors. Check them on your server.
-- Labels come from locales/<code>.json. Set label on a store to override it.

---@param kind string
---@param prefix string
---@param list vector3[]
---@param into table[]
local function stores(kind, prefix, list, into)
    for index, coords in ipairs(list) do
        into[#into + 1] = {
            id = prefix .. index,
            kind = kind,
            coords = coords,
            blip = true,
        }
    end
end

local list = {}

stores('clothing', 'clothing', {
    vector3(72.3, -1399.1, 29.4),
    vector3(-703.8, -152.3, 37.4),
    vector3(-167.9, -299.0, 39.7),
    vector3(428.7, -800.1, 29.5),
    vector3(-829.4, -1073.7, 11.3),
    vector3(-1447.8, -242.5, 49.8),
    vector3(11.6, 6514.2, 31.9),
    vector3(123.6, -219.4, 54.6),
    vector3(1696.3, 4829.3, 42.1),
    vector3(618.1, 2759.6, 42.1),
    vector3(1190.6, 2713.4, 38.2),
    vector3(-1193.4, -772.3, 17.3),
    vector3(-3172.5, 1048.1, 20.9),
    vector3(-1108.4, 2708.9, 19.1),
}, list)

stores('barber', 'barber', {
    vector3(-814.3, -183.8, 37.6),
    vector3(136.8, -1708.4, 29.3),
    vector3(-1282.6, -1116.8, 7.0),
    vector3(1931.5, 3729.7, 32.8),
    vector3(1212.8, -472.9, 66.2),
    vector3(-32.9, -152.3, 57.1),
    vector3(-278.1, 6228.5, 31.7),
}, list)

stores('tattoo', 'tattoo', {
    vector3(1322.6, -1651.9, 52.3),
    vector3(-1153.6, -1425.6, 4.9),
    vector3(322.1, 180.4, 103.6),
    vector3(-3170.0, 1075.0, 20.8),
    vector3(1864.6, 3747.7, 33.0),
    vector3(-293.7, 6200.0, 31.5),
}, list)

stores('surgeon', 'surgeon', {
    vector3(298.8, -572.8, 43.3),
}, list)

return {
    -- Models the character creator and the admin editor offer. Stores never change the model.
    models = { 'mp_m_freemode_01', 'mp_f_freemode_01' },

    -- Store points: { id, kind, coords, radius?, label?, blip?, job?, gang?, prices? }.
    -- kind: 'clothing', 'barber', 'tattoo', 'surgeon' or 'wardrobe' (outfits and uniforms only, free).
    -- blip: true (the kind's blip below), false, or { sprite?, color?, scale?, label? }.
    -- ped: an NPC, needs ug-lib. true (the kind's ped below, at coords), or { model?, coords? (vector4), animation? }.
    --   The default stores have none: their coords are the doors. Set coords where the clerk stands.
    -- job, gang: only members see and use the store. prices: overrides any of the prices below for this store.
    -- Example: { id = 'mrpd', kind = 'wardrobe', coords = vector3(461.4, -998.0, 30.7), job = 'police', blip = false },
    -- Example: { id = 'ponsonbys', kind = 'clothing', coords = vector3(-708.7, -151.9, 37.4), blip = true,
    --     ped = { coords = vector4(-708.7, -151.9, 37.4, 120.0) } },
    stores = list,

    -- Default blip of each kind.
    blips = {
        clothing = {
            sprite = 73,
            color = 47,
            scale = 0.7,
        },
        barber = {
            sprite = 71,
            color = 0,
            scale = 0.7,
        },
        tattoo = {
            sprite = 75,
            color = 1,
            scale = 0.7,
        },
        surgeon = {
            sprite = 102,
            color = 4,
            scale = 0.7,
        },
        wardrobe = {
            sprite = 366,
            color = 3,
            scale = 0.6,
        },
    },

    -- Default NPC of each kind, for stores with ped set: { model, animation? }.
    -- animation: { dict, name, flag? } or { scenario }. Leave a kind out to require a model on each store.
    peds = {
        clothing = {
            model = 's_f_y_shop_mid',
            animation = {
                scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            },
        },
        barber = {
            model = 's_f_m_fembarber',
            animation = {
                scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            },
        },
        tattoo = {
            model = 'u_m_y_tattoo_01',
            animation = {
                scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            },
        },
        surgeon = {
            model = 's_m_m_doctor_01',
            animation = {
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
        },
    },

    -- What a change costs. The server computes the bill; the page shows the same lines.
    -- component, prop, overlay: per changed piece. tattoo, tattooRemoval: per tattoo.
    -- hair, heritage, features, eyes, skin: once when anything in it changed.
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

    -- ug-core accounts tried in order. The first one that holds the whole amount pays. Free without the accounts module.
    payment = {
        accounts = { 'cash', 'bank' },
    },

    -- Distance in meters from a store point to open it, unless the store sets radius.
    storeRadius = 2.0,

    -- Saved outfits per character, and tattoos per appearance.
    maxOutfits = 20,
    maxTattoos = 60,

    -- Job and gang uniforms, worn for free at clothing stores and wardrobes.
    -- { [job or gang] = { { label, grades?, male = { components, props }, female = { components, props } } } }.
    -- grades: the grades that see it, all when left out. Parts left out stay as they are.
    -- Example:
    -- police = {
    --     { label = 'Patrol', male = { components = { top = { drawable = 55, texture = 0 }, legs = { drawable = 35, texture = 0 } } } },
    -- },
    uniforms = {},

    -- What tattoo stores undress, so the skin shows: { male = { components, props }, female = { ... } }.
    -- Only for the preview: the saved clothes come back when the editor closes. false keeps the clothes on.
    tattooOutfit = {
        male = {
            components = {
                mask = {
                    drawable = 0,
                    texture = 0,
                },
                arms = {
                    drawable = 15,
                    texture = 0,
                },
                legs = {
                    drawable = 61,
                    texture = 0,
                },
                bag = {
                    drawable = 0,
                    texture = 0,
                },
                shoes = {
                    drawable = 34,
                    texture = 0,
                },
                accessory = {
                    drawable = 0,
                    texture = 0,
                },
                undershirt = {
                    drawable = 15,
                    texture = 0,
                },
                armor = {
                    drawable = 0,
                    texture = 0,
                },
                decals = {
                    drawable = 0,
                    texture = 0,
                },
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
                glasses = {
                    drawable = -1,
                    texture = 0,
                },
            },
        },
        female = {
            components = {
                mask = {
                    drawable = 0,
                    texture = 0,
                },
                arms = {
                    drawable = 15,
                    texture = 0,
                },
                legs = {
                    drawable = 17,
                    texture = 0,
                },
                bag = {
                    drawable = 0,
                    texture = 0,
                },
                shoes = {
                    drawable = 35,
                    texture = 0,
                },
                accessory = {
                    drawable = 0,
                    texture = 0,
                },
                undershirt = {
                    drawable = 14,
                    texture = 0,
                },
                armor = {
                    drawable = 0,
                    texture = 0,
                },
                decals = {
                    drawable = 0,
                    texture = 0,
                },
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
                glasses = {
                    drawable = -1,
                    texture = 0,
                },
            },
        },
    },

    -- Preview poses: { id }, { id, dict, name, flag? } or { id, scenario }. Labels: poses.<id> in the locale file.
    poses = {
        {
            id = 'idle',
        },
        {
            id = 'handsUp',
            dict = 'missminuteman_1ig_2',
            name = 'handsup_base',
        },
        {
            id = 'armsCrossed',
            dict = 'amb@world_human_hang_out_street@female_arms_crossed@idle_a',
            name = 'idle_a',
        },
        {
            id = 'impatient',
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
    },

    -- Studio camera. Each preset: distance in front of the ped, height from its center, field of view.
    -- ease: 'linear', 'inOut', 'in' or 'out'. The wheel zooms between minDistance and maxDistance, gliding zoomDuration ms.
    camera = {
        duration = 600,
        ease = 'inOut',
        minDistance = 0.5,
        maxDistance = 4.0,
        zoomDuration = 150,
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

    -- Command that opens the full editor for yourself or a player id. Needs the ug-appearance.admin ACE. false turns it off.
    adminCommand = 'appearance',

    -- Default key to open a store. Players MAY change it in the game's key bindings.
    interactKey = 'E',

    -- How players open stores. 'key': walk in and press interactKey. 'target': aim at the store or its clerk with
    -- ug-target. Without ug-target started, 'target' falls back to the key.
    interaction = 'key',

    -- Colors, radius, font and scale of the editor, over ug-lib's theme: { mode?, colors?, radius?, font?, scale? }.
    -- colors takes ug-lib's tokens and one color per editor tab: model, heritage, features, eyes, skin, hair,
    -- facialHair, makeup, clothing, accessories, tattoos, outfits. mixFirst and mixSecond color the heritage mix bar.
    -- Colors are HSL triplets: theme = { colors = { clothing = '200 80% 55%' } }.
    theme = {},

    -- The editor screen. Keys you leave out keep their default.
    -- side: 'left' or 'right', where the panel sits. width: panel width in rem. opacity: panel background, 0 to 1.
    -- toolbar: 'top' or 'bottom'. hint: the controls line at the bottom. animations = false keeps everything still.
    -- resultDuration: ms the saved or error message stays.
    layout = {
        side = 'left',
        width = 22,
        opacity = 0.7,
        blur = true,
        toolbar = 'top',
        hint = true,
        animations = true,
        resultDuration = 3500,
    },

    -- Editor tools. false hides the tool, and the game refuses it too where the game does the work.
    features = {
        undo = true,
        randomize = true,
        compare = true,
        favorites = true,
        search = true,
        cameras = true,
        rotate = true,
        zoom = true,
        poses = true,
    },

    -- Mouse and keys. dragSpeed: degrees per dragged pixel. zoomSpeed: meters per wheel unit.
    -- keyRotate: degrees per Q or E press, 0 turns the keys off. rotateStep: degrees per toolbar turn button.
    controls = {
        dragSpeed = 0.4,
        zoomSpeed = 0.002,
        keyRotate = 15,
        rotateStep = 45,
    },

    -- Light presets on the toolbar, in order: 'natural', 'studio', 'day', 'night'. The first one is on when the editor opens.
    lights = { 'natural', 'studio', 'day', 'night' },

    -- The studio light preset: the clock for day and night, and the lamps around the ped.
    -- Each lamp: angle from the camera side, distance and height from the ped, color { r, g, b }, range, intensity.
    studio = {
        dayHour = 12,
        nightHour = 23,
        lights = {
            {
                angle = 35,
                distance = 1.6,
                height = 0.9,
                color = { 255, 244, 229 },
                range = 4.0,
                intensity = 2.2,
            },
            {
                angle = -50,
                distance = 1.8,
                height = 0.4,
                color = { 205, 220, 255 },
                range = 4.0,
                intensity = 1.2,
            },
            {
                angle = 180,
                distance = 1.4,
                height = 1.1,
                color = { 255, 255, 255 },
                range = 3.0,
                intensity = 1.6,
            },
        },
    },

    -- Game sounds: save (paid and saved), error (refused). { name, set }. A sound left out is silent.
    soundEffects = {
        save = {
            name = 'PURCHASE',
            set = 'HUD_LIQUOR_STORE_SOUNDSET',
        },
        error = {
            name = 'ERROR',
            set = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
        },
    },
}
