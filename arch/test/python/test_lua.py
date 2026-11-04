"""Prove delle configurazioni Lua di Hyprland 0.57 (accesso, desktop, impostazioni, barre,
comandi dei pannelli). Un "Hyprland finto" esegue i file con un vero Lua 5.5 (lupa) e
controlla ogni chiamata con l'elenco preso dai sorgenti di Hyprland (api_hyprland.json,
vedi estrai_api_hyprland.py): un nome sbagliato fa fallire la prova invece di mandare
Hyprland in "emergency mode" sul PC."""
import json
import os
import pathlib
import re
import shutil
import tempfile
import unittest

try:
    import lupa.lua55 as lupa
except ImportError:              # ~/.vetro-qt/bin/pip install lupa
    lupa = None

QUI = pathlib.Path(__file__).resolve().parent
FILE = QUI.parents[1] / "file"
API = json.loads((QUI / "api_hyprland.json").read_text())
CONFIG = set(API["config"])
TOGGLE = {"toggle", "on", "off", "enable", "disable"}

# il Lua che prepara le tabelle "rigide": un nome che Hyprland non ha da' errore subito
PREPARA = r"""
local function rigido(nome, t)
    return setmetatable(t, { __index = function(_, k)
        error(nome .. "." .. tostring(k) .. ": non esiste in Hyprland", 2)
    end })
end
local function costruisci(py)
    local hl = {}
    for _, n in ipairs(py.nomi_hl) do hl[n] = py.funzione(n) end
    hl.plugin = rigido("hl.plugin", { load = py.funzione("plugin.load") })
    local nt = {}
    for _, n in ipairs(py.nomi_notification) do nt[n] = py.funzione("notification." .. n) end
    hl.notification = rigido("hl.notification", nt)
    local dsp = {}
    for _, n in ipairs(py.nomi_dsp) do
        local spazio, nome = n:match("^([a-z_]+)%.([a-z_]+)$")
        if spazio then
            dsp[spazio] = dsp[spazio] or {}
            dsp[spazio][nome] = py.dispatcher(n)
        else
            dsp[n] = py.dispatcher(n)
        end
    end
    for k, v in pairs(dsp) do
        if type(v) == "table" then rigido("hl.dsp." .. k, v) end
    end
    hl.dsp = rigido("hl.dsp", dsp)
    return rigido("hl", hl)
end
return costruisci
"""


class Dispatcher:
    def __init__(self, nome, argomenti):
        self.nome, self.argomenti = nome, argomenti

    def __repr__(self):
        return f"{self.nome}{self.argomenti}"


class Hyprland:
    """Esegue un file di configurazione come farebbe Hyprland 0.57 e ricorda le chiamate."""

    def __init__(self, casa=None, mappa=None):
        if lupa is None:
            raise AssertionError("manca lupa (~/.vetro-qt/bin/pip install lupa)")
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.errori, self.binds, self.config, self.monitor = [], [], {}, []
        self.eventi, self.avviati, self.plugin, self.notifiche = {}, [], [], []
        self.window_rules, self.layer_rules, self.env, self.bottoni = [], [], {}, []
        self.animazioni, self.curve, self.gesti, self.eseguiti = [], {}, [], []
        self.hyprbars = False
        self.mappa = dict(mappa or {})          # "/etc/xdg/hypr" -> cartella vera
        if casa:
            casa_vera = str(casa)
            self.lua.globals().os.getenv = lambda n: casa_vera if n == "HOME" else None
        self._percorsi()
        py = self.lua.table_from({
            "nomi_hl": self.lua.table_from(API["hl"]),
            "nomi_notification": self.lua.table_from(API["notification"]),
            "nomi_dsp": self.lua.table_from(list(API["dsp"])),
            "funzione": self._funzione,
            "dispatcher": self._fabbrica,
        })
        self.lua.globals().hl = self.lua.execute(PREPARA)(py)

    # --- i percorsi: /etc/... si legge dalla cartella "file" del progetto ---------------
    def _percorsi(self):
        g = self.lua.globals()
        vero_open, vero_dofile = g.io.open, g.dofile

        def mappa(p):
            for da, a in self.mappa.items():
                if str(p).startswith(da):
                    return str(a) + str(p)[len(da):]
            return p

        g.io.open = lambda p, *m: vero_open(mappa(p), *m)
        g.dofile = lambda p: vero_dofile(mappa(p))

    # --- utilita' ---------------------------------------------------------------------
    def errore(self, testo):
        self.errori.append(testo)

    @staticmethod
    def tipo(v):
        """"table", "function"... per gli oggetti Lua; "py:..." per quelli di Python
        (un comando hl.dsp.* senza parentesi e' una funzione Python, non va bene)."""
        return lupa.lua_type(v) or "py:" + type(v).__name__

    def tabella(self, t, nome):
        if self.tipo(t) != "table":
            self.errore(f"{nome}: serve una tabella, non {self.tipo(t)}")
            return {}
        return {k: (self.tabella(v, f"{nome}.{k}") if self.tipo(v) == "table" and k == "match" else v)
                for k, v in t.items()}

    def campi(self, t, ammessi, nome):
        d = self.tabella(t, nome)
        for k in d:
            if k not in ammessi:
                self.errore(f"{nome}: campo sconosciuto '{k}'")
        return d

    # --- hl.dsp.* ---------------------------------------------------------------------
    def _fabbrica(self, nome):
        desc = API["dsp"][nome]

        def crea(*arg):
            if len(arg) > max(desc["argomenti"], 0):
                self.errore(f"hl.dsp.{nome}: troppi argomenti")
            a = arg[0] if arg else None
            if desc["campi"]:
                if a is not None:
                    d = self.campi(a, desc["campi"], f"hl.dsp.{nome}")
                    if "action" in d and nome != "window.fullscreen" and d["action"] not in TOGGLE:
                        self.errore(f"hl.dsp.{nome}: action '{d['action']}' non valida")
                    if nome == "window.fullscreen":
                        if d.get("mode", "fullscreen") not in ("fullscreen", "maximized"):
                            self.errore("hl.dsp.window.fullscreen: mode non valido")
                        if d.get("action", "toggle") not in ("toggle", "set", "unset"):
                            self.errore("hl.dsp.window.fullscreen: action non valida")
                    if nome == "dpms" and d.get("action") not in ("on", "off"):
                        self.errore("hl.dsp.dpms: action deve essere on oppure off")
                    if nome == "window.alter_zorder" and d.get("mode") not in ("top", "bottom"):
                        self.errore("hl.dsp.window.alter_zorder: mode deve essere top o bottom")
                    w = d.get("window")
                    if w is not None and not re.fullmatch(r"address:0x[0-9a-f]+|class:.+|title:.+", str(w)):
                        self.errore(f"hl.dsp.{nome}: finestra '{w}' non valida")
                    return Dispatcher(nome, d)
                if nome in ("window.alter_zorder", "dpms", "window.set_prop"):
                    self.errore(f"hl.dsp.{nome}: servono i campi")
                return Dispatcher(nome, {})
            if desc["argomenti"] and not isinstance(a, (str, int, float)):
                self.errore(f"hl.dsp.{nome}: serve un testo, non {self.tipo(a)}")
            return Dispatcher(nome, a)
        return crea

    def esegui_dispatcher(self, d):
        if isinstance(d, Dispatcher):
            self.eseguiti.append(d)
            if d.nome == "exec_cmd":
                self.avviati.append(d.argomenti)
        elif self.tipo(d) == "function":
            d()
        else:
            self.errore(f"serve un comando hl.dsp.* o una funzione, non {self.tipo(d)}")

    # --- hl.* -------------------------------------------------------------------------
    def _funzione(self, nome):
        return getattr(self, "hl_" + nome.replace(".", "_"), lambda *a: None)

    def hl_config(self, t, prefisso=""):
        if self.tipo(t) != "table":
            return self.errore("hl.config: serve una tabella")
        for k, v in t.items():
            chiave = f"{prefisso}.{k}" if prefisso else str(k)
            noto = chiave in CONFIG or (self.hyprbars and chiave in API["hyprbars_config"])
            if not noto and self.tipo(v) == "table":
                self.hl_config(v, chiave)
            elif not noto:
                self.errore(f"hl.config: opzione sconosciuta '{chiave}'")
            else:
                self.config[chiave] = dict(v.items()) if self.tipo(v) == "table" else v

    def hl_bind(self, tasti, comando, opzioni=None):
        parti = [p.strip() for p in str(tasti).split("+")]
        if any(not p for p in parti):
            self.errore(f"hl.bind '{tasti}': tasto vuoto")
        if len({p.lower() for p in parti}) != len(parti):
            self.errore(f"hl.bind '{tasti}': tasto ripetuto")
        if not (isinstance(comando, Dispatcher) or self.tipo(comando) == "function"):
            self.errore(f"hl.bind '{tasti}': serve un comando hl.dsp.* (con le parentesi)")
        o = self.campi(opzioni, API["bind_opzioni"], f"hl.bind '{tasti}'") if opzioni is not None else {}
        if o.get("mouse") and (o.get("repeating") or o.get("release") or o.get("locked")):
            self.errore(f"hl.bind '{tasti}': mouse non va con altre opzioni")
        if o.get("release") and o.get("repeating"):
            self.errore(f"hl.bind '{tasti}': release non va con repeating")
        self.binds.append({"tasti": " + ".join(parti), "comando": comando, "opzioni": o})

    def hl_dispatch(self, comando):
        self.esegui_dispatcher(comando)

    def hl_exec_cmd(self, comando, *resto):
        self.avviati.append(comando)

    def hl_on(self, evento, funzione):
        if evento not in API["eventi"]:
            self.errore(f"hl.on: evento sconosciuto '{evento}'")
        if self.tipo(funzione) != "function":
            self.errore("hl.on: serve una funzione")
        self.eventi.setdefault(evento, []).append(funzione)

    def hl_env(self, nome, valore):
        if not isinstance(nome, str) or not isinstance(valore, (str, int, float)):
            self.errore("hl.env: servono due testi")
        self.env[nome] = str(valore)

    def hl_monitor(self, t):
        d = self.campi(t, API["monitor"], "hl.monitor")
        if not isinstance(d.get("output"), str):
            self.errore("hl.monitor: manca output")
        self.monitor.append(d)

    def _regola(self, t, effetti, nome):
        d = self.campi(t, set(effetti) | {"name", "enabled", "match"}, nome)
        if "match" in d:
            self.campi(t["match"], API["match"], nome + ".match")
        return d

    def hl_window_rule(self, t):
        self.window_rules.append(self._regola(t, API["window_rule"], "hl.window_rule"))

    def hl_layer_rule(self, t):
        self.layer_rules.append(self._regola(t, API["layer_rule"], "hl.layer_rule"))

    def hl_curve(self, nome, t):
        d = self.campi(t, {"type", "points", "mass", "stiffness", "damping"}, "hl.curve")
        if d.get("type") == "bezier":
            punti = [list(p.values()) for p in t["points"].values()]
            if len(punti) != 2 or any(len(p) != 2 for p in punti):
                self.errore(f"hl.curve {nome}: servono due punti {{x, y}}")
        self.curve[nome] = d

    def hl_animation(self, t):
        d = self.campi(t, {"leaf", "enabled", "speed", "bezier", "spring", "style"}, "hl.animation")
        if d.get("leaf") not in API["animazioni"]:
            self.errore(f"hl.animation: animazione sconosciuta '{d.get('leaf')}'")
        if d.get("bezier") not in (None, "default") and d["bezier"] not in self.curve:
            self.errore(f"hl.animation: curva '{d['bezier']}' non definita prima")
        self.animazioni.append(d)

    def hl_gesture(self, t):
        self.gesti.append(self.campi(t, {"fingers", "direction", "action", "mods", "scale",
                                         "disable_inhibit"}, "hl.gesture"))

    def hl_plugin_load(self, percorso):
        self.plugin.append(percorso)

    def hl_notification_create(self, t):
        d = self.campi(t, {"text", "duration", "timeout", "time", "icon", "color", "font_size"},
                       "hl.notification.create")
        if "text" not in d or not ({"duration", "timeout", "time"} & set(d)):
            self.errore("hl.notification.create: servono text e duration")
        self.notifiche.append(d)

    # --- dopo che Hyprland ha caricato il plugin hyprbars -------------------------------
    def carica_hyprbars(self):
        self.hyprbars = True

        def bottone(t):
            d = self.campi(t, API["hyprbars_add_button"], "hl.plugin.hyprbars.add_button")
            if set(d) != set(API["hyprbars_add_button"]):
                self.errore("add_button: servono tutti i campi")
            self.bottoni.append(d)
        barre = self.lua.table_from({"add_button": bottone, "set_title": lambda *a: None})
        rawset = self.lua.eval("rawset")
        rawset(self.lua.globals().hl.plugin, "hyprbars", barre)

    # --- esecuzione -------------------------------------------------------------------
    def esegui_file(self, percorso):
        try:
            self.lua.execute(pathlib.Path(percorso).read_text(encoding="utf-8"))
        except lupa.LuaError as e:
            self.errore(f"errore Lua in {percorso}: {e}")
        return self

    def avvia(self):
        """L'evento hyprland.start (una volta sola, all'accensione)."""
        for f in self.eventi.get("hyprland.start", []):
            f()
        return self

    def esegui_comando(self, espressione):
        """Quello che fa 'hyprctl dispatch ESPRESSIONE' (return hl.dispatch(...))."""
        try:
            self.lua.execute(f"return hl.dispatch({espressione})")
        except lupa.LuaError as e:
            self.errore(f"dispatch {espressione}: {e}")
        return self

    def comando_shell(self, testo):
        """Controlla i 'hyprctl dispatch '...'' dentro un comando della shell."""
        trovati = re.findall(r"hyprctl dispatch '([^']*)'", testo)
        if "hyprctl dispatch" in testo and not trovati:
            self.errore(f"hyprctl dispatch senza apici: {testo}")
        for t in trovati:
            self.esegui_comando(t)
        return trovati

    def bind(self, tasti):
        for b in self.binds:
            if b["tasti"].lower() == tasti.lower():
                return b
        return None


def comando(b):
    """Il comando di un tasto, come testo (es. "global quickshell:avvio",
    "window.fullscreen action=toggle mode=maximized")."""
    c = b["comando"] if isinstance(b, dict) else b
    if not isinstance(c, Dispatcher):
        return "funzione"
    if isinstance(c.argomenti, dict):
        return " ".join([c.nome] + [f"{k}={v}" for k, v in sorted(c.argomenti.items())])
    return c.nome if c.argomenti is None else f"{c.nome} {c.argomenti}"


class ProvaAccesso(unittest.TestCase):
    F = FILE / "etc/vetro/accesso-hyprland.lua"

    def test_senza_errori(self):
        h = Hyprland().esegui_file(self.F).avvia()
        self.assertEqual(h.errori, [])
        self.assertEqual(h.config.get("input.kb_layout"), "it")
        self.assertTrue(h.config.get("misc.disable_watchdog_warning"))
        self.assertEqual(h.env.get("XCURSOR_THEME"), "Vetro")
        self.assertEqual(h.env.get("XDG_CONFIG_HOME"), "/etc/vetro/accesso")
        self.assertIn({"output": "Virtual-1", "mode": "1920x1080", "position": "auto", "scale": "1"}, h.monitor)

    def test_avvia_la_schermata_e_poi_esce(self):
        h = Hyprland().esegui_file(self.F)
        self.assertEqual(h.avviati, [], "niente programmi prima dell'avvio")
        h.avvia()
        self.assertEqual(len(h.avviati), 1)
        self.assertIn("qs -p /etc/xdg/quickshell/caelestia/accesso.qml; ", h.avviati[0])
        self.assertEqual(h.comando_shell(h.avviati[0]), ["hl.dsp.exit()"])
        self.assertEqual(h.errori, [])

    def test_nessun_tasto_apre_un_terminale(self):
        # se la configurazione avesse un errore e nessun tasto, Hyprland attiverebbe i tasti
        # d'emergenza (SUPER+Q = terminale) anche nella schermata di accesso
        h = Hyprland().esegui_file(self.F)
        self.assertGreaterEqual(len(h.binds), 1)
        for b in h.binds:
            self.assertEqual(comando(b), "no_op", b["tasti"])


class ProvaDesktop(unittest.TestCase):
    def setUp(self):
        self.casa = pathlib.Path(tempfile.mkdtemp())
        (self.casa / ".config/hypr").mkdir(parents=True)
        self.etc = pathlib.Path(tempfile.mkdtemp())
        shutil.copy(FILE / "etc/xdg/hypr/vetro.lua", self.etc / "vetro.lua")

    def tearDown(self):
        shutil.rmtree(self.casa)
        shutil.rmtree(self.etc)

    def carica(self):
        return Hyprland(casa=self.casa, mappa={"/etc/xdg/hypr": self.etc}).esegui_file(
            self.etc / "vetro.lua")

    def test_senza_errori_e_senza_file_dell_utente(self):
        h = self.carica().avvia()
        self.assertEqual(h.errori, [])
        self.assertEqual(h.avviati, ["/usr/local/bin/avvio-vetro"])
        self.assertEqual(h.config["decoration.rounding"], 18)
        self.assertEqual(h.config["general.border_size"], 0)
        self.assertEqual(h.config["input.kb_layout"], "it")
        # Hyprland 0.57 scrive i nomi con "_" al posto di "-" (tap-to-click -> tap_to_click)
        self.assertIs(h.config.get("input.touchpad.tap_to_click"), True)
        self.assertEqual(h.env["XCURSOR_THEME"], "Vetro")
        self.assertTrue(h.config["misc.disable_watchdog_warning"])
        self.assertEqual(h.notifiche, [])

    def test_tasti(self):
        h = self.carica()
        attesi = {
            "SUPER + SUPER_L": "global caelestia:launcher",
            "SUPER + SPACE": "global caelestia:launcher",
            "SUPER + L": "global caelestia:lock",
            "CTRL + ALT + DELETE": "global caelestia:session",
            "SUPER + A": "global caelestia:utilities",
            "SUPER + N": "global caelestia:sidebar",
            "SUPER + D": "global caelestia:dashboard",
            "SUPER + I": "global caelestia:nexus",
            "SUPER + K": "global caelestia:showall",
            "PRINT": "exec_cmd caelestia screenshot",
            "SHIFT + PRINT": "global caelestia:screenshot",
            "XF86AudioPlay": "global caelestia:mediaToggle",
            "XF86AudioNext": "global caelestia:mediaNext",
            "XF86MonBrightnessUp": "global caelestia:brightnessUp",
            "SUPER + RETURN": "exec_cmd foot",
            "SUPER + E": "exec_cmd thunar",
            "SUPER + Q": "window.close",
            "ALT + F4": "window.close",
            "SUPER + V": "window.float action=toggle",
            "SUPER + UP": "window.fullscreen action=toggle mode=maximized",
            "SUPER + F": "window.fullscreen action=toggle mode=fullscreen",
            "SUPER + DOWN": "window.move follow=False workspace=special:ridotte",
            "SUPER + S": "workspace.toggle_special ridotte",
            "SUPER + 1": "focus workspace=1",
            "SUPER + SHIFT + 5": "window.move workspace=5",
            "SUPER + CTRL + RIGHT": "focus workspace=e+1",
            "CTRL + ALT + BACKSPACE": "exec_cmd pkill -KILL -x quickshell",
        }
        for tasti, atteso in attesi.items():
            b = h.bind(tasti)
            self.assertIsNotNone(b, tasti)
            self.assertEqual(comando(b), atteso, tasti)
        self.assertTrue(h.bind("SUPER + SUPER_L")["opzioni"].get("release"))
        self.assertTrue(h.bind("SUPER + mouse:272")["opzioni"].get("mouse"))
        self.assertTrue(h.bind("XF86AudioRaiseVolume")["opzioni"].get("repeating"))
        for b in h.binds:
            self.assertNotIn("quickshell:", comando(b), b["tasti"])
        self.assertEqual(h.errori, [])

    def test_regole_dei_pannelli(self):
        h = self.carica()
        regole = {r["match"]["namespace"]: r for r in h.layer_rules}
        self.assertTrue(regole["caelestia-(border-exclusion|area-picker)"].get("no_anim"))
        self.assertEqual(regole["caelestia-(drawers|background)"].get("animation"), "fade")
        self.assertFalse(any("vetro-" in n for n in regole))

    def test_alt_tab_porta_in_cima(self):
        h = self.carica()
        b = h.bind("ALT + TAB")
        h.esegui_dispatcher(b["comando"])
        self.assertEqual([d.nome for d in h.eseguiti], ["window.cycle_next", "window.alter_zorder"])
        self.assertEqual(h.errori, [])

    def test_legge_i_file_dell_utente_in_ordine(self):
        c = self.casa / ".config/hypr"
        (c / "vetro-schermo.lua").write_text('hl.monitor({ output = "", mode = "1920x1080", position = "auto", scale = "1" })\n')
        shutil.copy(FILE / "etc/xdg/hypr/vetro-impostazioni.lua", c / "vetro-impostazioni.lua")
        (c / "personale.lua").write_text("hl.config({ decoration = { rounding = 4 } })\n")
        (self.etc / "vetro-barre.lua").write_text("hl.config({ general = { gaps_in = 3 } })\n")
        h = self.carica()
        self.assertEqual(h.errori, [])
        self.assertEqual(h.config["decoration.rounding"], 4, "personale.lua vince")
        self.assertEqual(h.config["general.gaps_in"], 6, "le impostazioni vengono dopo le barre")
        self.assertIn("1920x1080", [m.get("mode") for m in h.monitor])
        self.assertIn("vetro-finestre-libere", [r.get("name") for r in h.window_rules])

    def test_un_errore_in_personale_non_toglie_i_tasti(self):
        (self.casa / ".config/hypr/personale.lua").write_text("hl.config({ decorazione = 1 }\n")
        h = self.carica()
        self.assertIsNotNone(h.bind("SUPER + Q"))
        self.assertEqual(h.errori, [])
        self.assertEqual(len(h.notifiche), 1)
        self.assertIn("personale.lua", h.notifiche[0]["text"])


class ProvaImpostazioni(unittest.TestCase):
    def test_predefinite(self):
        h = Hyprland().esegui_file(FILE / "etc/xdg/hypr/vetro-impostazioni.lua")
        self.assertEqual(h.errori, [])
        self.assertEqual(h.config["decoration.rounding"], 18)
        self.assertEqual(h.window_rules, [{"name": "vetro-finestre-libere",
                                           "match": {"class": ".*"}, "float": True}])


class ProvaBarre(unittest.TestCase):
    SCRIPT = (FILE / "usr/local/bin/vetro-barre-aggiorna").read_text()

    def testo(self):
        m = re.search(r'cat > "\$CONF" << "FINE"\n(.*?)\nFINE\n', self.SCRIPT, re.S)
        self.assertIsNotNone(m, "il testo delle barre in vetro-barre-aggiorna")
        f = pathlib.Path(tempfile.mkdtemp()) / "vetro-barre.lua"
        f.write_text(m.group(1))
        self.addCleanup(shutil.rmtree, f.parent)
        return f

    def test_prima_del_plugin(self):
        # la prima lettura: il plugin non e' ancora caricato
        h = Hyprland().esegui_file(self.testo())
        self.assertEqual(h.errori, [])
        self.assertEqual(h.plugin, ["/usr/lib/hyprland-plugins/hyprbars.so"])
        self.assertEqual(h.bottoni, [])

    def test_con_il_plugin(self):
        h = Hyprland()
        h.carica_hyprbars()
        h.esegui_file(self.testo())
        self.assertEqual(h.errori, [])
        self.assertEqual(h.config["plugin.hyprbars.bar_height"], 34)
        self.assertEqual(h.config["plugin.hyprbars.bar_text_font"], "DM Sans")
        self.assertEqual([b["icon"] for b in h.bottoni], ["✕", "■", "–"])
        comandi = [h.comando_shell(b["action"]) for b in h.bottoni]
        comandi.append(h.comando_shell(h.config["plugin.hyprbars.on_double_click"]))
        self.assertEqual(comandi, [["hl.dsp.window.close()"],
                                   ['hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'],
                                   ['hl.dsp.window.move({ workspace = "special:ridotte", follow = false })'],
                                   ['hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']])
        self.assertEqual(h.errori, [])

    def test_senza_barre_e_lua_valido(self):
        m = re.search(r'echo "(-- Barre[^"]*)\$1\)" > "\$CONF"', self.SCRIPT)
        self.assertIsNotNone(m, "senza_barre scrive un commento Lua")


class ProvaComandiShell(unittest.TestCase):
    """I comandi a Hyprland scritti nei pannelli e negli script."""

    def test_nessun_dispatch_alla_vecchia(self):
        vecchi = []
        for f in (list((FILE / "etc/xdg/quickshell/vetro").glob("*")) + list((FILE / "usr/local/bin").glob("*"))
                  + list((FILE / "usr/local/lib/vetro/caelestia").rglob("*"))):
            if f.is_file():
                t = f.read_text(errors="replace")
                for riga in t.splitlines():
                    if riga.strip().startswith(("//", "#")):
                        continue
                    if re.search(r"hyprctl\"?,? *\"?dispatch|Hyprland\.dispatch\(", riga) \
                            and "hl.dsp." not in riga \
                            and "Hyprland.dispatch(comando)" not in riga:   # Finestre.invia (Hypr.js)
                        vecchi.append(f"{f.name}: {riga.strip()}")
        self.assertEqual(vecchi, [])


def motore_js():
    try:
        from PySide6.QtCore import QCoreApplication
        from PySide6.QtQml import QJSEngine
    except ImportError:
        raise AssertionError("manca PySide6 (~/.vetro-qt/bin/pip install PySide6-Essentials)")
    motore_js.app = QCoreApplication.instance() or QCoreApplication([])
    m = QJSEngine()
    r = m.evaluate((FILE / "usr/local/lib/vetro/caelestia/nuovi/utils/HyprImpostazioni.js").read_text().replace(".pragma library", ""))
    if r.isError():
        raise AssertionError(r.toString())
    return m


def js(m, chiamata):
    r = m.evaluate(chiamata)
    if r.isError():
        raise AssertionError(f"{chiamata}: {r.toString()}")
    return r.toString()


class ProvaHyprJs(unittest.TestCase):
    """HyprImpostazioni.js: i comandi che i pannelli mandano a Hyprland e il file delle impostazioni."""

    def setUp(self):
        self.m = motore_js()

    def test_comandi_delle_finestre(self):
        h = Hyprland()
        for chiamata, atteso in [
            ('riduci("0x55aa01")', "window.move follow=False window=address:0x55aa01 workspace=special:ridotte"),
            ('riduci("55AA01")', "window.move follow=False window=address:0x55aa01 workspace=special:ridotte"),
            ('sposta("0x55aa01", 3)', "window.move window=address:0x55aa01 workspace=3"),
            ('fuoco("0x55aa01")', "focus window=address:0x55aa01"),
            ('inCima("0x55aa01")', "window.alter_zorder mode=top window=address:0x55aa01"),
        ]:
            h.eseguiti.clear()
            h.esegui_comando(js(self.m, chiamata))
            self.assertEqual([comando(d) for d in h.eseguiti], [atteso], chiamata)
        self.assertEqual(h.errori, [])

    def test_indirizzi_strani_niente_comando(self):
        for a in ['""', '"0x12,ws"', '"abc\\")"', "undefined", '"0xZZ"']:
            self.assertEqual(js(self.m, f"riduci({a})"), "", a)
            self.assertEqual(js(self.m, f"fuoco({a})"), "", a)

    def test_testo_lua(self):
        h = Hyprland()
        # in JS: testo("a\\b\"c\nd"), cioe' a, barra rovescia, b, virgolette, c, a capo, d
        h.lua.execute("risultato = " + js(self.m, r'testo("a\\b\"c\nd")'))
        self.assertEqual(h.lua.globals().risultato, 'a\\b"c\nd')

    def test_impostazioni_predefinite_come_il_file(self):
        t = js(self.m, "impostazioni({animazioni: true, angoli: 18, sfocatura: true, spazi: 12, "
                       "affianca: false}, [], {})")
        self.assertEqual(t, (FILE / "etc/xdg/hypr/vetro-impostazioni.lua").read_text())

    def test_impostazioni_scelte(self):
        t = js(self.m, "impostazioni({animazioni: false, angoli: 0, sfocatura: false, spazi: 5, "
                       "affianca: true}, [{name: 'Virtual-1', width: 1920, height: 1080}], "
                       "{'Virtual-1': {risoluzione: '1280x720'}})")
        f = pathlib.Path(tempfile.mkdtemp()) / "i.lua"
        self.addCleanup(shutil.rmtree, f.parent)
        f.write_text(t)
        h = Hyprland().esegui_file(f)
        self.assertEqual(h.errori, [])
        self.assertFalse(h.config["animations.enabled"])
        self.assertFalse(h.config["decoration.blur.enabled"])
        self.assertEqual(h.config["decoration.rounding"], 0)
        self.assertEqual(h.config["general.gaps_in"], 3)
        self.assertEqual(h.config["general.gaps_out"], 5)
        self.assertEqual(h.window_rules, [])
        self.assertEqual(h.monitor, [{"output": "Virtual-1", "mode": "1280x720", "position": "0x0", "scale": "1"}])


if __name__ == "__main__":
    unittest.main()
