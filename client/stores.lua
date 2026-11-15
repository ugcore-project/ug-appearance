--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Store blips, clerks, and how players open stores: a point with the interact prompt, or ug-target zones and clerk
-- options. The server sent only the stores this player MAY see, and checks distance, job and gang again on Open.

---@class UgAp.Internal.Stores
local Stores = {}
UgAp.Internal.Stores = Stores

local Editor = UgAp.Internal.Editor
local Nui = UgAp.Internal.Nui
local Interaction = UgAp.Enums.Interaction
local Kind = UgAp.Enums.StoreKind

local RESOURCE = GetCurrentResourceName()
local KEYBIND = 'interact'
local TARGET = 'ug-target'
-- ug-target measures from the ped to the aim point. The store radius is checked separately, like the server does.
local TARGET_DISTANCE = 5.0
local ICONS = {
    [Kind.Clothing] = 'shirt',
    [Kind.Barber] = 'scissors',
    [Kind.Tattoo] = 'pen-tool',
    [Kind.Surgeon] = 'syringe',
    [Kind.Wardrobe] = 'shirt',
}

---@class UgApStoreSettings
---@field interactKey string
---@field interaction? UgApInteraction

---@type integer[]
local blips = {}
---@type table[] ug-lib points
local points = {}
---@type UgNpc[] store clerks
local npcs = {}
---@type integer[] ug-target zone ids
local zones = {}
---@type table<integer, boolean> clerk peds with a ug-target option
local targeted = {}
-- Clerks hide while an editor runs, so none stands in the studio shot.
local npcsHidden = false
---@type table? the store the player stands in
local current = nil
local keybound = false
local busy = false
local warned = false
---@type { stores: table[], settings: UgApStoreSettings }? the last refresh, to rebuild when ug-target restarts
local last = nil

---@param store table
---@return string
local function labelOf(store)
    return Nui.LabelOr(store.label or (store.blip and store.blip.label), 'stores.' .. store.kind, store.kind)
end

---True when stores open through ug-target. Falls back to the key, once with a warning, when it is not running.
---@param settings UgApStoreSettings
---@return boolean
local function usesTarget(settings)
    if settings.interaction ~= Interaction.Target then
        return false
    end

    if GetResourceState(TARGET) == 'started' then
        return true
    end

    if not warned then
        warned = true
        print('^3[ug-appearance] interaction is "target" but ug-target is not started. Using the interact key.^7')
    end

    return false
end

---Calls a ug-target export. ug-target MAY stop at any time, so failures are ignored.
---@param name string
---@param ... any
---@return any
local function target(name, ...)
    local args = table.pack(...)
    local ok, result = pcall(function()
        local api = exports[TARGET]

        return api[name](api, table.unpack(args, 1, args.n))
    end)

    return ok and result or nil
end

---@param ped integer
local function showNpc(ped)
    SetEntityVisible(ped, not npcsHidden, false)
    SetEntityCollision(ped, not npcsHidden, true)
end

---@param hidden boolean
local function hideNpcs(hidden)
    npcsHidden = hidden

    for _, npc in ipairs(npcs) do
        local ped = UgLib.Npc.GetPed(npc)

        if ped then
            showNpc(ped)
        end
    end
end

---Removes every blip, point, zone and clerk.
function Stores.Clear()
    for _, blip in ipairs(blips) do
        RemoveBlip(blip)
    end

    for _, point in ipairs(points) do
        point:Remove()
    end

    for _, id in ipairs(zones) do
        target('RemoveZone', id)
    end

    for ped in pairs(targeted) do
        target('RemoveLocalEntity', ped)
    end

    for _, npc in ipairs(npcs) do
        UgLib.Npc.Remove(npc)
    end

    blips, points, npcs, zones, targeted, current = {}, {}, {}, {}, {}, nil
    UgLib.TextUI.Hide()
end

---Opens a store, or the one the player stands in. MUST run in a thread.
---@param store? table
function Stores.Interact(store)
    store = store or current

    if not store or busy or Editor.IsOpen() then
        return
    end

    busy = true

    local ok, result, errorCode = UgCore.Callback.Await(RESOURCE .. ':Open', store.id)

    busy = false

    if ok and type(result) == 'table' and result.ok then
        UgLib.TextUI.Hide()
        Editor.Open(result)

        return
    end

    UgLib.Notify.Show({
        message = Editor.ErrorLabel(type(result) == 'table' and result.error or errorCode),
        type = UgLib.Enums.NotifyType.Error,
    })
end

---@param interactKey string
local function bindKey(interactKey)
    if keybound then
        return
    end

    keybound = true
    UgLib.Keybind.Register({
        name = KEYBIND,
        label = Nui.Label('stores.interact'),
        defaultKey = interactKey,
        onPressed = function()
            CreateThread(function()
                Stores.Interact()
            end)
        end,
    })
end

---True when the player's ped is within the store radius, the same check the server makes on Open.
---@param store table
---@return boolean
local function inRange(store)
    local ped = GetEntityCoords(PlayerPedId())
    local coords = store.coords
    local dx, dy, dz = ped.x - coords.x, ped.y - coords.y, ped.z - coords.z

    return dx * dx + dy * dy + dz * dz <= store.radius * store.radius
end

---The ug-target option of a store.
---@param store table
---@param label string
---@return table
local function optionOf(store, label)
    return {
        name = 'store:' .. store.id,
        label = label,
        icon = ICONS[store.kind] or 'shirt',
        distance = TARGET_DISTANCE,
        canInteract = function()
            return not Editor.IsOpen() and inRange(store)
        end,
        onSelect = function()
            CreateThread(function()
                Stores.Interact(store)
            end)
        end,
    }
end

---@param store table
---@param option? table the ug-target option for the clerk, nil without ug-target
local function placeNpc(store, option)
    local ped = store.ped

    npcs[#npcs + 1] = UgLib.Npc.Create({
        model = ped.model,
        coords = ped.coords,
        animation = ped.animation,
        data = store.id,
        onSpawn = function(npc)
            if npc.ped then
                showNpc(npc.ped)

                if option then
                    target('AddLocalEntity', npc.ped, option)
                    targeted[npc.ped] = true
                end
            end
        end,
        onDespawn = function(npc)
            if npc.ped and targeted[npc.ped] then
                target('RemoveLocalEntity', npc.ped)
                targeted[npc.ped] = nil
            end
        end,
    })
end

---@param store table
---@param label string
---@param settings UgApStoreSettings
local function placePoint(store, label, settings)
    points[#points + 1] = UgLib.Point.Create({
        coords = store.coords,
        distance = store.radius,
        data = store,
        onEnter = function()
            current = store

            if not Editor.IsOpen() then
                -- The key the player bound, read each time: they MAY change it in the FiveM settings.
                local key = keybound and UgLib.Keybind.GetKey(KEYBIND) or settings.interactKey

                UgLib.TextUI.Show({
                    text = label,
                    key = key,
                    style = UgLib.Enums.TextUIStyle.Keybind,
                })
            end
        end,
        onExit = function()
            if current == store then
                current = nil
            end

            UgLib.TextUI.Hide()
        end,
    })
end

---Replaces blips, points, zones and clerks with a new list from the server.
---@param stores table[]
---@param settings UgApStoreSettings
function Stores.Refresh(stores, settings)
    Stores.Clear()
    last = {
        stores = stores,
        settings = settings,
    }

    local withTarget = usesTarget(settings)

    if not withTarget then
        bindKey(settings.interactKey)
    end

    for _, store in ipairs(stores) do
        local coords = store.coords
        local label = labelOf(store)

        if store.blip then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

            SetBlipSprite(blip, store.blip.sprite)
            SetBlipColour(blip, store.blip.color)
            SetBlipScale(blip, store.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(label)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end

        local option = withTarget and optionOf(store, label) or nil

        if store.ped then
            placeNpc(store, option)
        end

        -- A store with a clerk opens from the clerk only: a zone too would show the option twice.
        if not option then
            placePoint(store, label, settings)
        elseif not store.ped then
            local id = target('AddSphereZone', {
                name = ('%s:%s'):format(RESOURCE, store.id),
                coords = coords,
                radius = store.radius,
                options = option,
            })

            if id then
                zones[#zones + 1] = id
            end
        end
    end
end

-- ug-target loses every option when it stops. Forget the ids, and build again when it starts.
AddEventHandler('onClientResourceStop', function(resource)
    if resource == TARGET then
        zones, targeted = {}, {}
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == TARGET and last then
        Stores.Refresh(last.stores, last.settings)
    end
end)

Editor.OnToggle(hideNpcs)
