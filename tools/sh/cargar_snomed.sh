#!/usr/bin/env bash
# =============================================================================
# Origen Salud · Carga completa de SNOMED CT Argentina en PostgreSQL 18
# =============================================================================
#
# Ejecuta la secuencia 01 -> 02 -> 03 -> 04 -> 05 -> 99 sin tener que recordar
# el orden, las rutas ni el directorio de trabajo de cada paso. Es idempotente
# salvo el 01, que recrea el esquema de staging sct2.
#
# REQUISITOS
#   - Ejecutar como superusuario de PostgreSQL (postgres), no como root:
#       sudo -u postgres bash tools/sh/cargar_snomed.sh /ruta/al/release
#   - php-cli y psql en el PATH.
#
# USO
#   tools/sh/cargar_snomed.sh <ruta-release|ruta-zip> [opciones]
#
#   <ruta-release>   Carpeta de la release (la que contiene Snapshot/ y
#                    Resources/) o el ZIP oficial descargado.
#
# OPCIONES
#   --db=NAME        Base de datos destino. Default: origen_salud
#   --cliente        Genera el 02_carga.sql con \copy (lee los archivos en la
#                    máquina donde corre psql) en lugar de COPY del servidor.
#                    Usarlo si postgres no puede leer la carpeta de la release.
#   --sin-refsets    No ejecuta 04_codigos_opcional.sql
#   --sin-mapeos     No ejecuta 05_map_excel.sql (NBU/GTIN)
#   --desde=N        Arranca en el paso N (1..7). Sirve para retomar una carga
#                    que falló a mitad de camino.
#   -h, --help       Muestra esta ayuda.
#
# EJEMPLO (VPS con la release descomprimida en /root)
#   sudo -u postgres bash tools/sh/cargar_snomed.sh \
#       /root/SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z
# =============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SQL_DIR="$ROOT/tools/sql/snomed"
DB="origen_salud"
MODO_CLIENTE=0
CON_REFSETS=1
CON_MAPEOS=1
DESDE=1
RELEASE=""

uso() {
    sed -n '2,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)  uso 0 ;;
        --db=*)     DB="${arg#*=}" ;;
        --desde=*)  DESDE="${arg#*=}" ;;
        --cliente)  MODO_CLIENTE=1 ;;
        --sin-refsets) CON_REFSETS=0 ;;
        --sin-mapeos)  CON_MAPEOS=0 ;;
        -*)         echo "Opción desconocida: $arg" >&2; uso 2 ;;
        *)          RELEASE="$arg" ;;
    esac
done

[[ -n "$RELEASE" ]] || uso 2
[[ -e "$RELEASE" ]] || { echo "ERROR: no existe la ruta '$RELEASE'." >&2; exit 1; }
[[ -d "$SQL_DIR" ]] || { echo "ERROR: no se encontró '$SQL_DIR'." >&2; exit 1; }

if [[ ! "$DESDE" =~ ^[0-9]+$ ]] || (( DESDE < 1 || DESDE > 7 )); then
    echo "ERROR: --desde debe ser un número entre 1 y 7." >&2
    exit 2
fi

paso() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

psql_f() {
    psql -d "$DB" -v ON_ERROR_STOP=1 -f "$1"
}

# --- Comprobaciones previas -------------------------------------------------
command -v php  >/dev/null || { echo "ERROR: falta php-cli." >&2; exit 1; }
command -v psql >/dev/null || { echo "ERROR: falta psql." >&2; exit 1; }

USUARIO_DB="$(psql -d "$DB" -tAc 'select current_user' 2>/dev/null || true)"
if [[ -z "$USUARIO_DB" ]]; then
    echo "ERROR: no se pudo conectar a la base '$DB'." >&2
    echo "       Probá:  sudo -u postgres psql -d $DB -c 'select 1'" >&2
    exit 1
fi

SUPER="$(psql -d "$DB" -tAc 'select rolsuper from pg_roles where rolname = current_user' 2>/dev/null || true)"
if [[ "$SUPER" != "t" ]]; then
    echo "ERROR: hay que ejecutar con un rol superusuario (por ejemplo postgres)." >&2
    echo "       Usuario actual: $USUARIO_DB" >&2
    echo "       Probá:  sudo -u postgres bash $0 ..." >&2
    exit 1
fi

echo "Proyecto:  $ROOT"
echo "Base:      $DB"
echo "Usuario:   $USUARIO_DB"
echo "Release:   $RELEASE"
echo "Modo COPY: $([[ $MODO_CLIENTE -eq 1 ]] && echo 'cliente (\copy)' || echo 'servidor (COPY)')"

# --- 1. Esquema de staging --------------------------------------------------
if (( DESDE <= 1 )); then
    paso "1/7 · Esquema de staging sct2 (destructivo sólo para sct2)"
    psql_f "$SQL_DIR/01_esquema.sql"
fi

# --- 2. Generar 02_carga.sql ------------------------------------------------
if (( DESDE <= 2 )); then
    paso "2/7 · Generar 02_carga.sql desde la release"
    gen_args=("$RELEASE" "--salida=$SQL_DIR/02_carga.sql")
    if (( MODO_CLIENTE == 1 )); then
        gen_args+=("--cliente")
    fi
    php "$ROOT/tools/php/generar_carga_snomed.php" "${gen_args[@]}"
fi

# --- 3. Cargar los .txt -----------------------------------------------------
if (( DESDE <= 3 )); then
    paso "3/7 · Cargar Snapshot (puede tardar 15-30 min)"
    psql_f "$SQL_DIR/02_carga.sql"
fi

# --- 4. Postcarga -----------------------------------------------------------
if (( DESDE <= 4 )); then
    paso "4/7 · Índices, derivadas, vistas y publicación (20-40 min)"
    psql_f "$SQL_DIR/03_postcarga.sql"
fi

# --- 5. Refsets filtrables --------------------------------------------------
if (( DESDE <= 5 && CON_REFSETS == 1 )); then
    paso "5/7 · Refsets filtrables para la API"
    psql_f "$SQL_DIR/04_codigos_opcional.sql"
fi

# --- 6. Mapeos NBU / GTIN ---------------------------------------------------
if (( DESDE <= 6 && CON_MAPEOS == 1 )); then
    paso "6/7 · Mapeos NBU y GTIN (Resources/)"

    RESOURCES=""
    if [[ -d "$RELEASE/Resources" ]]; then
        RESOURCES="$RELEASE/Resources"
    elif [[ -d "$RELEASE" ]] && compgen -G "$RELEASE/*.xlsx" >/dev/null; then
        RESOURCES="$RELEASE"
    fi

    if [[ -z "$RESOURCES" ]]; then
        echo "AVISO: no se encontró la carpeta Resources/; se omite el paso de mapeos." >&2
    else
        TSV_DIR="$RESOURCES"
        if [[ ! -f "$RESOURCES/Mapeo_NBU_SCT_Agosto26.tsv" \
           || ! -f "$RESOURCES/MAP_GTIN_a_RPCD_comercializadas_20260820.tsv" ]]; then
            # Si postgres no puede escribir en Resources (por ejemplo, la
            # release se descomprimió como root), se convierte a una carpeta
            # temporal escribible y se ejecuta psql desde ahí.
            if [[ ! -w "$RESOURCES" ]]; then
                TSV_DIR="${TMPDIR:-/tmp}/origen_sct_tsv"
                mkdir -p "$TSV_DIR"
            fi

            echo "Convirtiendo XLSX a TSV en $TSV_DIR ..."
            php "$ROOT/tools/php/convertir_excel_maps.php" "$RESOURCES" --salida="$TSV_DIR"
        fi

        # \copy resuelve los nombres contra el directorio de trabajo de psql:
        # hay que pararse en la carpeta de los TSV. El script trae los nombres
        # literales justamente para que esto funcione.
        ( cd "$TSV_DIR" && psql -d "$DB" -v ON_ERROR_STOP=1 -f "$SQL_DIR/05_map_excel.sql" )
    fi
fi

# --- 7. Verificación --------------------------------------------------------
if (( DESDE <= 7 )); then
    paso "7/7 · Verificación final"
    psql -d "$DB" -f "$SQL_DIR/99_verificacion.sql"
fi

paso "Listo"
echo "Revisá que los counts de la verificación coincidan con la release cargada."
