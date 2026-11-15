--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.Reset()
H.Load('server')

local Appearance = UgAp.Internal.Appearance
local Category = UgAp.Enums.Category
local Kind = UgAp.Enums.StoreKind
local Schema = UgCore.Schema

local MALE = 'mp_m_freemode_01'
local PRICES = {
    component = 60, prop = 40, overlay = 30, hair = 80, heritage = 1500,
    features = 1000, eyes = 300, skin = 200, tattoo = 150, tattooRemoval = 50,
}
local RULE = Appearance.Rule({ MALE, 'mp_f_freemode_01' }, 3)

---@param edit? fun(appearance: UgApAppearance)
---@return UgApAppearance
local function make(edit)
    local appearance = Appearance.Default(MALE)

    if edit then
        edit(appearance)
    end

    return appearance
end

print('appearance')

H.Test('the default has every component, prop, overlay and feature, and passes the rule', function()
    local appearance = make()
    local ok, _, detail = Schema.Check(RULE, appearance)

    H.Assert(ok, detail)
    H.Equal(appearance.components.top, {
        drawable = 0,
        texture = 0,
    })
    H.Equal(appearance.props.hat, {
        drawable = -1,
        texture = 0,
    })
    H.Equal(appearance.headOverlays.eyebrows.style, 0)
    H.Equal(appearance.headOverlays.beard.style, -1)
    H.Equal(appearance.faceFeatures.neckThickness, 0.0)
    H.Equal(#Appearance.Components, 10)
    H.Equal(#Appearance.Props, 5)
    H.Equal(#Appearance.Overlays, 13)
    H.Equal(#Appearance.FaceFeatures, 20)
end)

H.Test('keys follow native ids', function()
    H.Equal(Appearance.Components[1], {
        key = 'mask',
        id = 1,
    })
    H.Equal(Appearance.Components[10], {
        key = 'top',
        id = 11,
    })
    H.Equal(Appearance.Props[4], {
        key = 'watch',
        id = 6,
    })
    H.Equal(Appearance.Overlays[13], {
        key = 'addBodyBlemishes',
        id = 12,
    })
    H.Equal(Appearance.FaceFeatures[1], {
        key = 'noseWidth',
        id = 0,
    })
end)

H.Test('the rule rejects unknown keys, out-of-range values and models not listed', function()
    for _, case in ipairs({
        {
            edit = function(a) a.extra = true end,
            detail = 'unknown fields',
        },
        {
            edit = function(a) a.components.top.drawable = 5000 end,
            detail = 'components.top.drawable',
        },
        {
            edit = function(a) a.props.hat.drawable = -2 end,
            detail = 'props.hat.drawable',
        },
        {
            edit = function(a) a.faceFeatures.chinCleft = 1.5 end,
            detail = 'faceFeatures.chinCleft',
        },
        {
            edit = function(a) a.headBlend.shapeFirst = 46 end,
            detail = 'headBlend.shapeFirst',
        },
        {
            edit = function(a) a.hair.color = 64 end,
            detail = 'hair.color',
        },
        {
            edit = function(a) a.eyeColor = 32 end,
            detail = 'eyeColor',
        },
        {
            edit = function(a) a.model = 'a_c_chop' end,
            detail = 'model',
        },
        {
            edit = function(a) a.components.head = { drawable = 0, texture = 0 } end,
            detail = 'components: MUST NOT have unknown fields',
        },
    }) do
        local ok, _, detail = Schema.Check(RULE, make(case.edit))

        H.Assert(not ok, 'accepted: ' .. case.detail)
        H.Assert(tostring(detail):find(case.detail, 1, true), tostring(detail))
    end
end)

H.Test('the rule rejects the same tattoo twice and more than the limit', function()
    local tattoo = {
        collection = 1,
        overlay = 2,
    }
    local twice = make(function(a) a.tattoos = { tattoo, { collection = 1, overlay = 2 } } end)
    local many = make(function(a)
        for index = 1, 4 do
            a.tattoos[index] = {
                collection = 1,
                overlay = index,
            }
        end
    end)

    H.Assert(not Schema.Check(RULE, twice))
    H.Assert(not Schema.Check(RULE, many))
    H.Assert(Schema.Check(RULE, make(function(a) a.tattoos = { tattoo } end)))
end)

H.Test('without a model list the rule takes any model name', function()
    local open = Appearance.Rule(nil, 3)

    H.Assert(Schema.Check(open, make(function(a) a.model = 's_m_y_cop_01' end)))
    H.Assert(not Schema.Check(open, make(function(a) a.model = 'bad model!' end)))
end)

H.Test('clothing and accessories cost per piece', function()
    local edited = make(function(a)
        a.components.top.drawable = 5
        a.components.legs.texture = 2
        a.props.hat.drawable = 3
    end)
    local total, lines = Appearance.Price(make(), edited, Kind.Clothing, PRICES)

    H.Equal(total, 60 + 60 + 40)
    H.Equal(lines, {
        {
            category = Category.Clothing,
            key = 'legs',
            price = 60,
        },
        {
            category = Category.Clothing,
            key = 'top',
            price = 60,
        },
        {
            category = Category.Accessories,
            key = 'hat',
            price = 40,
        },
    })
end)

H.Test('hair, heritage, features, eyes and skin cost once, overlays per overlay', function()
    local edited = make(function(a)
        a.hair.style = 4
        a.hair.color = 9
        a.headBlend.shapeMix = 0.8
        a.headBlend.skinFirst = 3
        a.faceFeatures.noseWidth = 0.4
        a.faceFeatures.chinCleft = -0.2
        a.eyeColor = 3
        a.headOverlays.ageing.style = 2
        a.headOverlays.moles.style = 1
        a.headOverlays.beard.style = 10
        a.headOverlays.lipstick.color = 4
    end)
    local total, lines = Appearance.Price(make(), edited, Kind.Admin, PRICES)
    local free = total

    total = 0

    for _, line in ipairs(Appearance.Changes(make(), edited, PRICES)) do
        total = total + line.price
    end

    H.Equal(free, 0)
    H.Equal(#lines, 7)
    H.Equal(total, 80 + 1500 + 1000 + 300 + 200 + 30 + 30)
end)

H.Test('tattoos cost per added and per removed tattoo', function()
    local saved = make(function(a) a.tattoos = { { collection = 1, overlay = 1 }, { collection = 1, overlay = 2 } } end)
    local edited = make(function(a) a.tattoos = { { collection = 1, overlay = 2 }, { collection = 3, overlay = 4 }, { collection = 3, overlay = 5 } } end)
    local total, lines = Appearance.Price(saved, edited, Kind.Tattoo, PRICES)

    H.Equal(total, 150 * 2 + 50)
    H.Equal(lines[3], {
        category = Category.Tattoos,
        key = '1:1',
        price = 50,
        removed = true,
    })
end)

H.Test('floats within a JSON round trip are not changes', function()
    local edited = make(function(a) a.headBlend.shapeMix = 0.50000001 end)

    H.Equal(#Appearance.Changes(make(), edited, PRICES), 0)
end)

H.Test('Outside finds the first category a kind does not allow', function()
    local edited = make(function(a)
        a.hair.style = 3
        a.components.top.drawable = 2
    end)

    H.Equal(Appearance.Outside(make(), edited, Kind.Barber), Category.Clothing)
    H.Equal(Appearance.Outside(make(), edited, Kind.Clothing), Category.Hair)
    H.Equal(Appearance.Outside(make(), edited, Kind.Admin), nil)
    H.Equal(Appearance.Outside(make(), make(function(a) a.model = 'mp_f_freemode_01' end), Kind.Surgeon), Category.Model)
end)

H.Test('Restrict takes every locked category from the saved appearance', function()
    local saved = make()
    local edited = make(function(a)
        a.hair.style = 3
        a.components.top.drawable = 2
        a.headOverlays.beard.style = 5
        a.headOverlays.ageing.style = 5
    end)
    local result = Appearance.Restrict(saved, edited, Kind.Barber)

    H.Equal(result.hair.style, 3)
    H.Equal(result.headOverlays.beard.style, 5)
    H.Equal(result.components.top.drawable, 0)
    H.Equal(result.headOverlays.ageing.style, -1)
    H.Equal(edited.components.top.drawable, 2)
end)

H.Test('Wear replaces only the parts an outfit lists', function()
    local worn = Appearance.Wear(make(function(a) a.components.shoes.drawable = 7 end), {
        components = {
            top = {
                drawable = 55,
                texture = 1,
            },
        },
        props = {
            hat = {
                drawable = 2,
                texture = 0,
            },
        },
    })

    H.Equal(worn.components.top, {
        drawable = 55,
        texture = 1,
    })
    H.Equal(worn.components.shoes.drawable, 7)
    H.Equal(worn.props.hat.drawable, 2)
end)

H.Done()
