<?php

declare(strict_types=1);

/**
 * Origen Salud · Importador CSV de la familia DENTAR
 *
 * Carga masiva e idempotente de procedimientos (DENTAR-PR) y diagnósticos
 * (DENTAR-DX) en las tablas dentar_*, y al final los publica en el Origen
 * Catalog Engine (`os_*`).
 *
 * Uso:
 *   php tools/php/import_dentar_csv.php <archivo.csv> [opciones]
 *
 * Opciones:
 *   --version=N   Número de versión a crear/actualizar dentro de cada catálogo.
 *                 Default: 1. Cada producto mantiene su propia numeración.
 *   --dry-run     Valida y simula; al final hace ROLLBACK y no deja cambios.
 *   --quiet       No imprime progreso cada 100 filas.
 *   --sin-sync    No sincroniza con Origen Catalog Engine (os_*). Por defecto
 *                 el importador ejecuta sql/sync_dentar_to_os.sql dentro de la
 *                 misma transacción, para que /v1/catalogs vea los cambios.
 *
 * Columnas del CSV (encabezado obligatorio, orden libre):
 *   codigo             DNT-PR-NNNNNN o DNT-DX-NNNNNN (obligatorio)
 *   catalogo           PR | DX | dentar-pr | dentar-dx (opcional; si falta se
 *                      infiere del prefijo del código)
 *   termino            Término preferido en es-AR (obligatorio)
 *   definicion         Texto de la definición (default: el término)
 *   criterios_clinicos Criterios de uso / justificación clínica (opcional)
 *   ambito_clinico     Sólo DENTAR-PR. Ej: "Capítulo III - Endodoncia"
 *   categoria          Código de dentar_category del mismo catálogo.
 *                      DENTAR-PR: CAT-DIAG, CAT-ENDO, … / DENTAR-DX: CAT-DX
 *   tipo_concepto      Sólo DENTAR-PR: procedure|service|evaluation|
 *                      diagnostic_service|rehabilitation
 *   sinonimos          Términos alternativos separados por "|"
 *   nomenclador_ar     Sólo DENTAR-PR. Código del nomenclador argentino, ej: 03.01
 *   cdt_2025           Sólo DENTAR-PR. Código ADA CDT 2025, ej: D3310
 *   cie10              Sólo DENTAR-DX. Código CIE-10, ej: K02.1
 *   snomed_sctid       SCTID del concepto SNOMED CT (procedimiento o diagnóstico)
 *
 * Reglas de mapeo por catálogo (dentar_catalog_mapping_rule):
 *   DENTAR-PR → NOMENCLADOR-AR obligatorio; CDT-2025 y SNOMED-CT permitidos.
 *   DENTAR-DX → CIE-10 obligatorio; SNOMED-CT permitido.
 *
 * Códigos de salida: 0 correcto, 1 error de datos/conexión, 2 uso incorrecto.
 */

require_once dirname(__DIR__, 2) . '/bootstrap.php';

use OrigenSalud\Api\Config\Database;
use OrigenSalud\Tools\Php\ImporterIdentity;

/** @var array<string, array<string, string>> catálogo => columna CSV => system_code */
const DENTAR_MAPEOS = [
    'dentar-pr' => [
        'nomenclador_ar' => 'NOMENCLADOR-AR',
        'cdt_2025' => 'CDT-2025',
        'snomed_sctid' => 'SNOMED-CT',
    ],
    'dentar-dx' => [
        'cie10' => 'CIE-10',
        'snomed_sctid' => 'SNOMED-CT',
    ],
];

/** @var array<string, string> catálogo => columna de mapeo obligatoria */
const DENTAR_MAPEOS_OBLIGATORIOS = [
    'dentar-pr' => 'nomenclador_ar',
    'dentar-dx' => 'cie10',
];

const DENTAR_TIPOS = ['procedure', 'service', 'evaluation', 'diagnostic_service', 'rehabilitation'];

const DENTAR_PREFIJOS = [
    'DNT-PR' => 'dentar-pr',
    'DNT-DX' => 'dentar-dx',
];

function uso(int $codigo): never
{
    $texto = <<<'TXT'
    Uso: php tools/php/import_dentar_csv.php <archivo.csv> [--version=N] [--dry-run] [--quiet] [--sin-sync]

    Columnas: codigo, catalogo, termino, definicion, criterios_clinicos,
              ambito_clinico, categoria, tipo_concepto, sinonimos,
              nomenclador_ar, cdt_2025, cie10, snomed_sctid
    TXT;

    fwrite($codigo === 0 ? STDOUT : STDERR, $texto . PHP_EOL);
    exit($codigo);
}

function normalizarCabecera(string $columna): string
{
    $limpio = strtolower(trim($columna));
    $limpio = str_replace(
        [' ', '-', '.', 'á', 'é', 'í', 'ó', 'ú', 'ñ'],
        ['_', '_', '_', 'a', 'e', 'i', 'o', 'u', 'n'],
        $limpio
    );

    return preg_replace('/_+/', '_', $limpio) ?? $limpio;
}

function normalizarCatalogo(string $valor): ?string
{
    $limpio = strtolower(trim($valor));
    $limpio = str_replace(['_', ' '], '-', $limpio);

    return match ($limpio) {
        'pr', 'dentar-pr' => 'dentar-pr',
        'dx', 'dentar-dx' => 'dentar-dx',
        default => null,
    };
}

$archivo = null;
$version = 1;
$dryRun = false;
$quiet = false;
$sinSync = false;

foreach (array_slice($argv, 1) as $arg) {
    if ($arg === '-h' || $arg === '--help') {
        uso(0);
    }

    if ($arg === '--dry-run') {
        $dryRun = true;
        continue;
    }

    if ($arg === '--quiet') {
        $quiet = true;
        continue;
    }

    if ($arg === '--sin-sync') {
        $sinSync = true;
        continue;
    }

    if (str_starts_with($arg, '--version=')) {
        $valor = substr($arg, strlen('--version='));
        if (!ctype_digit($valor) || (int) $valor < 1) {
            fwrite(STDERR, "ERROR: --version debe ser un entero >= 1.\n");
            exit(2);
        }
        $version = (int) $valor;
        continue;
    }

    if (str_starts_with($arg, '-')) {
        fwrite(STDERR, "Opción desconocida: {$arg}\n");
        uso(2);
    }

    $archivo = $arg;
}

if ($archivo === null) {
    uso(2);
}

if (!is_readable($archivo)) {
    fwrite(STDERR, "ERROR: no se puede leer '{$archivo}'.\n");
    exit(1);
}

$handle = fopen($archivo, 'r');
if ($handle === false) {
    fwrite(STDERR, "ERROR: no se pudo abrir '{$archivo}'.\n");
    exit(1);
}

$muestra = fgets($handle);
rewind($handle);

$delimitador = ',';
if (!str_contains((string) $muestra, ',') && str_contains((string) $muestra, ';')) {
    $delimitador = ';';
} elseif (str_contains((string) $muestra, "\t")) {
    $delimitador = "\t";
}

$cabecera = fgetcsv($handle, 0, $delimitador, '"', '');
if ($cabecera === false) {
    fwrite(STDERR, "ERROR: el CSV está vacío.\n");
    exit(1);
}

$indices = [];
foreach ($cabecera as $i => $columna) {
    $indices[normalizarCabecera((string) $columna)] = $i;
}

foreach (['codigo', 'termino'] as $obligatoria) {
    if (!isset($indices[$obligatoria])) {
        fwrite(STDERR, "ERROR: falta la columna obligatoria '{$obligatoria}'.\n");
        exit(1);
    }
}

try {
    $db = Database::connection();
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: no se pudo conectar a la base: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}

$valor = static function (array $fila, string $columna) use ($indices): ?string {
    if (!isset($indices[$columna])) {
        return null;
    }

    $dato = $fila[$indices[$columna]] ?? null;
    if ($dato === null) {
        return null;
    }

    $texto = trim((string) $dato);

    return $texto === '' ? null : $texto;
};

$hayTabla = static function (string $tabla) use ($db): bool {
    return in_array(
        $db->query("SELECT to_regclass('public.{$tabla}') IS NOT NULL")->fetchColumn(),
        [true, 't', '1', 1],
        true
    );
};

$tablasRequeridas = [
    'dentar_catalog',
    'dentar_category',
    'dentar_concept',
    'dentar_concept_version',
    'dentar_term',
    'dentar_concept_category',
    'dentar_concept_mapping',
    'dentar_diagnosis',
    'dentar_diagnosis_version',
    'dentar_diagnosis_term',
    'dentar_diagnosis_mapping',
];

foreach ($tablasRequeridas as $tabla) {
    if (!$hayTabla($tabla)) {
        fwrite(
            STDERR,
            "ERROR: falta la tabla '{$tabla}'. Ejecutá sql/dentar_family.sql y luego sql/dentar_core_and_diagnosis.sql antes de importar.\n"
        );
        exit(1);
    }
}

$catalogos = [];
foreach ($db->query('SELECT code, id FROM dentar_catalog')->fetchAll(PDO::FETCH_ASSOC) as $fila) {
    $catalogos[(string) $fila['code']] = (int) $fila['id'];
}

foreach (['dentar-pr', 'dentar-dx'] as $codigoCatalogo) {
    if (!isset($catalogos[$codigoCatalogo])) {
        fwrite(
            STDERR,
            "ERROR: dentar_catalog no tiene '{$codigoCatalogo}'. Ejecutá sql/dentar_family.sql antes de importar.\n"
        );
        exit(1);
    }
}

$categoriaDx = $db->prepare(
    "SELECT id FROM dentar_category WHERE code = 'CAT-DX' AND catalog_id = :catalogo"
);
$categoriaDx->execute([':catalogo' => $catalogos['dentar-dx']]);
$categoriaDxId = $categoriaDx->fetchColumn();
$categoriaDx->closeCursor();

if ($categoriaDxId === false) {
    fwrite(
        STDERR,
        "ERROR: no existe la categoría CAT-DX en dentar_category. Ejecutá sql/dentar_core_and_diagnosis.sql antes de importar.\n"
    );
    exit(1);
}
$categoriaDxId = (int) $categoriaDxId;

$haySnomed = $hayTabla('snomed_concepts');

$hayEngine = $hayTabla('os_catalog');
$syncFile = dirname(__DIR__, 2) . '/sql/03_dentar/sync_dentar_to_os.sql';

if ($sinSync !== true) {
    if ($hayEngine !== true) {
        fwrite(STDERR, "ERROR: no existe os_catalog. Ejecutá sql/origen_catalog_engine.sql antes de importar, o usá --sin-sync.\n");
        exit(1);
    }

    if (!is_readable($syncFile)) {
        fwrite(STDERR, "ERROR: no se encontró '{$syncFile}'. Usá --sin-sync para omitir la sincronización con os_*.\n");
        exit(1);
    }
}

$sistemas = array_flip(
    $db->query('SELECT code FROM dentar_terminology_system')->fetchAll(PDO::FETCH_COLUMN)
);

$stmtCategoria = $db->prepare(
    'SELECT id FROM dentar_category WHERE code = :codigo AND catalog_id = :catalogo'
);
$stmtSctid = $haySnomed
    ? $db->prepare('SELECT 1 FROM snomed_concepts WHERE id = :id')
    : null;

// DENTAR-PR ------------------------------------------------------------------
$stmtConcepto = $db->prepare(
    'INSERT INTO dentar_concept (catalog_id, code, concept_type)
     VALUES (:catalogo, :codigo, :tipo)
     ON CONFLICT (code) DO UPDATE SET concept_type = EXCLUDED.concept_type, catalog_id = EXCLUDED.catalog_id
     RETURNING id'
);
$stmtVersion = $db->prepare(
    'INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, clinical_criteria)
     VALUES (:concepto, :version, :definicion, :ambito, :criterios)
     ON CONFLICT (concept_id, version_number) DO UPDATE
        SET definition = EXCLUDED.definition,
            clinical_scope = EXCLUDED.clinical_scope,
            clinical_criteria = EXCLUDED.clinical_criteria
     RETURNING id'
);
$stmtTerminoPreferido = $db->prepare(
    "SELECT id FROM dentar_term
      WHERE concept_version_id = :version AND term_type = 'preferred' AND language = 'es-AR'
      LIMIT 1"
);
$stmtTerminoExiste = $db->prepare(
    'SELECT id FROM dentar_term
      WHERE concept_version_id = :version AND term_type = :tipo AND language = \'es-AR\' AND term = :termino
      LIMIT 1'
);
$stmtTerminoActualiza = $db->prepare('UPDATE dentar_term SET term = :termino WHERE id = :id');
$stmtTerminoInserta = $db->prepare(
    "INSERT INTO dentar_term (concept_version_id, language, term, term_type)
     VALUES (:version, 'es-AR', :termino, :tipo)"
);
$stmtCategoriaVinculo = $db->prepare(
    'INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
     VALUES (:version, :categoria, TRUE)
     ON CONFLICT (concept_version_id, category_id) DO NOTHING'
);
$stmtMapeo = $db->prepare(
    'INSERT INTO dentar_concept_mapping
         (concept_version_id, system_code, external_code, external_display, relationship)
     VALUES (:version, :sistema, :externo, :texto, :relacion)
     ON CONFLICT (concept_version_id, system_code, external_code) DO UPDATE
        SET external_display = EXCLUDED.external_display,
            relationship = EXCLUDED.relationship'
);

// DENTAR-DX ------------------------------------------------------------------
$stmtDiagnostico = $db->prepare(
    "INSERT INTO dentar_diagnosis (catalog_id, code, clinical_name, status, category_id)
     VALUES (:catalogo, :codigo, :nombre, 'active', :categoria)
     ON CONFLICT (code) DO UPDATE
        SET clinical_name = EXCLUDED.clinical_name,
            catalog_id = EXCLUDED.catalog_id,
            category_id = COALESCE(EXCLUDED.category_id, dentar_diagnosis.category_id)
     RETURNING id"
);
$stmtDiagnosticoVersion = $db->prepare(
    'INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
     VALUES (:diagnostico, :version, :definicion, :criterios)
     ON CONFLICT (diagnosis_id, version_number) DO UPDATE
        SET definition = EXCLUDED.definition,
            clinical_criteria = EXCLUDED.clinical_criteria'
);
$stmtDiagnosticoCategoria = $db->prepare(
    'UPDATE dentar_diagnosis SET category_id = :categoria WHERE id = :diagnostico'
);
$stmtDiagnosticoTerminoPreferido = $db->prepare(
    "SELECT id FROM dentar_diagnosis_term
      WHERE diagnosis_id = :diagnostico AND term_type = 'preferred' AND language = 'es-AR'
      LIMIT 1"
);
$stmtDiagnosticoTerminoExiste = $db->prepare(
    'SELECT id FROM dentar_diagnosis_term
      WHERE diagnosis_id = :diagnostico AND term_type = :tipo AND language = \'es-AR\' AND term = :termino
      LIMIT 1'
);
$stmtDiagnosticoTerminoActualiza = $db->prepare(
    'UPDATE dentar_diagnosis_term SET term = :termino WHERE id = :id'
);
$stmtDiagnosticoTerminoInserta = $db->prepare(
    "INSERT INTO dentar_diagnosis_term (diagnosis_id, language, term, term_type)
     VALUES (:diagnostico, 'es-AR', :termino, :tipo)"
);
$stmtDiagnosticoMapeo = $db->prepare(
    'INSERT INTO dentar_diagnosis_mapping
         (diagnosis_id, system_code, external_code, external_display, mapping_type)
     VALUES (:diagnostico, :sistema, :externo, :texto, :relacion)
     ON CONFLICT (diagnosis_id, system_code, external_code) DO UPDATE
        SET external_display = EXCLUDED.external_display,
            mapping_type = EXCLUDED.mapping_type'
);

$existentes = [
    'dentar-pr' => array_flip($db->query('SELECT code FROM dentar_concept')->fetchAll(PDO::FETCH_COLUMN)),
    'dentar-dx' => array_flip($db->query('SELECT code FROM dentar_diagnosis')->fetchAll(PDO::FETCH_COLUMN)),
];

$creados = ['dentar-pr' => 0, 'dentar-dx' => 0];
$actualizados = ['dentar-pr' => 0, 'dentar-dx' => 0];
$errores = [];
$avisos = [];
$procesadas = 0;
$huboErrores = false;

$importerRunId = ImporterIdentity::newRunId('import_dentar_csv');

$db->beginTransaction();
ImporterIdentity::bind($db, $importerRunId);

try {
    ImporterIdentity::assertWritableMode();

    $fila = 1;
    while (($datos = fgetcsv($handle, 0, $delimitador, '"', '')) !== false) {
        $fila++;

        if ($datos === [null] || $datos === []) {
            continue;
        }

        $codigo = $valor($datos, 'codigo');
        $termino = $valor($datos, 'termino');

        if ($codigo === null || $termino === null) {
            $errores[] = "fila {$fila}: falta codigo o termino";
            continue;
        }

        if (preg_match('/^(DNT-(?:PR|DX))-(\d{6})$/', $codigo, $partes) !== 1) {
            $errores[] = "fila {$fila}: código inválido '{$codigo}' (se espera DNT-PR-NNNNNN o DNT-DX-NNNNNN)";
            continue;
        }

        $catalogoCodigo = DENTAR_PREFIJOS[$partes[1]];
        $catalogoId = $catalogos[$catalogoCodigo];

        $catalogoDeclarado = $valor($datos, 'catalogo');
        if ($catalogoDeclarado !== null) {
            $catalogoNormalizado = normalizarCatalogo($catalogoDeclarado);
            if ($catalogoNormalizado === null) {
                $errores[] = "fila {$fila}: catalogo '{$catalogoDeclarado}' inválido (usá PR, DX, dentar-pr o dentar-dx)";
                continue;
            }

            if ($catalogoNormalizado !== $catalogoCodigo) {
                $errores[] = "fila {$fila}: el código '{$codigo}' pertenece a {$catalogoCodigo}, pero la columna catalogo dice '{$catalogoDeclarado}'";
                continue;
            }
        }

        $definicion = $valor($datos, 'definicion') ?? $termino;
        $short_definition = $valor($datos, 'short_definition');
        $global_period = $valor($datos, 'global_period');
        $work_rvu = $valor($datos, 'work_rvu');
        $practice_expense_rvu = $valor($datos, 'practice_expense_rvu');
        $malpractice_rvu = $valor($datos, 'malpractice_rvu');
        $total_rvu = $valor($datos, 'total_rvu');
        $estimated_payment = $valor($datos, 'estimated_payment');
        $criterios = $valor($datos, 'criterios_clinicos');
        $sinonimos = $valor($datos, 'sinonimos');

        $categoriaCodigo = $valor($datos, 'categoria');
        $categoriaId = null;

        if ($catalogoCodigo === 'dentar-dx' && $categoriaCodigo === null) {
            $categoriaId = $categoriaDxId;
        } elseif ($categoriaCodigo !== null) {
            $stmtCategoria->execute([
                ':codigo' => $categoriaCodigo,
                ':catalogo' => $catalogoId,
            ]);
            $categoriaId = $stmtCategoria->fetchColumn();
            $stmtCategoria->closeCursor();

            if ($categoriaId === false) {
                $mensaje = "fila {$fila}: categoría '{$categoriaCodigo}' inexistente en {$catalogoCodigo}";
                if ($catalogoCodigo === 'dentar-dx') {
                    $avisos[] = $mensaje . '; se usa CAT-DX';
                    $categoriaId = $categoriaDxId;
                } else {
                    $avisos[] = $mensaje . '; se omite el vínculo';
                    $categoriaId = null;
                }
            } else {
                $categoriaId = (int) $categoriaId;
            }
        }

        if ($catalogoCodigo === 'dentar-pr') {
            $tipo = $valor($datos, 'tipo_concepto') ?? 'procedure';
            if (!in_array($tipo, DENTAR_TIPOS, true)) {
                $errores[] = "fila {$fila}: tipo_concepto inválido '{$tipo}'";
                continue;
            }

            $ambito = $valor($datos, 'ambito_clinico');

            $stmtConcepto->execute([
                ':catalogo' => $catalogoId,
                ':codigo' => $codigo,
                ':tipo' => $tipo,
            ]);
            $conceptoId = (int) $stmtConcepto->fetchColumn();
            $stmtConcepto->closeCursor();

            $stmtVersion->execute([
                ':concepto' => $conceptoId,
                ':version' => $version,
                ':definicion' => $definicion,
                ':short_definition' => $short_definition,
                ':global_period' => $global_period,
                ':work_rvu' => $work_rvu,
                ':practice_expense_rvu' => $practice_expense_rvu,
                ':malpractice_rvu' => $malpractice_rvu,
                ':total_rvu' => $total_rvu,
                ':estimated_payment' => $estimated_payment,
                ':ambito' => $ambito,
                ':criterios' => $criterios,
            ]);
            $versionId = (int) $stmtVersion->fetchColumn();
            $stmtVersion->closeCursor();

            $stmtTerminoPreferido->execute([':version' => $versionId]);
            $terminoId = $stmtTerminoPreferido->fetchColumn();
            $stmtTerminoPreferido->closeCursor();

            if ($terminoId === false) {
                $stmtTerminoInserta->execute([
                    ':version' => $versionId,
                    ':termino' => $termino,
                    ':tipo' => 'preferred',
                ]);
            } else {
                $stmtTerminoActualiza->execute([':termino' => $termino, ':id' => (int) $terminoId]);
            }

            if ($sinonimos !== null) {
                foreach (explode('|', $sinonimos) as $sinonimo) {
                    $sinonimo = trim($sinonimo);
                    if ($sinonimo === '') {
                        continue;
                    }

                    $stmtTerminoExiste->execute([
                        ':version' => $versionId,
                        ':tipo' => 'synonym',
                        ':termino' => $sinonimo,
                    ]);
                    $yaExiste = $stmtTerminoExiste->fetchColumn();
                    $stmtTerminoExiste->closeCursor();
                    if ($yaExiste !== false) {
                        continue;
                    }

                    $stmtTerminoInserta->execute([
                        ':version' => $versionId,
                        ':termino' => $sinonimo,
                        ':tipo' => 'synonym',
                    ]);
                }
            }

            if ($categoriaId !== null) {
                $stmtCategoriaVinculo->execute([
                    ':version' => $versionId,
                    ':categoria' => $categoriaId,
                ]);
            }

            if ($categoriaCodigo === null) {
                $avisos[] = "fila {$fila}: DENTAR-PR sin categoría; se importa sin capítulo";
            }

            $huboMapeoObligatorio = false;
            foreach (DENTAR_MAPEOS['dentar-pr'] as $columna => $sistema) {
                $externo = $valor($datos, $columna);
                if ($externo === null) {
                    continue;
                }

                if ($columna === DENTAR_MAPEOS_OBLIGATORIOS['dentar-pr']) {
                    $huboMapeoObligatorio = true;
                }

                if (!isset($sistemas[$sistema])) {
                    $avisos[] = "fila {$fila}: falta dentar_terminology_system '{$sistema}'; se omite el mapeo";
                    continue;
                }

                if ($columna === 'snomed_sctid') {
                    if (ctype_digit($externo) !== true) {
                        $avisos[] = "fila {$fila}: snomed_sctid '{$externo}' no es numérico";
                        continue;
                    }

                    if ($haySnomed && $stmtSctid !== null) {
                        $stmtSctid->execute([':id' => (int) $externo]);
                        $existeSctid = $stmtSctid->fetchColumn();
                        $stmtSctid->closeCursor();
                        if ($existeSctid === false) {
                            $avisos[] = "fila {$fila}: SCTID {$externo} no está en snomed_concepts";
                        }
                    }
                }

                $stmtMapeo->execute([
                    ':version' => $versionId,
                    ':sistema' => $sistema,
                    ':externo' => $externo,
                    ':texto' => $termino,
                    ':relacion' => 'equivalent',
                ]);
            }

            if (!$huboMapeoObligatorio) {
                $avisos[] = "fila {$fila}: DENTAR-PR sin nomenclador_ar (mapeo obligatorio según dentar_catalog_mapping_rule)";
            }
        } else {
            // DENTAR-DX
            $tipo = $valor($datos, 'tipo_concepto');
            if ($tipo !== null && $tipo !== 'diagnosis') {
                $avisos[] = "fila {$fila}: tipo_concepto '{$tipo}' no aplica a DENTAR-DX; se ignora";
            }

            if ($valor($datos, 'ambito_clinico') !== null) {
                $avisos[] = "fila {$fila}: ambito_clinico no aplica a DENTAR-DX; se ignora";
            }

            $stmtDiagnostico->execute([
                ':catalogo' => $catalogoId,
                ':codigo' => $codigo,
                ':nombre' => $termino,
                ':categoria' => $categoriaId,
            ]);
            $diagnosticoId = (int) $stmtDiagnostico->fetchColumn();
            $stmtDiagnostico->closeCursor();

            if ($categoriaId !== null) {
                $stmtDiagnosticoCategoria->execute([
                    ':categoria' => $categoriaId,
                    ':diagnostico' => $diagnosticoId,
                ]);
            }

            $stmtDiagnosticoVersion->execute([
                ':diagnostico' => $diagnosticoId,
                ':version' => $version,
                ':definicion' => $definicion,
                ':criterios' => $criterios,
            ]);

            $stmtDiagnosticoTerminoPreferido->execute([':diagnostico' => $diagnosticoId]);
            $terminoId = $stmtDiagnosticoTerminoPreferido->fetchColumn();
            $stmtDiagnosticoTerminoPreferido->closeCursor();

            if ($terminoId === false) {
                $stmtDiagnosticoTerminoInserta->execute([
                    ':diagnostico' => $diagnosticoId,
                    ':termino' => $termino,
                    ':tipo' => 'preferred',
                ]);
            } else {
                $stmtDiagnosticoTerminoActualiza->execute([
                    ':termino' => $termino,
                    ':id' => (int) $terminoId,
                ]);
            }

            if ($sinonimos !== null) {
                foreach (explode('|', $sinonimos) as $sinonimo) {
                    $sinonimo = trim($sinonimo);
                    if ($sinonimo === '') {
                        continue;
                    }

                    $stmtDiagnosticoTerminoExiste->execute([
                        ':diagnostico' => $diagnosticoId,
                        ':tipo' => 'synonym',
                        ':termino' => $sinonimo,
                    ]);
                    $yaExiste = $stmtDiagnosticoTerminoExiste->fetchColumn();
                    $stmtDiagnosticoTerminoExiste->closeCursor();
                    if ($yaExiste !== false) {
                        continue;
                    }

                    $stmtDiagnosticoTerminoInserta->execute([
                        ':diagnostico' => $diagnosticoId,
                        ':termino' => $sinonimo,
                        ':tipo' => 'synonym',
                    ]);
                }
            }

            $huboMapeoObligatorio = false;
            foreach (DENTAR_MAPEOS['dentar-dx'] as $columna => $sistema) {
                $externo = $valor($datos, $columna);
                if ($externo === null) {
                    continue;
                }

                if ($columna === DENTAR_MAPEOS_OBLIGATORIOS['dentar-dx']) {
                    $huboMapeoObligatorio = true;
                }

                if (!isset($sistemas[$sistema])) {
                    $avisos[] = "fila {$fila}: falta dentar_terminology_system '{$sistema}'; se omite el mapeo";
                    continue;
                }

                if ($columna === 'snomed_sctid') {
                    if (ctype_digit($externo) !== true) {
                        $avisos[] = "fila {$fila}: snomed_sctid '{$externo}' no es numérico";
                        continue;
                    }

                    if ($haySnomed && $stmtSctid !== null) {
                        $stmtSctid->execute([':id' => (int) $externo]);
                        $existeSctid = $stmtSctid->fetchColumn();
                        $stmtSctid->closeCursor();
                        if ($existeSctid === false) {
                            $avisos[] = "fila {$fila}: SCTID {$externo} no está en snomed_concepts";
                        }
                    }
                }

                $stmtDiagnosticoMapeo->execute([
                    ':diagnostico' => $diagnosticoId,
                    ':sistema' => $sistema,
                    ':externo' => $externo,
                    ':texto' => $termino,
                    ':relacion' => 'equivalent',
                ]);
            }

            if (!$huboMapeoObligatorio) {
                $avisos[] = "fila {$fila}: DENTAR-DX sin cie10 (mapeo obligatorio según dentar_catalog_mapping_rule)";
            }

            if ($valor($datos, 'nomenclador_ar') !== null || $valor($datos, 'cdt_2025') !== null) {
                $avisos[] = "fila {$fila}: nomenclador_ar/cdt_2025 no aplican a DENTAR-DX; se ignoran";
            }
        }

        if (isset($existentes[$catalogoCodigo][$codigo])) {
            $actualizados[$catalogoCodigo]++;
        } else {
            $creados[$catalogoCodigo]++;
            $existentes[$catalogoCodigo][$codigo] = true;
        }

        $procesadas++;
        if (!$quiet && $procesadas % 100 === 0) {
            echo "Procesadas {$procesadas} filas...\n";
        }
    }

    // Si alguna fila no pasó la validación no se publica nada: el catálogo se
    // carga por lotes y un lote a medias es peor que un lote rechazado.
    if ($errores !== []) {
        $huboErrores = true;
        $db->rollBack();
        $creados = ['dentar-pr' => 0, 'dentar-dx' => 0];
        $actualizados = ['dentar-pr' => 0, 'dentar-dx' => 0];
    } else {
        if ($sinSync !== true) {
            if (!$quiet) {
                echo "Sincronizando DENTAR-PR y DENTAR-DX con Origen Catalog Engine (os_*)...\n";
            }

            $sqlSync = file_get_contents($syncFile);
            if ($sqlSync === false) {
                throw new RuntimeException("No se pudo leer '{$syncFile}'.");
            }

            $db->exec($sqlSync);
        }

        if ($dryRun) {
            $db->rollBack();
        } else {
            $db->commit();
        }
    }
} catch (Throwable $e) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL . "Se revirtieron todos los cambios.\n");
    exit(1);
} finally {
    fclose($handle);
}

echo PHP_EOL;
echo str_repeat('=', 60) . PHP_EOL;
echo 'DENTAR · familia importada'
    . ($dryRun ? ' (DRY RUN, sin cambios)' : ($huboErrores ? ' (CON ERRORES, sin cambios)' : ''))
    . PHP_EOL;
echo str_repeat('=', 60) . PHP_EOL;
echo "Versión:      {$version} (por catálogo)\n";
echo "Run ID:       {$importerRunId}\n";
echo "Procesadas:   {$procesadas}\n";
echo 'DENTAR-PR:    ' . ($creados['dentar-pr'] + $actualizados['dentar-pr'])
    . " filas ({$creados['dentar-pr']} nuevos, {$actualizados['dentar-pr']} actualizados)\n";
echo 'DENTAR-DX:    ' . ($creados['dentar-dx'] + $actualizados['dentar-dx'])
    . " filas ({$creados['dentar-dx']} nuevos, {$actualizados['dentar-dx']} actualizados)\n";
echo 'Sincronizado: '
    . ($sinSync === true ? 'no (--sin-sync)' : ($huboErrores ? 'no (errores)' : ($dryRun ? 'sí, revertido (--dry-run)' : 'sí (os_*)')))
    . "\n";
echo 'Errores:      ' . count($errores) . "\n";
echo 'Avisos:       ' . count($avisos) . "\n";

foreach (array_slice($errores, 0, 20) as $error) {
    echo "  ERROR  {$error}\n";
}
if (count($errores) > 20) {
    echo '  ... y ' . (count($errores) - 20) . " errores más\n";
}

foreach (array_slice($avisos, 0, 20) as $aviso) {
    echo "  AVISO  {$aviso}\n";
}
if (count($avisos) > 20) {
    echo '  ... y ' . (count($avisos) - 20) . " avisos más\n";
}

exit($errores === [] ? 0 : 1);
