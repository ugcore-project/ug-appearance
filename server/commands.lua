--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- The admin editor command and `ugap`, the console inspector.

---@class UgAp.Internal.Commands
local Commands = {}
UgAp.Internal.Commands = Commands

local Config = UgAp.Internal.Config
local Sessions = UgAp.Internal.Sessions
local Logger = UgCore.Logger

local ADMIN_ACE = 'ug-appearance.admin'

---Opens the full editor on a player. `caller` 0 is the console.
---@param caller integer
---@param args string[]
---@return string? problem shown to the console
function Commands.Admin(caller, args)
    if caller ~= 0 and not IsPlayerAceAllowed(tostring(caller), ADMIN_ACE) then
        return nil
    end

    local target = args[1] and math.tointeger(tonumber(args[1])) or caller

    if not target or target <= 0 then
        return 'Usage: appearance <player id>'
    end

    local ok, errorCode = Sessions.Push(target, UgAp.Enums.StoreKind.Admin)

    if not ok then
        return ('Could not open the editor for %d: %s'):format(target, tostring(errorCode))
    end

    Logger.Info('Player %d opened the admin editor for %d.', caller, target)

    return nil
end

---@return string[] lines
function Commands.Status()
    local now = GetGameTimer()
    local lines = {}

    for source, session in pairs(Sessions.All()) do
        lines[#lines + 1] = ('  %d  %s%s  %ds'):format(source, session.kind, session.store and (' ' .. session.store.id) or '', (now - session.openedAt) // 1000)
    end

    table.sort(lines)
    table.insert(lines, 1, ('ug-appearance: %d open session(s).'):format(#lines))

    return lines
end

---Registers the commands. Runs once after a clean boot.
function Commands.Register()
    local name = Config.Get().adminCommand

    if name then
        RegisterCommand(name, function(caller, args)
            local problem = Commands.Admin(caller, args)

            if problem and caller == 0 then
                print(problem)
            end
        end, false)
    end

    RegisterCommand('ugap', function(caller, args)
        if caller ~= 0 then
            return
        end

        if args[1] == 'status' then
            for _, line in ipairs(Commands.Status()) do
                print(line)
            end
        else
            print('Usage: ugap status')
        end
    end, true)
end
