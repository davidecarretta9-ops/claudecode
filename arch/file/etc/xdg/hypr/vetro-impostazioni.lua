-- Creato da Impostazioni (desktop Vetro): non modificarlo a mano,
-- le tue aggiunte vanno in ~/.config/hypr/personale.lua
hl.config({
    animations = { enabled = true },
    decoration = { rounding = 18, blur = { enabled = true } },
    general = { gaps_in = 6, gaps_out = 12 },
})
-- le finestre si aprono libere (non affiancate), come su macOS e Windows
hl.window_rule({ name = "vetro-finestre-libere", match = { class = ".*" }, float = true })
