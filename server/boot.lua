--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Last server script: loads config, waits for ug-core, creates the tables and registers everything.

local Config = UgAp.Internal.Config
local Logger = UgCore.Logger

local RESOURCE = GetCurrentResourceName()
local READY_TIMEOUT = 60000

---Set once config, ug-core and the database are all usable. Nothing registers before.
---@type boolean
UgAp.Internal.Ready = false

---@return string? problem why this resource cannot run
local function checkCore()
    if not UgCore.Lifecycle.Await(UgCore.Enums.Lifecycle.Ready, READY_TIMEOUT) then
        return 'ug-core did not become ready. Check its console output.'
    end

    if not UgCore.Modules.IsEnabled('characters') then
        return "ug-core's characters module is disabled. Enable it in ug-core's config/modules.lua."
    end

    if not UgAp.Internal.Database.Init() then
        return 'Could not create the ug_appearances and ug_outfits tables. Check oxmysql.'
    end

    return nil
end

CreateThread(function()
    local ok, errors = Config.Load()

    if not ok then
        for _, message in ipairs(errors) do
            Logger.Error(message)
        end

        Logger.Error('Config invalid: %d error(s). ug-appearance stays idle.', #errors)

        return
    end

    local problem = checkCore()

    if problem then
        Logger.Error(problem)
        Logger.Error('ug-appearance stays idle.')

        return
    end

    UgAp.Internal.Sessions.Register()
    UgAp.Internal.Outfits.Register()
    UgAp.Internal.Commands.Register()
    UgAp.Internal.Ready = true

    local config = Config.Get()

    print(('[ug-appearance] v%s ready: %d stores, %d models.'):format(
        GetResourceMetadata(RESOURCE, 'version', 0) or '?',
        #config.stores,
        #config.models
    ))
end)
