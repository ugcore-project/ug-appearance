--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- The editor flow: opens the studio and the page, applies page edits live inside the allowed categories, shows the
-- bill, saves through the server or hands the creator's result back, and always restores what it changed.

---@class UgAp.Internal.Editor
local Editor = {}
UgAp.Internal.Editor = Editor

local Appearance = UgAp.Internal.Appearance
local Ped = UgAp.Internal.Ped
local Studio = UgAp.Internal.Studio
local Nui = UgAp.Internal.Nui
local Enums = UgAp.Enums
local Action = Enums.NuiAction
local Callback = Enums.NuiCallback
local Kind = Enums.StoreKind
local Errors = UgCore.Enums.Errors

local RESOURCE = GetCurrentResourceName()

---@class UgApSetup
---@field models string[]
---@field maxTattoos integer
---@field poses table[]
---@field camera UgApStudioSettings
---@field lights? UgApLight[]
---@field studio? UgApStudioLights
---@field soundEffects? table<UgApSound, { name: string, set: string }>

---@type UgApSetup?
local setup = nil

---@class UgApEditorState
---@field creator boolean editing a ped of its own for the character creator, without a server session
---@field kind UgApStoreKind
---@field prices UgApPrices
---@field free boolean
---@field saved UgApAppearance
---@field edited UgApAppearance
---@field ped integer
---@field original? integer the creator's caller ped, hidden while the editor runs
---@field promise? table resolved with the creator's result
---@field openedAt integer
---@field undressed boolean wearing a preview outfit that the saved appearance MUST replace on close

---@type UgApEditorState?
local state = nil
---@type fun(open: boolean)[]
local listeners = {}

---The server's settings. Needed before any editor opens.
---@param value UgApSetup
function Editor.Configure(value)
    setup = value
    Nui.Configure(value)
end

---Runs `listener(true)` when an editor opens and `listener(false)` when it closes.
---@param listener fun(open: boolean)
function Editor.OnToggle(listener)
    listeners[#listeners + 1] = listener
end

---@param open boolean
local function notify(open)
    for _, listener in ipairs(listeners) do
        local ok, message = pcall(listener, open)

        if not ok then
            print(('[ug-appearance] Editor listener failed: %s'):format(tostring(message)))
        end
    end
end

---@return boolean
function Editor.IsOpen()
    return state ~= nil
end

---@param errorCode string?
---@return string
function Editor.ErrorLabel(errorCode)
    if errorCode == Errors.InsufficientFunds then
        return Nui.Label('page.errorFunds')
    elseif errorCode == Errors.NoPermission or errorCode == Errors.NotLoaded then
        return Nui.Label('page.errorDenied')
    elseif errorCode == Errors.InvalidArgs then
        return Nui.Label('page.errorInvalid')
    end

    return Nui.Label('page.errorFailed')
end

local function sendBill()
    if not state then
        return
    end

    local total, lines = Appearance.Price(state.saved, state.edited, state.kind, state.prices)

    Nui.Send(Action.Bill, {
        total = state.free and 0 or total,
        lines = lines,
    })
end

---@return table[]
local function poseList()
    local list = {}

    for index, pose in ipairs(setup and setup.poses or {}) do
        list[index] = {
            id = pose.id,
            label = Nui.LabelOr(nil, 'poses.' .. pose.id, pose.id),
        }
    end

    return list
end

---@param payload table? outfits and uniforms from the server
local function openPage(payload)
    if not state or not setup then
        return
    end

    payload = payload or {}

    Nui.Send(Action.Open, {
        kind = state.kind,
        categories = Appearance.KindCategories[state.kind],
        free = state.free,
        appearance = state.saved,
        catalog = Ped.Catalog(state.ped, state.edited.model),
        models = (state.kind == Kind.Creator or state.kind == Kind.Admin) and setup.models or {},
        poses = poseList(),
        outfits = payload.outfits or {},
        uniforms = payload.uniforms or {},
        label = payload.label,
        maxTattoos = setup.maxTattoos,
    })
    sendBill()
    SetNuiFocus(true, true)
end

---@param ped integer
---@param kind UgApStoreKind
---@param saved UgApAppearance
---@param options { creator: boolean, prices?: UgApPrices, free: boolean, original?: integer, promise?: table, undressed?: boolean }
---@param payload? table
local function begin(ped, kind, saved, options, payload)
    local config = setup

    if not config then
        return
    end

    state = {
        creator = options.creator,
        kind = kind,
        prices = options.prices or {
            component = 0,
            prop = 0,
            overlay = 0,
            hair = 0,
            heritage = 0,
            features = 0,
            eyes = 0,
            skin = 0,
            tattoo = 0,
            tattooRemoval = 0,
        },
        free = options.free,
        saved = saved,
        edited = Appearance.Copy(saved),
        ped = ped,
        original = options.original,
        promise = options.promise,
        openedAt = GetGameTimer(),
        undressed = options.undressed == true,
    }

    notify(true)
    Studio.Start(ped, config.camera, config.poses, config.studio, config.lights and config.lights[1])
    openPage(payload)
    print(('[ug-appearance] Editor opened: %s.'):format(kind))
end

---Opens the editor for a server session. MUST run in a thread.
---@param payload table from the server: kind, prices, free, appearance, outfits, uniforms, label, undress?
function Editor.Open(payload)
    if state or not setup then
        return
    end

    local ped = Ped.Apply(PlayerPedId(), payload.appearance)

    -- Only the ped wears it: saved and edited keep the real clothes, which this kind cannot change.
    if payload.undress then
        Ped.ApplyDiff(ped, payload.appearance, Appearance.Wear(payload.appearance, payload.undress))
    end

    begin(ped, payload.kind, payload.appearance, {
        creator = false,
        prices = payload.prices,
        free = payload.free,
        undressed = payload.undress ~= nil,
    }, payload)
end

---Spawns the creator's own ped in place of the caller's.
---@param model string
---@param coords vector3
---@param heading number
---@return integer?
local function spawnPreview(model, coords, heading)
    if not UgLib.Streaming.Model(model) then
        return nil
    end

    local ped = CreatePed(4, joaat(model), coords.x, coords.y, coords.z - 1.0, heading, false, false)

    UgLib.Streaming.Release(UgLib.Enums.Asset.Model, model)
    SetPedDefaultComponentVariation(ped)

    return ped
end

---The character creator: edits a ped of its own over `ped`, and returns the appearance, or nil when cancelled.
---MUST run in a thread.
---@param ped integer
---@param options? { models?: string[] }
---@return UgApAppearance?
function Editor.OpenCreator(ped, options)
    if state or not setup then
        return nil
    end

    local models = type(options) == 'table' and type(options.models) == 'table' and options.models or setup.models
    local model = models[1] or setup.models[1]

    for _, candidate in ipairs(models) do
        if Ped.HasModel(ped, candidate) then
            model = candidate
        end
    end

    local coords = GetEntityCoords(ped)
    local preview = spawnPreview(model, vector3(coords.x, coords.y, coords.z), GetEntityHeading(ped))

    if not preview then
        return nil
    end

    SetEntityVisible(ped, false, false)

    local saved = Appearance.Default(model)
    local result = promise.new()

    Ped.ApplyDiff(preview, nil, saved)
    begin(preview, Kind.Creator, saved, {
        creator = true,
        free = true,
        original = ped,
        promise = result,
    })

    return Citizen.Await(result)
end

---Closes everything. `revert` puts the saved appearance back on the player's ped.
---@param revert boolean
---@param result? UgApAppearance the creator's answer
function Editor.Close(revert, result)
    local current = state

    if not current then
        return
    end

    state = nil
    Studio.Stop()
    SetNuiFocus(false, false)
    Nui.Send(Action.Close)

    if current.creator then
        if DoesEntityExist(current.ped) then
            DeletePed(current.ped)
        end

        if current.original and DoesEntityExist(current.original) then
            SetEntityVisible(current.original, true, false)
        end

        if current.promise then
            current.promise:resolve(result)
        end
    elseif revert or current.undressed then
        CreateThread(function()
            Ped.Apply(PlayerPedId(), current.saved)
        end)
    end

    notify(false)
end

---Swaps the edited model: a fresh default for it, a new catalog and a new ped. MUST run in a thread.
---@param model string
local function swapModel(model)
    if not state then
        return
    end

    local ped = state.ped

    if state.creator then
        local coords = GetEntityCoords(ped)
        local preview = spawnPreview(model, vector3(coords.x, coords.y, coords.z + 0.0), GetEntityHeading(ped))

        if not preview or not state then
            return
        end

        DeletePed(ped)
        ped = preview
    else
        ped = Ped.SetPlayerModel(model) or ped
    end

    state.ped = ped
    state.edited = Appearance.Default(model)
    Ped.ApplyDiff(ped, nil, state.edited)
    Studio.SetPed(ped)
    Nui.Send(Action.Catalog, {
        catalog = Ped.Catalog(ped, model),
        appearance = state.edited,
    })
    sendBill()
end

---@param appearance UgApAppearance checked by the bridge
local function onChange(appearance)
    if not state then
        return
    end

    local restricted = Appearance.Restrict(state.saved, appearance, state.kind)

    if restricted.model ~= state.edited.model then
        local allowed = false

        for _, model in ipairs(setup and setup.models or {}) do
            if model == restricted.model then
                allowed = true
            end
        end

        if allowed then
            CreateThread(function()
                swapModel(restricted.model)
            end)
        end

        return
    end

    Ped.ApplyDiff(state.ped, state.edited, restricted)
    state.edited = restricted
    sendBill()
end

---Replaces the saved appearance after the server changed it (outfit, uniform), keeping edits outside clothing.
---@param appearance UgApAppearance
local function onSavedChanged(appearance)
    if not state then
        return
    end

    local edited = Appearance.Wear(state.edited, {
        components = appearance.components,
        props = appearance.props,
    })

    Ped.ApplyDiff(state.ped, state.edited, edited)
    state.saved = appearance
    state.edited = edited
    Nui.Send(Action.Appearance, {
        appearance = edited,
        saved = appearance,
    })
    sendBill()
end

---Plays one of the owner's sounds. A sound the owner left out is silent.
---@param name UgApSound
local function sound(name)
    local effect = setup and setup.soundEffects and setup.soundEffects[name]

    if effect then
        PlaySoundFrontend(-1, effect.name, effect.set, true)
    end
end

---Calls a server callback and answers the page with a result.
---@param name string
---@param kind UgApResultKind
---@param ... any
---@return table? result the server answer when it succeeded
local function request(name, kind, ...)
    local ok, result, errorCode = UgCore.Callback.Await(RESOURCE .. ':' .. name, ...)

    if ok and type(result) == 'table' and result.ok then
        return result
    end

    local code = type(result) == 'table' and result.error or errorCode

    sound(Enums.Sound.Error)
    Nui.Send(Action.Result, {
        kind = kind,
        ok = false,
        message = Editor.ErrorLabel(code),
    })

    return nil
end

local function onSave()
    local current = state

    if not current then
        return
    end

    CreateThread(function()
        if current.creator then
            local ok, result = UgCore.Callback.Await(RESOURCE .. ':Pending', current.edited)

            if not ok or type(result) ~= 'table' or not result.ok then
                print('[ug-appearance] The server did not keep the creator appearance.')
            end

            Editor.Close(false, current.edited)

            return
        end

        local result = request('Save', Enums.ResultKind.Save, current.edited)

        if not result or state ~= current then
            return
        end

        current.saved = result.appearance
        print(('[ug-appearance] Saved %s for %d.'):format(current.kind, result.total))
        sound(Enums.Sound.Save)
        Nui.Send(Action.Result, {
            kind = Enums.ResultKind.Save,
            ok = true,
            total = result.total,
        })
        Editor.Close(false)
    end)
end

local function onCancel()
    local current = state

    if not current then
        return
    end

    Editor.Close(true)

    if not current.creator then
        CreateThread(function()
            UgCore.Callback.Await(RESOURCE .. ':Close')
        end)
    end
end

---@param active boolean
local function onCompare(active)
    if not state or state.saved.model ~= state.edited.model then
        return
    end

    if active then
        Ped.ApplyDiff(state.ped, state.edited, state.saved)
    else
        Ped.ApplyDiff(state.ped, state.saved, state.edited)
    end
end

---@param name string
---@param read fun(result: table)
---@param unpackValue? fun(value: any): ... the callback arguments, the value itself by default
---@return fun(value: any)
local function outfitAction(name, read, unpackValue)
    return function(value)
        if not state or state.creator then
            return
        end

        CreateThread(function()
            local result = request(name, Enums.ResultKind.Outfit, (unpackValue or function(v) return v end)(value))

            if result then
                read(result)
            end
        end)
    end
end

---@param result table
local function sendOutfits(result)
    Nui.Send(Action.Outfits, {
        outfits = result.outfits,
    })
end

---@param result table
local function wear(result)
    onSavedChanged(result.appearance)
end

Nui.On(Callback.Change, onChange)
Nui.On(Callback.Save, onSave)
Nui.On(Callback.Cancel, onCancel)
Nui.On(Callback.Compare, onCompare)
Nui.On(Callback.Camera, function(preset)
    Studio.Frame(preset)
end)
Nui.On(Callback.Rotate, function(delta)
    Studio.Rotate(delta)
end)
Nui.On(Callback.Zoom, function(delta)
    Studio.Zoom(delta)
end)
Nui.On(Callback.Light, function(light)
    Studio.Light(light)
end)
Nui.On(Callback.Pose, function(id)
    CreateThread(function()
        Studio.Pose(id)
    end)
end)
Nui.On(Callback.OutfitSave, outfitAction('SaveOutfit', sendOutfits))
Nui.On(Callback.OutfitDelete, outfitAction('DeleteOutfit', sendOutfits))
Nui.On(Callback.OutfitReplace, outfitAction('ReplaceOutfit', sendOutfits))
Nui.On(Callback.OutfitRename, outfitAction('RenameOutfit', sendOutfits, function(value)
    return value.id, value.name
end))
Nui.On(Callback.OutfitWear, outfitAction('WearOutfit', wear))
Nui.On(Callback.UniformWear, outfitAction('WearUniform', wear))

---Dresses the player's ped from the server, after a character loads. MUST run in a thread.
---@param appearance UgApAppearance
function Editor.ApplyOwn(appearance)
    if state then
        return
    end

    Ped.Apply(PlayerPedId(), appearance)
end
