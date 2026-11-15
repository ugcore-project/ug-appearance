--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Editor sessions, the saved appearance of loaded characters, saving with payment, the creator hand-off and the
-- multicharacter fetch. Every answer is a table: { ok = true, ... } or { ok = false, error = <UgErrorCode> }.

---@class UgApSession
---@field kind UgApStoreKind
---@field store? table the config store, nil for sessions opened by code
---@field prices UgApPrices
---@field free boolean
---@field openedAt integer GetGameTimer

---@class UgAp.Internal.Sessions
local Sessions = {}
UgAp.Internal.Sessions = Sessions

local Config = UgAp.Internal.Config
local Database = UgAp.Internal.Database
local Appearance = UgAp.Internal.Appearance
local Schema = UgCore.Schema
local Errors = UgCore.Enums.Errors
local Kind = UgAp.Enums.StoreKind
local Logger = UgCore.Logger

local RESOURCE = GetCurrentResourceName()
local OPEN_EVENT = RESOURCE .. ':Open'
local APPLY_EVENT = RESOURCE .. ':Apply'
-- Distance a player MAY stand beyond a store's radius: the server reads the ped a moment after the client did.
local DISTANCE_SLACK = 2.0
local PENDING_SECONDS = 600
local MAX_FETCH = 32

---@type table<integer, UgApSession>
local sessions = {}
---@type table<integer, { characterId: integer, appearance: UgApAppearance }>
local saved = {}
---@type table<integer, { appearance: UgApAppearance, at: integer }>
local pending = {}

---@param errorCode UgErrorCode
---@return table
local function fail(errorCode)
    return {
        ok = false,
        error = errorCode,
    }
end

Sessions.Fail = fail

---@param store? table
---@return UgApPrices
local function pricesOf(store)
    local prices = Appearance.Copy(Config.Get().prices)

    for key, value in pairs(store and store.prices or {}) do
        prices[key] = value
    end

    return prices
end

---@param model any
---@return string
local function startingModel(model)
    local models = Config.Get().models

    for _, allowed in ipairs(models) do
        if allowed == model then
            return model
        end
    end

    return models[1]
end

---The saved appearance of the player's loaded character, from the cache or the database.
---@param source integer
---@return boolean ok
---@return UgApAppearance? appearance a copy
---@return integer? characterId
function Sessions.Saved(source)
    local character = UgCore.Characters.GetActive(source)

    if not character then
        return false, nil, nil
    end

    local entry = saved[source]

    if not entry or entry.characterId ~= character.id then
        local ok, appearance = Database.Get(character.id)

        if not ok then
            return false, nil, nil
        end

        entry = {
            characterId = character.id,
            appearance = appearance or Appearance.Default(startingModel(character.data and character.data.model)),
        }
        saved[source] = entry
    end

    return true, Appearance.Copy(entry.appearance), character.id
end

---Replaces the saved appearance in the database and the cache.
---@param source integer
---@param characterId integer
---@param appearance UgApAppearance
---@return boolean ok
function Sessions.Store(source, characterId, appearance)
    if not Database.Set(characterId, appearance) then
        return false
    end

    saved[source] = {
        characterId = characterId,
        appearance = Appearance.Copy(appearance),
    }

    return true
end

---@param source integer
---@return UgApSession?
function Sessions.Get(source)
    return sessions[source]
end

---@return table<integer, UgApSession>
function Sessions.All()
    return sessions
end

---@param source integer
---@param store table
---@return boolean
local function memberOf(source, store)
    if store.job then
        local job = UgCore.Modules.IsEnabled('jobs') and UgCore.Jobs.Get(source) or nil

        if not job or job.name ~= store.job then
            return false
        end
    end

    if store.gang then
        local gang = UgCore.Modules.IsEnabled('gangs') and UgCore.Gangs.Get(source) or nil

        if not gang or gang.name ~= store.gang then
            return false
        end
    end

    return true
end

---Uniforms the player's job and gang offer, with their shape for the model.
---@param source integer
---@param model string
---@return { label: string, outfit: table }[]
function Sessions.Uniforms(source, model)
    local list = {}
    local uniforms = Config.Get().uniforms
    local shape = model == 'mp_f_freemode_01' and 'female' or 'male'

    for _, entry in ipairs({
        {
            module = 'jobs',
            get = function() return UgCore.Jobs.Get(source) end,
        },
        {
            module = 'gangs',
            get = function() return UgCore.Gangs.Get(source) end,
        },
    }) do
        local role = UgCore.Modules.IsEnabled(entry.module) and entry.get() or nil

        for _, uniform in ipairs(role and uniforms[role.name] or {}) do
            local grades = uniform.grades
            local allowed = grades == nil

            for _, grade in ipairs(grades or {}) do
                if role and grade == role.grade then
                    allowed = true
                end
            end

            if allowed and uniform[shape] then
                list[#list + 1] = {
                    label = uniform.label,
                    outfit = uniform[shape],
                }
            end
        end
    end

    return list
end

---What the client needs before any session: the studio settings, and the stores this player MAY see.
---Stores need a loaded character, so a creator before the first load gets none.
---@param source integer
---@return table
function Sessions.Setup(source)
    local config = Config.Get()
    local stores = {}

    if UgCore.Characters.GetActive(source) then
        for _, store in ipairs(config.stores) do
            if memberOf(source, store) then
                stores[#stores + 1] = {
                    id = store.id,
                    kind = store.kind,
                    coords = store.coords,
                    radius = store.radius or config.storeRadius,
                    label = store.label,
                    blip = store.blip,
                    ped = store.ped,
                }
            end
        end
    end

    return {
        ok = true,
        stores = stores,
        models = config.models,
        maxTattoos = config.maxTattoos,
        poses = config.poses,
        camera = config.camera,
        interactKey = config.interactKey,
        interaction = config.interaction,
        theme = config.theme,
        layout = config.layout,
        features = config.features,
        controls = config.controls,
        lights = config.lights,
        studio = config.studio,
        soundEffects = config.soundEffects,
    }
end

---What the client needs to open the editor.
---@param source integer
---@param session UgApSession
---@param appearance UgApAppearance
---@return table
local function payloadOf(source, session, appearance)
    local payload = {
        kind = session.kind,
        categories = Appearance.KindCategories[session.kind],
        prices = session.prices,
        free = session.free,
        appearance = appearance,
        store = session.store and session.store.id or nil,
        label = session.store and session.store.label or nil,
    }

    local tattooOutfit = Config.Get().tattooOutfit

    -- Tattoo stores undress the preview so the skin shows. Only freemode models have known clothes.
    if session.kind == Kind.Tattoo and tattooOutfit then
        if appearance.model == 'mp_m_freemode_01' then
            payload.undress = tattooOutfit.male
        elseif appearance.model == 'mp_f_freemode_01' then
            payload.undress = tattooOutfit.female
        end
    end

    if session.kind == Kind.Clothing or session.kind == Kind.Wardrobe or session.kind == Kind.Admin then
        local _, outfits = Database.ListOutfits(saved[source].characterId)
        local uniforms = {}

        for index, uniform in ipairs(Sessions.Uniforms(source, appearance.model)) do
            uniforms[index] = uniform.label
        end

        payload.outfits = outfits
        payload.uniforms = uniforms
    end

    return payload
end

---Opens a session for a loaded player. Used by stores, exports and the admin command.
---@param source integer
---@param kind UgApStoreKind
---@param options? { store?: table, free?: boolean }
---@return boolean ok
---@return table? payload
---@return UgErrorCode? errorCode
function Sessions.Start(source, kind, options)
    options = options or {}

    local ok, appearance = Sessions.Saved(source)

    if not ok or not appearance then
        return false, nil, Errors.NotLoaded
    end

    local session = {
        kind = kind,
        store = options.store,
        prices = pricesOf(options.store),
        free = options.free == true or Appearance.FreeKinds[kind] == true,
        openedAt = GetGameTimer(),
    }

    sessions[source] = session
    Logger.Debug('player %d opened %s%s.', source, kind, options.store and (' at ' .. options.store.id) or '')

    return true, payloadOf(source, session, appearance), nil
end

---Opens a session and tells the client to show the editor. For code: exports and commands.
---@param source integer
---@param kind UgApStoreKind
---@param options? { free?: boolean }
---@return boolean ok
---@return UgErrorCode? errorCode
function Sessions.Push(source, kind, options)
    local ok, payload, errorCode = Sessions.Start(source, kind, options)

    if not ok or not payload then
        return false, errorCode
    end

    UgCore.Network.TriggerClient(source, OPEN_EVENT, payload)

    return true, nil
end

---@param source integer
---@param storeId string
---@return table
function Sessions.Open(source, storeId)
    local store = nil

    for _, entry in ipairs(Config.Get().stores) do
        if entry.id == storeId then
            store = entry
        end
    end

    if not store then
        return fail(Errors.NotFound)
    end

    if not memberOf(source, store) then
        return fail(Errors.NoPermission)
    end

    local radius = store.radius or Config.Get().storeRadius

    if not UgCore.Guard.IsNear(source, store.coords, radius + DISTANCE_SLACK) then
        UgCore.Guard.Flag(source, UgCore.Enums.Violations.OutOfRange, ('store %s'):format(store.id))

        return fail(Errors.NoPermission)
    end

    local ok, payload, errorCode = Sessions.Start(source, store.kind, {
        store = store,
    })

    if not ok or not payload then
        return fail(errorCode or Errors.InternalError)
    end

    payload.ok = true

    return payload
end

---Takes `total` from the first configured account that holds it. Free without the accounts module.
---@param source integer
---@param total integer
---@param reason string
---@return boolean ok
---@return string? account the account that paid, nil when nothing was taken
function Sessions.Pay(source, total, reason)
    if total <= 0 or not UgCore.Modules.IsEnabled('accounts') then
        return true, nil
    end

    for _, account in ipairs(Config.Get().payment.accounts) do
        local balance = UgCore.Accounts.GetBalance(source, account)

        if balance and balance >= total then
            local paid = UgCore.Accounts.Remove(source, account, total, reason)

            if paid then
                return true, account
            end
        end
    end

    return false, nil
end

---@param source integer
---@param edited UgApAppearance validated by the schema
---@return table
function Sessions.Save(source, edited)
    local session = sessions[source]

    if not session or session.kind == Kind.Wardrobe then
        return fail(Errors.NoPermission)
    end

    local ok, current, characterId = Sessions.Saved(source)

    if not ok or not current or not characterId then
        return fail(Errors.NotLoaded)
    end

    local outside = Appearance.Outside(current, edited, session.kind)

    if outside then
        UgCore.Guard.Flag(source, UgCore.Enums.Violations.InvalidPayload, ('%s changed %s'):format(session.kind, outside))

        return fail(Errors.InvalidArgs)
    end

    if edited.model ~= current.model and startingModel(edited.model) ~= edited.model then
        return fail(Errors.InvalidArgs)
    end

    local total, lines = Appearance.Price(current, edited, session.kind, session.prices)

    if session.free then
        total = 0
    end

    if #lines == 0 then
        sessions[source] = nil

        return {
            ok = true,
            appearance = current,
            total = 0,
        }
    end

    local reason = ('%s:%s'):format(RESOURCE, session.kind)
    local paid, account = Sessions.Pay(source, total, reason)

    if not paid then
        return fail(Errors.InsufficientFunds)
    end

    if not Sessions.Store(source, characterId, edited) then
        if account then
            UgCore.Accounts.Add(source, account, total, reason .. ':refund')
        end

        return fail(Errors.InternalError)
    end

    sessions[source] = nil
    Logger.Debug('player %d saved %s: %d change(s) for %d.', source, session.kind, #lines, total)

    return {
        ok = true,
        appearance = edited,
        total = total,
    }
end

---@param source integer
---@return table
function Sessions.Close(source)
    sessions[source] = nil

    return {
        ok = true,
    }
end

---Keeps the creator's appearance until ug-core creates the character.
---@param source integer
---@param appearance UgApAppearance validated by the schema, models included
---@return table
function Sessions.Pending(source, appearance)
    if UgCore.Characters.GetActive(source) then
        return fail(Errors.NoPermission)
    end

    pending[source] = {
        appearance = appearance,
        at = os.time(),
    }

    return {
        ok = true,
    }
end

---Saves a pending creator appearance for a new character. MUST run in a thread.
---@param source integer
---@param characterId integer
function Sessions.Created(source, characterId)
    local entry = pending[source]

    pending[source] = nil

    if not entry or os.time() - entry.at > PENDING_SECONDS then
        return
    end

    if not Database.Set(characterId, entry.appearance) then
        Logger.Warn('Could not save the appearance of character %d.', characterId)
    end
end

---The saved appearances of the caller's own characters. Ids the caller does not own are left out.
---@param source integer
---@param characterIds integer[]
---@return table
function Sessions.Fetch(source, characterIds)
    local ok, characters = UgCore.Characters.GetAll(source)

    if not ok or not characters then
        return fail(Errors.NotFound)
    end

    local owned = {}

    for _, character in ipairs(characters) do
        owned[character.id] = true
    end

    local ids = {}

    for _, id in ipairs(characterIds) do
        if owned[id] then
            ids[#ids + 1] = id
        end
    end

    local read, appearances = Database.GetMany(ids)

    if not read then
        return fail(Errors.InternalError)
    end

    return {
        ok = true,
        appearances = appearances,
    }
end

---Sends the saved appearance to a player whose character just loaded. MUST run in a thread.
---@param source integer
function Sessions.Loaded(source)
    local ok, appearance = Sessions.Saved(source)

    if ok and appearance then
        UgCore.Network.TriggerClient(source, APPLY_EVENT, appearance)
    end
end

---What the player's loaded character wears: its model, components and props. Copies, nil when not loaded.
---@param source integer
---@return { model: string, components: table<string, UgApAppearancePart>, props: table<string, UgApAppearancePart> }?
function Sessions.Clothing(source)
    local ok, appearance = Sessions.Saved(source)

    if not ok or not appearance then
        return nil
    end

    return {
        model = appearance.model,
        components = appearance.components,
        props = appearance.props,
    }
end

---Changes clothing and accessories of the loaded character, saves them and dresses the ped, for trusted resources
---such as an inventory that takes clothes off. Refused while an editor is open: its save would bring the old pieces
---back. MUST run in a thread.
---@param source integer
---@param parts any `{ components?, props? }`, each piece `{ drawable, texture }`
---@return boolean ok
---@return UgErrorCode? errorCode
function Sessions.SetClothing(source, parts)
    if sessions[source] then
        return false, Errors.NoPermission
    end

    local checked, clean = Schema.Check(Appearance.PartialOutfitRule, parts)

    if not checked then
        return false, Errors.InvalidArgs
    end

    local ok, appearance, characterId = Sessions.Saved(source)

    if not ok or not appearance or not characterId then
        return false, Errors.NotLoaded
    end

    local worn = Appearance.Wear(appearance, clean)

    if not Sessions.Store(source, characterId, worn) then
        return false, Errors.InternalError
    end

    UgCore.Network.TriggerClient(source, APPLY_EVENT, worn)

    return true, nil
end

---Forgets everything about a player.
---@param source integer
function Sessions.Forget(source)
    sessions[source] = nil
    saved[source] = nil
    pending[source] = nil
end

---Registers callbacks, events and exports. Runs once after a clean boot.
function Sessions.Register()
    local config = Config.Get()
    local Callback = UgCore.Callback
    local Events = UgCore.Events
    local CharacterEvents = UgCore.Enums.Events.Characters

    Callback.Register('Setup', {
        schema = Schema.Define({}),
        rate = {
            max = 5,
            per = 10000,
        },
    }, Sessions.Setup)

    Callback.Register('Open', {
        schema = Schema.Define({
            Schema.String({
                min = 1,
                max = 32,
                pattern = '^[%w_%-]+$',
            }),
        }),
        rate = {
            max = 5,
            per = 10000,
        },
        requirePlayer = true,
        requireAlive = true,
    }, Sessions.Open)

    Callback.Register('Save', {
        schema = Schema.Define({ Appearance.Rule(nil, config.maxTattoos) }),
        rate = {
            max = 3,
            per = 10000,
        },
        requirePlayer = true,
    }, Sessions.Save)

    Callback.Register('Close', {
        schema = Schema.Define({}),
        rate = {
            max = 5,
            per = 10000,
        },
    }, Sessions.Close)

    Callback.Register('Pending', {
        schema = Schema.Define({ Appearance.Rule(config.models, config.maxTattoos) }),
        rate = {
            max = 3,
            per = 10000,
        },
    }, Sessions.Pending)

    Callback.Register('Fetch', {
        schema = Schema.Define({
            Schema.Array(Schema.Integer({
                min = 1,
                max = 2147483647,
            }), {
                max = MAX_FETCH,
            }),
        }),
        rate = {
            max = 5,
            per = 10000,
        },
    }, Sessions.Fetch)

    Events.On(CharacterEvents.Loaded, function(source)
        CreateThread(function()
            Sessions.Loaded(source)
        end)
    end)

    Events.On(CharacterEvents.Unloaded, function(source)
        sessions[source] = nil
        saved[source] = nil
    end)

    Events.On(CharacterEvents.Created, function(source, characterId)
        CreateThread(function()
            Sessions.Created(source, characterId)
        end)
    end)

    AddEventHandler('playerDropped', function()
        Sessions.Forget(source --[[@as integer]])
    end)

    -- For trusted resources: housing wardrobes, job lockers, admin tools.
    ---@param target integer
    ---@param kind UgApStoreKind
    ---@param options? { free?: boolean }
    ---@return boolean ok
    ---@return UgErrorCode? errorCode
    local function openStore(target, kind, options)
        if Appearance.KindCategories[kind] == nil or kind == Kind.Creator then
            return false, Errors.InvalidArgs
        end

        return Sessions.Push(target, kind, {
            free = type(options) == 'table' and options.free == true,
        })
    end

    ---@param target integer
    ---@return boolean ok
    ---@return UgErrorCode? errorCode
    local function openWardrobe(target)
        return Sessions.Push(target, Kind.Wardrobe)
    end

    exports('OpenStore', openStore)
    exports('OpenWardrobe', openWardrobe)

    -- For trusted resources: an inventory with clothing slots.
    ---@param target integer
    ---@return table?
    local function getClothing(target)
        if math.type(target) ~= 'integer' then
            return nil
        end

        return Sessions.Clothing(target)
    end

    ---@param target integer
    ---@param parts any
    ---@return boolean ok
    ---@return UgErrorCode? errorCode
    local function setClothing(target, parts)
        if math.type(target) ~= 'integer' then
            return false, Errors.InvalidArgs
        end

        return Sessions.SetClothing(target, parts)
    end

    exports('GetClothing', getClothing)
    exports('SetClothing', setClothing)

    exports('GetAppearance', function(characterId)
        if math.type(characterId) ~= 'integer' then
            return nil
        end

        local _, appearance = Database.Get(characterId)

        return appearance
    end)
end
