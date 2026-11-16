<?php
/**
 * =============================================================================
 *  generar_carga_cie10.php  ::  CIE-10-ES (Edición Española) → OpenEMR
 * =============================================================================
 *
 * Genera el archivo sql/02_carga.sql con los LOAD DATA LOCAL INFILE listos
 * para ejecutar en DBeaver-CE o con el cliente mysql.
 * No se conecta a la base de datos: solo escribe el SQL.
 *
 * Uso:
 *   php scripts/generar_carga.php <ruta-carpeta> [opciones]
 *
 * Ejemplos:
 *   # Desde la carpeta con los CSV descargados del Ministerio de Sanidad:
 *   php scripts/generar_carga.php "D:\codigos\cie-10"
 *
 *   # Especificando ruta de servidor (si se ejecuta el SQL en el servidor):
 *   php scripts/generar_carga.php "D:\codigos\cie-10" --ruta=/opt/cie10
 *
 *   # Solo diagnósticos:
 *   php scripts/generar_carga.php "D:\codigos\cie-10" --solo-diag
 *
 *   # Solo procedimientos:
 *   php scripts/generar_carga.php "D:\codigos\cie-10" --solo-proced
 *
 *   # Escribir en un archivo alternativo:
 *   php scripts/generar_carga.php "D:\codigos\cie-10" --salida=sql/02_carga_2026.sql
 *
 *   # Mostrar el SQL por pantalla:
 *   php scripts/generar_carga.php "D:\codigos\cie-10" --stdout
 *
 * Opciones:
 *   --salida=RUTA    Archivo SQL de salida (por defecto: sql/02_carga.sql)
 *   --ruta=RUTA      Ruta base escrita en los LOAD DATA (si es distinta de la carpeta fuente)
 *   --solo-diag      Solo genera la carga de diagnósticos
 *   --solo-proced    Solo genera la carga de procedimientos
 *   --revision=N     Número de revisión a guardar en el campo `revision` (defecto: 1)
 *   --sin-track      No agrega INSERT en standardized_tables_track
 *   --stdout         Escribe el SQL por pantalla en vez de en un archivo
 *
 * FUENTE DE LOS CSV
 *   Ministerio de Sanidad de España:
 *   https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm
 *
 *   Archivos esperados (tab-separados, CRLF, UTF-8 sin BOM):
 *     Diagnosticos_Tabla_Referencia_CIE10ES_<AÑO>.csv
 *       Columnas: Código | Descripción | Nodo_Final | Manifestación | ...
 *     Procedimientos_Tabla_Referencia_CIE10ES_<AÑO>.csv
 *       Columnas: Código | Descripción | Hombre | Mujer
 *
 * NOTAS DE DISEÑO
 *   - El CSV de diagnósticos tiene el código CON punto (A00.0). OpenEMR espera
 *     dx_code con punto y formatted_dx_code sin punto. El script genera el
 *     SET `formatted_dx_code` = REPLACE(@dx_code, '.', '') para que MySQL
 *     calcule el campo sin punto en la carga.
 *   - La columna Nodo_Final=1 indica que el código es codificable (nodo hoja).
 *     Los ~2 registros con Nodo_Final != 1 son categorías padre. Se cargan igual
 *     con valid_for_coding=0 para conservar el árbol completo.
 *   - short_desc se genera con LEFT(Descripción, 60) directamente en MySQL.
 *   - Los CSV del Ministerio de Sanidad a veces incluyen un BOM UTF-8 (EF BB BF)
 *     o lo que parece UTF-8 con firma. El LOAD DATA maneja esto con IGNORE 1 LINES.
 * =============================================================================
 */

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "Este script se ejecuta por línea de comandos.\n");
    exit(1);
}

// -----------------------------------------------------------------------------
// Patrones de nombre de archivo que acepta el script
// -----------------------------------------------------------------------------
const PATRON_DIAG   = '/Diagnosticos?[_\s]Tabla[_\s]Referencia[_\s]CIE10ES?[_\s](\d{4}).*\.csv$/i';
const PATRON_PROCED = '/Procedimientos?[_\s]Tabla[_\s]Referencia[_\s]CIE10ES?[_\s](\d{4}).*\.csv$/i';

// -----------------------------------------------------------------------------
// Argumentos
// -----------------------------------------------------------------------------
$opciones = [
    'salida'      => dirname(__DIR__) . '/sql/02_carga.sql',
    'ruta'        => null,
    'solo-diag'   => false,
    'solo-proced' => false,
    'revision'    => 1,
    'sin-track'   => false,
    'stdout'      => false,
];
$fuente = null;

foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--')) {
        $partes = explode('=', substr($arg, 2), 2);
        $clave  = $partes[0];
        $valor  = $partes[1] ?? null;

        if (in_array($clave, ['salida', 'ruta'], true)) {
            if ($valor === null || $valor === '') {
                fwrite(STDERR, "Falta el valor de --$clave\n");
                exit(1);
            }
            $opciones[$clave] = $valor;
            continue;
        }
        if ($clave === 'revision') {
            $opciones['revision'] = (int) ($valor ?? 1);
            continue;
        }
        if (!array_key_exists($clave, $opciones)) {
            fwrite(STDERR, "Opción desconocida: --$clave\n");
            exit(1);
        }
        $opciones[$clave] = true;
        continue;
    }
    if ($fuente !== null) {
        fwrite(STDERR, "Indicó más de una ruta de origen.\n");
        exit(1);
    }
    $fuente = $arg;
}

if ($fuente === null) {
    fwrite(STDERR, <<<TXT
Uso: php scripts/generar_carga.php <ruta-carpeta-csv> [opciones]

  --salida=RUTA    archivo SQL de salida (por defecto sql/02_carga.sql)
  --ruta=RUTA      ruta base en los LOAD DATA (si difiere de la carpeta)
  --solo-diag      solo diagnósticos
  --solo-proced    solo procedimientos
  --revision=N     número de revisión en el campo `revision` (defecto: 1)
  --sin-track      no insertar en standardized_tables_track
  --stdout         mostrar el SQL en pantalla

TXT);
    exit(1);
}

$fuente = rtrim(str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $fuente), DIRECTORY_SEPARATOR);
if (!is_dir($fuente)) {
    fwrite(STDERR, "No es una carpeta o no existe: $fuente\n");
    exit(1);
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
function aviso(string $texto): void
{
    fwrite(STDOUT, $texto . "\n");
}

function error(string $texto): never
{
    fwrite(STDERR, "ERROR: $texto\n");
    exit(1);
}

/** Escapa una ruta para usarla dentro de una cadena SQL. */
function rutaSql(string $ruta): string
{
    return str_replace("'", "''", str_replace('\\', '/', $ruta));
}

// -----------------------------------------------------------------------------
// Buscar los CSV en la carpeta
// -----------------------------------------------------------------------------
$archivos = scandir($fuente);
if ($archivos === false) {
    error("No se puede leer la carpeta: $fuente");
}

$csvDiag   = null;
$csvProced = null;
$anioDiag  = null;
$anioProced = null;

foreach ($archivos as $nombre) {
    $ruta = $fuente . DIRECTORY_SEPARATOR . $nombre;
    if (!is_file($ruta)) {
        continue;
    }
    if ($csvDiag === null && preg_match(PATRON_DIAG, $nombre, $m) === 1) {
        $csvDiag  = $nombre;
        $anioDiag = $m[1];
    }
    if ($csvProced === null && preg_match(PATRON_PROCED, $nombre, $m) === 1) {
        $csvProced  = $nombre;
        $anioProced = $m[1];
    }
}

if (!$opciones['solo-proced'] && $csvDiag === null) {
    error("No se encontró el CSV de diagnósticos en: $fuente\n" .
          "Nombre esperado: Diagnosticos_Tabla_Referencia_CIE10ES_<AÑO>.csv");
}
if (!$opciones['solo-diag'] && $csvProced === null) {
    error("No se encontró el CSV de procedimientos en: $fuente\n" .
          "Nombre esperado: Procedimientos_Tabla_Referencia_CIE10ES_<AÑO>.csv");
}

$anio = $anioDiag ?? $anioProced ?? date('Y');
aviso("CIE-10-ES edición: $anio");
if ($csvDiag)   { aviso("  Diagnósticos:    $csvDiag"); }
if ($csvProced) { aviso("  Procedimientos:  $csvProced"); }

$rutaCarga = rtrim(
    str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $opciones['ruta'] ?? $fuente),
    DIRECTORY_SEPARATOR
);

// -----------------------------------------------------------------------------
// Generar el SQL
// -----------------------------------------------------------------------------
$lineas   = [];
$lineas[] = '-- =============================================================================';
$lineas[] = '-- 02_carga.sql  ::  LOAD DATA de CIE-10-ES para OpenEMR';
$lineas[] = '-- =============================================================================';
$lineas[] = '-- GENERADO AUTOMÁTICAMENTE por scripts/generar_carga.php. No editar a mano.';
$lineas[] = '--';
$lineas[] = '-- Edición CIE-10-ES : ' . $anio;
$lineas[] = '-- Generado          : ' . date('Y-m-d H:i:s');
$lineas[] = '-- Carpeta fuente    : ' . $fuente;
$lineas[] = '-- Ruta en los LOAD  : ' . $rutaCarga;
$lineas[] = '--';
$lineas[] = '-- ANTES DE EJECUTAR';
$lineas[] = '--   1) En el servidor MySQL: SET GLOBAL local_infile = 1;';
$lineas[] = '--   2) En DBeaver: conexión → Propiedades driver → allowLoadLocalInfile = true';
$lineas[] = '--   3) Ejecutar 01_esquema.sql antes de este archivo.';
$lineas[] = '--   4) Las rutas son del equipo desde donde se EJECUTA el SQL.';
$lineas[] = '-- =============================================================================';
$lineas[] = '';
$lineas[] = 'SET NAMES utf8mb4;';
$lineas[] = '';

// --- DIAGNÓSTICOS ---
if (!$opciones['solo-proced'] && $csvDiag !== null) {
    $rutaArchivo = $rutaCarga . '/' . $csvDiag;
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = '-- [1] icd10_dx_order_code  — Diagnósticos CIE-10-ES ' . $anio;
    $lineas[] = '--     Columnas CSV: Código | Descripción | Nodo_Final | ...';
    $lineas[] = '--     dx_code = con punto (A00.0); formatted_dx_code = sin punto (A000)';
    $lineas[] = '--     valid_for_coding = Nodo_Final (1 = codificable, 0 = categoría padre)';
    $lineas[] = '--     short_desc = LEFT(Descripción, 60); long_desc = Descripción completa';
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = 'TRUNCATE TABLE `icd10_dx_order_code`;';
    $lineas[] = 'LOAD DATA LOCAL INFILE \'' . rutaSql($rutaArchivo) . '\'';
    $lineas[] = '  INTO TABLE `icd10_dx_order_code`';
    $lineas[] = '  CHARACTER SET utf8mb4';
    $lineas[] = "  FIELDS TERMINATED BY '\\t' ESCAPED BY ''";
    $lineas[] = "  LINES TERMINATED BY '\\r\\n'";
    $lineas[] = '  IGNORE 1 LINES';
    $lineas[] = '  (@dx_code, @long_desc, @valid_for_coding,';
    $lineas[] = '   @manifestacion, @perinatal, @pediatrico, @obstetrico,';
    $lineas[] = '   @adulto, @mujer, @hombre, @poa, @dp, @vcdp)';
    $lineas[] = '  SET';
    $lineas[] = '    `dx_code`           = @dx_code,';
    $lineas[] = "    `formatted_dx_code` = REPLACE(@dx_code, '.', ''),";
    $lineas[] = '    `valid_for_coding`  = IF(TRIM(@valid_for_coding) = \'1\', \'1\', \'0\'),';
    $lineas[] = '    `long_desc`         = @long_desc,';
    $lineas[] = '    `short_desc`        = LEFT(@long_desc, 60),';
    $lineas[] = '    `active`            = 1,';
    $lineas[] = '    `revision`          = ' . $opciones['revision'];
    $lineas[] = ';';
    $lineas[] = '';
}

// --- PROCEDIMIENTOS ---
if (!$opciones['solo-diag'] && $csvProced !== null) {
    $rutaArchivo = $rutaCarga . '/' . $csvProced;
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = '-- [2] icd10_pcs_order_code  — Procedimientos CIE-10-ES ' . $anio;
    $lineas[] = '--     Columnas CSV: Código | Descripción | Hombre | Mujer';
    $lineas[] = '--     pcs_code = 7 caracteres alfanuméricos (0016070)';
    $lineas[] = '--     Todos los códigos son codificables (valid_for_coding = 1)';
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = 'TRUNCATE TABLE `icd10_pcs_order_code`;';
    $lineas[] = 'LOAD DATA LOCAL INFILE \'' . rutaSql($rutaArchivo) . '\'';
    $lineas[] = '  INTO TABLE `icd10_pcs_order_code`';
    $lineas[] = '  CHARACTER SET utf8mb4';
    $lineas[] = "  FIELDS TERMINATED BY '\\t' ESCAPED BY ''";
    $lineas[] = "  LINES TERMINATED BY '\\r\\n'";
    $lineas[] = '  IGNORE 1 LINES';
    $lineas[] = '  (@pcs_code, @long_desc, @hombre, @mujer)';
    $lineas[] = '  SET';
    $lineas[] = '    `pcs_code`         = @pcs_code,';
    $lineas[] = '    `valid_for_coding` = \'1\',';
    $lineas[] = '    `long_desc`        = @long_desc,';
    $lineas[] = '    `short_desc`       = LEFT(@long_desc, 60),';
    $lineas[] = '    `active`           = 1,';
    $lineas[] = '    `revision`         = ' . $opciones['revision'];
    $lineas[] = ';';
    $lineas[] = '';
}

// --- REGISTRO DE VERSIÓN ---
if (!$opciones['sin-track']) {
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = '-- Registro de la versión importada';
    $lineas[] = '-- (lo lee OpenEMR en Administración → Codificación → Tablas estandarizadas)';
    $lineas[] = '-- -----------------------------------------------------------------------------';
    if (!$opciones['solo-proced'] && $csvDiag !== null) {
        $lineas[] = 'INSERT INTO `standardized_tables_track`';
        $lineas[] = '  (`imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`)';
        $lineas[] = "VALUES (NOW(), 'ICD10', 'CIE-10-ES $anio', '$anio-01-01', '');";
        $lineas[] = '';
    }
    if (!$opciones['solo-diag'] && $csvProced !== null) {
        $lineas[] = 'INSERT INTO `standardized_tables_track`';
        $lineas[] = '  (`imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`)';
        $lineas[] = "VALUES (NOW(), 'ICD10PCS', 'CIE-10-ES PCS $anio', '$anio-01-01', '');";
        $lineas[] = '';
    }
}

$lineas[] = "SELECT 'Carga terminada. Continúe con 03_postcarga.sql.' AS resultado;";
$lineas[] = '';

$sql = implode("\n", $lineas);

if ($opciones['stdout']) {
    fwrite(STDOUT, $sql);
    exit(0);
}

$salidaPath = $opciones['salida'];
if (!is_dir(dirname($salidaPath))) {
    error("No existe la carpeta de salida: " . dirname($salidaPath));
}
if (file_put_contents($salidaPath, $sql) === false) {
    error("No se pudo escribir: $salidaPath");
}

aviso('');
aviso("SQL generado: $salidaPath");
aviso("Siguiente paso: ejecutar sql/01_esquema.sql y después sql/02_carga.sql en DBeaver.");

