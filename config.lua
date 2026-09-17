--[[
    ██╗     ██╗  ██╗██████╗       ████████╗██████╗  █████╗ ██╗███╗   ██╗███████╗
    ██║     ╚██╗██╔╝██╔══██╗      ╚══██╔══╝██╔══██╗██╔══██╗██║████╗  ██║██╔════╝
    ██║      ╚███╔╝ ██████╔╝█████╗   ██║   ██████╔╝███████║██║██╔██╗ ██║███████╗
    ██║      ██╔██╗ ██╔══██╗╚════╝   ██║   ██╔══██╗██╔══██║██║██║╚██╗██║╚════██║
    ███████╗██╔╝ ██╗██║  ██║         ██║   ██║  ██║██║  ██║██║██║ ╚████║███████║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝         ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝

    🐺 LXR Core - Trains & Tramway

    Keeps the railroad alive: the game's ambient trains and the Saint Denis
    trolley (which RedM leaves to chance), plus server-managed lines that run
    on a timetable, stop at stations, sell tickets and can be robbed. One host
    client spawns each managed train; the server owns the timetable and hands
    the train to another player when the host leaves, so the 3:15 to Annesburg
    keeps running whoever is online.

    ═══════════════════════════════════════════════════════════════════════════════
    SERVER INFORMATION
    ═══════════════════════════════════════════════════════════════════════════════

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves 🐺
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/ZHMKVYyhBa (development)
    GitHub:      https://github.com/LXRCore

    ═══════════════════════════════════════════════════════════════════════════════

    Version: 1.0.0
    Performance Target: 0.00 ms idle on non-host clients; host runs one 1 s watcher per train

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████

Config.Lang = 'en' -- any file in locales/ ('en', 'ka'); missing keys fall back to English

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ AMBIENT RAIL TRAFFIC ██████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
-- The game's own trains: freight and passenger trains roaming every line and
-- the Saint Denis trolley. RedM does not guarantee them, so we ask for them
-- explicitly on every client.
Config.Ambient = {
    enabled        = true,   -- SetRandomTrains(true) on every client (false = no ambient trains at all)
    whistles       = true,   -- ambient trains blow their whistle
    lawOnTrains    = true,   -- lawmen ride ambient trains (game default)
    reapplyEveryMs = 60000,  -- some scripts / cutscenes reset the flag; re-assert on a timer (0 = only at load)
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ MANAGED LINES ██████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
-- Server-managed trains. Each line is one train that always exists while
-- players are online: spawned by a host client, cruising at `cruiseSpeed`,
-- stopping at stations when `stopsAtStations` is true.
-- `config` is a train config name (see docs/TRAIN-CONFIGS.md) or a hash.
Config.Managed = {
    enabled            = true,
    hostSelection      = 'nearest', -- 'nearest' (player closest to the spawn point) or 'first'
    pinOwnership       = true,      -- the host keeps the train; no OneSync migration (migrating trains teleport and lose carriages on current builds)
    respawnDelayMs     = 15000,     -- wait after the train vanished (host left / deleted) before spawning again
    hostCheckMs        = 5000,      -- server timer that verifies hosts are still connected
    despawnWhenEmpty   = true,      -- delete managed trains when the server has no loaded players
    collisionAvoidance = true,      -- trains slow for each other on shared track
    destructible       = false,     -- false: dynamite does not derail managed trains
    reverseAllowed     = false,
}

Config.Lines = {
    {
        id            = 'trolley',
        label         = 'Saint Denis Trolley',
        config        = 'trolley_config',            -- 0xBF69518F
        spawn         = vector3(2551.94, -1327.53, 46.5),  -- on the trolley loop; the game snaps to the nearest track point
        direction     = true,
        cruiseSpeed   = 4.0,                          -- m/s  (~14 km/h)
        stopsAtStations = true,
        passengers    = true,
        conductor     = true,
        whistleAtStops = false,
        blip          = { enabled = true, sprite = 'blip_train_tram', label = 'Trolley' },
        fare          = 0.05,                         -- $ charged when boarding (0 = free)
    },
    {
        id            = 'express',
        label         = 'Eastern Express',
        config        = 'engine_config',              -- 0x3260CE89 — engine + passenger cars
        spawn         = vector3(-322.12, 812.68, 118.0), -- near Valentine station
        direction     = true,
        cruiseSpeed   = 12.0,                         -- m/s (~43 km/h)
        stopsAtStations = true,
        passengers    = true,
        conductor     = true,
        whistleAtStops = true,
        blip          = { enabled = true, sprite = 'blip_train', label = 'Passenger Train' },
        fare          = nil,                          -- nil: use the station's ticket price
        robbable      = true,                         -- fires lxr:train:halted when stopped outside a station
    },
    {
        id            = 'freight',
        label         = 'Annesburg Freight',
        config        = 'industry2_config',           -- 0x767DEB32 — freight consist
        spawn         = vector3(2934.0, 1373.0, 58.0),  -- near Annesburg
        direction     = false,
        cruiseSpeed   = 10.0,
        stopsAtStations = false,
        passengers    = false,
        conductor     = true,
        whistleAtStops = false,
        blip          = { enabled = false },
        robbable      = true,
    },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ STATIONS & TICKETS ████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
-- Fares: 3¢ a mile, the 1899 passenger rate. Price is the fare *to* this station.
Config.Stations = {
    { id = 'valentine',  label = 'Valentine',       coords = vector3(-172.35, 628.9, 114.09),  price = 1.20 },
    { id = 'emerald',    label = 'Emerald Station',  coords = vector3(1524.03, 440.05, 90.68),  price = 0.75 },
    { id = 'rhodes',     label = 'Rhodes',           coords = vector3(1226.71, -1301.17, 76.9), price = 1.80 },
    { id = 'saintdenis', label = 'Saint Denis',      coords = vector3(2745.72, -1394.6, 46.18), price = 2.40 },
    { id = 'annesburg',  label = 'Annesburg',        coords = vector3(2932.84, 1367.86, 58.38), price = 2.10 },
    { id = 'wallace',    label = 'Wallace Station',  coords = vector3(-1301.49, 401.66, 95.4),  price = 1.50 },
    { id = 'riggs',      label = 'Riggs Station',    coords = vector3(-1092.06, -576.4, 82.4),  price = 1.35 },
    { id = 'flatneck',   label = 'Flatneck Station', coords = vector3(-334.9, -364.2, 88.3),    price = 0.90 },
    { id = 'armadillo',  label = 'Armadillo',        coords = vector3(-3728.4, -2599.8, -13.3), price = 3.60 },
    { id = 'benedict',   label = 'Benedict Point',   coords = vector3(-5228.6, -3470.1, -21.0), price = 4.20 },
}

Config.Tickets = {
    enabled        = true,
    item           = 'train_ticket',   -- catalog item; info.from / info.to / info.paidAt
    account        = 'cash',
    promptDistance = 2.0,
    promptKey      = 0xCEFD9220,       -- E
    requireTicketToBoard = true,       -- false: anyone may climb aboard a stopped train
    refundOnUnusedPct = 50,            -- /ticketrefund at a station gives this % back (0 = disabled)
    freeForJobs    = { 'railroad', 'usmarshal', 'postal' },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ RIDING ████████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Riding = {
    boardDistance  = 6.0,     -- distance from a waiting train to show the board prompt
    boardKey       = 0xCEFD9220, -- E
    stationWaitMs  = 20000,   -- how long a managed train waits at a station (game default used when nil)
    fastTravel     = {        -- optional: buy a ticket and skip the ride (fade out / warp / fade in)
        enabled   = true,
        onlyWhenTrainAbsent = true, -- only offer when no managed passenger train is waiting
        travelMs  = 6000,     -- fade time simulating the journey
        surcharge = 0.25,     -- added to the ticket price (Pullman seat)
    },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ SECURITY ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Security = {
    rateLimit       = { burst = 10, windowMs = 5000 },  -- per-source net event budget
    maxTicketsHeld  = 5,
    hostReportRange = 200.0,   -- a host must be within this distance of the spawn point when it reports the train
    logExploits     = true,
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ DEBUG █████████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Debug = {
    enabled     = false,
    printBanner = true,
    adminCommands = true,   -- /train spawn <line> | /train delete <line> | /train list  (lxrcore.admin)
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- Train config names → hashes. Add your own.
-- ═══════════════════════════════════════════════════════════════════════════════
Config.TrainConfigs = {
    trolley_config          = 0xBF69518F,
    engine_config           = 0x3260CE89,
    dummy_engine_config     = 0x26509FBB,
    industry2_config        = 0x767DEB32,
    gunslinger3_config      = 0x3D72571D,
    gunslinger4_config      = 0x5AA369CA,
    winter4_config          = 0x487B2BE7,
    prisoner_escort_config  = 0x515E31ED,
    appleseed_config        = 0x8EAC625C,
    bountyhunter_config     = 0xF9B038FC,
    ghost_train_config      = 0x0E62D710,
    handcart_config         = 0x3EDA466D,
    minecart_config         = 0xC75AA08C,
}
