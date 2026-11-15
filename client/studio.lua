--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- The studio around the ped: a camera that frames the part being edited, turning, zoom, preview poses and lights.
-- The camera stays where the ped first faced; turning moves the ped, so the lights and the view keep their place.

---@class UgApStudioSettings
---@field duration integer
---@field ease UgApEase
---@field minDistance number
---@field maxDistance number
---@field zoomDuration? integer
---@field presets table<UgApCamera, { distance: number, height: number, fov: number }>

---The light presets' clock and lamps, from the owner config.
---@class UgApStudioLights
---@field dayHour integer
---@field nightHour integer
---@field lights { angle: number, distance: number, height: number, color: integer[], range: number, intensity: number }[]

---@class UgAp.Internal.Studio
local Studio = {}
UgAp.Internal.Studio = Studio

local Camera = UgAp.Internal.Camera
local Light = UgAp.Enums.Light
local CameraPreset = UgAp.Enums.Camera

-- Zoom settles faster than preset changes, unless the owner set camera.zoomDuration.
local QUICK_MS = 150
-- Used when the setup has no studio table.
local DEFAULT_STUDIO = {
    dayHour = 12,
    nightHour = 23,
    lights = {},
}

---@class UgApStudioState
---@field ped integer
---@field origin vector3
---@field heading number the ped's heading now
---@field view number the heading the camera looks from, fixed at start
---@field settings UgApStudioSettings
---@field studio UgApStudioLights
---@field poses table[]
---@field preset UgApCamera
---@field distance number
---@field height number
---@field fov number
---@field light UgApLight
---@field clock boolean

---@type UgApStudioState?
local state = nil
local move = 0

---@return boolean
function Studio.IsOpen()
    return state ~= nil
end

---@return integer?
function Studio.Ped()
    return state and state.ped
end

---The camera pose for the current preset and zoom.
---@return UgApCameraPose
function Studio.Shot()
    assert(state, 'Studio.Shot without a studio')

    local fx, fy = Camera.Forward(state.view)
    local origin = state.origin
    local at = vector3(origin.x + fx * state.distance, origin.y + fy * state.distance, origin.z + state.height)

    return {
        coords = at,
        rotation = Camera.LookAt(at, vector3(origin.x, origin.y, origin.z + state.height)),
        fov = state.fov,
    }
end

---Glides the camera to the current pose.
---@param duration integer
local function glide(duration)
    move = move + 1

    local id = move
    local from = Camera.Get()
    local to = Studio.Shot()

    if not from or duration <= 0 then
        Camera.Set(to)

        return
    end

    local ease = state and state.settings.ease
    local started = GetGameTimer()

    CreateThread(function()
        while id == move and state do
            local t = (GetGameTimer() - started) / duration

            Camera.Set(Camera.Mix(from, to, Camera.Ease(ease, t)))

            if t >= 1 then
                return
            end

            Wait(0)
        end
    end)
end

---Frames a preset at its own distance.
---@param preset UgApCamera
function Studio.Frame(preset)
    if not state then
        return
    end

    local shot = state.settings.presets[preset]

    if not shot then
        return
    end

    state.preset, state.distance, state.height, state.fov = preset, shot.distance, shot.height, shot.fov
    glide(state.settings.duration)
end

---Moves the camera closer (negative) or further (positive), in meters.
---@param delta number
function Studio.Zoom(delta)
    if not state then
        return
    end

    local settings = state.settings

    state.distance = math.min(math.max(state.distance + delta, settings.minDistance), settings.maxDistance)
    glide(settings.zoomDuration or QUICK_MS)
end

---Turns the ped by `delta` degrees.
---@param delta number
function Studio.Rotate(delta)
    if not state then
        return
    end

    state.heading = (state.heading + delta) % 360
    SetEntityHeading(state.ped, state.heading)
end

---Plays a preview pose by id. MUST run in a thread.
---@param id string
function Studio.Pose(id)
    if not state then
        return
    end

    for _, pose in ipairs(state.poses) do
        if pose.id == id then
            ClearPedTasks(state.ped)

            if pose.scenario then
                UgLib.Animation.Scenario(state.ped, pose.scenario)
            elseif pose.dict then
                UgLib.Animation.Play(state.ped, pose.dict, pose.name, {
                    flag = pose.flag or 1,
                })
            end

            return
        end
    end
end

---@param light UgApLight
function Studio.Light(light)
    if not state then
        return
    end

    state.light = light

    local studio = state.studio
    local hour = (light == Light.Day and studio.dayHour) or (light == Light.Night and studio.nightHour) or nil

    if hour then
        NetworkOverrideClockTime(hour, 0, 0)
        state.clock = true
    elseif state.clock then
        NetworkClearClockTimeOverride()
        state.clock = false
    end
end

---Draws the studio lights around the ped, from the camera side.
local function drawLights()
    if not state then
        return
    end

    local origin = state.origin

    for _, light in ipairs(state.studio.lights) do
        local fx, fy = Camera.Forward(state.view + light.angle)

        DrawLightWithRangeAndShadow(origin.x + fx * light.distance, origin.y + fy * light.distance, origin.z + light.height,
            light.color[1], light.color[2], light.color[3], light.range, light.intensity, 1.0)
    end
end

---Opens the studio around a ped: frozen, invincible, HUD and controls off, the camera gliding to the full shot.
---@param ped integer
---@param settings UgApStudioSettings
---@param poses table[]
---@param studio? UgApStudioLights
---@param light? UgApLight the preset on at start, natural by default
function Studio.Start(ped, settings, poses, studio, light)
    if state then
        Studio.Stop()
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    state = {
        ped = ped,
        origin = vector3(coords.x, coords.y, coords.z),
        heading = heading,
        view = heading,
        settings = settings,
        studio = studio or DEFAULT_STUDIO,
        poses = poses,
        preset = CameraPreset.Full,
        distance = settings.maxDistance,
        height = settings.presets[CameraPreset.Full].height,
        fov = settings.presets[CameraPreset.Full].fov,
        light = Light.Natural,
        clock = false,
    }

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    Camera.Set(Studio.Shot())
    Studio.Frame(CameraPreset.Full)
    Studio.Light(light or Light.Natural)

    local current = state

    CreateThread(function()
        while state == current do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)

            if current.light == Light.Studio then
                drawLights()
            end

            Wait(0)
        end
    end)
end

---Puts everything back: camera, clock, ped state. Safe to call when closed.
function Studio.Stop()
    if not state then
        return
    end

    local ped, duration, clock = state.ped, state.settings.duration, state.clock

    state = nil
    move = move + 1

    if clock then
        NetworkClearClockTimeOverride()
    end

    if DoesEntityExist(ped) then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
    end

    Camera.Release(duration)
end

---Moves the studio to another ped in the same place, such as after a model swap. The camera stays.
---@param ped integer
function Studio.SetPed(ped)
    if not state then
        return
    end

    state.ped = ped
    SetEntityHeading(ped, state.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end
