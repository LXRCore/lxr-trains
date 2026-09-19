--[[
    ██╗     ██╗  ██╗██████╗       ████████╗██████╗  █████╗ ██╗███╗   ██╗███████╗
    ██║     ╚██╗██╔╝██╔══██╗      ╚══██╔══╝██╔══██╗██╔══██╗██║████╗  ██║██╔════╝
    ██║      ╚███╔╝ ██████╔╝█████╗   ██║   ██████╔╝███████║██║██╔██╗ ██║███████╗
    ██║      ██╔██╗ ██╔══██╗╚════╝   ██║   ██╔══██╗██╔══██║██║██║╚██╗██║╚════██║
    ███████╗██╔╝ ██╗██║  ██║         ██║   ██║  ██║██║  ██║██║██║ ╚████║███████║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝         ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝

    🐺 LXR Core - Trains & Tramway

    Ambient rail traffic + Saint Denis trolley, server-managed timetable lines
    with station stops, tickets, boarding and robbery hooks.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves 🐺
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/GAhk8cgXe9
    GitHub:      https://github.com/LXRCore

    Version: 1.0.0
    Performance Target: 0.00 ms idle (host: one 1 s watcher per train)

    Framework Support:
    - LXR Core v3 (Native — GetCoreObject / GetLXR)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'lxr-trains'
author 'iBoss21 / LXRCore'
description 'LXRCore v3 trains and tramway: ambient rail traffic, managed lines, stations, tickets'
version '1.0.1'
repository 'https://github.com/LXRCore/lxr-trains'

shared_scripts {
    '@lxr-core/shared/import.lua',   -- LXRShared: the catalog, jobs, gangs, weapons, horses, prices
    'shared/locale.lua',
    'locales/*.lua',
    'config.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependency 'lxr-core'
