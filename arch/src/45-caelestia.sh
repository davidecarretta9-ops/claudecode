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
