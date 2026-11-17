<?php

declare(strict_types=1);

/**
 * Origen Salud - Portal de Documentación para Desarrolladores (med.origen.ar/docs)
 *
 * Documentación interactiva de la API REST v1 y del servidor de terminología HL7 FHIR R4.
 * Admite visualización trilingüe (es-AR / EN / PT-BR) y ejemplos de código en 7 lenguajes de programación:
 * cURL, JavaScript, Python, PHP, C# (.NET), Java y Go.
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/portal/i18n/I18n.php';

use OrigenSalud\Web\I18n;

$locale = I18n::boot();

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language');
header('Content-Language: ' . $locale);
$t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);

$requestPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/docs'), PHP_URL_PATH);
$currentPath = is_string($requestPath) && $requestPath !== '' ? $requestPath : '/docs';

$baseUrl = rtrim((string) env('WEB_BASE_URL', 'https://med.origen.ar'), '/');
if ($baseUrl === '') {
    $baseUrl = 'https://med.origen.ar';
}

$contactEmail = 'contacto@origen.ar';
$accessMailto = 'mailto:' . $contactEmail . '?subject=' . rawurlencode($t('nav.access_api'));
$contactMailto = 'mailto:' . $contactEmail;
$legalMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal'));
$year = date('Y');

?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($t('docs.meta_title')) ?></title>
    <meta name="description" content="<?= e($t('docs.meta_description')) ?>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="<?= e($t('docs.meta_title')) ?>">
    <meta property="og:description" content="<?= e($t('docs.meta_description')) ?>">
    <meta property="og:locale" content="<?= e(I18n::metadata($locale)['og_locale']) ?>">
    <link rel="canonical" href="<?= e($baseUrl . '/docs') ?>">
    <?php foreach (I18n::alternateLinks($currentPath) as $alternate): ?>
    <link rel="alternate" hreflang="<?= e($alternate['hreflang']) ?>" href="<?= e($baseUrl . $alternate['href']) ?>">
    <?php endforeach; ?>
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
            <?php require dirname(__DIR__) . '/portal/Views/partials/language-switcher.php'; ?>
            <a class="button button-small" href="<?= e($accessMailto) ?>"><?= e($t('nav.access')) ?></a>
        </div>
    </div>
</header>

<main id="main">
    <div class="container docs-layout">
        <!-- Sidebar Navigation -->
        <aside class="docs-sidebar" aria-label="<?= e($t('docs.nav_index')) ?>">
            <div class="docs-nav-group">
                <h3><?= e($t('docs.nav_getting_started')) ?></h3>
                <ul>
                    <li><a href="#intro"><?= e($t('docs.nav_overview')) ?></a></li>
                    <li><a href="#auth"><?= e($t('docs.nav_auth')) ?></a></li>
                    <li><a href="#domains"><?= e($t('docs.nav_domains')) ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= e($t('docs.nav_catalog_engine')) ?></h3>
                <ul>
                    <li><a href="#catalogs"><?= e($t('docs.nav_catalogs')) ?></a></li>
                    <li><a href="#catalogs-items"><?= e($t('docs.nav_catalog_items')) ?></a></li>
                    <li><a href="#catalogs-mappings"><?= e($t('docs.nav_mappings')) ?></a></li>
                    <li><a href="#catalogs-pharma"><?= e($t('docs.nav_pharma')) ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= e($t('docs.nav_unified_search')) ?></h3>
                <ul>
                    <li><a href="#search"><?= e($t('docs.nav_search')) ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= e($t('docs.nav_dental')) ?></h3>
                <ul>
                    <li><a href="#dental-diagnoses"><?= e($t('docs.nav_dental_diagnoses')) ?></a></li>
                    <li><a href="#dental-justifications"><?= e($t('docs.nav_dental_justifications')) ?></a></li>
                    <li><a href="#dental-snomed"><?= e($t('docs.nav_dental_snomed')) ?></a></li>
                    <li><a href="#dental-procedure"><?= e($t('docs.nav_dental_cdt')) ?></a></li>
                    <li><a href="#cdt-nn"><?= e($t('docs.nav_cdt_nn')) ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= e($t('docs.nav_clinical_catalogs')) ?></h3>
                <ul>
                    <li><a href="#snomed"><?= e($t('docs.nav_snomed')) ?></a></li>
                    <li><a href="#cie10"><?= e($t('docs.nav_cie10')) ?></a></li>
                    <li><a href="#anmat"><?= e($t('docs.nav_anmat')) ?></a></li>
                    <li><a href="#loinc"><?= e($t('docs.nav_loinc')) ?></a></li>
                    <li><a href="#local-catalogs"><?= e($t('docs.nav_local_catalogs')) ?></a></li>
                </ul>
            </div>

            <div class="docs-nav-group">
                <h3><?= e($t('docs.nav_fhir')) ?></h3>
                <ul>
                    <li><a href="#fhir-intro"><?= e($t('docs.nav_fhir_intro')) ?></a></li>
                    <li><a href="#fhir-lookup"><?= e($t('docs.nav_fhir_lookup')) ?></a></li>
                    <li><a href="#fhir-expand"><?= e($t('docs.nav_fhir_expand')) ?></a></li>
                    <li><a href="#fhir-translate"><?= e($t('docs.nav_fhir_translate')) ?></a></li>
                    <li><a href="#fhir-resources"><?= e($t('docs.nav_fhir_resources')) ?></a></li>
                </ul>
            </div>
        </aside>

        <!-- Documentation Content -->
        <article class="docs-content">
            <div class="docs-header">
                <h1><?= e($t('docs.header_title')) ?></h1>
                <p class="lead">
                    <?= e($t('docs.header_lead'))
                    ?>
                </p>
            </div>

            <!-- 1. GENERAL & AUTH -->
            <section id="intro" class="docs-section">
                <h2><?= e($t('docs.overview_title')) ?></h2>
                <p>
                    <?= e($t('docs.overview_text'))
                    ?>
                </p>
                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= e($t('docs.table_environment')) ?></th>
                            <th>URL</th>
                            <th><?= e($t('docs.table_description')) ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>Production REST</strong></td>
                            <td><code>https://api.origen.ar/v1</code></td>
                            <td><?= e($t('docs.env_rest')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>HL7 FHIR R4</strong></td>
                            <td><code>https://api.origen.ar/fhir</code></td>
                            <td><?= e($t('docs.env_fhir')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Health Check</strong></td>
                            <td><code>https://api.origen.ar/health</code></td>
                            <td><?= e($t('docs.env_health')) ?></td>
                        </tr>
                    </tbody>
                </table>
            </section>

            <section id="auth" class="docs-section">
                <h2><?= e($t('docs.auth_title')) ?></h2>
                <p>
                    <?= e($t('docs.auth_text'))
                    ?>
                </p>
                <div class="endpoint-badge">
                    <span class="method-get">HEADER</span>
                    <code>Authorization: Bearer orig_live_xxxxxxxxxxxxxxxxxxxx</code>
                </div>

                <div class="alert-box">
                    <p>
                        <strong><?= e($t('docs.auth_important')) ?></strong>
                        <?= e($t('docs.auth_warning'))
                        ?>
                    </p>
                </div>
            </section>

            <!-- CATALOG ENGINE -->
            <section id="catalogs" class="docs-section">
                <h2><?= e($t('docs.catalogs_title')) ?></h2>
                <p>
                    <?= e($t('docs.catalogs_text'))
                    ?>
                </p>

                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= e($t('docs.table_scope')) ?></th>
                            <th><?= e($t('docs.table_catalog_code')) ?></th>
                            <th><?= e($t('docs.table_description')) ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong style="color:var(--teal-dark)">Propio</strong></td>
                            <td><code>dentar</code></td>
                            <td><?= e($t('docs.catalog_dentar')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>nn-pmo</code></td>
                            <td><?= e($t('docs.catalog_pmo')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>nbu</code></td>
                            <td><?= e($t('docs.catalog_nbu')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>nhpgd</code></td>
                            <td><?= e($t('docs.catalog_hospitales')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>andis</code></td>
                            <td><?= e($t('docs.catalog_discapacidad')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>kinesiologia</code></td>
                            <td><?= e($t('docs.catalog_fisioterapia')) ?></td>
                        </tr>
                        <tr>
                            <td><strong>Argentina</strong></td>
                            <td><code>salud-mental</code></td>
                            <td><?= e($t('docs.catalog_psicologia')) ?></td>
                        </tr>
                    </tbody>
                </table>

                <h3 id="catalogs-items"><?= e($t('docs.catalog_items_title')) ?></h3>
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
                        <button class="copy-btn"><?= e($t('docs.copy')) ?></button>
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

                <h3 id="catalogs-mappings"><?= e($t('docs.mappings_title')) ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/mappings?system={system}&amp;code={code}</code>
                </div>
                <p>
                    <?= e($t('docs.mappings_text'))
                    ?>
                </p>

                <h3 id="catalogs-pharma"><?= e($t('docs.pharma_title')) ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/medicines/identifiers/{system}/{code}</code>
                </div>
                <p>
                    <?= e($t('docs.pharma_text'))
                    ?>
                </p>
            </section>

            <!-- 2. UNIFIED SEARCH -->
            <section id="search" class="docs-section">
                <h2><?= e($t('docs.search_title')) ?></h2>
                <p><?= e($t('docs.search_text')) ?></p>

                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/search?q={query}&amp;domains={d1,d2}&amp;lang={es-AR|en|pt-BR}&amp;limit={n}</code>
                </div>

                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= e($t('docs.table_parameter')) ?></th>
                            <th><?= e($t('docs.table_type')) ?></th>
                            <th><?= e($t('docs.table_default')) ?></th>
                            <th><?= e($t('docs.table_description')) ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><code>q</code></td>
                            <td>string</td>
                            <td><em><?= e($t('docs.table_required')) ?></em></td>
                            <td><?= e($t('docs.search_q')) ?></td>
                        </tr>
                        <tr>
                            <td><code>domains</code></td>
                            <td>string</td>
                            <td><code>snomed,cie10,odontologia</code></td>
                            <td><?= e($t('docs.search_domains')) ?></td>
                        </tr>
                        <tr>
                            <td><code>limit</code></td>
                            <td>integer</td>
                            <td><code>20</code></td>
                            <td><?= e($t('docs.search_limit')) ?></td>
                        </tr>
                        <tr>
                            <td><code>lang</code></td>
                            <td>string</td>
                            <td><code>es-AR</code></td>
                            <td><?= e($t('docs.search_lang')) ?></td>
                        </tr>
                        <tr>
                            <td><code>Accept-Language</code></td>
                            <td>header</td>
                            <td><code>es-AR</code></td>
                            <td><?= e($t('docs.search_accept_language')) ?></td>
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
                        <button class="copy-btn"><?= e($t('docs.copy')) ?></button>
                    </div>

                    <!-- cURL -->
                    <pre class="code-pane is-active" data-lang="curl"><code>curl -s -X GET "https://api.origen.ar/v1/search?q=caries&amp;domains=odontologia,snomed,cie10&amp;lang=<?= e(I18n::metadata($locale)['api_language']) ?>&amp;limit=5" \
  -H "Authorization: Bearer TU_API_KEY" \
  -H "Accept: application/json" \
  -H "Accept-Language: <?= e(I18n::metadata($locale)['api_language']) ?>"</code></pre>

                    <!-- JavaScript -->
                    <pre class="code-pane" data-lang="js"><code>const apiKey = 'TU_API_KEY';
const language = '<?= e(I18n::metadata($locale)['api_language']) ?>';
const url = 'https://api.origen.ar/v1/search?q=caries&amp;domains=odontologia,snomed,cie10&amp;lang=' + language + '&amp;limit=5';

const response = await fetch(url, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'Accept': 'application/json',
    'Accept-Language': language
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
                <h2><?= e($t('docs.dental_title')) ?></h2>
                <p>
                    <?= e($t('docs.dental_text'))
                    ?>
                </p>

                <h3><?= e($t('docs.dental_diagnoses_title')) ?></h3>
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
                        <button class="copy-btn"><?= e($t('docs.copy')) ?></button>
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
                <h3><?= e($t('docs.dental_justification_title')) ?></h3>
                <p>
                    <?= e($t('docs.dental_justification_text'))
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
                        <button class="copy-btn"><?= e($t('docs.copy')) ?></button>
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
                <h3><?= e($t('docs.dental_snomed_title')) ?></h3>
                <p>
                    <?= e($t('docs.dental_snomed_text'))
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
                        <button class="copy-btn"><?= e($t('docs.copy')) ?></button>
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

            <!-- CDT / NN: exposición real -->
            <section id="cdt-nn" class="docs-section">
                <h2><?= e($t('cdtnn.title')) ?></h2>
                <p><?= e($t('cdtnn.intro')) ?></p>

                <h3><?= e($t('cdtnn.cdt_title')) ?></h3>
                <p><?= e($t('cdtnn.cdt_text')) ?></p>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/search/odontologia?q={query}&amp;lang={locale}</code>
                </div>
                <div class="endpoint-badge" style="margin-top: 6px;">
                    <span class="method-get">GET</span>
                    <code>/v1/odontologia/{id}</code>
                </div>
                <div class="alert-box">
                    <p><strong><?= e($t('cdtnn.no_cdt_endpoint')) ?></strong>
                        <?= e($t('cdtnn.cdt_dialect')) ?></p>
                </div>

                <h3><?= e($t('cdtnn.nn_title')) ?></h3>
                <p><?= e($t('cdtnn.nn_text')) ?></p>

                <h3><?= e($t('cdtnn.nomenclador_title')) ?></h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/nomenclador</code>
                </div>
                <p><?= e($t('cdtnn.nomenclador_text')) ?></p>
            </section>

            <!-- 6. CLINICAL CATALOGS -->
            <section id="snomed" class="docs-section">
                <h2><?= e($t('docs.clinical_title')) ?></h2>

                <h3>SNOMED-CT Concept Detail (`/v1/snomed/{id}`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/snomed/{concept_id}?lang={es|en}</code>
                </div>
                <p>
                    <?= e($t('docs.snomed_text'))
                    ?>
                </p>

                <h3>WHO ICD-10 (`/v1/cie10/{codigo}`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/cie10/{codigo}</code>
                </div>
                <p>
                    <?= e($t('docs.cie10_text'))
                    ?>
                </p>

                <h3 id="anmat">ANMAT Pharmaceutical Vademecum (`/v1/anmat/{id}`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/anmat/{id}</code>
                </div>
                <p>
                    <?= e($t('docs.anmat_text'))
                    ?>
                </p>

                <h3 id="loinc">LOINC Laboratory & Clinical Observations (`/v1/loinc`)</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/v1/loinc?q={query}&amp;class={class}&amp;status={status}&amp;limit={n}</code>
                </div>
                <div class="endpoint-badge" style="margin-top: 6px;">
                    <span class="method-get">GET</span>
                    <code>/v1/loinc/{code}</code>
                </div>
                <p>
                    <?= e($t('docs.loinc_text'))
                    ?>
                </p>
                <div class="code-tabs">
                    <div class="code-tab-nav">
                        <button class="tab-btn active" data-lang="curl">cURL</button>
                        <button class="tab-btn" data-lang="js">JavaScript</button>
                        <button class="tab-btn" data-lang="py">Python</button>
                        <button class="tab-btn" data-lang="php">PHP</button>
                        <button class="tab-btn" data-lang="cs">C#</button>
                        <button class="tab-btn" data-lang="java">Java</button>
                        <button class="tab-btn" data-lang="go">Go</button>
                    </div>
                    <pre class="code-pane active" data-lang="curl"><code>curl -s -X GET "https://api.origen.ar/v1/loinc?q=hemograma" \
  -H "Authorization: Bearer &lt;API_KEY&gt;"</code></pre>
                    <pre class="code-pane" data-lang="js"><code>const res = await fetch('https://api.origen.ar/v1/loinc?q=hemograma', {
  headers: { 'Authorization': 'Bearer &lt;API_KEY&gt;' }
});
const data = await res.json();
console.log(data);</code></pre>
                    <pre class="code-pane" data-lang="py"><code>import requests

r = requests.get(
    "https://api.origen.ar/v1/loinc",
    params={"q": "hemograma"},
    headers={"Authorization": "Bearer &lt;API_KEY&gt;"}
)
print(r.json())</code></pre>
                    <pre class="code-pane" data-lang="php"><code>$ch = curl_init('https://api.origen.ar/v1/loinc?q=hemograma');
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer &lt;API_KEY&gt;']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$res = json_decode(curl_exec($ch), true);
curl_close($ch);
print_r($res);</code></pre>
                    <pre class="code-pane" data-lang="cs"><code>using var client = new HttpClient();
client.DefaultRequestHeaders.Add("Authorization", "Bearer &lt;API_KEY&gt;");
var json = await client.GetStringAsync("https://api.origen.ar/v1/loinc?q=hemograma");
Console.WriteLine(json);</code></pre>
                    <pre class="code-pane" data-lang="java"><code>var client = HttpClient.newHttpClient();
var req = HttpRequest.newBuilder()
    .uri(URI.create("https://api.origen.ar/v1/loinc?q=hemograma"))
    .header("Authorization", "Bearer &lt;API_KEY&gt;")
    .GET().build();
var res = client.send(req, HttpResponse.BodyHandlers.ofString());
System.out.println(res.body());</code></pre>
                    <pre class="code-pane" data-lang="go"><code>req, _ := http.NewRequest("GET", "https://api.origen.ar/v1/loinc?q=hemograma", nil)
req.Header.Set("Authorization", "Bearer &lt;API_KEY&gt;")
res, _ := http.DefaultClient.Do(req)
body, _ := io.ReadAll(res.Body)
fmt.Println(string(body))</code></pre>
                </div>
            </section>

            <!-- 7. HL7 FHIR R4 -->
            <section id="fhir-intro" class="docs-section">
                <h2><?= e($t('docs.fhir_title')) ?></h2>
                <p>
                    <?= e($t('docs.fhir_text'))
                    ?>
                </p>

                <table class="param-table">
                    <thead>
                        <tr>
                            <th><?= e($t('docs.table_terminology')) ?></th>
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
                    <?= e($t('docs.fhir_lookup_text'))
                    ?>
                </p>

                <h3 id="fhir-expand">FHIR ValueSet `$expand`</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/fhir/ValueSet/$expand?url={valueset_url}&amp;filter={query}</code>
                </div>
                <p>
                    <?= e($t('docs.fhir_expand_text'))
                    ?>
                </p>

                <h3 id="fhir-translate">FHIR ConceptMap `$translate`</h3>
                <div class="endpoint-badge">
                    <span class="method-get">GET</span>
                    <code>/fhir/ConceptMap/$translate?code={code}&amp;system={source}&amp;target={target}</code>
                </div>
                <p>
                    <?= e($t('docs.fhir_translate_text'))
                    ?>
                </p>

                <h3 id="fhir-resources"><?= e($t('docs.fhir_resources_title')) ?></h3>
                <p>
                    <?= e($t('docs.fhir_resources_text'))
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
        "code": "DNT-PR-000007",
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
                        copyBtn.innerText = <?= json_encode($t('docs.copied'), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?>;
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
