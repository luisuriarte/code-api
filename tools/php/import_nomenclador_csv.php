<?php

declare(strict_types=1);

/**
 * Origen Salud - CLI de Ingesta Masiva de Nomencladores en CSV
 *
 * Permite cargar o actualizar de forma idempotente cualquier nomenclador argentino:
 * CUBRA NBU, Nomenclador Nacional (NN_PMO), NHPGD, Discapacidad (ANDIS), Kinesiología, Salud Mental.
 *
 * Uso:
 *   php tools/php/import_nomenclador_csv.php <archivo.csv> <TIPO_NOMENCLADOR>
 *
 * Ejemplos:
 *   php tools/php/import_nomenclador_csv.php archivos/nbu_2026.csv NBU
 *   php tools/php/import_nomenclador_csv.php archivos/nn_pmo.csv NN_PMO
 *   php tools/php/import_nomenclador_csv.php archivos/andis.csv ANDIS
 */

require_once dirname(__DIR__, 2) . '/bootstrap.php';

use OrigenSalud\Api\Config\Database;

if ($argc < 3) {
    fwrite(STDERR, "Uso: php tools/php/import_nomenclador_csv.php <archivo.csv> <TIPO_NOMENCLADOR>\n");
    fwrite(STDERR, "Tipos válidos: NN_PMO, NBU, NHPGD, ANDIS, KINESIOLOGIA, SALUD_MENTAL, VADEMECUM\n");
    exit(1);
}

$csvFile = $argv[1];
$tipoNomenclador = strtoupper(trim($argv[2]));

if (!file_exists($csvFile) || !is_readable($csvFile)) {
    fwrite(STDERR, "Error: No se puede leer el archivo CSV '{$csvFile}'.\n");
    exit(1);
}

echo "========================================================\n";
echo "Origen Salud · Ingesta de Nomenclador: {$tipoNomenclador}\n";
echo "Archivo: {$csvFile}\n";
echo "========================================================\n";

try {
    $db = Database::connection();
} catch (Throwable $e) {
    fwrite(STDERR, "Error de conexión a la base de datos: " . $e->getMessage() . "\n");
    exit(1);
}

$handle = fopen($csvFile, 'r');
if ($handle === false) {
    fwrite(STDERR, "Error al abrir el archivo.\n");
    exit(1);
}

// Detectar delimitador de la primera línea
$sampleLine = fgets($handle);
rewind($handle);

$delimiter = ',';
if (str_contains($sampleLine, ';') && !str_contains($sampleLine, ',')) {
    $delimiter = ';';
} elseif (str_contains($sampleLine, "\t")) {
    $delimiter = "\t";
}

$headers = fgetcsv($handle, 0, $delimiter);
if ($headers === false) {
    fwrite(STDERR, "Error: El archivo CSV está vacío.\n");
    exit(1);
}

// Normalizar nombres de columnas
$headerMap = [];
foreach ($headers as $idx => $col) {
    $clean = strtolower(trim((string) $col));
    $clean = str_replace([' ', '-', '.'], '_', $clean);
    $headerMap[$clean] = $idx;
}

$sql = 'INSERT INTO nomencladores_argentina (
            tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor, gastos_valor, snomed_concept_id, codigo_loinc
        ) VALUES (
            :tipo, :codigo, :capitulo, :descripcion, :unidad_tipo, :unidad_valor, :gastos_valor, :snomed, :loinc
        )
        ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
            capitulo = EXCLUDED.capitulo,
            descripcion = EXCLUDED.descripcion,
            unidad_tipo = EXCLUDED.unidad_tipo,
            unidad_valor = EXCLUDED.unidad_valor,
            gastos_valor = EXCLUDED.gastos_valor,
            snomed_concept_id = coalesce(EXCLUDED.snomed_concept_id, nomencladores_argentina.snomed_concept_id),
            codigo_loinc = coalesce(EXCLUDED.codigo_loinc, nomencladores_argentina.codigo_loinc)';

$stmt = $db->prepare($sql);

$count = 0;
$db->beginTransaction();

while (($row = fgetcsv($handle, 0, $delimiter)) !== false) {
    if (empty($row) || (count($row) === 1 && $row[0] === null)) {
        continue;
    }

    $codigo = trim((string) ($row[$headerMap['codigo'] ?? 0] ?? ''));
    if ($codigo === '') {
        continue;
    }

    $descripcion = trim((string) ($row[$headerMap['descripcion'] ?? $headerMap['nombre'] ?? 1] ?? ''));
    $capitulo = isset($headerMap['capitulo']) ? trim((string) ($row[$headerMap['capitulo']] ?? '')) : null;
    $unidadTipo = isset($headerMap['unidad_tipo']) ? trim((string) ($row[$headerMap['unidad_tipo']] ?? '')) : null;
    $unidadValor = isset($headerMap['unidad_valor']) && is_numeric($row[$headerMap['unidad_valor']]) ? (float) $row[$headerMap['unidad_valor']] : null;
    $gastosValor = isset($headerMap['gastos_valor']) && is_numeric($row[$headerMap['gastos_valor']]) ? (float) $row[$headerMap['gastos_valor']] : null;
    $snomed = isset($headerMap['snomed_concept_id']) && ctype_digit(trim((string) $row[$headerMap['snomed_concept_id']])) ? (int) $row[$headerMap['snomed_concept_id']] : null;
    $loinc = isset($headerMap['codigo_loinc']) ? trim((string) ($row[$headerMap['codigo_loinc']] ?? '')) : null;

    $stmt->execute([
        ':tipo' => $tipoNomenclador,
        ':codigo' => $codigo,
        ':capitulo' => $capitulo !== '' ? $capitulo : null,
        ':descripcion' => $descripcion,
        ':unidad_tipo' => $unidadTipo !== '' ? $unidadTipo : null,
        ':unidad_valor' => $unidadValor,
        ':gastos_valor' => $gastosValor,
        ':snomed' => $snomed,
        ':loinc' => $loinc !== '' ? $loinc : null,
    ]);

    $count++;
    if ($count % 500 === 0) {
        echo "Procesadas {$count} filas...\n";
    }
}

$db->commit();
fclose($handle);

echo "¡Listo! Ingesta completada con éxito: {$count} registros procesados para {$tipoNomenclador}.\n";
