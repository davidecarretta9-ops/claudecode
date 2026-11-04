# --- oversicaOS: Caelestia (l'interfaccia) e i suoi pezzi, a versione fissa ----------
# Caelestia (https://github.com/caelestia-dots, licenza GPL-3) si scarica con git a un
# commit fisso: il commit e' anche il controllo che il codice sia quello giusto.
CAELESTIA_SHELL_URL="https://github.com/caelestia-dots/shell"
CAELESTIA_SHELL_COMMIT="bcbb5d5139d5159839c7362d8f4954ccc7dbd67d"
CAELESTIA_CLI_URL="https://github.com/caelestia-dots/cli"
CAELESTIA_CLI_COMMIT="fdb3e47038c77ec8e7bb6010ffbcae00501d420b"
QUICKSHELL_GIT_URL="https://github.com/quickshell-mirror/quickshell"
QUICKSHELL_COMMIT="9b0f339b19057f4731bf3b48293307d7ef241671"
M3SHAPES_URL="https://github.com/soramanew/m3shapes"
M3SHAPES_COMMIT="32ad9ce328bb77ed349b40a3be10ee9ea610b8ab"
MATERIALYOU_URL="https://files.pythonhosted.org/packages/eb/23/2e63e7bdfcc1aa7ba955386ad09e3bd8a535a1092d7af501659b63cb6282/materialyoucolor-3.0.4.tar.gz"
MATERIALYOU_SHA256="30b8dde034dce180845b0eaf52f72c5b22cd5b60bd7aff96804febae4e266276"

# scarica_git URL COMMIT CARTELLA: i sorgenti di URL esattamente al COMMIT (3 tentativi)
scarica_git() {
    local url=$1 commit=$2 dir=$3 nome=${1##*/} volta
    for volta in 1 2 3; do
        rm -rf "$dir"
        mkdir -p "$dir"
        if esegui git -C "$dir" init -q \
            && esegui git -C "$dir" remote add origin "$url" \
            && esegui git -C "$dir" fetch -q --depth 1 origin "$commit" \
            && esegui git -C "$dir" checkout -q FETCH_HEAD \
            && [ "$(esegui git -C "$dir" rev-parse HEAD)" = "$commit" ]; then
            return 0
        fi
        avviso "Scaricare $nome non e' riuscito (tentativo $volta di 3)"
        [ -n "$VETRO_RADICE" ] || sleep $((volta * 5))
    done
    rm -rf "$dir"
    muori "Non riesco a scaricare $nome alla versione giusta ($commit): controlla la rete e rilancia"
}

# scarica_controllato URL SHA256 FILE: scarica e controlla l'impronta
scarica_controllato() {
    local url=$1 sha=$2 file=$3
    mkdir -p "$(dirname "$file")"
    if ! esegui curl -fL --retry 3 -o "$file" "$url"; then
        rm -f "$file"
        muori "Non riesco a scaricare ${url##*/}: controlla la rete e rilancia"
    fi
    if [ "$(sha256sum "$file" | cut -d' ' -f1)" != "$sha" ]; then
        rm -f "$file"
        muori "Il file ${url##*/} non passa il controllo (sha256): non lo uso"
    fi
}

# I pacchetti ufficiali che servono a Caelestia (compilarlo e usarlo)
PKG_CAELESTIA=(git gettext cmake ninja pkgconf qt6-base qt6-declarative qt6-imageformats
               qt6-multimedia qt6-shadertools qt6-svg qt6-wayland pipewire libqalculate aubio
               cava ddcutil brightnessctl lm_sensors power-profiles-daemon networkmanager
               fish swappy grim slurp wl-clipboard cliphist fuzzel ffmpeg libnotify glib2
               ttf-cascadia-code-nerd python-build python-installer python-hatchling
               python-hatch-vcs python-setuptools python-wheel pybind11 python-pillow)
CAELESTIA_VERSIONE=2.5.0       # l'ultima versione con nome prima del commit fisso
CAELESTIA_CLI_VERSIONE=1.1.3

# compila_caelestia: m3shapes, materialyoucolor, cli e shell di Caelestia (con i
# ritocchi di oversicaOS), installati nel sistema
compila_caelestia() {
    local t; t=$(mktemp -d)
    installa_pacchetti "${PKG_CAELESTIA[@]}"
    # le barre della musica: libcava viene dal pacchetto cava di Arch
    esegui pkg-config --exists libcava || esegui pkg-config --exists cava \
        || { rm -rf "$t"; muori "Manca libcava (pacchetto cava): lfs.sh va aggiornato (mandami questo messaggio)"; }

    info "Compilo le forme di Caelestia (m3shapes)"
    scarica_git "$M3SHAPES_URL" "$M3SHAPES_COMMIT" "$t/m3shapes"
    esegui cmake -S "$t/m3shapes" -B "$t/m3shapes-build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/ \
        && esegui cmake --build "$t/m3shapes-build" \
        && esegui cmake --install "$t/m3shapes-build" \
        || { rm -rf "$t"; muori "Le forme di Caelestia (m3shapes) non si compilano"; }

    info "Preparo i colori presi dallo sfondo (materialyoucolor)"
    scarica_controllato "$MATERIALYOU_URL" "$MATERIALYOU_SHA256" "$t/materialyoucolor.tar.gz"
    esegui tar -xzf "$t/materialyoucolor.tar.gz" -C "$t" \
        && esegui python3 -m build --wheel --no-isolation --outdir "$t/ruote" "$t/materialyoucolor-3.0.4" \
        || { rm -rf "$t"; muori "materialyoucolor non si compila"; }

    info "Compilo il comando di Caelestia (cli)"
    scarica_git "$CAELESTIA_CLI_URL" "$CAELESTIA_CLI_COMMIT" "$t/caelestia-cli"
    SETUPTOOLS_SCM_PRETEND_VERSION=$CAELESTIA_CLI_VERSIONE \
        esegui python3 -m build --wheel --no-isolation --outdir "$t/ruote" "$t/caelestia-cli" \
        || { rm -rf "$t"; muori "Il comando di Caelestia (cli) non si compila"; }
    local ruota
    for ruota in "$t"/ruote/*.whl; do
        esegui python3 -m installer --overwrite-existing "$ruota" \
            || { rm -rf "$t"; muori "Non riesco a installare ${ruota##*/}"; }
    done

    info "Compilo Caelestia (l'interfaccia di oversicaOS, qualche minuto)"
    scarica_git "$CAELESTIA_SHELL_URL" "$CAELESTIA_SHELL_COMMIT" "$t/caelestia-shell"
    applica_ritocchi "$t/caelestia-shell"
    esegui cmake -S "$t/caelestia-shell" -B "$t/caelestia-shell-build" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
            -DVERSION="$CAELESTIA_VERSIONE" -DGIT_REVISION="$CAELESTIA_SHELL_COMMIT" -DDISTRIBUTOR=oversicaOS \
            "-DENABLE_MODULES=extras;plugin;shell" \
        && esegui cmake --build "$t/caelestia-shell-build" \
        && esegui cmake --install "$t/caelestia-shell-build" \
        || { rm -rf "$t"; muori "Caelestia non si compila: mandami il registro (sudo bash lfs.sh registri)"; }
    rm -rf "$t"
    ok "Caelestia compilato e installato"
}

# si controlla all'inizio che ci siano tutti (come gli altri pacchetti del desktop)
PKG_FASE2+=("${PKG_CAELESTIA[@]}")
