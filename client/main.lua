--[[ ═══════════════════════════════════════════════════════════════════════════
     🐺 LXR-TRAINS — Client: ambient flag, host duty, stations, boarding
     ═══════════════════════════════════════════════════════════════════════════
     Every client asserts the ambient-train flag. The client the server picks
     as host spawns the managed train (_CREATE_MISSION_TRAIN), registers it on
     the network, applies speed / station behaviour and runs one 1 s watcher
     that reports station stops, unexpected halts and loss of the entity.
     Everyone else only reads GlobalState['lxr-trains'] for blips and the
     board prompt. Nothing here is trusted by the server without checks.
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()

local hosted = {}     -- lineId → { train = entity, def = table, station = int|nil, halted = bool }
local blips = {}      -- lineId → blip
local waitingAt = {}  -- lineId → stationIndex while a managed train is waiting

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🚂 AMBIENT
-- ═══════════════════════════════════════════════════════════════════════════════
local function applyAmbient()
    Citizen.InvokeNative(0x1156C6EE7E82A98A, Config.Ambient.enabled)              -- SET_RANDOM_TRAINS
end

CreateThread(function()
    applyAmbient()
    if (Config.Ambient.reapplyEveryMs or 0) > 0 then
        while true do
            Wait(Config.Ambient.reapplyEveryMs)
            applyAmbient()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🧑‍✈️ HOST DUTY
-- ═══════════════════════════════════════════════════════════════════════════════
local function loadTrainModels(configHash)
    local cars = Citizen.InvokeNative(0x635423D55CA84FC8, configHash, Citizen.ResultAsInteger()) -- _GET_NUM_CARS_FROM_TRAIN_CONFIG
    if not cars or cars <= 0 then return false end
    for i = 0, cars - 1 do
        local model = Citizen.InvokeNative(0x8DF5F6A19F99F0D5, configHash, i, Citizen.ResultAsInteger()) -- _GET_TRAIN_MODEL_FROM_TRAIN_CONFIG_BY_CAR_INDEX
        if model and model ~= 0 then
            RequestModel(model)
            local tries = 0
            while not HasModelLoaded(model) and tries < 200 do Wait(25) tries = tries + 1 end
        end
    end
    return true
end

local function spawnTrain(id, def)
    if not loadTrainModels(def.config) then
        LXRCore.Log.warn('trains', 'train config has no cars', { line = id })
        return nil
    end
    local snapped = Citizen.InvokeNative(0x6DE03BCC15E81710, def.spawn.x, def.spawn.y, def.spawn.z, Citizen.ResultAsVector()) -- _GET_NEAREST_TRAIN_TRACK_POSITION
    local at = (snapped and #(snapped) > 0.0) and snapped or def.spawn
    local train = Citizen.InvokeNative(0xC239DBD9A57D2A71, def.config, at.x, at.y, at.z, def.direction, def.passengers, true, def.conductor, Citizen.ResultAsInteger()) -- _CREATE_MISSION_TRAIN
    if not train or train == 0 then return nil end
    local tries = 0
    while not Citizen.InvokeNative(0xBD3C4A2ED509205E, train) and tries < 100 do Wait(50) tries = tries + 1 end -- _HAS_TRAIN_LOADED
    NetworkRegisterEntityAsNetworked(train)
    SetEntityAsMissionEntity(train, true, true)
    if Config.Managed.pinOwnership then
        -- ownership hand-overs teleport a train to the first node of its track and drop its
        -- carriages on current builds; the host keeps the train and the server re-hosts by
        -- respawning instead (citizenfx/fivem#4205 tracks the engine-side fix)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(train), false)
    end
    Citizen.InvokeNative(0x4182C037AA1F0091, train, def.stopsAtStations == true)          -- _SET_TRAIN_STOPS_FOR_STATIONS
    Citizen.InvokeNative(0x01021EB2E96B793C, train, def.cruiseSpeed + 0.0)               -- SET_TRAIN_CRUISE_SPEED
    Citizen.InvokeNative(0x9F29999DFDF2AEB8, train, def.cruiseSpeed + 0.0)               -- _SET_TRAIN_MAX_SPEED
    Citizen.InvokeNative(0xE6BD7DD3FD474415, train, def.collisionAvoidance == true)      -- _SET_TRAIN_COLLISION_AVOIDANCE_ENABLED
    Citizen.InvokeNative(0x07E2E21E799080A0, train, def.destructible == true)            -- _SET_TRAIN_DESTRUCTION_ENABLED
    Citizen.InvokeNative(0x06A09A6E0C6D2A84, train, def.reverseAllowed == true)          -- _SET_TRAIN_REVERSE_ENABLED
    if def.stationWaitMs then Citizen.InvokeNative(0x8EC47DD4300BF063, train, 0.0) end   -- SET_TRAIN_OFFSET_FROM_STATION (keep default alignment)
    return train
end

local function watch(id)
    CreateThread(function()
        local h = hosted[id]
        while h and hosted[id] == h do
            Wait(1000)
            if not DoesEntityExist(h.train) or not NetworkHasControlOfEntity(h.train) then
                hosted[id] = nil
                TriggerServerEvent('lxr-trains:server:lost', id)
                return
            end
            -- a consist that lost carriages is not our train any more: hand it back for a clean respawn
            if h.cars and Citizen.InvokeNative(0x60B7D1DCC312697D, h.train, Citizen.ResultAsInteger()) < h.cars then
                hosted[id] = nil
                Citizen.InvokeNative(0x0D3630FB07E8B570, Citizen.PointerValueIntInitialized(h.train)) -- DELETE_MISSION_TRAIN
                TriggerServerEvent('lxr-trains:server:lost', id)
                return
            end
            local waiting = Citizen.InvokeNative(0xE887BD31D97793F6, h.train)                        -- IS_TRAIN_WAITING_AT_STATION
            local station = Citizen.InvokeNative(0x86FA6D8B48667D75, h.train, Citizen.ResultAsInteger()) -- GET_CURRENT_STATION_FOR_TRAIN
            if waiting and h.station ~= station then
                h.station = station
                TriggerServerEvent('lxr-trains:server:station', id, station, true)
                if h.def.whistleAtStops then Citizen.InvokeNative(0xCFE122EC635CC2B2, h.train, 'WHISTLE_SHORT', true, false) end -- _TRIGGER_TRAIN_WHISTLE
            elseif not waiting and h.station ~= nil then
                TriggerServerEvent('lxr-trains:server:station', id, h.station, false)
                h.station = nil
            end
            -- stopped outside a station for a while → robbery hook
            local speed = GetEntitySpeed(h.train)
            if h.def.robbable and not waiting and speed < 0.2 then
                h.stillFor = (h.stillFor or 0) + 1
                if h.stillFor == 5 and not h.halted then
                    h.halted = true
                    local c = GetEntityCoords(h.train)
                    TriggerServerEvent('lxr-trains:server:halted', id, { x = c.x, y = c.y, z = c.z })
                end
            else
                h.stillFor, h.halted = 0, false
            end
        end
    end)
end

RegisterNetEvent('lxr-trains:client:host', function(id, def)
    if hosted[id] then return end
    local train = spawnTrain(id, def)
    if not train then return TriggerServerEvent('lxr-trains:server:lost', id) end
    hosted[id] = { train = train, def = def, cars = Citizen.InvokeNative(0x60B7D1DCC312697D, train, Citizen.ResultAsInteger()) } -- _GET_TRAIN_CARRIAGE_TRAILER_NUMBER
    TriggerServerEvent('lxr-trains:server:spawned', id, NetworkGetNetworkIdFromEntity(train))
    watch(id)
end)

RegisterNetEvent('lxr-trains:client:release', function(id)
    local h = hosted[id]
    hosted[id] = nil
    if h and DoesEntityExist(h.train) then
        local ptr = h.train
        Citizen.InvokeNative(0x0D3630FB07E8B570, Citizen.PointerValueIntInitialized(ptr)) -- DELETE_MISSION_TRAIN
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🗺️ BLIPS & STATE
-- ═══════════════════════════════════════════════════════════════════════════════
local function refreshBlips()
    local state = GlobalState['lxr-trains'] or {}
    for id, b in pairs(blips) do
        if not state[id] or not state[id].netId then RemoveBlip(b) blips[id] = nil end
    end
    for id, info in pairs(state) do
        if info.netId and info.blip and info.blip.enabled and not blips[id] and NetworkDoesNetworkIdExist(info.netId) then
            local ent = NetworkGetEntityFromNetworkId(info.netId)
            if ent ~= 0 then
                local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, joaat('BLIP_STYLE_OBJECTIVE'), ent) -- BLIP_ADD_FOR_ENTITY
                if blip and blip ~= 0 then
                    Citizen.InvokeNative(0x74F74D3207ED525C, blip, joaat(info.blip.sprite or 'blip_train'), true) -- SET_BLIP_SPRITE
                    Citizen.InvokeNative(0x9CB1A1623062F402, blip, info.blip.label or info.label)                 -- SET_BLIP_NAME_FROM_PLAYER_STRING
                    blips[id] = blip
                end
            end
        end
    end
end

AddStateBagChangeHandler('lxr-trains', 'global', function() Wait(500) refreshBlips() end)
CreateThread(function() Wait(3000) refreshBlips() end)

RegisterNetEvent('lxr-trains:client:station', function(id, stationIndex, waiting)
    waitingAt[id] = waiting and stationIndex or nil
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🎫 STATIONS — ticket prompts
-- ═══════════════════════════════════════════════════════════════════════════════
local function openTicketMenu(station)
    local options = {}
    for _, s in ipairs(Config.Stations) do
        if s.id ~= station.id then
            options[#options + 1] = { id = s.id, label = s.label, price = s.price }
        end
    end
    -- lxr-menu when present, otherwise a simple cycling prompt list via notifications
    if GetResourceState('lxr-menu') == 'started' then
        local items = {}
        for _, o in ipairs(options) do
            items[#items + 1] = { header = o.label, txt = Lang:t('ui.price', { price = o.price }), params = { event = 'lxr-trains:client:buy', args = { station.id, o.id } } }
        end
        if Config.Riding.fastTravel.enabled then
            items[#items + 1] = { header = Lang:t('ui.fast_travel'), txt = Lang:t('ui.fast_travel_desc', { surcharge = Config.Riding.fastTravel.surcharge }), params = { event = 'lxr-trains:client:fastTravelMenu', args = { station.id } } }
        end
        items[#items + 1] = { header = Lang:t('ui.close'), params = { event = 'lxr-menu:client:closeMenu' } }
        exports['lxr-menu']:openMenu(items)
    else
        -- fallback: sell a ticket to the next station in the list
        local next = options[1]
        if next then TriggerEvent('lxr-trains:client:buy', station.id, next.id) end
    end
end

RegisterNetEvent('lxr-trains:client:buy', function(fromId, toId, fast)
    local ok, res = LXR.RPC.Server('lxr-trains:buyTicket', fromId, toId, fast == true)
    if not ok then return LXRCore.Functions.Notify(Lang:t('error.' .. tostring(res)), 'error') end
    if type(res) == 'table' and res.fastTravel then
        DoScreenFadeOut(800)
        Wait(900)
        local ped = PlayerPedId()
        SetEntityCoords(ped, res.to.x, res.to.y, res.to.z, false, false, false, false)
        Wait(math.max(0, (Config.Riding.fastTravel.travelMs or 3000) - 900))
        DoScreenFadeIn(800)
        LXRCore.Functions.Notify(Lang:t('info.arrived'), 'success')
    else
        LXRCore.Functions.Notify(Lang:t('info.ticket_bought', { price = res.price }), 'success')
    end
end)

RegisterNetEvent('lxr-trains:client:fastTravelMenu', function(fromId)
    if GetResourceState('lxr-menu') ~= 'started' then return end
    local items = {}
    for _, s in ipairs(Config.Stations) do
        if s.id ~= fromId then
            items[#items + 1] = { header = s.label, txt = Lang:t('ui.price', { price = s.price + Config.Riding.fastTravel.surcharge }), params = { event = 'lxr-trains:client:buy', args = { fromId, s.id, true } } }
        end
    end
    items[#items + 1] = { header = Lang:t('ui.close'), params = { event = 'lxr-menu:client:closeMenu' } }
    exports['lxr-menu']:openMenu(items)
end)

CreateThread(function()
    if not Config.Tickets.enabled then return end
    for _, s in ipairs(Config.Stations) do
        LXRCore.Prompts.Create('lxr-trains:station:' .. s.id, s.coords, Config.Tickets.promptKey, Lang:t('prompt.tickets', { station = s.label }),
            { type = 'callback', event = function() openTicketMenu(s) end }, Config.Tickets.promptDistance, nil, 0)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🚉 BOARDING — prompt when a managed train waits nearby
-- ═══════════════════════════════════════════════════════════════════════════════
local boardPrompt
CreateThread(function()
    while true do
        local sleep = 1000
        local state = GlobalState['lxr-trains'] or {}
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local near, nearId
        for id, info in pairs(state) do
            if info.netId and waitingAt[id] ~= nil and NetworkDoesNetworkIdExist(info.netId) then
                local ent = NetworkGetEntityFromNetworkId(info.netId)
                if ent ~= 0 then
                    -- distance to the closest carriage
                    local n = Citizen.InvokeNative(0x60B7D1DCC312697D, ent, Citizen.ResultAsInteger()) or 0 -- _GET_TRAIN_CARRIAGE_TRAILER_NUMBER
                    for i = 0, math.max(0, n) do
                        local car = Citizen.InvokeNative(0xD0FB093A4CDB932C, ent, i, Citizen.ResultAsInteger()) -- GET_TRAIN_CARRIAGE
                        if car and car ~= 0 and #(GetEntityCoords(car) - pos) <= Config.Riding.boardDistance then near, nearId = car, id break end
                    end
                end
            end
            if near then break end
        end
        if near and not IsPedInAnyVehicle(ped, false) and not Citizen.InvokeNative(0x6F972C1AB75A1ED0, ped) then -- IS_PED_IN_ANY_TRAIN
            sleep = 0
            if not boardPrompt then boardPrompt = LXRCore.Prompts.Register(Config.Riding.boardKey, Lang:t('prompt.board', { line = state[nearId].label }), 0) end
            PromptSetEnabled(boardPrompt, true)
            PromptSetVisible(boardPrompt, true)
            if Citizen.InvokeNative(0xC92AC953F0A982AE, boardPrompt) then -- PROMPT_HAS_STANDARD_MODE_COMPLETED
                local ok, err = LXR.RPC.Server('lxr-trains:canBoard', nearId)
                if ok then
                    local c = GetEntityCoords(near)
                    Citizen.InvokeNative(0x3774B03456DD6106, ped, c.x, c.y, c.z, 12.0) -- TASK_USE_NEAREST_TRAIN_SCENARIO_TO_COORD_WARP
                else
                    LXRCore.Functions.Notify(Lang:t('error.' .. tostring(err)), 'error')
                end
                Wait(1500)
            end
        elseif boardPrompt then
            PromptSetEnabled(boardPrompt, false)
            PromptSetVisible(boardPrompt, false)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(hosted) do TriggerEvent('lxr-trains:client:release', id) end
    for _, b in pairs(blips) do RemoveBlip(b) end
    if boardPrompt then PromptDelete(boardPrompt) end
end)
