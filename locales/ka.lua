--[[ ═══════════════════════════════════════════════════════════════════════════
     🐺 LXR-TRAINS — Locale: Georgian (ქართული) — 1:1 mirror of en.lua
     Developer   : iBoss21 | Brand : LXRCore | https://www.lxrcore.com
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

Locale.Register('ka', {
    prompt = { open = 'გახსნა',
        tickets = '%{station} — ბილეთები',
        board   = 'ჩაჯექით: %{line}',
    },
    ui = {
        price            = '$%{price}',
        fast_travel      = 'ახლავე გამგზავრება',
        fast_travel_desc = 'მგზავრობის გამოტოვება (+$%{surcharge})',
        close            = 'დახურვა',
    },
    info = {
        ticket_bought = 'ბილეთი ნაყიდია: $%{price}',
        arrived       = 'ჩამოხვედით',
        refunded      = 'ბილეთი დაბრუნდა: $%{amount}',
    },
    error = {
        rate           = 'შეანელეთ',
        disabled       = 'სალარო დაკეტილია',
        invalid        = 'ასეთი მიმართულება არ არსებობს',
        too_far        = 'მიუახლოვდით სალაროს',
        too_many       = 'ძალიან ბევრი ბილეთი გაქვთ',
        no_money       = 'საკმარისი ფული არ გაქვთ',
        inventory_full = 'ჩანთა სავსეა',
        no_train       = 'აქ მატარებელი არ არის',
        no_ticket      = 'ბილეთი გჭირდებათ',
        not_at_station = 'ბილეთის დაბრუნება მხოლოდ სადგურზეა შესაძლებელი',
        unknown_line   = 'უცნობი ხაზი',
    },
    command = {
        ticketrefund = 'გამოუყენებელი ბილეთის დაბრუნება (სადგურზე)',
        train        = 'მართული მატარებლები (ადმინი): spawn | delete | list',
    },
})
