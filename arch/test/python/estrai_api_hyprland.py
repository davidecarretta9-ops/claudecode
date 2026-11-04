#!/usr/bin/env python3
"""Estrae dai sorgenti di Hyprland (e del plugin hyprbars) i nomi della configurazione
Lua: opzioni di hl.config, comandi hl.dsp.* con i loro campi, opzioni di hl.bind,
campi delle regole e degli schermi. Scrive api_hyprland.json, che usa test_lua.py.

Si rilancia quando Arch passa a una nuova versione di Hyprland:
    python3 estrai_api_hyprland.py SORGENTI_HYPRLAND SORGENTI_PLUGIN

Legge soltanto i file (non compila e non esegue niente)."""
import json
import re
import subprocess
import sys
from pathlib import Path


def leggi(p):
    return Path(p).read_text(encoding="utf-8", errors="replace")


def corpo_funzione(testo, nome):
    """Il corpo di 'static int nome(lua_State* L) { ... }' (graffe bilanciate)."""
    m = re.search(r"(?:static )?int " + re.escape(nome) + r"\(lua_State\* L\)\s*\{", testo)
    if not m:
        return ""
    i, livello = m.end(), 1
    while livello and i < len(testo):
        livello += {"{": 1, "}": -1}.get(testo[i], 0)
        i += 1
    return testo[m.end():i]


def campi_di(corpo):
    campi = set(re.findall(
        r"(?:tableOpt\w*|requireTableField\w*)\(L,\s*\d+,\s*\"([a-z_0-9]+)\"", corpo))
    if "tableToggleAction(L, 1" in corpo:
        campi.add("action")
    if "pushWindowUpval(L, 1)" in corpo:
        campi.add("window")
    return sorted(campi)


def array_nomi(testo, inizio):
    """I primi nomi {"nome", ...} di un elenco 'inline constexpr ... NOME[] = { ... };'."""
    i = testo.index(inizio)
    fine = testo.index("\n    };", i)
    return sorted(set(re.findall(r"\{\"([a-z_:.0-9]+)\",", testo[i:fine])))


def main(hypr, plugin):
    hypr, plugin = Path(hypr), Path(plugin)
    lb = hypr / "src/config/lua/bindings"
    api = {}
    try:
        api["versione"] = subprocess.run(["git", "-C", str(hypr), "describe", "--tags"],
                                         capture_output=True, text=True).stdout.strip()
    except OSError:
        api["versione"] = "?"

    valori = leggi(hypr / "src/config/values/ConfigValues.cpp")
    api["config"] = sorted({k.replace(":", ".") for k in re.findall(
        r"\"([a-z_]+(?::[a-zA-Z_.0-9-]+)+)\"", valori)})

    disp = leggi(lb / "LuaBindingsDispatchers.cpp")
    dsp, pendenti = {}, {}
    blocco = disp[disp.index("void Internal::registerDispatcherBindings"):]
    for riga in blocco.splitlines():
        m = re.search(r"setDispatcherFn\(L, \"([a-z_]+)\", (\w+), (\d+)\)", riga)
        if m:
            pendenti[m.group(1)] = {"campi": campi_di(corpo_funzione(disp, m.group(2))),
                                    "argomenti": int(m.group(3))}
            continue
        m = re.search(r"lua_setfield\(L, -2, \"([a-z_]+)\"\)", riga)
        if "lua_newtable(L);" in riga or (m and m.group(1) == "dsp"):
            dsp.update(pendenti)            # registrati fuori dagli spazi (hl.dsp.nome)
            pendenti = {}
        elif m:
            dsp.update({m.group(1) + "." + k: v for k, v in pendenti.items()})
            pendenti = {}
    api["dsp"] = dict(sorted(dsp.items()))

    alto = leggi(lb / "LuaBindingsToplevel.cpp")
    corpo_bind = corpo_funzione(alto, "hlBind")
    api["bind_opzioni"] = sorted(set(re.findall(r"getBool\(\"([a-z_]+)\"\)", corpo_bind))
                                 | set(re.findall(r"readOptString\(\"([a-z_]+)\"\)", corpo_bind))
                                 | {"device"})
    regole = leggi(lb / "LuaBindingsConfigRules.cpp")
    api["hl"] = sorted((set(re.findall(r"set(?:Mgr)?Fn\(L, (?:mgr, )?\"([a-z_]+)\"", alto))
                        | set(re.findall(r"set(?:Mgr)?Fn\(L, (?:mgr, )?\"([a-z_]+)\"", regole)))
                       - {"load"})
    api["plugin"] = ["load"]
    albero = leggi(hypr / "src/config/shared/animation/AnimationTree.cpp")
    api["animazioni"] = sorted(set(re.findall(r"createNode\(\"([a-zA-Z]+)\"", albero)))
    eventi = leggi(hypr / "src/config/lua/LuaEventHandler.cpp")
    api["eventi"] = sorted(set(re.findall(r"dispatch\(\"([a-z_.]+)\"", eventi)))

    interni = leggi(lb / "LuaBindingsInternal.hpp")
    api["window_rule"] = array_nomi(interni, "WINDOW_RULE_EFFECT_DESCS[]")
    api["layer_rule"] = array_nomi(regole, "LAYER_RULE_EFFECT_DESCS[]")
    api["monitor"] = array_nomi(regole, "MONITOR_FIELDS[]") + ["output"]
    api["workspace_rule"] = array_nomi(regole, "WORKSPACE_RULE_FIELDS[]")
    api["match"] = sorted(set(re.findall(r"\{RULE_PROP_\w+, \"([a-z_]+)\"\}",
                                         leggi(hypr / "src/desktop/rule/Rule.cpp"))))
    nots = leggi(lb / "LuaBindingsNotification.cpp")
    api["notification"] = sorted(set(re.findall(r"setFn\(L, \"([a-z_]+)\"", nots)))

    barre = subprocess.run(["git", "-C", str(plugin), "show", "origin/main:hyprbars/main.cpp"],
                           capture_output=True, text=True).stdout or leggi(plugin / "hyprbars/main.cpp")
    api["hyprbars_config"] = sorted({k.replace(":", ".") for k in re.findall(
        r"\"(plugin:hyprbars:[a-z_.]+)\"", barre)})
    api["hyprbars_funzioni"] = sorted(set(re.findall(
        r"addLuaFunction\(PHANDLE, \"hyprbars\", \"([a-z_]+)\"", barre)))
    api["hyprbars_add_button"] = sorted(set(re.findall(
        r"lua_getfield\(L, 1, \"([a-z_]+)\"\)", corpo_funzione(barre, "newLuaButton"))))
    return api


if __name__ == "__main__":
    risultato = main(sys.argv[1], sys.argv[2])
    destinazione = Path(__file__).with_name("api_hyprland.json")
    destinazione.write_text(json.dumps(risultato, indent=1, ensure_ascii=False) + "\n")
    print(f"scritto {destinazione} (Hyprland {risultato['versione']}, "
          f"{len(risultato['config'])} opzioni, {len(risultato['dsp'])} comandi)")
