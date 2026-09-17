--[[ ═══════════════════════════════════════════════════════════════════════════
     🐺 LXR-TRAINS — Server: timetable, hosts, tickets
     ═══════════════════════════════════════════════════════════════════════════
     The server never touches a train entity; it decides which client hosts
     each managed line, records the network id the host reports, and re-hosts
     when that player leaves. Tickets are sold here (money through lxr-core,
     ticket as a catalog item with info.from/to). Everything a client sends is
     validated: distance to the spawn point when reporting, rate limits,
     ticket ownership on boarding.
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()

local lines = {}        -- id → { def, host = src|nil, netId = int|nil, since = ms, respawnAt = ms|nil }
local buckets = {}

local function log(level, msg, data) LXRCore.Log[level]('trains', msg, data) end

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then
        b = { at = now, n = 0 }
        buckets[src] = b
    end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end

local function configHash(ref)
    if type(ref) == 'number' then return ref end
    return Config.TrainConfigs[ref] or joaat(ref)
end

local function publish()
    local out = {}
    for id, l in pairs(lines) do
        out[id] = { netId = l.netId, host = l.host, label = l.def.label, blip = l.def.blip, fare = l.def.fare, stops = l.def.stopsAtStations }
    end
    GlobalState['lxr-trains'] = out
end

local function loadedPlayers()
    local out = {}
    for src in pairs(LXRCore.Players) do out[#out + 1] = src end
    return out
end

local function pickHost(def)
    local players = loadedPlayers()
    if #players == 0 then return nil end
    if Config.Managed.hostSelection ~= 'nearest' then return players[1] end
    local best, bestD = nil, math.huge
    for _, src in ipairs(players) do
        local ped = GetPlayerPed(src)
        if ped ~= 0 then
            local d = #(GetEntityCoords(ped) - def.spawn)
            if d < bestD then best, bestD = src, d end
        end
    end
    return best or players[1]
end

local function assignHost(id)
    local l = lines[id]
    if not l or l.netId then return end
    local host = pickHost(l.def)
    if not host then return end
    l.host = host
    l.since = GetGameTimer()
    TriggerClientEvent('lxr-trains:client:host', host, id, {
        config = configHash(l.def.config), spawn = l.def.spawn, direction = l.def.direction,
        cruiseSpeed = l.def.cruiseSpeed, stopsAtStations = l.def.stopsAtStations, passengers = l.def.passengers,
        conductor = l.def.conductor, whistleAtStops = l.def.whistleAtStops, robbable = l.def.robbable,
        collisionAvoidance = Config.Managed.collisionAvoidance, destructible = Config.Managed.destructible,
        reverseAllowed = Config.Managed.reverseAllowed, stationWaitMs = Config.Riding.stationWaitMs,
    })
    log('info', 'host assigned', { line = id, host = host })
end

local function releaseLine(id, reason)
    local l = lines[id]
    if not l then return end
    if l.host and l.netId then
        TriggerClientEvent('lxr-trains:client:release', l.host, id)
    end
    l.host, l.netId = nil, nil
    l.respawnAt = GetGameTimer() + Config.Managed.respawnDelayMs
    publish()
    LXRCore.Emit('lxr:train:removed', {}, id, reason)
end

-- host reports the spawned train
RegisterNetEvent('lxr-trains:server:spawned', function(id, netId)
    local src = source
    if limited(src) then return end
    local l = lines[id]
    if not l or l.host ~= src then
        return LXRCore.Log.exploit(src, 'reported a train for a line it does not host', { line = tostring(id) })
    end
    local ped = GetPlayerPed(src)
    if ped ~= 0 and #(GetEntityCoords(ped) - l.def.spawn) > Config.Security.hostReportRange then
        LXRCore.Log.exploit(src, 'train report from too far away', { line = id })
        return releaseLine(id, 'bad_host')
    end
    l.netId = tonumber(netId)
    publish()
    LXRCore.Emit('lxr:train:spawned', {}, id, l.netId, src)
    log('info', 'train running', { line = id, netId = l.netId, host = src })
end)

RegisterNetEvent('lxr-trains:server:lost', function(id)
    local src = source
    local l = lines[id]
    if not l or l.host ~= src then return end
    log('warn', 'host lost the train', { line = id, host = src })
    releaseLine(id, 'lost')
end)

RegisterNetEvent('lxr-trains:server:station', function(id, stationIndex, waiting)
    local src = source
    local l = lines[id]
    if not l or l.host ~= src then return end
    LXRCore.Emit(waiting and 'lxr:train:arrived' or 'lxr:train:departed', {}, id, stationIndex)
    TriggerClientEvent('lxr-trains:client:station', -1, id, stationIndex, waiting)
end)

RegisterNetEvent('lxr-trains:server:halted', function(id, coords)
    local src = source
    local l = lines[id]
    if not l or l.host ~= src or not l.def.robbable then return end
    LXRCore.Emit('lxr:train:halted', {}, id, coords)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🎫 TICKETS
-- ═══════════════════════════════════════════════════════════════════════════════
local function stationById(id)
    for _, s in ipairs(Config.Stations) do if s.id == id then return s end end
end

local function jobFree(Player)
    local job = Player.PlayerData.job and Player.PlayerData.job.name
    for _, j in ipairs(Config.Tickets.freeForJobs) do if j == job then return true end end
    return false
end

LXR.RPC.Register('lxr-trains:buyTicket', function(src, fromId, toId, fastTravel)
    if limited(src) then return false, 'rate' end
    local Player = LXRCore.Functions.GetPlayer(src)
    if not Player or not Config.Tickets.enabled then return false, 'disabled' end
    local from, to = stationById(fromId), stationById(toId)
    if not from or not to or from == to then return false, 'invalid' end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - from.coords) > Config.Tickets.promptDistance + 3.0 then
        LXRCore.Log.exploit(src, 'ticket purchase away from the station', { from = fromId })
        return false, 'too_far'
    end
    local held = LXRCore.Inventory.GetItemCount(src, Config.Tickets.item)
    if held >= Config.Security.maxTicketsHeld then return false, 'too_many' end
    local price = to.price or 0
    if fastTravel and Config.Riding.fastTravel.enabled then price = price + (Config.Riding.fastTravel.surcharge or 0) end
    if jobFree(Player) then price = 0 end
    if price > 0 and not Player.Functions.RemoveMoney(Config.Tickets.account, price, 'train ticket ' .. from.id .. '>' .. to.id) then
        return false, 'no_money'
    end
    if fastTravel and Config.Riding.fastTravel.enabled then
        LXRCore.Emit('lxr:train:fastTravel', {}, src, from.id, to.id, price)
        return true, { fastTravel = true, to = { x = to.coords.x, y = to.coords.y, z = to.coords.z }, price = price }
    end
    local ok = Player.Functions.AddItem(Config.Tickets.item, 1, nil, { from = from.id, to = to.id, fromLabel = from.label, toLabel = to.label, paid = price, paidAt = os.time() }, 'train ticket')
    if not ok then
        if price > 0 then Player.Functions.AddMoney(Config.Tickets.account, price, 'train ticket refund') end
        return false, 'inventory_full'
    end
    LXRCore.Emit('lxr:train:ticket', {}, src, from.id, to.id, price)
    return true, { price = price }
end)

LXR.RPC.Register('lxr-trains:canBoard', function(src, lineId)
    local Player = LXRCore.Functions.GetPlayer(src)
    if not Player then return false end
    local l = lines[lineId]
    if not l or not l.netId then return false, 'no_train' end
    if not Config.Tickets.requireTicketToBoard or jobFree(Player) then return true end
    local fare = l.def.fare
    if fare ~= nil then
        if fare > 0 and not Player.Functions.RemoveMoney(Config.Tickets.account, fare, 'fare ' .. lineId) then return false, 'no_money' end
        return true
    end
    local ticket = LXRCore.Inventory.GetItem(src, Config.Tickets.item)
    if not ticket then return false, 'no_ticket' end
    Player.Functions.RemoveItem(Config.Tickets.item, 1, ticket.slot, 'boarded')
    LXRCore.Emit('lxr:train:boarded', {}, src, lineId, ticket.info)
    return true
end)

LXR.Commands.Register({
    name = 'ticketrefund', help = Lang:t('command.ticketrefund'), permission = 'user',
    handler = function(src)
        if (Config.Tickets.refundOnUnusedPct or 0) <= 0 then return end
        local Player = LXRCore.Functions.GetPlayer(src)
        if not Player then return end
        local ped = GetPlayerPed(src)
        local near = false
        for _, s in ipairs(Config.Stations) do if #(GetEntityCoords(ped) - s.coords) < 5.0 then near = true break end end
        if not near then return LXRCore.Notify(src, Lang:t('error.not_at_station'), 'error') end
        local ticket = LXRCore.Inventory.GetItem(src, Config.Tickets.item)
        if not ticket then return LXRCore.Notify(src, Lang:t('error.no_ticket'), 'error') end
        local back = LXRShared.Round((tonumber(ticket.info and ticket.info.paid) or 0) * Config.Tickets.refundOnUnusedPct / 100, 2)
        if Player.Functions.RemoveItem(Config.Tickets.item, 1, ticket.slot, 'refund') then
            if back > 0 then Player.Functions.AddMoney(Config.Tickets.account, back, 'ticket refund') end
            LXRCore.Notify(src, Lang:t('info.refunded', { amount = back }), 'success')
        end
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🛠️ ADMIN
-- ═══════════════════════════════════════════════════════════════════════════════
if Config.Debug.adminCommands then
    LXR.Commands.Register({
        name = 'train', help = Lang:t('command.train'), permission = 'admin',
        args = { { name = 'action', help = 'spawn | delete | list' }, { name = 'line', help = 'line id' } },
        handler = function(src, args)
            local action, id = args[1], args[2]
            if action == 'list' then
                for lid, l in pairs(lines) do
                    LXRCore.Notify(src, ('%s: %s host=%s net=%s'):format(lid, l.def.label, tostring(l.host), tostring(l.netId)), 'info', 6000)
                end
            elseif action == 'delete' and lines[id] then
                releaseLine(id, 'admin')
            elseif action == 'spawn' and lines[id] then
                lines[id].respawnAt = nil
                assignHost(id)
            else
                LXRCore.Notify(src, Lang:t('error.unknown_line'), 'error')
            end
        end,
    })
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ⏱️ SCHEDULER
-- ═══════════════════════════════════════════════════════════════════════════════
local function tick()
    local now = GetGameTimer()
    local anyone = next(LXRCore.Players) ~= nil
    for id, l in pairs(lines) do
        if l.host and not LXRCore.Players[l.host] then
            log('warn', 'host disconnected', { line = id, host = l.host })
            l.host, l.netId = nil, nil
            l.respawnAt = now + 1000
            publish()
        end
        if not anyone and Config.Managed.despawnWhenEmpty and l.netId then
            releaseLine(id, 'empty')
        elseif anyone and not l.host and (not l.respawnAt or now >= l.respawnAt) then
            assignHost(id)
        end
    end
end

CreateThread(function()
    if not Config.Managed.enabled then return end
    for _, def in ipairs(Config.Lines) do lines[def.id] = { def = def } end
    publish()
    while true do
        Wait(Config.Managed.hostCheckMs)
        tick()
    end
end)

AddEventHandler('playerDropped', function()
    buckets[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(lines) do releaseLine(id, 'stop') end
    GlobalState['lxr-trains'] = nil
end)

CreateThread(function()
    Wait(1500)
    if not Config.Debug.printBanner then return end
    print('^5═══════════════════════════════════════════════════════════════════════════════^7')
    print(('^5🐺 LXR-TRAINS^7 ^3v%s^7 — ambient %s · %d managed line(s) · %d station(s) · tickets %s'):format(
        GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?',
        Config.Ambient.enabled and '^2ON^7' or '^1OFF^7', #Config.Lines, #Config.Stations, Config.Tickets.enabled and '^2ON^7' or '^1OFF^7'))
    print('^5═══════════════════════════════════════════════════════════════════════════════^7')
end)
