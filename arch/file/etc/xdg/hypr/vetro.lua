-- Hyprland, desktop "Vetro" (creato da lfs.sh). Hyprland 0.57 legge solo file Lua.
-- Questo file e' per tutti: le TUE modifiche mettile in ~/.config/hypr/personale.lua
-- (viene letto per ultimo e vince). Le scelte fatte da Impostazioni finiscono in
-- ~/.config/hypr/vetro-impostazioni.lua. Tutti e due li crea avvia-desktop.
-- Dopo una modifica a mano:  hyprctl reload

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })
-- (nelle macchine virtuali 1920x1080: lo scrive avvia-desktop in vetro-schermo.lua,
-- letto piu' sotto. La risoluzione scelta in Impostazioni -> Schermo vale su tutte)

-- --- ambiente --------------------------------------------------------------------
hl.env("XCURSOR_SIZE", "24")
-- puntatori del mouse "Vetro" (freccia bianca come su Windows): li disegna il passo
-- "desktop". Senza un tema di puntatori Hyprland mostra il suo di riserva
hl.env("XCURSOR_THEME", "Vetro")
hl.env("HYPRCURSOR_SIZE", "24")
-- (niente GTK_CSD=1: le barre del titolo le disegna il plugin hyprbars, vedi
-- /etc/xdg/hypr/vetro-barre.lua)
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- --- aspetto -----------------------------------------------------------------------
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        -- finestre chiare e arrotondate, senza bordo colorato (come nel video)
        border_size = 0,
        col = { active_border = "rgba(00000000)", inactive_border = "rgba(00000000)" },
        resize_on_border = true,
        extend_border_grab_area = 12,
        layout = "dwindle",
    },
    decoration = {
        rounding = 18,
        rounding_power = 2.4,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        dim_inactive = false,
        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = "rgba(0000002e)",
            color_inactive = "rgba(0000001a)",
        },
        blur = {
            enabled = true,
            size = 9,
            passes = 3,
            noise = 0.02,
            contrast = 1.0,
            brightness = 0.9,
            vibrancy = 0.17,
            popups = true,
        },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        -- se i pannelli ripartono mentre lo schermo e' bloccato, possono riprenderlo
        allow_session_lock_restore = true,
        -- niente avviso "manca hyprland-guiutils": servirebbe solo per alcune finestre
        -- di domanda di Hyprland (permessi, "il programma non risponde"), qui non usate
        disable_hyprland_guiutils_check = true,
        -- niente avviso "avviato senza start-hyprland": Hyprland lo avvia avvia-desktop
        disable_watchdog_warning = true,
    },
    xwayland = { force_zero_scaling = true },
    -- registro di Hyprland in ~/.cache/hyprland.log (quello della volta prima in
    -- ~/.cache/hyprland-prima.log); li raccoglie "sudo bash lfs.sh registri" dal tuo PC
    debug = { disable_logs = false, enable_stdout_logs = true },
    -- nelle macchine virtuali il puntatore "hardware" a volte non si vede
    cursor = { no_hardware_cursors = 1 },
    -- tastiera e mouse
    input = {
        kb_layout = "it",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
})

-- animazioni morbide
hl.curve("morbida",  { type = "bezier", points = { { 0.22, 1 },    { 0.36, 1 } } })
hl.curve("rapida",   { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })
hl.curve("elastica", { type = "bezier", points = { { 0.34, 1.36 }, { 0.64, 1 } } })
hl.curve("lineare",  { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.animation({ leaf = "global",           enabled = true, speed = 8,   bezier = "default" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4.5, bezier = "elastica", style = "popin 88%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,   bezier = "rapida",   style = "popin 90%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4.5, bezier = "morbida",  style = "slide" })
hl.animation({ leaf = "border",           enabled = true, speed = 6,   bezier = "morbida" })
hl.animation({ leaf = "fade",             enabled = true, speed = 3.5, bezier = "rapida" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 4,   bezier = "morbida",  style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2.5, bezier = "rapida",   style = "fade" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 3,   bezier = "rapida" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 2.5, bezier = "rapida" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,   bezier = "morbida",  style = "slidefade 18%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,   bezier = "morbida",  style = "slidevert" })

-- tre dita sul touchpad: cambia scrivania
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- --- finestre ----------------------------------------------------------------------
-- come su macOS e Windows le finestre si aprono "libere" (non affiancate): la regola
-- e' in ~/.config/hypr/vetro-impostazioni.lua, perche' da Impostazioni -> Finestre si
-- puo' scegliere di affiancarle in automatico.
hl.window_rule({
    name = "vetro-impostazioni",
    match = { title = "^(Impostazioni di sistema)$" },
    float = true,
    center = true,
})

-- sfocatura dietro i pannelli di Quickshell (solo dove non sono trasparenti)
hl.layer_rule({ name = "vetro-sfocatura", match = { namespace = "^(vetro-.*)$" },
                blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "vetro-sfondo-fermo", match = { namespace = "^(vetro-sfondo)$" }, no_anim = true })

-- --- tasti ------------------------------------------------------------------------
local W = "SUPER"     -- il tasto Windows

-- tasto Windows da solo: cerca le app (come lo Start o Spotlight)
hl.bind(W .. " + SUPER_L", hl.dsp.global("quickshell:avvio"), { release = true })
hl.bind(W .. " + SPACE", hl.dsp.global("quickshell:avvio"))
hl.bind(W .. " + A", hl.dsp.global("quickshell:pannello"))
hl.bind(W .. " + D", hl.dsp.global("quickshell:cruscotto"))
hl.bind(W .. " + I", hl.dsp.global("quickshell:impostazioni"))
hl.bind(W .. " + L", hl.dsp.global("quickshell:blocca"))
hl.bind(W .. " + N", hl.dsp.global("quickshell:notifiche"))

hl.bind(W .. " + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd("foot"))
hl.bind(W .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(W .. " + B", hl.dsp.exec_cmd("/usr/local/bin/browser-predefinito"))
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("xfce4-taskmanager"))
hl.bind("PRINT", hl.dsp.exec_cmd("/usr/local/bin/schermata"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("/usr/local/bin/schermata area"))

-- finestre
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(W .. " + Q", hl.dsp.window.close())
hl.bind(W .. " + UP", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(W .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(W .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(W .. " + DOWN", hl.dsp.global("quickshell:riduci"))
-- Alt+Tab: la finestra dopo, e portata davanti alle altre
hl.bind("ALT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind("ALT + SHIFT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind(W .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(W .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- scrivanie (workspace)
for i = 1, 5 do
    hl.bind(W .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(W .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(W .. " + CTRL + RIGHT", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(W .. " + CTRL + LEFT", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(W .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(W .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- volume e musica (anche a schermo bloccato)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
        { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("quickshell:musica-play"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("quickshell:musica-avanti"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("quickshell:musica-indietro"), { locked = true })

-- --- avvio ------------------------------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/local/bin/avvio-vetro")
end)

-- --- gli altri file -----------------------------------------------------------------
-- Si leggono se ci sono. Un errore in uno di questi non ferma il resto (i tasti qui
-- sopra restano): compare un avviso in alto e il registro dice cosa non va.
local function leggi(percorso)
    local f = io.open(percorso, "r")
    if not f then
        return
    end
    f:close()
    local fatto, errore = pcall(dofile, percorso)
    if not fatto then
        print("Vetro: errore in " .. percorso .. ": " .. tostring(errore))
        hl.notification.create({
            text = "Vetro: errore in " .. percorso .. " (le altre impostazioni valgono)",
            duration = 15000,
            icon = "warning",
        })
    end
end

local cartella = (os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/hypr"
-- le barre del titolo delle finestre (plugin hyprbars, se si e' compilato)
leggi("/etc/xdg/hypr/vetro-barre.lua")
-- la risoluzione di partenza (la scrive avvia-desktop a ogni accesso)
leggi(cartella .. "/vetro-schermo.lua")
-- le scelte fatte da Impostazioni, poi le tue modifiche
leggi(cartella .. "/vetro-impostazioni.lua")
leggi(cartella .. "/personale.lua")
