-- lfs.sh: Hyprland solo per la schermata di accesso di oversicaOS (lo apre greetd come
-- utente "greeter"). Hyprland 0.57 legge solo file Lua. Niente tasti utili: si scrive solo
-- la password (Tab cambia utente). La schermata e' il blocco di Caelestia: quando ha finito
-- (password giusta) si chiude anche questo Hyprland e parte il desktop.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })
-- nelle macchine virtuali (QEMU) all'accensione lo schermo partirebbe piccolo
hl.monitor({ output = "Virtual-1", mode = "1920x1080", position = "auto", scale = "1" })

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Vetro")
hl.env("QT_QPA_PLATFORM", "wayland")
-- le scelte di Caelestia per questa schermata: italiano, sfondo sfocato dietro il blocco
hl.env("XDG_CONFIG_HOME", "/etc/vetro/accesso")

hl.config({
    -- la tastiera italiana, come nel desktop (se no la password non si scrive uguale)
    input = { kb_layout = "it" },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        disable_hyprland_guiutils_check = true,
        -- niente avviso "avviato senza start-hyprland": lo avvia greetd
        disable_watchdog_warning = true,
    },
    -- nelle macchine virtuali il puntatore "hardware" a volte non si vede
    cursor = { no_hardware_cursors = 1 },
})

-- un tasto che non fa niente: se un giorno questo file avesse un errore, Hyprland
-- senza nessun tasto attiverebbe i suoi tasti d'emergenza (Windows+Q apre un terminale)
hl.bind("SUPER + F12", hl.dsp.no_op())

hl.on("hyprland.start", function()
    -- USER: nel riquadro del sistema e per l'avatar si vede il tuo nome, non "greeter"
    hl.exec_cmd("USER=$(head -n 1 /etc/vetro/utente 2>/dev/null || echo greeter) "
                .. "qs -p /etc/xdg/quickshell/caelestia/accesso.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)
