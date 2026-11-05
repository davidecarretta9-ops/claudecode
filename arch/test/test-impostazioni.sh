#!/bin/bash
# Prove delle altre pagine delle Impostazioni di oversicaOS: Privacy e sicurezza, Energia e
# blocco, Notifiche, Data e ora, Archiviazione, Aggiornamenti; ordine delle pagine
# (piano oversicaOS, Task 15)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
N="$F/usr/local/lib/vetro/caelestia/nuovi"
DATA="$F/usr/local/sbin/oversica-data"
PY=python3
[ -x "$HOME/.vetro-qt/bin/python" ] && PY="$HOME/.vetro-qt/bin/python"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}

data_finta() {   # un timedatectl finto e due fusi orari finti
    radice_finta
    mkdir -p "$RADICE/bin" "$RADICE/usr/share/zoneinfo/Europe" "$RADICE/usr/share/zoneinfo/America/Argentina"
    : > "$RADICE/usr/share/zoneinfo/Europe/Rome"
    : > "$RADICE/usr/share/zoneinfo/America/Argentina/Buenos_Aires"
    printf '#!/bin/sh\necho "timedatectl $*" >> "%s/.chiamate"\n' "$RADICE" > "$RADICE/bin/timedatectl"
    chmod 755 "$RADICE/bin/timedatectl"
}

data() {
    OVERSICA_RADICE=$RADICE PATH="$RADICE/bin:$PATH" bash "$DATA" "$@" >/dev/null 2>&1
}

test_oversica_data_fuso_valido() {
    data_finta
    data fuso Europe/Rome; uguale 0 "$?" "Europe/Rome va bene"
    chiamato "timedatectl set-timezone Europe/Rome"
    data fuso America/Argentina/Buenos_Aires; uguale 0 "$?" "fuso con due livelli"
    data fuso ../../etc; uguale 1 "$?" "../../etc rifiutato"
    data fuso Europe/../../../etc/passwd; uguale 1 "$?" "percorso con .. rifiutato"
    data fuso Europe/Nonesiste; uguale 1 "$?" "fuso che non esiste rifiutato"
    data fuso "Europe/Rome; rm"; uguale 1 "$?" "caratteri strani rifiutati"
    data fuso; uguale 1 "$?" "senza fuso"
    non_chiamato "timedatectl set-timezone ../../etc"
    non_chiamato "Nonesiste"
}

test_oversica_data_automatica() {
    data_finta
    data automatica si; uguale 0 "$?" "ora automatica"
    chiamato "timedatectl set-ntp true"
    data automatica no; uguale 0 "$?" "ora a mano"
    chiamato "timedatectl set-ntp false"
    data automatica boh; uguale 1 "$?" "valore strano rifiutato"
    data altro; uguale 1 "$?" "comando sconosciuto rifiutato"
}

test_oversica_data_24h() {
    # il formato dell'ora e' una scelta di Caelestia (non serve l'amministratore)
    contiene "$N/modules/nexus/pages/DataOraPage.qml" "GlobalConfig.services.clockFormat = "
    contiene "$N/modules/nexus/pages/DataOraPage.qml" "ClockFormat.TwentyFourHour"
    contiene "$N/modules/nexus/pages/DataOraPage.qml" '"/usr/local/sbin/oversica-data", "fuso"'
}

test_sudoers_data() {
    uguale '%wheel ALL=(root) NOPASSWD: /usr/local/sbin/oversica-data' \
           "$(grep -v '^#' "$F/etc/sudoers.d/41-oversica-data" | grep .)" "una sola regola, solo l'aiutante"
}

test_installate() {
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna
    finto fc-cache; finto visudo; curl_carattere; compilazione_finta_base
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    f2_desktop >/dev/null
    esiste "$RADICE/usr/local/sbin/oversica-data"
    chiamato "visudo -cf $RADICE/etc/sudoers.d/41-oversica-data"
    case " ${PKG_CAELESTIA[*]} " in *" pacman-contrib "*) ok_prova "checkupdates c'e'" ;; *) fallita "manca pacman-contrib" ;; esac
}

test_pagine_registrate() {
    radice_finta
    local s="$RADICE/sorgente"; mkdir -p "$s"
    cp -a "$QUI_TEST/caelestia-originali/." "$s/"
    ( CAELESTIA_RITOCCHI="$F/usr/local/lib/vetro/caelestia" applica_ritocchi "$s" ) >/dev/null 2>&1
    local r
    r=$("$PY" - "$s/modules/nexus" <<'FINE'
import re, sys, pathlib
d = pathlib.Path(sys.argv[1])

def voci(testo, nome):
    testo = re.sub(r"//[^\n]*", "", testo)
    j = testo.index("[", testo.index(nome)) + 1
    prof, inizio, out = 0, None, []
    while True:
        c = testo[j]
        if c == "{":
            if prof == 0:
                inizio = j
            prof += 1
        elif c == "}":
            prof -= 1
            if prof == 0:
                out.append(testo[inizio:j + 1])
        elif c == "]" and prof == 0:
            return out
        j += 1

PAGINE = [("account", "AccountPage"), ("appearance", "WallpaperAndStyle"), ("schermo", "SchermoPage"),
          ("network", "NetworkPage"), ("bluetooth", "BluetoothPage"), ("audio", "AudioPage"),
          ("privacy", "PrivacyPage"), ("energia", "EnergiaPage"), ("notifiche", "NotifichePage"),
          ("tastiera", "TastieraPage"), ("dataora", "DataOraPage"), ("archiviazione", "ArchiviazionePage"),
          ("accessibilita", "AccessibilitaPage"), ("aggiornamenti", "AggiornamentiPage"),
          ("panels", "PanelsPage"), ("apps", "AppsPage"), ("language", "LanguageAndRegion"),
          ("about", "AboutPage")]
pagine = voci((d / "PageRegistry.qml").read_text(), "pages:")
comp = voci((d / "PageCompRegistry.qml").read_text(), "pageComps:")
errori = []
if len(pagine) != len(comp):
    errori.append(f"{len(pagine)} voci in pages, {len(comp)} in pageComps")
chiavi = [(re.search(r'chiave: "([a-z]+)"', p) or [None, None])[1] for p in pagine]
if None in chiavi:
    errori.append("una pagina senza chiave")
ordine = [c for c in chiavi if c in dict(PAGINE)]
if ordine != [c for c, _ in PAGINE]:
    errori.append(f"ordine: {ordine}")
for i, c in enumerate(chiavi):
    tipo = dict(PAGINE).get(c)
    if tipo and i < len(comp) and f"{tipo} {{" not in comp[i]:
        errori.append(f"{c}: pageComps[{i}] non e' {tipo}")
if any("PlaceholderComp" in c for c in comp):
    errori.append("ci sono ancora pagine in costruzione")
print("; ".join(errori) or "ok")
FINE
)
    uguale "ok" "$r" "pagine nello stesso ordine in pages e pageComps"
}

test_qml_sintassi() {
    local f e=0
    while IFS= read -r f; do
        if ! [ -x "$QMLLINT" ] || "$QMLLINT" "$f" 2>&1 | grep -q '\[syntax\]'; then
            fallita "QML: ${f#"$N/"}"; e=1
        fi
    done < <(find "$N" -name '*.qml')
    [ "$e" -eq 1 ] || ok_prova "QML nuovi senza errori di sintassi"
}

test_pagine_usano_vetro() {
    local p="$N/modules/nexus/pages"
    contiene "$p/PrivacyPage.qml" '"fantasma"'
    contiene "$p/PrivacyPage.qml" '"vpn"'
    contiene "$p/PrivacyPage.qml" '"cassaforte"'
    contiene "$p/PrivacyPage.qml" '"guardiano-regole"'
    contiene "$p/PrivacyPage.qml" "/etc/fantasma/attivo"
    contiene "$p/EnergiaPage.qml" "GlobalConfig.general.idle.timeouts"
    contiene "$p/EnergiaPage.qml" "PowerProfiles.profile"
    contiene "$p/NotifichePage.qml" "PersistentState.doNotDisturb"
    contiene "$p/ArchiviazionePage.qml" '"gio", "trash", "--empty"'
    contiene "$p/AggiornamentiPage.qml" '"checkupdates"'
}

prova test_oversica_data_fuso_valido
prova test_oversica_data_automatica
prova test_oversica_data_24h
prova test_sudoers_data
prova test_installate
prova test_pagine_registrate
prova test_qml_sintassi
prova test_pagine_usano_vetro
riassunto
