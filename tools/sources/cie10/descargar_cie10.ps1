<#
.SYNOPSIS
    Descarga y convierte los archivos CIE-10-ES del Ministerio de Sanidad de España.

.DESCRIPTION
    Automatiza la obtención de las tablas de referencia de CIE-10-ES (Diagnósticos y
    Procedimientos) desde el portal oficial del Ministerio de Sanidad de España y las
    convierte a CSV tab-separado listo para usar con generar_carga.php.

    El portal publica los archivos en formato XLSX. Este script:
      1. Detecta la edición más reciente disponible (o usa --Anio si se especifica).
      2. Descarga los XLSX a la carpeta destino.
      3. Los convierte a CSV tab-separado UTF-8 usando COM de Excel o LibreOffice.
      4. Genera automáticamente sql/02_carga.sql invocando generar_carga.php.

.PARAMETER Destino
    Carpeta donde guardar los archivos descargados.
    Por defecto: la carpeta cie-10 junto al proyecto.

.PARAMETER Anio
    Año de la edición a descargar (ej: 2026). Si no se indica, intenta detectar
    la más reciente probando los últimos años.

.PARAMETER SoloDescargar
    Descarga los XLSX pero no convierte ni genera SQL. Útil para revisar antes.

.PARAMETER SoloConvertir
    Convierte XLSX a CSV sin descargar (asume que los XLSX ya están en Destino).

.PARAMETER Revision
    Número de revisión para el campo `revision` de las tablas (defecto: autodetectado
    según el año: 2022=1, 2024=2, 2026=3, etc.)

.EXAMPLE
    # Descarga, convierte y genera SQL de la edición más reciente:
    .\descargar_cie10.ps1

.EXAMPLE
    # Solo descarga el XLSX de 2026:
    .\descargar_cie10.ps1 -Anio 2026 -SoloDescargar

.EXAMPLE
    # Convierte XLSX ya descargados en una carpeta específica:
    .\descargar_cie10.ps1 -Destino "D:\codigos\cie-10" -SoloConvertir

.NOTES
    Fuente oficial: https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm
    Consulta:       https://www.eciemaps.sanidad.gob.es/
#>

[CmdletBinding()]
param(
    [string] $Destino      = "",
    [int]    $Anio         = 0,
    [switch] $SoloDescargar,
    [switch] $SoloConvertir,
    [int]    $Revision     = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# Configuración
# =============================================================================

# Raíz del proyecto (carpeta padre de scripts/)
$raiz = Split-Path -Parent $PSScriptRoot

if (-not $Destino) {
    # Por defecto: carpeta cie-10 en el directorio de trabajo
    $Destino = Join-Path (Split-Path -Parent $raiz) "cie-10"
}

# URL base del Ministerio de Sanidad de España
# Los archivos siguen el patrón real (confirmado en Nov 2026):
#   .../normalizacion/CIE10/<AÑO>/Diagnosticos_Tabla_Referencia_CIE10ES_<AÑO>.xlsx
#   .../normalizacion/CIE10/<AÑO>/Procedimientos_Tabla_Referencia_CIE10ES_<AÑO>.xlsx
$urlBase = "https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/CIE10"

# Años a probar en orden descendente (más reciente primero)
$aniosProbar = @(2026, 2025, 2024, 2023, 2022)

# Mapeo año → número de revisión
$revisionPorAnio = @{
    2022 = 1; 2023 = 1; 2024 = 2; 2025 = 2; 2026 = 3
}

# =============================================================================
# Helpers
# =============================================================================

function Escribir-Info($msg)   { Write-Host $msg -ForegroundColor Cyan }
function Escribir-Ok($msg)     { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Escribir-Aviso($msg)  { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Escribir-Error($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

function Intentar-Descarga([string]$url, [string]$destArchivo) {
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $destArchivo -TimeoutSec 60 -UseBasicParsing
        return $true
    } catch {
        return $false
    }
}

function Convertir-XlsxACsv([string]$xlsxPath, [string]$csvPath) {
    # Intento 1: COM de Excel (si está instalado)
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Open($xlsxPath)
        $ws = $wb.Worksheets.Item(1)
        # xlCSVUTF8 = 62 (Excel 2016+); xlCSV = 6 (cualquier versión)
        try {
            $wb.SaveAs($csvPath, 62)  # xlCSVUTF8
        } catch {
            $wb.SaveAs($csvPath, 6)   # xlCSV
        }
        $wb.Close($false)
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        # Excel guarda con coma; hay que convertir a tab si es necesario
        return "excel"
    } catch {
        # Excel no disponible
    }

    # Intento 2: LibreOffice (si está en PATH)
    $libreOffice = Get-Command "soffice" -ErrorAction SilentlyContinue
    if ($libreOffice) {
        $tmpDir = [System.IO.Path]::GetTempPath()
        $args = @(
            "--headless",
            "--convert-to", "csv:Text - txt - csv (StarCalc):9,34,76,1",
            "--outdir", $tmpDir,
            $xlsxPath
        )
        # 9=TAB, 34=", 76=UTF-8, 1=primera hoja
        & soffice @args | Out-Null
        $tmpCsv = Join-Path $tmpDir ([System.IO.Path]::GetFileNameWithoutExtension($xlsxPath) + ".csv")
        if (Test-Path $tmpCsv) {
            Move-Item $tmpCsv $csvPath -Force
            return "libreoffice"
        }
    }

    return $null  # No se pudo convertir
}

function Ajustar-SeparadorCsv([string]$csvPath) {
    # Si Excel guardó con coma, convierte a tab
    $primeraLinea = (Get-Content $csvPath -Encoding UTF8 -TotalCount 1)
    if ($primeraLinea -match "Código,Descripción" -or $primeraLinea -match "Codigo,Descripcion") {
        Escribir-Aviso "El CSV tiene comas. Convirtiendo a tab-separado..."
        $contenido = Get-Content $csvPath -Encoding UTF8
        $contenido = $contenido | ForEach-Object {
            # Conversión simple: reemplaza , por tab (válida si no hay comas en las descripciones)
            $_ -replace '","', "`t" -replace '^"', '' -replace '"$', ''
        }
        $contenido | Set-Content $csvPath -Encoding UTF8
        Escribir-Ok "Convertido a tab-separado."
    }
}

# =============================================================================
# Paso 1: Detectar/confirmar el año
# =============================================================================

Escribir-Info "=== Descarga CIE-10-ES del Ministerio de Sanidad de España ==="
Escribir-Info ""

if (-not (Test-Path $Destino)) {
    New-Item -ItemType Directory -Path $Destino | Out-Null
    Escribir-Ok "Carpeta destino creada: $Destino"
}

$anioFinal = $Anio
if ($anioFinal -eq 0 -and -not $SoloConvertir) {
    Escribir-Info "Detectando edición más reciente..."

    # Probar URLs comunes del Ministerio de Sanidad
    $urlPatrones = @(
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/CIE10/{0}/Diagnosticos_Tabla_Referencia_CIE10ES_{0}.xlsx",
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/docs/CIE/Diagnosticos_Tabla_Referencia_CIE10ES_{0}.xlsx",
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/sistest/clasifEnfermedades/resources/Diagnosticos_Tabla_Referencia_CIE10ES_{0}.xlsx"
    )

    foreach ($yr in $aniosProbar) {
        foreach ($patron in $urlPatrones) {
            $urlPrueba = $patron -f $yr
            try {
                $resp = Invoke-WebRequest -Uri $urlPrueba -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                if ($resp.StatusCode -eq 200) {
                    $anioFinal = $yr
                    Escribir-Ok "Edición $yr encontrada en: $urlPrueba"
                    break
                }
            } catch { }
        }
        if ($anioFinal -ne 0) { break }
    }

    if ($anioFinal -eq 0) {
        Escribir-Aviso "No se pudo detectar automáticamente la URL del Ministerio."
        Escribir-Aviso "El portal puede requerir navegación manual. Opciones:"
        Escribir-Aviso "  1) Ir a: https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm"
        Escribir-Aviso "  2) Descargar manualmente los XLSX a: $Destino"
        Escribir-Aviso "  3) Volver a ejecutar este script con -SoloConvertir"
        Escribir-Aviso ""
        Escribir-Aviso "O especificar el año: .\descargar_cie10.ps1 -Anio 2026"
        exit 1
    }
} elseif ($anioFinal -eq 0) {
    # SoloConvertir: detectar por los XLSX presentes
    $xlsxPresentes = Get-ChildItem $Destino -Filter "Diagnosticos_Tabla_Referencia_CIE10ES_*.xlsx" |
                     Sort-Object Name -Descending | Select-Object -First 1
    if ($xlsxPresentes) {
        if ($xlsxPresentes.Name -match '_(\d{4})\.xlsx$') {
            $anioFinal = [int]$Matches[1]
            Escribir-Ok "Edición detectada desde XLSX presente: $anioFinal"
        }
    }
    if ($anioFinal -eq 0) {
        Escribir-Error "No se encontraron XLSX en $Destino. Use -Anio o descargue primero."
        exit 1
    }
}

Escribir-Info "Edición a procesar: $anioFinal"

# Calcular revisión
if ($Revision -eq 0) {
    $Revision = if ($revisionPorAnio.ContainsKey($anioFinal)) { $revisionPorAnio[$anioFinal] } else { 1 }
}
Escribir-Info "Número de revisión: $Revision"

# =============================================================================
# Paso 2: Descargar XLSX
# =============================================================================

$xlsxDiag   = Join-Path $Destino "Diagnosticos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx"
$xlsxProced = Join-Path $Destino "Procedimientos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx"
$csvDiag    = Join-Path $Destino "Diagnosticos_Tabla_Referencia_CIE10ES_$anioFinal.csv"
$csvProced  = Join-Path $Destino "Procedimientos_Tabla_Referencia_CIE10ES_$anioFinal.csv"

if (-not $SoloConvertir) {
    Escribir-Info ""
    Escribir-Info "=== Descarga ==="

    $urlsDiag = @(
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/CIE10/$anioFinal/Diagnosticos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx",
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/docs/CIE/Diagnosticos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx",
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/sistest/clasifEnfermedades/resources/Diagnosticos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx"
    )
    $urlsProced = @(
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/CIE10/$anioFinal/Procedimientos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx",
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/docs/CIE/Procedimientos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx",
        "https://www.sanidad.gob.es/estadEstudios/estadisticas/sistest/clasifEnfermedades/resources/Procedimientos_Tabla_Referencia_CIE10ES_$anioFinal.xlsx"
    )

    $descargaDiag = $false
    foreach ($url in $urlsDiag) {
        Write-Host "  Descargando diagnósticos desde: $url"
        if (Intentar-Descarga $url $xlsxDiag) {
            Escribir-Ok "Descargado: $(Split-Path $xlsxDiag -Leaf)"
            $descargaDiag = $true
            break
        }
    }
    if (-not $descargaDiag) {
        Escribir-Aviso "No se pudo descargar automáticamente el XLSX de diagnósticos."
        Escribir-Aviso "Descargarlo manualmente desde:"
        Escribir-Aviso "  https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm"
        Escribir-Aviso "  y guardarlo como: $xlsxDiag"
    }

    $descargaProced = $false
    foreach ($url in $urlsProced) {
        Write-Host "  Descargando procedimientos desde: $url"
        if (Intentar-Descarga $url $xlsxProced) {
            Escribir-Ok "Descargado: $(Split-Path $xlsxProced -Leaf)"
            $descargaProced = $true
            break
        }
    }
    if (-not $descargaProced) {
        Escribir-Aviso "No se pudo descargar automáticamente el XLSX de procedimientos."
    }
}

if ($SoloDescargar) {
    Escribir-Info ""
    Escribir-Info "Modo --SoloDescargar: proceso terminado."
    Escribir-Info "Para convertir y generar SQL: .\descargar_cie10.ps1 -SoloConvertir"
    exit 0
}

# =============================================================================
# Paso 3: Convertir XLSX → CSV tab-separado
# =============================================================================

Escribir-Info ""
Escribir-Info "=== Conversión XLSX → CSV ==="

foreach ($par in @(
    @{ xlsx = $xlsxDiag;   csv = $csvDiag;   nombre = "Diagnósticos" },
    @{ xlsx = $xlsxProced; csv = $csvProced;  nombre = "Procedimientos" }
)) {
    if (-not (Test-Path $par.xlsx)) {
        Escribir-Aviso "No se encuentra: $($par.xlsx) — omitiendo conversión."
        continue
    }

    # Si ya existe el CSV y es más reciente que el XLSX, no reconvertir
    if ((Test-Path $par.csv) -and
        (Get-Item $par.csv).LastWriteTime -ge (Get-Item $par.xlsx).LastWriteTime) {
        Escribir-Ok "$($par.nombre): CSV ya actualizado, omitiendo conversión."
        continue
    }

    Write-Host "  Convirtiendo $($par.nombre)..."
    $metodo = Convertir-XlsxACsv $par.xlsx $par.csv
    if ($metodo) {
        Ajustar-SeparadorCsv $par.csv
        $filas = (Get-Content $par.csv -Encoding UTF8 | Measure-Object -Line).Lines - 1
        Escribir-Ok "$($par.nombre): $filas filas → $($par.csv) (via $metodo)"
    } else {
        Escribir-Aviso "$($par.nombre): no se pudo convertir automáticamente."
        Escribir-Aviso "Convertir manualmente:"
        Escribir-Aviso "  LibreOffice: Archivo → Guardar como → CSV, separador TAB, UTF-8"
        Escribir-Aviso "  Guardar como: $($par.csv)"
    }
}

# =============================================================================
# Paso 4: Generar sql/02_carga.sql
# =============================================================================

Escribir-Info ""
Escribir-Info "=== Generación del SQL ==="

$phpExe = Get-Command "php" -ErrorAction SilentlyContinue
if ($phpExe) {
    $generador = Join-Path $raiz "scripts\generar_carga.php"
    if (Test-Path $generador) {
        & php $generador $Destino --revision=$Revision
        Escribir-Ok "SQL generado."
    } else {
        Escribir-Aviso "No se encontró: $generador"
    }
} else {
    Escribir-Aviso "PHP no está en el PATH. Generar manualmente:"
    Escribir-Aviso "  php scripts\generar_carga.php `"$Destino`" --revision=$Revision"
}

# =============================================================================
# Resumen final
# =============================================================================

Escribir-Info ""
Escribir-Info "=== Resumen ==="
Write-Host "  Edición procesada : CIE-10-ES $anioFinal (revisión $Revision)"
Write-Host "  Carpeta fuente    : $Destino"
Write-Host "  SQL generado      : $(Join-Path $raiz 'sql\02_carga.sql')"
Escribir-Info ""
Escribir-Info "Pasos siguientes en DBeaver:"
Write-Host "  1. sql\01_esquema.sql   → Execute Script"
Write-Host "  2. sql\02_carga.sql     → Execute Script"
Write-Host "  3. sql\03_postcarga.sql → Execute Script"
Write-Host "  4. sql\99_verificacion.sql → Execute Script y verificar OK"
