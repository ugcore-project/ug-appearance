--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Last client script: reads the server's setup, listens for the server's events, and exports the appearance contract.

local Editor = UgAp.Internal.Editor
local Stores = UgAp.Internal.Stores
local Ped = UgAp.Internal.Ped
local Appearance = UgAp.Internal.Appearance

local RESOURCE = GetCurrentResourceName()
local SETUP_DEBOUNCE = 500

---@type UgSchemaRule?
local rule = nil
local refresh = 0

---Reads the setup from the server: studio settings and the stores this player MAY see. MUST run in a thread.
local function setup()
    local ok, result = UgCore.Callback.Await(RESOURCE .. ':Setup')

    if not ok or type(result) ~= 'table' or not result.ok then
        return
    end

    rule = Appearance.Rule(nil, result.maxTattoos)
    Editor.Configure(result)
    Stores.Refresh(result.stores, {
        interactKey = result.interactKey,
        interaction = result.interaction,
    })
end

---Reads the setup again once state settles, such as after a job change.
local function scheduleSetup()
    refresh = refresh + 1

    local id = refresh

    CreateThread(function()
        Wait(SETUP_DEBOUNCE)

        if id == refresh then
            setup()
        end
    end)
end

CreateThread(function()
    if UgCore.Lifecycle.Await(UgCore.Enums.Lifecycle.Ready) then
        setup()
    end
end)

UgCore.Network.Register('Open', function(payload)
    CreateThread(function()
        Editor.Open(payload)
    end)
end)

UgCore.Network.Register('Apply', function(appearance)
    CreateThread(function()
        Editor.ApplyOwn(appearance)
    end)
end)

do
    local bag = ('player:%d'):format(GetPlayerServerId(PlayerId()))
    local StateBags = UgCore.Enums.StateBags

    for _, key in ipairs({ StateBags.Loaded, StateBags.Job, StateBags.Gang }) do
        if key then
            AddStateBagChangeHandler(key, bag, scheduleSetup)
        end
    end
end

AddEventHandler('onResourceStop', function(name)
    if name == RESOURCE then
        Editor.Close(true)
        Stores.Clear()
    end
end)

---@param appearance any
---@return boolean
local function valid(appearance)
    return rule ~= nil and (UgCore.Schema.Check(rule, appearance))
end

-- The appearance contract, for ug-multicharacter. See CLAUDE.md.
exports('OpenCreator', function(ped, options)
    return Editor.OpenCreator(ped, options)
end)

exports('Apply', function(ped, appearance)
    if type(ped) ~= 'number' or not DoesEntityExist(ped) or not valid(appearance) then
        return false
    end

    Ped.Apply(ped, appearance)

    return true
end)

exports('Fetch', function(characterIds)
    if type(characterIds) ~= 'table' then
        return {}
    end

    local ok, result = UgCore.Callback.Await(RESOURCE .. ':Fetch', characterIds)

    return ok and type(result) == 'table' and result.ok and result.appearances or {}
end)
