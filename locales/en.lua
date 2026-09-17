--[[ ═══════════════════════════════════════════════════════════════════════════
     🐺 LXR-TRAINS — Locale: English (canonical)
     Developer   : iBoss21 | Brand : LXRCore | https://www.lxrcore.com
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

Locale.Register('en', {
    prompt = {
        tickets = '%{station} — Tickets',
        board   = 'Board the %{line}',
    },
    ui = {
        price            = '$%{price}',
        fast_travel      = 'Travel now',
        fast_travel_desc = 'Skip the ride (+$%{surcharge})',
        close            = 'Close',
    },
    info = {
        ticket_bought = 'Ticket bought for $%{price}',
        arrived       = 'You have arrived',
        refunded      = 'Ticket refunded: $%{amount}',
    },
    error = {
        rate           = 'Slow down',
        disabled       = 'The ticket office is closed',
        invalid        = 'No such destination',
        too_far        = 'Step up to the ticket window',
        too_many       = 'You are holding too many tickets',
        no_money       = 'You cannot afford that',
        inventory_full = 'Your satchel is full',
        no_train       = 'There is no train here',
        no_ticket      = 'You need a ticket',
        not_at_station = 'Refunds are only given at a station',
        unknown_line   = 'Unknown line',
    },
    command = {
        ticketrefund = 'Refund an unused train ticket (at a station)',
        train        = 'Manage managed trains (admin): spawn | delete | list',
    },
})
