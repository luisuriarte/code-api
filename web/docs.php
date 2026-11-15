<?php

declare(strict_types=1);

/**
 * Origen Salud - Portal de Documentación para Desarrolladores (med.origen.ar/docs)
 *
 * Documentación interactiva de la API REST v1 y del servidor de terminología HL7 FHIR R4.
 * Admite visualización bilingüe (ES / EN) y ejemplos de código en 7 lenguajes de programación:
 * cURL, JavaScript, Python, PHP, C# (.NET), Java y Go.
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once __DIR__ . '/includes/i18n.php';

use OrigenSalud\Web\I18n;

header('Content-Type: text/html; charset=UTF-8');

$locale = I18n::boot();
$t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);

$requestPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/docs'), PHP_URL_PATH);
$currentPath = is_string($requestPath) && $requestPath !== '' ? $requestPath : '/docs';
$languageUrl = static fn (string $language): string => $currentPath . '?lang=' . $language;

$baseUrl = rtrim((string) env('WEB_BASE_URL', 'https://med.origen.ar'), '/');
if ($baseUrl === '') {
    $baseUrl = 'https://med.origen.ar';
}

$contactEmail = 'contacto@origen.ar';
$accessMailto = 'mailto:' . $contactEmail . '?subject=' . rawurlencode($locale === 'en' ? 'API Access Request' : 'Solicitud de acceso API');
$contactMailto = 'mailto:' . $contactEmail;
$legalMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal'));
$year = date('Y');

$isEn = $locale === 'en';
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= $isEn ? 'API & FHIR Documentation | Origen Salud' : 'Documentación de API y FHIR | Origen Salud' ?></title>
    <meta name="description" content="<?= $isEn ? 'Developer documentation for Origen Salud B2B Terminology API and HL7 FHIR R4 Terminology Services with multi-language code examples.' : 'Documentación para desarrolladores de la API REST de Origen Salud y servidor de terminología HL7 FHIR R4 con ejemplos en múltiples lenguajes.' ?>">
    <link rel="canonical" href="<?= e($baseUrl . '/docs') ?>">
    <link rel="alternate" hreflang="es" href="<?= e($baseUrl . '/docs?lang=es') ?>">
    <link rel="alternate" hreflang="en" href="<?= e($baseUrl . '/docs?lang=en') ?>">
    <link rel="stylesheet" href="assets/css/app.css">
    <style>
        /* Docs Layout & Components */
        .docs-layout {
            display: grid;
            grid-template-columns: 280px 1fr;
            gap: 40px;
            align-items: start;
            padding: 40px 0 80px;
        }
        @media (max-width: 960px) {
            .docs-layout {
                grid-template-columns: 1fr;
            }
        }
        /* Sticky Sidebar */
        .docs-sidebar {
            position: sticky;
            top: 24px;
            max-height: calc(100vh - 48px);
            overflow-y: auto;
            padding: 20px;
            border-radius: var(--radius);
            background: var(--paper);
            border: 1px solid var(--line);
        }
        .docs-sidebar h3 {
            font-size: 0.85rem;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: var(--muted);
            margin: 0 0 12px;
        }
        .docs-nav-group {
            margin-bottom: 24px;
        }
        .docs-nav-group ul {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .docs-nav-group li {
            margin-bottom: 6px;
        }
        .docs-nav-group a {
            display: block;
            padding: 6px 10px;
            border-radius: 6px;
            color: var(--ink-soft);
            font-size: 0.9rem;
            line-height: 1.4;
            transition: all 0.15s ease;
        }
        .docs-nav-group a:hover,
        .docs-nav-group a.is-active {
            background: var(--white);
            color: var(--teal-dark);
            box-shadow: var(--shadow-sm);
        }
        /* Main Content */
        .docs-content {
            min-width: 0;
        }
        .docs-header {
            margin-bottom: 40px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--line);
        }
        .docs-header h1 {
            font-size: 2.5rem;
            color: var(--ink);
            margin-bottom: 12px;
        }
        .docs-header .lead {
            font-size: 1.15rem;
            color: var(--ink-soft);
            max-width: 800px;
        }
        /* Sections */
        .docs-section {
            margin-bottom: 60px;
            scroll-margin-top: 30px;
        }
        .docs-section h2 {
            font-size: 1.8rem;
            color: var(--ink);
            border-bottom: 2px solid var(--mint);
            padding-bottom: 8px;
            margin-bottom: 20px;
        }
        .docs-section h3 {
            font-size: 1.3rem;
            color: var(--ink-soft);
            margin: 28px 0 12px;
        }
        /* Endpoint Box */
        .endpoint-badge {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 8px 14px;
            border-radius: 8px;
            background: #061522;
            color: #fff;
            font-family: var(--font-mono);
            font-size: 0.92rem;
            margin-bottom: 16px;
        }
        .method-get {
            background: #0c7c86;
            color: #fff;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.75rem;
        }
        .method-post {
            background: #2563eb;
            color: #fff;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.75rem;
        }
        /* Tables */
        .param-table {
            width: 100%;
            border-collapse: collapse;
            margin: 16px 0 24px;
            font-size: 0.92rem;
        }
        .param-table th,
        .param-table td {
            padding: 10px 14px;
            text-align: left;
            border-bottom: 1px solid var(--line);
        }
        .param-table th {
            background: var(--paper);
            color: var(--ink);
            font-weight: 600;
        }
        .param-table code {
            font-family: var(--font-mono);
            background: var(--mint);
            color: var(--teal-dark);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.85rem;
        }
        /* Interactive Multi-Language Code Tabs */
        .code-container {
            margin: 20px 0 32px;
            border-radius: var(--radius);
            background: #061522;
            border: 1px solid rgba(255, 255, 255, 0.12);
            overflow: hidden;
            box-shadow: var(--shadow-sm);
        }
        .code-tabs-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: #0a1f30;
            padding: 4px 12px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            overflow-x: auto;
        }
        .code-tabs-list {
            display: flex;
            gap: 4px;
        }
        .tab-btn {
            background: transparent;
            border: none;
            color: #8da4b8;
            font-size: 0.82rem;
            font-weight: 600;
            padding: 8px 12px;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        .tab-btn:hover {
            color: #fff;
            background: rgba(255, 255, 255, 0.06);
        }
        .tab-btn.is-active {
            color: #0c7c86;
            background: #061522;
            border-bottom: 2px solid #0c7c86;
        }
        .copy-btn {
            background: rgba(255, 255, 255, 0.08);
            border: 1px solid rgba(255, 255, 255, 0.15);
            color: #c9e6ee;
            font-size: 0.75rem;
            padding: 4px 10px;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        .copy-btn:hover {
            background: rgba(255, 255, 255, 0.15);
            color: #fff;
        }
        .code-pane {
            display: none;
            margin: 0;
            padding: 20px;
            overflow-x: auto;
            color: #c9e6ee;
            font-family: var(--font-mono);
            font-size: 0.88rem;
            line-height: 1.5;
        }
        .code-pane.is-active {
            display: block;
        }
        /* JSON response box */
        .response-card {
            border: 1px solid var(--line);
            border-radius: var(--radius);
            background: var(--paper);
            margin: 20px 0;
            overflow: hidden;
        }
        .response-head {
            background: #eef4f8;
            padding: 8px 16px;
            font-size: 0.82rem;
            font-weight: 600;
            color: var(--ink-soft);
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid var(--line);
        }
        .response-card pre {
            margin: 0;
            padding: 16px 20px;
            overflow-x: auto;
            font-family: var(--font-mono);
            font-size: 0.85rem;
            color: var(--ink);
            background: #fafcfe;
        }
        /* Callout alert boxes */
        .alert-box {
            padding: 16px 20px;
            border-radius: 12px;
            margin: 20px 0;
            border-left: 4px solid var(--teal);
            background: var(--mint);
            font-size: 0.95rem;
        }
        .alert-box p {
            margin: 0;
        }
        .alert-box strong {
            color: var(--teal-dark);
        }
    </style>
</head>
<body>
<a class="skip-link" href="#main"><?= e($t('a11y.skip')) ?></a>

<header class="site-header">
    <div class="container header-inner">
        <a class="brand" href="/" aria-label="Origen Salud">
            <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="brand-name">Origen<span>Salud</span></span>
        </a>

        <nav class="site-nav" aria-label="<?= e($t('nav.label')) ?>">
            <a href="/#plataforma"><?= e($t('nav.platform')) ?></a>
            <a href="/#snomed"><?= e($t('nav.snomed')) ?></a>
            <a href="/#anmat"><?= e($t('nav.anmat')) ?></a>
            <a href="/#api"><?= e($t('nav.api')) ?></a>
            <a href="/docs" aria-current="page" class="is-active"><?= e($t('nav.docs')) ?></a>
            <a href="/#contacto"><?= e($t('nav.contact')) ?></a>
        </nav>

        <div class="header-actions">
            <div class="lang-switch" role="group" aria-label="<?= e($t('lang.label')) ?>">
                <a href="<?= e($languageUrl('es')) ?>"
                   hreflang="es"
                   lang="es"
                   title="<?= e($t('lang.es')) ?>"
                   <?= $locale === 'es' ? 'aria-current="true" class="is-active"' : '' ?>>ES</a>
                <span aria-hidden="true">/</span>
                <a href="<?= e($languageUrl('en')) ?>"
                   hreflang="en"
                   lang="en"
                   title="<?= e($t('lang.en')) ?>"
                   <?= $locale === 'en' ? 'aria-current="true" class="is-active"' : '' ?>>EN</a>
            </div>
            <a class="button button-small" href="<?= e($accessMailto) ?>"><?= e($t('nav.access')) ?></a>
        </div>
    </div>
</header>

<main id="main">
    <div class="container docs-layout">
        <!-- Sidebar Navigation -->
        <aside class="docs-sidebar" aria-label="<?= $isEn ? 'Documentation index' : 'Índice de documentación' ?>">
            <div class="docs-nav-group">
                <h3><?= $isEn ? 'Getting Started' : 'Primeros Pasos' ?></h3>
                <ul>
                    <li><a href="#intro"><?= $isEn ? 'Overview & Base URL' : 'General y URL Base' ?></a></li>
                    <li><a href="#auth"><?= $isEn ? 'Authentication' : 'Autenticación' ?></a></li>
                    <li><a href="#domains"><?= $isEn ? 'Clinical Domains' : 'Dominios Clínicos' ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= $isEn ? 'Catalog Engine (Argentina)' : 'Motor de Nomencladores' ?></h3>
                <ul>
                    <li><a href="#catalogs"><?= $isEn ? 'Catalogs (/v1/catalogs)' : 'Catálogos (/v1/catalogs)' ?></a></li>
                    <li><a href="#catalogs-items"><?= $isEn ? 'Procedures (/v1/catalogs/{id}/items)' : 'Prestaciones e Ítems' ?></a></li>
                    <li><a href="#catalogs-mappings"><?= $isEn ? 'Semantic Mappings (/v1/mappings)' : 'Mapeos y Equivalencias' ?></a></li>
                    <li><a href="#catalogs-pharma"><?= $isEn ? 'Pharma Identifiers (Troquel/GTIN)' : 'Vademécum (Troquel/GTIN)' ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= $isEn ? 'Unified Search' : 'Búsqueda Unificada' ?></h3>
                <ul>
                    <li><a href="#search"><?= $isEn ? 'Multimodel Search (/v1/search)' : 'Búsqueda Multimodelo' ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= $isEn ? 'Dental Module (DENTAR)' : 'Odontología (DENTAR)' ?></h3>
                <ul>
                    <li><a href="#dental-diagnoses"><?= $isEn ? 'Dental Diagnoses & CIE-10' : 'Diagnósticos y CIE-10' ?></a></li>
                    <li><a href="#dental-justifications"><?= $isEn ? 'Clinical Justifications (Audit)' : 'Justificación de Auditoría' ?></a></li>
                    <li><a href="#dental-snomed"><?= $isEn ? 'SNOMED-CT Dental Lookup' : 'Búsqueda por SNOMED-CT' ?></a></li>
                    <li><a href="#dental-procedure"><?= $isEn ? 'Procedure Rules & CDT' : 'Ficha Técnica y CDT 2025' ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= $isEn ? 'Clinical Catalogs' : 'Catálogos Clínicos' ?></h3>
                <ul>
                    <li><a href="#snomed"><?= $isEn ? 'SNOMED CT Concepts' : 'Conceptos SNOMED CT' ?></a></li>
                    <li><a href="#cie10"><?= $isEn ? 'WHO ICD-10 (CIE-10)' : 'CIE-10 de la OMS' ?></a></li>
                    <li><a href="#anmat"><?= $isEn ? 'ANMAT Medications' : 'Medicamentos ANMAT' ?></a></li>
                    <li><a href="#local-catalogs"><?= $isEn ? 'Lab, Vaccines & Imaging' : 'Laboratorio, Vacunas e Imágenes' ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= $isEn ? 'HL7® FHIR® R4' : 'HL7® FHIR® R4' ?></h3>
                <ul>
                    <li><a href="#fhir-intro"><?= $isEn ? 'FHIR Terminology Service' : 'Servidor Terminológico' ?></a></li>
                    <li><a href="#fhir-lookup"><?= $isEn ? 'CodeSystem $lookup' : 'Operación $lookup' ?></a></li>
                    <li><a href="#fhir-expand"><?= $isEn ? 'ValueSet $expand' : 'Operación $expand' ?></a></li>
                    <li><a href="#fhir-translate"><?= $isEn ? 'ConceptMap $translate' : 'Operación $translate' ?></a></li>
                    <li><a href="#fhir-resources"><?= $isEn ? 'Procedure & Condition' : 'Recursos Procedure y Condition' ?></a></li>
                </ul>
            </div>
        </aside>

        <!-- Documentation Content -->
        <article class="docs-content">
            <div class="docs-header">
                <h1><?= $isEn ? 'Developer API Documentation' : 'Documentación de la API para Desarrolladores' ?></h1>
                <p class="lead">
                    <?= $isEn
                        ? 'Connect your Electronic Health Records (EHR), dental billing engines, and e-prescription systems with Origen Salud B2B Terminology-as-a-Service and HL7 FHIR R4 standard services.'
                        : 'Conecta tus Historias Clínicas Electrónicas (HCE), motores de auditoría odontológica y plataformas de receta electrónica a la infraestructura de terminología clínica unificada de Origen Salud.'
                    ?>
                </p>
            </div>

            <!-- 1. GENERAL & AUTH -->
            <section id="intro" class="docs-section">
                <h2><?= $isEn ? '1. Overview & Base URLs' : '1. Información General y URLs Base' ?></h2>
                <p>
                    <?= $isEn
                        ? 'All API endpoints deliver JSON responses with UTF-8 encoding. Requests must be performed over HTTPS.'
                        : 'Todas las solicitudes se realizan mediante HTTPS y devuelven respuestas en formato JSON codificado en UTF-8.'
                    ?>
                </p>
                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= $isEn ? 'Environment' : 'Entorno' ?></th>
                            <th>URL</th>
                            <th><?= $isEn ? 'Description' : 'Descripción' ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>Production REST</strong></td>
                            <td><code>https://api.origen.ar/v1</code></td>
                            <td><?= $isEn ? 'Unified REST API for terminology queries and audits.' : 'API REST unificada de consultas y auditoría terminológica.' ?></td>
                        </tr>
                        <tr>
                            <td><strong>HL7 FHIR R4</strong></td>
                            <td><code>https://api.origen.ar/fhir</code></td>
                            <td><?= $isEn ? 'Official HL7 FHIR Release 4 Terminology Server.' : 'Servidor terminológico estándar HL7 FHIR Release 4.' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Health Check</strong></td>
                            <td><code>https://api.origen.ar/health</code></td>
                            <td><?= $isEn ? 'Public monitoring endpoint for uptime and load balancers.' : 'Endpoint público para balanceadores y monitoreo de disponibilidad.' ?></td>
                        </tr>
                    </tbody>
                </table>
            </section>

            <section id="auth" class="docs-section">
                <h2><?= $isEn ? '2. Authentication' : '2. Autenticación' ?></h2>
                <p>
                    <?= $isEn
                        ? 'Authentication is performed using a B2B API Key sent in the HTTP headers. You can pass it via standard Bearer token or direct X-API-Key header:'
                        : 'La autenticación se realiza mediante una API Key corporativa enviada en las cabeceras HTTP. Es posible enviarla mediante Bearer token estándar o mediante la cabecera X-API-Key:'
                    ?>
                </p>
                <div class="endpoint-badge">
                    <span class="method-get">HEADER</span>
                    <code>Authorization: Bearer orig_live_xxxxxxxxxxxxxxxxxxxx</code>
                </div>

                <div class="alert-box">
                    <p>
                        <strong><?= $isEn ? 'Important:' : 'Importante:' ?></strong>
                        <?= $isEn
                            ? 'Never expose your API Key in client-side applications (SPA, public web pages, or mobile apps). All requests should originate from your secure backend servers.'
                            : 'Nunca expongas tu API Key en aplicaciones del lado del cliente (SPAs, páginas web públicas o apps móviles sin backend intermedio). Todas las llamadas deben originarse desde servidores seguros.'
                        ?>
                    </p>
                </div>
            </section>

            <!-- CATALOG ENGINE -->
            <section id="catalogs" class="docs-section">
                <h2><?= $isEn ? '3. Origen Catalog Engine & Argentine Healthcare Catalogs' : '3. Motor de Catálogos y Nomencladores Argentinos' ?></h2>
                <p>
                    <?= $isEn
                        ? 'Origen Catalog Engine 1.0 provides decoupled, versioned access to national healthcare nomenclators, proprietary catalogs (DENTAR), pricing schedules (UB, Galenos, Modules, Pesos), and pharmaceutical identifiers (Troquel, AlfaBeta, Kairos, GTIN).'
                        : 'Origen Catalog Engine 1.0 ofrece acceso desacoplado y versionado a los nomencladores nacionales argentinos, catálogos propios (DENTAR), esquemas arancelarios (UB, Galenos, Módulos, Pesos) e identificadores farmacéuticos (Troquel, AlfaBeta, Kairos, GTIN).'
                    ?>
                </p>

                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= $isEn ? 'Scope' : 'Ámbito' ?></th>
                            <th><?= $isEn ? 'Catalog Code' : 'Código de Catálogo' ?></th>
                            <th><?= $isEn ? 'Description' : 'Descripción' ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong style="color:var(--teal-dark)">Propio</strong></td>
                            <td><code>dentar</code></td>
                            <td><?= $isEn ? 'DENTAR System: Dental procedures harmonized with ADA CDT 2025 and ICD-10.' : 'Sistema DENTAR: Prestaciones odontológicas armonizadas con ADA CDT 2025 y CIE-10.' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>nn-pmo</code></td>
                            <td><?= $isEn ? 'National Medical & Sanatorial Nomenclator (PMO) with Galenos.' : 'Nomenclador Nacional Médico y Quirúrgico (PMO) con Galenos.' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>nbu</code></td>
                            <td><?= $isEn ? 'CUBRA Single Biochemical Nomenclator with Biochemical Units (UB) & LOINC.' : 'Nomenclador Bioquímico Único de CUBRA con Unidades Bioquímicas (UB) y LOINC.' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>nhpgd</code></td>
                            <td><?= $isEn ? 'Decentralized Public Hospitals Nomenclator for cost recovery.' : 'Nomenclador de Hospitales Públicos Descentralizados (recupero hospitalario).' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>andis</code></td>
                            <td><?= $isEn ? 'Disability Basic Services Nomenclator with rehabilitation modules.' : 'Nomenclador de Prestaciones Básicas para Personas con Discapacidad (ANDIS).' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>kinesiologia</code></td>
                            <td><?= $isEn ? 'Kinesiology and Physical Therapy sessions.' : 'Nomenclador de Fisioterapia y Kinesiología motriz y respiratoria.' ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>salud-mental</code></td>
                            <td><?= $isEn ? 'Psychology and Mental Health sessions and psychodiagnosis.' : 'Nomenclador de Psicología y Salud Mental (psicoterapias y peritajes).' ?></td>
                        </tr>
                    </tbody>
                </table>

                <h3 id="catalogs-items"><?= $isEn ? 'Browse Catalog Items & Procedures' : 'Consultar Prestaciones de un Catálogo' ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/catalogs/{catalog_code}/items?q={query}&amp;limit={n}</code>
                </div>

                <div class="code-container" data-container="cat-items">
                    <div class="code-tabs-header">
                        <div class="code-tabs-list">
                            <button class="tab-btn is-active" data-lang="curl">cURL</button>
                            <button class="tab-btn" data-lang="js">JavaScript</button>
                            <button class="tab-btn" data-lang="python">Python</button>
                            <button class="tab-btn" data-lang="php">PHP</button>
                            <button class="tab-btn" data-lang="csharp">C# (.NET)</button>
                            <button class="tab-btn" data-lang="java">Java</button>
                            <button class="tab-btn" data-lang="go">Go</button>
                        </div>
                        <button class="copy-btn"><?= $isEn ? 'Copy' : 'Copiar' ?></button>
                    </div>

                    <pre class="code-pane is-active" data-lang="curl"><code># Consultar hemograma en NBU
curl -s -X GET "https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma" \
  -H "Authorization: Bearer TU_API_KEY"</code></pre>

                    <pre class="code-pane" data-lang="js"><code>const res = await fetch('https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma', {
  headers: { 'Authorization': 'Bearer TU_API_KEY' }
});
const items = await res.json();
console.log(items.data);</code></pre>

                    <pre class="code-pane" data-lang="python"><code>import requests

res = requests.get(
    "https://api.origen.ar/v1/catalogs/nbu/items",
    headers={"Authorization": "Bearer TU_API_KEY"},
    params={"q": "hemograma"}
)
print(res.json()["data"])</code></pre>

                    <pre class="code-pane" data-lang="php"><code>&lt;?php
$ch = curl_init('https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma');
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer TU_API_KEY', 'Accept: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$data = json_decode(curl_exec($ch), true);
curl_close($ch);
print_r($data['data']);</code></pre>

                    <pre class="code-pane" data-lang="csharp"><code>using var client = new HttpClient();
client.DefaultRequestHeaders.Add("Authorization", "Bearer TU_API_KEY");
var json = await client.GetStringAsync("https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma");
Console.WriteLine(json);</code></pre>

                    <pre class="code-pane" data-lang="java"><code>HttpRequest req = HttpRequest.newBuilder()
    .uri(URI.create("https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma"))
    .header("Authorization", "Bearer TU_API_KEY").GET().build();
HttpResponse&lt;String&gt; resp = HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString());
System.out.println(resp.body());</code></pre>

                    <pre class="code-pane" data-lang="go"><code>req, _ := http.NewRequest("GET", "https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma", nil)
req.Header.Set("Authorization", "Bearer TU_API_KEY")
resp, _ := http.DefaultClient.Do(req)
body, _ := io.ReadAll(resp.Body)
fmt.Println(string(body))</code></pre>
                </div>

                <h3 id="catalogs-mappings"><?= $isEn ? 'Cross-Terminology Mappings (SNOMED, CIE-10, LOINC)' : 'Mapeos Cruzados (SNOMED-CT, CIE-10, LOINC)' ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/mappings?system={system}&amp;code={code}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Discover which procedures correspond to an international clinical concept (or vice-versa).'
                        : 'Descubre qué prestaciones corresponden a un concepto clínico internacional (o viceversa).'
                    ?>
                </p>

                <h3 id="catalogs-pharma"><?= $isEn ? 'Pharmacy: Commercial Identifiers (Troquel / AlfaBeta / Kairos / GTIN)' : 'Farmacia: Identificadores Comerciales (Troquel / AlfaBeta / Kairos / GTIN)' ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/medicines/identifiers/{system}/{code}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Validate prescriptions and insurance coverage directly by Troquel number, AlfaBeta ID, Kairos ID, or GS1 GTIN barcode.'
                        : 'Valida recetas electrónicas y coberturas de farmacia directamente por Número de Troquel, código AlfaBeta, código Kairos o código de barras GTIN.'
                    ?>
                </p>
            </section>

            <!-- 2. UNIFIED SEARCH -->
            <section id="search" class="docs-section">
                <h2><?= $isEn ? '3. Unified Multimodel Search' : '3. Búsqueda Unificada Multimodelo' ?></h2>
                <p>
                    <?= $isEn
                        ? 'Perform blazing-fast searches across multiple clinical vocabularies simultaneously. Trigram matching (pg_trgm) and phonetic ranking ensure typo tolerance.'
                        : 'Realiza búsquedas simultáneas ultrarrápidas a través de múltiples vocabularios clínicos. La coincidencia por trigramas (pg_trgm) y ponderación fonética ofrece tolerancia ante errores ortográficos.'
                    ?>
                </p>

                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/search?q={query}&amp;domains={d1,d2}&amp;lang={es|en}&amp;limit={n}</code>
                </div>

                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= $isEn ? 'Parameter' : 'Parámetro' ?></th>
                            <th><?= $isEn ? 'Type' : 'Tipo' ?></th>
                            <th><?= $isEn ? 'Default' : 'Defecto' ?></th>
                            <th><?= $isEn ? 'Description' : 'Descripción' ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><code>q</code></td>
                            <td>string</td>
                            <td><em><?= $isEn ? 'Required' : 'Requerido' ?></em></td>
                            <td><?= $isEn ? 'Search term, clinical keyword or exact code.' : 'Término a buscar, palabra clave clínica o código exacto.' ?></td>
                        </tr>
                        <tr>
                            <td><code>domains</code></td>
                            <td>string</td>
                            <td><code>snomed,cie10,odontologia</code></td>
                            <td><?= $isEn ? 'Comma-separated list of domains to search.' : 'Lista separada por comas de dominios clínicos a consultar.' ?></td>
                        </tr>
                        <tr>
                            <td><code>limit</code></td>
                            <td>integer</td>
                            <td><code>20</code></td>
                            <td><?= $isEn ? 'Number of results (max 100).' : 'Cantidad de resultados por página (máximo 100).' ?></td>
                        </tr>
                        <tr>
                            <td><code>lang</code></td>
                            <td>string</td>
                            <td><code>es</code></td>
                            <td><?= $isEn ? 'Language for descriptions (es or en).' : 'Idioma de las descripciones (es o en).' ?></td>
                        </tr>
                    </tbody>
                </table>

                <!-- MULTI-LANGUAGE CODE TABS EXAMPLE 1 -->
                <div class="code-container" data-container="search">
                    <div class="code-tabs-header">
                        <div class="code-tabs-list">
                            <button class="tab-btn is-active" data-lang="curl">cURL</button>
                            <button class="tab-btn" data-lang="js">JavaScript</button>
                            <button class="tab-btn" data-lang="python">Python</button>
                            <button class="tab-btn" data-lang="php">PHP</button>
                            <button class="tab-btn" data-lang="csharp">C# (.NET)</button>
                            <button class="tab-btn" data-lang="java">Java</button>
                            <button class="tab-btn" data-lang="go">Go</button>
                        </div>
                        <button class="copy-btn"><?= $isEn ? 'Copy' : 'Copiar' ?></button>
                    </div>

                    <!-- cURL -->
                    <pre class="code-pane is-active" data-lang="curl"><code>curl -s -X GET "https://api.origen.ar/v1/search?q=caries&domains=odontologia,snomed,cie10&limit=5" \
  -H "Authorization: Bearer TU_API_KEY" \
  -H "Accept: application/json"</code></pre>

                    <!-- JavaScript -->
                    <pre class="code-pane" data-lang="js"><code>const apiKey = 'TU_API_KEY';
const url = 'https://api.origen.ar/v1/search?q=caries&domains=odontologia,snomed,cie10&limit=5';

const response = await fetch(url, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'Accept': 'application/json'
  }
});

const result = await response.json();
console.log(result.data);</code></pre>

                    <!-- Python -->
                    <pre class="code-pane" data-lang="python"><code>import requests

api_key = "TU_API_KEY"
url = "https://api.origen.ar/v1/search"
params = {
    "q": "caries",
    "domains": "odontologia,snomed,cie10",
    "limit": 5
}
headers = {
    "Authorization": f"Bearer {api_key}",
    "Accept": "application/json"
}

response = requests.get(url, headers=headers, params=params)
data = response.json()
print(data["data"])</code></pre>

                    <!-- PHP -->
                    <pre class="code-pane" data-lang="php"><code>&lt;?php
$apiKey = 'TU_API_KEY';
$url = 'https://api.origen.ar/v1/search?' . http_build_query([
    'q' => 'caries',
    'domains' => 'odontologia,snomed,cie10',
    'limit' => 5
]);

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $apiKey,
        'Accept: application/json'
    ]
]);

$response = curl_exec($ch);
curl_close($ch);
$result = json_decode($response, true);
print_r($result['data']);</code></pre>

                    <!-- C# -->
                    <pre class="code-pane" data-lang="csharp"><code>using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

using var client = new HttpClient();
client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "TU_API_KEY");
client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

var url = "https://api.origen.ar/v1/search?q=caries&domains=odontologia,snomed,cie10&limit=5";
var response = await client.GetStringAsync(url);
Console.WriteLine(response);</code></pre>

                    <!-- Java -->
                    <pre class="code-pane" data-lang="java"><code>import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class Main {
    public static void main(String[] args) throws Exception {
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create("https://api.origen.ar/v1/search?q=caries&domains=odontologia,snomed,cie10&limit=5"))
            .header("Authorization", "Bearer TU_API_KEY")
            .header("Accept", "application/json")
            .GET()
            .build();

        HttpResponse&lt;String&gt; response = client.send(request, HttpResponse.BodyHandlers.ofString());
        System.out.println(response.body());
    }
}</code></pre>

                    <!-- Go -->
                    <pre class="code-pane" data-lang="go"><code>package main

import (
	"fmt"
	"io"
	"net/http"
)

func main() {
	url := "https://api.origen.ar/v1/search?q=caries&domains=odontologia,snomed,cie10&limit=5"
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", "Bearer TU_API_KEY")
	req.Header.Set("Accept", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	fmt.Println(string(body))
}</code></pre>
                </div>
            </section>

            <!-- 3. DENTAL MODULE (DENTAR) -->
            <section id="dental-diagnoses" class="docs-section">
                <h2><?= $isEn ? '4. Dental Module (DENTAR / ADA CDT / CIE-10)' : '4. Módulo Odontológico (DENTAR / ADA CDT / CIE-10)' ?></h2>
                <p>
                    <?= $isEn
                        ? 'DENTAR harmonizes the 11 chapters of the Argentine Dental Nomenclator, ADA CDT 2025 (12 categories), permanent DNT-XXXXXX codes, SNOMED-CT clinical procedures, and ICD-10 (K00–K14) diagnosis justifications.'
                        : 'DENTAR armoniza los 11 capítulos del Nomenclador Odontológico Argentino, ADA CDT 2025 (12 categorías), códigos permanentes DNT-XXXXXX, procedimientos clínicos SNOMED-CT y justificaciones diagnósticas CIE-10 (K00–K14).'
                    ?>
                </p>

                <h3><?= $isEn ? 'Dental Diagnoses Catalog & Search' : 'Catálogo y Búsqueda de Diagnósticos Odontológicos' ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/odontologia/diagnosticos[?q=...&amp;snomed=...&amp;cie10=...]</code>
                </div>

                <!-- MULTI-LANGUAGE CODE TABS EXAMPLE 2 -->
                <div class="code-container" data-container="dental-diag">
                    <div class="code-tabs-header">
                        <div class="code-tabs-list">
                            <button class="tab-btn is-active" data-lang="curl">cURL</button>
                            <button class="tab-btn" data-lang="js">JavaScript</button>
                            <button class="tab-btn" data-lang="python">Python</button>
                            <button class="tab-btn" data-lang="php">PHP</button>
                            <button class="tab-btn" data-lang="csharp">C# (.NET)</button>
                            <button class="tab-btn" data-lang="java">Java</button>
                            <button class="tab-btn" data-lang="go">Go</button>
                        </div>
                        <button class="copy-btn"><?= $isEn ? 'Copy' : 'Copiar' ?></button>
                    </div>

                    <pre class="code-pane is-active" data-lang="curl"><code>curl -s -X GET "https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001" \
  -H "Authorization: Bearer TU_API_KEY"</code></pre>

                    <pre class="code-pane" data-lang="js"><code>const response = await fetch('https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001', {
  headers: { 'Authorization': 'Bearer TU_API_KEY' }
});
const diagnoses = await response.json();
console.log(diagnoses.data);</code></pre>

                    <pre class="code-pane" data-lang="python"><code>import requests

res = requests.get(
    "https://api.origen.ar/v1/odontologia/diagnosticos",
    headers={"Authorization": "Bearer TU_API_KEY"},
    params={"snomed": "80967001"}
)
print(res.json()["data"])</code></pre>

                    <pre class="code-pane" data-lang="php"><code>&lt;?php
$ch = curl_init('https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001');
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer TU_API_KEY', 'Accept: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$data = json_decode(curl_exec($ch), true);
curl_close($ch);
print_r($data['data']);</code></pre>

                    <pre class="code-pane" data-lang="csharp"><code>using var client = new HttpClient();
client.DefaultRequestHeaders.Add("Authorization", "Bearer TU_API_KEY");
var json = await client.GetStringAsync("https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001");
Console.WriteLine(json);</code></pre>

                    <pre class="code-pane" data-lang="java"><code>HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001"))
    .header("Authorization", "Bearer TU_API_KEY")
    .GET().build();
HttpResponse&lt;String&gt; response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
System.out.println(response.body());</code></pre>

                    <pre class="code-pane" data-lang="go"><code>req, _ := http.NewRequest("GET", "https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001", nil)
req.Header.Set("Authorization", "Bearer TU_API_KEY")
resp, _ := http.DefaultClient.Do(req)
body, _ := io.ReadAll(resp.Body)
fmt.Println(string(body))</code></pre>
                </div>

                <div class="response-card">
                    <div class="response-head">
                        <span>Response JSON (200 OK)</span>
                        <span>took_ms: 1.45</span>
                    </div>
                    <pre><code>{
  "data": [
    {
      "code": "DNT-DX-0005",
      "clinical_name": "Caries limitada al esmalte (manchas blancas / cavitación incipiente)",
      "cie10": { "code": "K02.0", "description": "Caries limitada al esmalte" },
      "snomed_ct": { "concept_id": "80967001", "term": "Caries dental" }
    },
    {
      "code": "DNT-DX-0006",
      "clinical_name": "Caries de la dentina (cavitación simple, compuesta o compleja)",
      "cie10": { "code": "K02.1", "description": "Caries de la dentina" },
      "snomed_ct": { "concept_id": "80967001", "term": "Caries dental" }
    }
  ],
  "meta": { "total": 2, "language": "es" }
}</code></pre>
                </div>
            </section>

            <!-- 4. CLINICAL JUSTIFICATIONS -->
            <section id="dental-justifications" class="docs-section">
                <h3><?= $isEn ? 'Clinical Justification & Audit Rules for Procedures' : 'Justificación Clínica y Auditoría para Prestaciones' ?></h3>
                <p>
                    <?= $isEn
                        ? 'Verify which diagnoses justify a dental procedure before authorization or billing. Accepts Argentine code (02.01), CDT (D2140), DENTAR (DNT-000007), internal ID, or SNOMED-CT SCTID (424759004).'
                        : 'Consulta qué diagnósticos justifican una práctica odontológica antes de autorizarla o facturarla. Acepta indistintamente código del nomenclador argentino (02.01), código CDT (D2140), código DENTAR (DNT-000007), ID numérico o SCTID de SNOMED-CT (424759004).'
                    ?>
                </p>

                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/odontologia/{identificador}/diagnosticos</code>
                </div>

                <!-- MULTI-LANGUAGE CODE TABS EXAMPLE 3 -->
                <div class="code-container" data-container="dental-just">
                    <div class="code-tabs-header">
                        <div class="code-tabs-list">
                            <button class="tab-btn is-active" data-lang="curl">cURL</button>
                            <button class="tab-btn" data-lang="js">JavaScript</button>
                            <button class="tab-btn" data-lang="python">Python</button>
                            <button class="tab-btn" data-lang="php">PHP</button>
                            <button class="tab-btn" data-lang="csharp">C# (.NET)</button>
                            <button class="tab-btn" data-lang="java">Java</button>
                            <button class="tab-btn" data-lang="go">Go</button>
                        </div>
                        <button class="copy-btn"><?= $isEn ? 'Copy' : 'Copiar' ?></button>
                    </div>

                    <pre class="code-pane is-active" data-lang="curl"><code>curl -s -X GET "https://api.origen.ar/v1/odontologia/02.01/diagnosticos" \
  -H "Authorization: Bearer TU_API_KEY"</code></pre>

                    <pre class="code-pane" data-lang="js"><code>const res = await fetch('https://api.origen.ar/v1/odontologia/02.01/diagnosticos', {
  headers: { 'Authorization': 'Bearer TU_API_KEY' }
});
const auditData = await res.json();
console.log(auditData.data.clinical_justifications);</code></pre>

                    <pre class="code-pane" data-lang="python"><code>import requests

res = requests.get(
    "https://api.origen.ar/v1/odontologia/02.01/diagnosticos",
    headers={"Authorization": "Bearer TU_API_KEY"}
)
print(res.json()["data"]["clinical_justifications"])</code></pre>

                    <pre class="code-pane" data-lang="php"><code>&lt;?php
$ch = curl_init('https://api.origen.ar/v1/odontologia/02.01/diagnosticos');
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer TU_API_KEY', 'Accept: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = json_decode(curl_exec($ch), true);
curl_close($ch);
print_r($response['data']['clinical_justifications']);</code></pre>

                    <pre class="code-pane" data-lang="csharp"><code>using var client = new HttpClient();
client.DefaultRequestHeaders.Add("Authorization", "Bearer TU_API_KEY");
var json = await client.GetStringAsync("https://api.origen.ar/v1/odontologia/02.01/diagnosticos");
Console.WriteLine(json);</code></pre>

                    <pre class="code-pane" data-lang="java"><code>HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("https://api.origen.ar/v1/odontologia/02.01/diagnosticos"))
    .header("Authorization", "Bearer TU_API_KEY")
    .GET().build();
HttpResponse&lt;String&gt; response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
System.out.println(response.body());</code></pre>

                    <pre class="code-pane" data-lang="go"><code>req, _ := http.NewRequest("GET", "https://api.origen.ar/v1/odontologia/02.01/diagnosticos", nil)
req.Header.Set("Authorization", "Bearer TU_API_KEY")
resp, _ := http.DefaultClient.Do(req)
body, _ := io.ReadAll(resp.Body)
fmt.Println(string(body))</code></pre>
                </div>
            </section>

            <!-- 5. SNOMED DENTAL LOOKUP -->
            <section id="dental-snomed" class="docs-section">
                <h3><?= $isEn ? 'Direct SNOMED-CT Dental Resolution' : 'Resolución Directa por SNOMED-CT' ?></h3>
                <p>
                    <?= $isEn
                        ? 'Query any SNOMED-CT Concept ID to instantly discover if it represents a dental procedure, a diagnosis, or both, with all cross-mappings.'
                        : 'Consulta cualquier Concept ID de SNOMED-CT para descubrir de inmediato si representa una práctica odontológica, un diagnóstico bucal o ambos, con todos sus mapeos cruzados.'
                    ?>
                </p>

                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/odontologia/snomed/{sctid}</code>
                </div>

                <div class="code-container" data-container="dental-snomed">
                    <div class="code-tabs-header">
                        <div class="code-tabs-list">
                            <button class="tab-btn is-active" data-lang="curl">cURL</button>
                            <button class="tab-btn" data-lang="js">JavaScript</button>
                            <button class="tab-btn" data-lang="python">Python</button>
                            <button class="tab-btn" data-lang="php">PHP</button>
                            <button class="tab-btn" data-lang="csharp">C# (.NET)</button>
                            <button class="tab-btn" data-lang="java">Java</button>
                            <button class="tab-btn" data-lang="go">Go</button>
                        </div>
                        <button class="copy-btn"><?= $isEn ? 'Copy' : 'Copiar' ?></button>
                    </div>

                    <pre class="code-pane is-active" data-lang="curl"><code>curl -s -X GET "https://api.origen.ar/v1/odontologia/snomed/80967001" \
  -H "Authorization: Bearer TU_API_KEY"</code></pre>

                    <pre class="code-pane" data-lang="js"><code>const res = await fetch('https://api.origen.ar/v1/odontologia/snomed/80967001', {
  headers: { 'Authorization': 'Bearer TU_API_KEY' }
});
const data = await res.json();
console.log(data.data.diagnoses);</code></pre>

                    <pre class="code-pane" data-lang="python"><code>import requests

res = requests.get(
    "https://api.origen.ar/v1/odontologia/snomed/80967001",
    headers={"Authorization": "Bearer TU_API_KEY"}
)
print(res.json()["data"])</code></pre>

                    <pre class="code-pane" data-lang="php"><code>&lt;?php
$ch = curl_init('https://api.origen.ar/v1/odontologia/snomed/80967001');
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer TU_API_KEY', 'Accept: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$res = json_decode(curl_exec($ch), true);
curl_close($ch);
print_r($res['data']);</code></pre>

                    <pre class="code-pane" data-lang="csharp"><code>using var client = new HttpClient();
client.DefaultRequestHeaders.Add("Authorization", "Bearer TU_API_KEY");
var json = await client.GetStringAsync("https://api.origen.ar/v1/odontologia/snomed/80967001");
Console.WriteLine(json);</code></pre>

                    <pre class="code-pane" data-lang="java"><code>HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("https://api.origen.ar/v1/odontologia/snomed/80967001"))
    .header("Authorization", "Bearer TU_API_KEY")
    .GET().build();
HttpResponse&lt;String&gt; response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
System.out.println(response.body());</code></pre>

                    <pre class="code-pane" data-lang="go"><code>req, _ := http.NewRequest("GET", "https://api.origen.ar/v1/odontologia/snomed/80967001", nil)
req.Header.Set("Authorization", "Bearer TU_API_KEY")
resp, _ := http.DefaultClient.Do(req)
body, _ := io.ReadAll(resp.Body)
fmt.Println(string(body))</code></pre>
                </div>
            </section>

            <!-- 6. CLINICAL CATALOGS -->
            <section id="snomed" class="docs-section">
                <h2><?= $isEn ? '5. Clinical Catalogs & Concept Endpoints' : '5. Catálogos Clínicos y Endpoints de Conceptos' ?></h2>

                <h3>SNOMED-CT Concept Detail (`/v1/snomed/{id}`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/snomed/{concept_id}?lang={es|en}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Returns fully specified names (FSN), active synonyms, direct hierarchy (parents and children), ICD-10 maps, and an enriched dental block if the concept relates to oral healthcare.'
                        : 'Devuelve nombres completamente especificados (FSN), sinónimos activos, jerarquía directa (padres e hijos), mapeos a CIE-10 y un bloque dental enriquecido automáticamente si el concepto corresponde a odontología.'
                    ?>
                </p>

                <h3>WHO ICD-10 (`/v1/cie10/{codigo}`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/cie10/{codigo}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Lookup any WHO ICD-10 code (e.g., K02.1 or K021) with bilingual English and Spanish descriptions and official SNOMED-CT cross-mappings.'
                        : 'Consulta cualquier código CIE-10 de la OMS (ej. K02.1 o K021) con descripciones oficiales bilingües en español e inglés y equivalencias cruzadas a SNOMED-CT.'
                    ?>
                </p>

                <h3 id="anmat">ANMAT Pharmaceutical Vademecum (`/v1/anmat/{id}`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/anmat/{id}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Query medications authorized by ANMAT Argentina, including certificate number, generic/commercial brand, pharmaceutical form, presentation, lab, and mapped SNOMED-CT concept ID.'
                        : 'Consulta especialidades medicinales autorizadas por ANMAT Argentina, incluyendo número de certificado, nombre genérico y comercial, forma farmacéutica, laboratorio y concepto SNOMED-CT vinculado.'
                    ?>
                </p>
            </section>

            <!-- 7. HL7 FHIR R4 -->
            <section id="fhir-intro" class="docs-section">
                <h2><?= $isEn ? '6. HL7® FHIR® R4 Terminology Services' : '6. Servicios de Terminología HL7® FHIR® R4' ?></h2>
                <p>
                    <?= $isEn
                        ? 'Origen Salud supports the official HL7 FHIR Release 4 standard for Terminology Servers, allowing seamless integration with EHR systems such as Epic, Cerner, GNU Health, and OpenEMR.'
                        : 'Origen Salud soporta el estándar oficial HL7 FHIR Release 4 para servidores de terminología, permitiendo la integración directa con sistemas de Historia Clínica Electrónica como Epic, Cerner, GNU Health y OpenEMR.'
                    ?>
                </p>

                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= $isEn ? 'Terminology' : 'Terminología' ?></th>
                            <th>Canonical URI (System)</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>SNOMED CT</strong></td>
                            <td><code>http://snomed.info/sct</code></td>
                        </tr>
                        <tr>
                            <td><strong>WHO ICD-10</strong></td>
                            <td><code>http://hl7.org/fhir/sid/icd-10</code></td>
                        </tr>
                        <tr>
                            <td><strong>DENTAR Procedures</strong></td>
                            <td><code>https://origen.ar/fhir/CodeSystem/dentar-procedures</code></td>
                        </tr>
                        <tr>
                            <td><strong>DENTAR Diagnoses</strong></td>
                            <td><code>https://origen.ar/fhir/CodeSystem/dentar-diagnoses</code></td>
                        </tr>
                        <tr>
                            <td><strong>ADA CDT 2025</strong></td>
                            <td><code>http://www.ada.org/cdt</code></td>
                        </tr>
                        <tr>
                            <td><strong>Argentine Dental Nomenclator</strong></td>
                            <td><code>https://origen.ar/fhir/CodeSystem/ar-nomenclador-odontologico</code></td>
                        </tr>
                        <tr>
                            <td><strong>LOINC</strong></td>
                            <td><code>http://loinc.org</code></td>
                        </tr>
                    </tbody>
                </table>

                <h3 id="fhir-lookup">FHIR CodeSystem `$lookup`</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/fhir/CodeSystem/$lookup?system={uri}&amp;code={codigo}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Inspects a code and returns human-readable designations, audit properties (e.g. tooth required, pre/post-op x-rays), and category groupings in a standard FHIR Parameters resource.'
                        : 'Inspecciona un código y devuelve designaciones legibles, propiedades de auditoría (pieza requerida, radiografías previas/posteriores) y agrupaciones categóricas en un recurso FHIR Parameters estándar.'
                    ?>
                </p>

                <h3 id="fhir-expand">FHIR ValueSet `$expand`</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/fhir/ValueSet/$expand?url={valueset_url}&amp;filter={query}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Expands a ValueSet for live clinical search, dropdowns, and autocomplete in the EHR UI.'
                        : 'Expande conjuntos de valores para búsqueda clínica en tiempo real, menús desplegables y autocompletado en la interfaz de la HCE.'
                    ?>
                </p>

                <h3 id="fhir-translate">FHIR ConceptMap `$translate`</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/fhir/ConceptMap/$translate?code={code}&amp;system={source}&amp;target={target}</code>
                </div>
                <p>
                    <?= $isEn
                        ? 'Translates codes across systems (e.g. Argentine Nomenclator to ADA CDT 2025, or Procedure to justifying ICD-10 Diagnoses).'
                        : 'Traduce códigos entre diferentes vocabularios (ej. Nomenclador Argentino a ADA CDT 2025, o Prestación a Diagnósticos CIE-10 que la justifican).'
                    ?>
                </p>

                <h3 id="fhir-resources"><?= $isEn ? 'Clinical Resource Modeling' : 'Modelado de Recursos Clínicos' ?></h3>
                <p>
                    <?= $isEn
                        ? 'Example representing a restorative dental intervention in an HL7 FHIR Procedure resource with tooth 36 (FDI system) in bodySite:'
                        : 'Ejemplo de representación de una intervención restauradora en un recurso HL7 FHIR Procedure con especificación de pieza dental 36 (sistema FDI) en bodySite:'
                    ?>
                </p>
                <div class="response-card">
                    <div class="response-head">
                        <span>FHIR R4 Procedure (Oral Health)</span>
                        <span>application/fhir+json</span>
                    </div>
                    <pre><code>{
  "resourceType": "Procedure",
  "id": "proc-dental-36",
  "status": "completed",
  "code": {
    "coding": [
      {
        "system": "https://origen.ar/fhir/CodeSystem/dentar-procedures",
        "code": "DNT-000007",
        "display": "Restauración con amalgama - cavidad simple"
      },
      {
        "system": "http://www.ada.org/cdt",
        "code": "D2140",
        "display": "Amalgam - one surface"
      },
      {
        "system": "https://origen.ar/fhir/CodeSystem/ar-nomenclador-odontologico",
        "code": "02.01"
      }
    ]
  },
  "subject": { "reference": "Patient/100234" },
  "reasonReference": [
    { "reference": "Condition/diag-caries-k021", "display": "Caries de la dentina (K02.1)" }
  ],
  "bodySite": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "245404008",
          "display": "Estructura del primer molar inferior izquierdo permanente (Pieza 36)"
        }
      ],
      "text": "Pieza 36 (FDI)"
    }
  ]
}</code></pre>
                </div>
            </section>
        </article>
    </div>
</main>

<footer class="site-footer">
    <div class="container footer-grid">
        <div class="footer-brand">
            <a class="brand" href="/" aria-label="Origen Salud">
                <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                    <rect width="40" height="40" rx="12" fill="currentColor"/>
                    <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
                </svg>
                <span class="brand-name">Origen<span>Salud</span></span>
            </a>
            <p><?= e($t('footer.tagline')) ?></p>
        </div>

        <div>
            <h3><?= e($t('footer.product')) ?></h3>
            <ul>
                <li><a href="/#api"><?= e($t('footer.product_api')) ?></a></li>
                <li><a href="/docs"><?= e($t('nav.docs')) ?></a></li>
                <li><a href="/#snomed"><?= e($t('footer.product_snomed')) ?></a></li>
                <li><a href="/#anmat"><?= e($t('footer.product_anmat')) ?></a></li>
            </ul>
        </div>

        <div>
            <h3><?= e($t('footer.company')) ?></h3>
            <ul>
                <li><a href="/#plataforma"><?= e($t('footer.company_about')) ?></a></li>
                <li><a href="<?= e($contactMailto) ?>"><?= e($t('footer.company_contact')) ?></a></li>
            </ul>
        </div>

        <div>
            <h3><?= e($t('footer.legal')) ?></h3>
            <ul>
                <li><a href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_terms')) ?></a></li>
                <li><a href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_privacy')) ?></a></li>
            </ul>
        </div>
    </div>

    <div class="container footer-bottom">
        <p><?= e($t('footer.rights', ['%year%' => $year])) ?></p>
        <p class="disclaimer"><?= e($t('footer.disclaimer')) ?></p>
    </div>
</footer>

<script>
    // Interactive Code Tabs and Language Synchronization
    document.addEventListener('DOMContentLoaded', () => {
        const containers = document.querySelectorAll('.code-container');

        // Global switch: clicking a language in one container switches all code blocks to that language
        const switchAllTabs = (targetLang) => {
            containers.forEach(container => {
                const buttons = container.querySelectorAll('.tab-btn');
                const panes = container.querySelectorAll('.code-pane');

                buttons.forEach(btn => {
                    if (btn.dataset.lang === targetLang) {
                        btn.classList.add('is-active');
                    } else {
                        btn.classList.remove('is-active');
                    }
                });

                panes.forEach(pane => {
                    if (pane.dataset.lang === targetLang) {
                        pane.classList.add('is-active');
                    } else {
                        pane.classList.remove('is-active');
                    }
                });
            });
        };

        containers.forEach(container => {
            const buttons = container.querySelectorAll('.tab-btn');
            const copyBtn = container.querySelector('.copy-btn');

            buttons.forEach(btn => {
                btn.addEventListener('click', () => {
                    const lang = btn.dataset.lang;
                    switchAllTabs(lang);
                });
            });

            if (copyBtn) {
                copyBtn.addEventListener('click', async () => {
                    const activePane = container.querySelector('.code-pane.is-active code');
                    if (!activePane) return;

                    try {
                        await navigator.clipboard.writeText(activePane.innerText);
                        const originalText = copyBtn.innerText;
                        copyBtn.innerText = '<?= $isEn ? 'Copied!' : '¡Copiado!' ?>';
                        setTimeout(() => {
                            copyBtn.innerText = originalText;
                        }, 2000);
                    } catch (err) {
                        console.error('Failed to copy', err);
                    }
                });
            }
        });

        // Sidebar active link highlighting on scroll
        const sections = document.querySelectorAll('.docs-section');
        const navLinks = document.querySelectorAll('.docs-sidebar a');

        window.addEventListener('scroll', () => {
            let currentId = '';
            sections.forEach(section => {
                const top = section.offsetTop - 120;
                if (window.scrollY >= top) {
                    currentId = section.getAttribute('id');
                }
            });

            navLinks.forEach(link => {
                if (link.getAttribute('href') === '#' + currentId) {
                    link.classList.add('is-active');
                } else {
                    link.classList.remove('is-active');
                }
            });
        }, { passive: true });
    });
</script>
</body>
</html>
