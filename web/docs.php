<?php

declare(strict_types=1);

/**
 * Origen Salud - Centro de documentación para desarrolladores (med.origen.ar/docs).
 *
 * Página independiente, trilingüe y de solo lectura. El contenido describe
 * exclusivamente el contrato real de la API pública v1 (api.origen.ar).
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/portal/i18n/I18n.php';

use OrigenSalud\Web\I18n;

$locale = I18n::boot();

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language, Cookie');
header('Content-Language: ' . $locale);

$t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
$esc = static fn (string $value): string => e($value);
$raw = static fn (string $value): string => htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

$baseUrl = rtrim((string) env('WEB_BASE_URL', 'https://med.origen.ar'), '/');
if ($baseUrl === '') {
    $baseUrl = 'https://med.origen.ar';
}

$apiBase = 'https://api.origen.ar';
$canonical = $baseUrl . '/docs?lang=' . rawurlencode($locale);
$metadata = I18n::metadata($locale);
$year = date('Y');

$alternates = [];
foreach (I18n::SUPPORTED as $supported) {
    $info = I18n::metadata($supported);
    $alternates[] = [
        'hreflang' => $info['hreflang'],
        'href' => $baseUrl . '/docs?lang=' . rawurlencode($supported),
        'short' => $info['short'],
        'label' => $t('docs.lang.' . ($supported === 'es-AR' ? 'es' : ($supported === 'pt-BR' ? 'pt' : 'en'))),
        'active' => $supported === $locale,
    ];
}

$homePath = I18n::localizedPath($locale, '/');
$contactPath = I18n::localizedPath($locale, '/contact');
$accessMailto = 'mailto:contacto@origen.ar?subject=' . rawurlencode($t('nav.access_api'));
$contactMailto = 'mailto:contacto@origen.ar';
$legalMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal'));
$privacyMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal_privacy'));

$articles = [
    ['id' => 'overview', 'key' => 'overview', 'group' => 'start'],
    ['id' => 'auth', 'key' => 'auth', 'group' => 'start'],
    ['id' => 'conventions', 'key' => 'conventions', 'group' => 'start'],
    ['id' => 'quickstart', 'key' => 'quickstart', 'group' => 'start'],
    ['id' => 'search', 'key' => 'search', 'group' => 'core'],
    ['id' => 'catalogs', 'key' => 'catalogs', 'group' => 'core'],
    ['id' => 'mappings', 'key' => 'mappings', 'group' => 'core'],
    ['id' => 'clinical', 'key' => 'clinical', 'group' => 'domain'],
    ['id' => 'dental', 'key' => 'dental', 'group' => 'domain'],
    ['id' => 'pending', 'key' => 'pending', 'group' => 'operations'],
    ['id' => 'openapi', 'key' => 'openapi', 'group' => 'operations'],
    ['id' => 'support', 'key' => 'support', 'group' => 'operations'],
];

$articleIndex = [];
foreach ($articles as $index => $article) {
    $articleIndex[$article['id']] = $index;
}

$grouped = [];
foreach ($articles as $article) {
    $grouped[$article['group']][] = $article;
}

/**
 * @param list<array{name:string,type:string,default:string,required:string,text:string}> $rows
 */
$renderParams = static function (array $rows) use ($t, $esc): void {
    ?>
    <div class="table-wrap">
        <table class="param-table">
            <thead>
                <tr>
                    <th scope="col"><?= $esc($t('search.params_title')) ?></th>
                    <th scope="col"><?= $esc($t('common.default')) ?></th>
                    <th scope="col"><?= $esc($t('common.required')) ?></th>
                    <th scope="col"><?= $esc($t('search.domains_title')) ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($rows as $row): ?>
                    <tr>
                        <td><code><?= $esc($row['name']) ?></code></td>
                        <td><?= $esc($row['default']) ?></td>
                        <td><?= $esc($row['required']) ?></td>
                        <td><?= $esc($row['text']) ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php
};

$renderEndpoint = static function (string $path, string $access = 'authenticated') use ($apiBase, $t, $esc): void {
    $label = $access === 'public' ? $t('common.public') : $t('common.authenticated');
    $tone = $access === 'public' ? 'ok' : 'key';
    ?>
    <div class="endpoint">
        <span class="method method--get"><?= $esc($t('common.method_get')) ?></span>
        <code class="endpoint__path"><?= $esc($path) ?></code>
        <span class="badge badge--<?= $tone ?>"><?= $esc($label) ?></span>
        <button type="button" class="copy-endpoint" data-endpoint="<?= $esc($apiBase . $path) ?>"
                aria-label="<?= $esc($t('docs.a11y.copy_endpoint')) ?>"><?= $esc($t('docs.a11y.copy_endpoint')) ?></button>
    </div>
    <?php
};

$renderSubhead = static function (string $id, string $label): void {
    echo '<h3 id="' . e($id) . '">' . e($label) . '</h3>';
};

$renderCallout = static function (string $tone, string $title, string $text) use ($esc): void {
    ?>
    <div class="callout callout--<?= $esc($tone) ?>">
        <strong><?= $esc($title) ?></strong>
        <p><?= $esc($text) ?></p>
    </div>
    <?php
};

/**
 * @param array<string, string> $snippets
 */
$renderCode = static function (string $id, array $snippets) use ($t, $esc, $raw): void {
    $labels = [
        'curl' => $t('code.curl'),
        'php' => $t('code.php'),
        'python' => $t('code.python'),
        'java' => $t('code.java'),
        'javascript' => $t('code.javascript'),
        'csharp' => $t('code.csharp'),
    ];
    ?>
    <div class="code-container" data-code-block="<?= $esc($id) ?>">
        <div class="code-toolbar">
            <div class="code-tabs" role="tablist" aria-label="<?= $esc($t('docs.a11y.code_language')) ?>">
                <?php foreach ($snippets as $lang => $_): ?>
                    <button type="button" class="code-tab" role="tab" data-code-lang="<?= $esc($lang) ?>"
                            aria-selected="false" tabindex="-1"><?= $esc($labels[$lang] ?? $lang) ?></button>
                <?php endforeach; ?>
            </div>
            <button type="button" class="copy-code" data-copy-code><?= $esc($t('docs.a11y.copy')) ?></button>
        </div>
        <?php foreach ($snippets as $lang => $code): ?>
            <pre class="code-pane" data-code-pane="<?= $esc($lang) ?>" role="tabpanel" hidden><code><?= $raw($code) ?></code></pre>
        <?php endforeach; ?>
    </div>
    <?php
};

$renderResponse = static function (string $title, string $json, string $note = '') use ($esc): void {
    ?>
    <figure class="response-card">
        <figcaption class="response-head">
            <span><?= $esc($title) ?></span>
            <span class="badge badge--get">200</span>
        </figcaption>
        <pre><code><?= $esc($json) ?></code></pre>
        <?php if ($note !== ''): ?>
            <p class="response-note"><?= $esc($note) ?></p>
        <?php endif; ?>
    </figure>
    <?php
};

$renderArticleNav = static function (string $id) use ($articles, $articleIndex, $t, $esc): void {
    $index = $articleIndex[$id];
    $prev = $articles[$index - 1] ?? null;
    $next = $articles[$index + 1] ?? null;
    ?>
    <nav class="article-nav" aria-label="<?= $esc($t('docs.a11y.next')) ?>">
        <?php if ($prev !== null): ?>
            <a class="article-nav__link article-nav__link--prev" href="#<?= $esc($prev['id']) ?>">
                <span><?= $esc($t('docs.a11y.previous')) ?></span>
                <strong><?= $esc($t('docs.article.' . $prev['key'] . '.title')) ?></strong>
            </a>
        <?php else: ?>
            <span></span>
        <?php endif; ?>
        <?php if ($next !== null): ?>
            <a class="article-nav__link article-nav__link--next" href="#<?= $esc($next['id']) ?>">
                <span><?= $esc($t('docs.a11y.next')) ?></span>
                <strong><?= $esc($t('docs.article.' . $next['key'] . '.title')) ?></strong>
            </a>
        <?php endif; ?>
    </nav>
    <?php
};

$quickstartSnippets = [
    'curl' => <<<'CODE'
curl --get "https://api.origen.ar/v1/catalogs/dentar-pr/items" \
  --data-urlencode "q=evaluacion" \
  --data-urlencode "limit=5" \
  -H "Accept: application/json" \
  -H "X-API-Key: TU_API_KEY"
CODE,
    'php' => <<<'CODE'
<?php

$url = 'https://api.origen.ar/v1/catalogs/dentar-pr/items?' . http_build_query([
    'q' => 'evaluacion',
    'limit' => 5,
]);

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        'Accept: application/json',
        'X-API-Key: TU_API_KEY',
    ],
]);

$body = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
curl_close($ch);

if ($body === false || $status !== 200) {
    throw new RuntimeException('La API no devolvió 200.');
}

$payload = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
CODE,
    'python' => <<<'CODE'
import json
import urllib.parse
import urllib.request

params = urllib.parse.urlencode({"q": "evaluacion", "limit": 5})
url = f"https://api.origen.ar/v1/catalogs/dentar-pr/items?{params}"

request = urllib.request.Request(
    url,
    headers={
        "Accept": "application/json",
        "X-API-Key": "TU_API_KEY",
    },
)

with urllib.request.urlopen(request, timeout=10) as response:
    payload = json.load(response)

print(payload["data"][0]["term"])
CODE,
    'java' => <<<'CODE'
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;

public final class ApiExample {
    public static void main(String[] args) throws Exception {
        String query = "q=" + URLEncoder.encode("evaluacion", StandardCharsets.UTF_8)
                + "&limit=5";

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://api.origen.ar/v1/catalogs/dentar-pr/items?" + query))
                .header("Accept", "application/json")
                .header("X-API-Key", "TU_API_KEY")
                .GET()
                .build();

        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new IllegalStateException("HTTP " + response.statusCode());
        }

        System.out.println(response.body());
    }
}
CODE,
    'javascript' => <<<'CODE'
async function main() {
  const url = new URL('https://api.origen.ar/v1/catalogs/dentar-pr/items');
  url.searchParams.set('q', 'evaluacion');
  url.searchParams.set('limit', '5');

  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'X-API-Key': 'TU_API_KEY',
    },
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const payload = await response.json();
  console.log(payload.data[0].term);
}

main().catch((error) => console.error(error));
CODE,
    'csharp' => <<<'CODE'
using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;

internal static class ApiExample
{
    private static async Task Main()
    {
        using var client = new HttpClient();
        client.DefaultRequestHeaders.Add("X-API-Key", "TU_API_KEY");
        client.DefaultRequestHeaders.Accept.Add(
            new MediaTypeWithQualityHeaderValue("application/json"));

        var response = await client.GetAsync(
            "https://api.origen.ar/v1/catalogs/dentar-pr/items?q=evaluacion&limit=5");
        response.EnsureSuccessStatusCode();

        using var stream = await response.Content.ReadAsStreamAsync();
        using var payload = await JsonDocument.ParseAsync(stream);
        Console.WriteLine(payload.RootElement.GetProperty("data")[0]
            .GetProperty("term").GetString());
    }
}
CODE,
];

$searchCurl = <<<'CODE'
curl --get "https://api.origen.ar/v1/search" \
  --data-urlencode "q=infarto" \
  --data-urlencode "domains=snomed,cie10" \
  --data-urlencode "lang=es-AR" \
  --data-urlencode "limit=10" \
  -H "X-API-Key: TU_API_KEY"
CODE;

$mappingsCurl = <<<'CODE'
curl --get "https://api.origen.ar/v1/mappings" \
  --data-urlencode "system=SNOMED-CT" \
  --data-urlencode "code=22298006" \
  --data-urlencode "catalog=dentar-pr" \
  -H "X-API-Key: TU_API_KEY"
CODE;

$dentalCurl = <<<'CODE'
curl --get "https://api.origen.ar/v1/odontologia/diagnosticos/K02.1" \
  -H "Accept: application/json" \
  -H "X-API-Key: TU_API_KEY"
CODE;

$healthResponse = <<<'JSON'
{
  "status": "ok",
  "service": "origen-salud-api",
  "version": "1.0.0",
  "time": "2026-11-19T12:34:56+00:00",
  "checks": {
    "database": "ok"
  }
}
JSON;

$successResponse = <<<'JSON'
{
  "data": [],
  "meta": {
    "took_ms": 3.42
  },
  "request_id": "a1b2c3d4e5f60718293a4b5c6d7e8f90"
}
JSON;

$errorResponse = <<<'JSON'
{
  "error": {
    "code": "bad_request",
    "message": "El parámetro q es obligatorio.",
    "details": {
      "q": "Enviá un término de búsqueda de entre 2 y 80 caracteres."
    }
  },
  "request_id": "a1b2c3d4e5f60718293a4b5c6d7e8f90"
}
JSON;

$quickstartResponse = <<<'JSON'
{
  "data": [
    {
      "permanent_code": "DNT-PR-000001",
      "official_code": "01.01",
      "term": "Evaluación oral integral",
      "category": "Evaluación",
      "pricing": {
        "unit_type": "UB",
        "units": 3.8,
        "fixed_price": null
      }
    }
  ],
  "meta": {
    "requested_language": "es-AR",
    "effective_language": "es",
    "source_language": "es",
    "fallback_applied": true,
    "dialect_determined": false,
    "took_ms": 4.12
  },
  "request_id": "a1b2c3d4e5f60718293a4b5c6d7e8f90"
}
JSON;

$searchResponse = <<<'JSON'
{
  "data": [
    {
      "domain": "snomed",
      "source": "snomed",
      "id": "22298006",
      "code": "22298006",
      "term": "Infarto del miocardio",
      "subtitle": null,
      "language": "es",
      "kind": "synonym",
      "score": 0.95,
      "metadata": {
        "description_id": "…",
        "concept_id": "22298006",
        "term_type": "synonym"
      }
    }
  ],
  "meta": {
    "query": "infarto",
    "language": "es",
    "domains": ["snomed", "cie10"],
    "limit": 10,
    "offset": 0,
    "returned": 1,
    "has_more": false,
    "next_offset": null,
    "page_counts": { "snomed": 1, "cie10": 0 },
    "took_ms": 5.31
  },
  "request_id": "a1b2c3d4e5f60718293a4b5c6d7e8f90"
}
JSON;
?>
<!doctype html>
<html lang="<?= $esc($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= $esc($t('docs.meta.title')) ?></title>
    <meta name="description" content="<?= $esc($t('docs.meta.description')) ?>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="<?= $esc($t('docs.meta.title')) ?>">
    <meta property="og:description" content="<?= $esc($t('docs.meta.description')) ?>">
    <meta property="og:locale" content="<?= $esc($metadata['og_locale']) ?>">
    <meta property="og:url" content="<?= $esc($canonical) ?>">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="<?= $esc($t('docs.meta.title')) ?>">
    <meta name="twitter:description" content="<?= $esc($t('docs.meta.description')) ?>">
    <link rel="canonical" href="<?= $esc($canonical) ?>">
    <?php foreach ($alternates as $alternate): ?>
        <link rel="alternate" hreflang="<?= $esc($alternate['hreflang']) ?>" href="<?= $esc($alternate['href']) ?>">
    <?php endforeach; ?>
    <link rel="stylesheet" href="assets/css/app.css?v=docs-v2">
    <style>
        .docs-shell { display: grid; grid-template-columns: 248px minmax(0, 1fr) 190px; gap: 32px; align-items: start; padding: 32px 0 72px; }
        .docs-sidebar, .docs-toc { position: sticky; top: 20px; max-height: calc(100vh - 40px); overflow-y: auto; }
        .docs-sidebar { padding: 18px; border: 1px solid var(--line); border-radius: var(--radius); background: var(--paper); }
        .docs-sidebar__title { margin: 0 0 12px; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
        .docs-search { position: relative; margin-bottom: 16px; }
        .docs-search input { width: 100%; padding: 9px 34px 9px 12px; border: 1px solid var(--line); border-radius: 8px; background: var(--white); color: var(--ink); font: inherit; font-size: .88rem; }
        .docs-search__clear { position: absolute; right: 6px; top: 50%; transform: translateY(-50%); border: 0; background: transparent; color: var(--muted); cursor: pointer; padding: 4px 6px; font-size: 1rem; }
        .docs-search__empty { display: none; margin: 8px 2px; font-size: .82rem; color: var(--muted); }
        .docs-nav-group { margin-bottom: 18px; }
        .docs-nav-group h3 { margin: 0 0 6px; font-size: .72rem; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
        .docs-nav-group ul { list-style: none; padding: 0; margin: 0; }
        .docs-nav-group a { display: block; padding: 6px 9px; border-radius: 6px; color: var(--ink-soft); font-size: .88rem; line-height: 1.35; text-decoration: none; }
        .docs-nav-group a:hover, .docs-nav-group a.is-active { background: var(--white); color: var(--teal-dark); box-shadow: var(--shadow-sm); }
        .docs-main { min-width: 0; }
        .docs-intro { margin-bottom: 28px; padding-bottom: 22px; border-bottom: 1px solid var(--line); }
        .docs-intro__badge { display: inline-block; margin-bottom: 10px; padding: 4px 10px; border-radius: 999px; background: var(--mint); color: var(--teal-dark); font-size: .75rem; font-weight: 700; letter-spacing: .04em; }
        .docs-intro h1 { margin: 0 0 10px; font-size: clamp(1.8rem, 4vw, 2.6rem); line-height: 1.1; color: var(--ink); }
        .docs-intro p { margin: 0; max-width: 76ch; color: var(--ink-soft); font-size: 1.05rem; }
        .breadcrumb ol { display: flex; flex-wrap: wrap; gap: 6px; list-style: none; padding: 0; margin: 0 0 18px; font-size: .82rem; color: var(--muted); }
        .breadcrumb li + li::before { content: "/"; margin-right: 6px; color: var(--line); }
        .breadcrumb a { color: var(--teal-dark); }
        .breadcrumb [aria-current="page"] { color: var(--ink); font-weight: 600; }
        .docs-toc { padding: 16px; border-left: 2px solid var(--mint); font-size: .84rem; }
        .docs-toc h2 { margin: 0 0 8px; font-size: .72rem; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
        .docs-toc ol { list-style: none; padding: 0; margin: 0; }
        .docs-toc a { display: block; padding: 4px 0; color: var(--ink-soft); text-decoration: none; }
        .docs-toc a:hover, .docs-toc a.is-active { color: var(--teal-dark); font-weight: 600; }
        .docs-section { margin-bottom: 56px; scroll-margin-top: 24px; }
        .docs-section > h2 { margin: 0 0 10px; padding-bottom: 8px; border-bottom: 2px solid var(--mint); font-size: 1.6rem; color: var(--ink); }
        .docs-section > p.lead { margin: 0 0 22px; color: var(--ink-soft); font-size: 1.02rem; }
        .docs-section h3 { margin: 30px 0 10px; scroll-margin-top: 24px; font-size: 1.2rem; color: var(--ink); }
        .docs-section p { color: var(--ink-soft); }
        .table-wrap { width: 100%; overflow-x: auto; margin: 14px 0 22px; }
        .param-table { width: 100%; min-width: 620px; border-collapse: collapse; font-size: .9rem; }
        .param-table th, .param-table td { padding: 9px 12px; text-align: left; border-bottom: 1px solid var(--line); vertical-align: top; }
        .param-table th { background: var(--paper); color: var(--ink); font-weight: 700; }
        .param-table code, .endpoint__path { font-family: var(--font-mono); }
        .param-table code { padding: 2px 5px; border-radius: 4px; background: var(--mint); color: var(--teal-dark); font-size: .85em; }
        .endpoint { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 12px 0 20px; padding: 10px 12px; border-radius: 10px; background: #061522; color: #d7f1f7; }
        .endpoint__path { flex: 1 1 320px; min-width: 0; overflow-wrap: anywhere; font-size: .88rem; }
        .method { padding: 3px 8px; border-radius: 5px; background: #0c7c86; color: #fff; font-size: .72rem; font-weight: 800; letter-spacing: .04em; }
        .badge { padding: 3px 8px; border-radius: 999px; font-size: .7rem; font-weight: 700; white-space: nowrap; }
        .badge--key { background: rgba(255, 196, 0, .16); color: #ffd97a; }
        .badge--ok { background: rgba(52, 211, 153, .18); color: #8ef0c4; }
        .badge--get { background: var(--mint); color: var(--teal-dark); }
        .badge--pending { background: #fff2d9; color: #8a5a00; }
        .copy-endpoint, .copy-code { border: 1px solid rgba(255, 255, 255, .2); border-radius: 6px; background: rgba(255, 255, 255, .08); color: inherit; padding: 5px 9px; cursor: pointer; font: inherit; font-size: .74rem; }
        .copy-endpoint:hover, .copy-code:hover { background: rgba(255, 255, 255, .16); }
        .callout { margin: 18px 0; padding: 14px 16px; border-left: 4px solid var(--teal); border-radius: 10px; background: var(--mint); }
        .callout p { margin: 6px 0 0; }
        .callout--warning { border-color: #d97706; background: #fff8e8; }
        .callout--danger { border-color: #b91c1c; background: #fef2f2; }
        .callout--pending { border-color: #8a5a00; background: #fff9e8; }
        .code-container { margin: 16px 0 26px; border: 1px solid rgba(255, 255, 255, .12); border-radius: var(--radius); background: #061522; overflow: hidden; box-shadow: var(--shadow-sm); }
        .code-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 6px 10px; background: #0a1f30; border-bottom: 1px solid rgba(255, 255, 255, .08); }
        .code-tabs { display: flex; gap: 3px; overflow-x: auto; }
        .code-tab { border: 0; border-radius: 6px; background: transparent; color: #8da4b8; cursor: pointer; padding: 7px 10px; font: inherit; font-size: .78rem; font-weight: 600; white-space: nowrap; }
        .code-tab:hover { background: rgba(255, 255, 255, .07); color: #fff; }
        .code-tab[aria-selected="true"] { background: #061522; color: #7dd3fc; box-shadow: inset 0 -2px 0 #0c7c86; }
        .code-pane { margin: 0; padding: 18px; overflow-x: auto; color: #c9e6ee; font-family: var(--font-mono); font-size: .84rem; line-height: 1.55; tab-size: 4; }
        .code-pane[hidden] { display: none; }
        .response-card { margin: 16px 0 24px; border: 1px solid var(--line); border-radius: var(--radius); background: var(--paper); overflow: hidden; }
        .response-head { display: flex; justify-content: space-between; gap: 10px; padding: 8px 14px; border-bottom: 1px solid var(--line); background: #eef4f8; color: var(--ink-soft); font-size: .82rem; font-weight: 700; }
        .response-card pre { margin: 0; padding: 16px; overflow-x: auto; background: #fafcfe; color: var(--ink); font-family: var(--font-mono); font-size: .82rem; line-height: 1.55; }
        .response-note { margin: 0; padding: 10px 14px; border-top: 1px solid var(--line); color: var(--muted); font-size: .8rem; }
        .article-nav { display: flex; justify-content: space-between; gap: 12px; margin-top: 34px; padding-top: 18px; border-top: 1px solid var(--line); }
        .article-nav__link { display: grid; gap: 2px; max-width: 46%; padding: 10px 14px; border: 1px solid var(--line); border-radius: 10px; color: var(--ink-soft); text-decoration: none; }
        .article-nav__link span { font-size: .72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }
        .article-nav__link strong { color: var(--teal-dark); font-size: .9rem; }
        .article-nav__link--next { text-align: right; margin-left: auto; }
        .docs-lang-switch { display: flex; align-items: center; gap: 5px; }
        .docs-lang-switch a { padding: 4px 7px; border-radius: 5px; color: var(--ink-soft); font-size: .78rem; font-weight: 700; text-decoration: none; }
        .docs-lang-switch a[aria-current="true"] { background: var(--mint); color: var(--teal-dark); }
        a:focus-visible, button:focus-visible, input:focus-visible { outline: 3px solid #7dd3fc; outline-offset: 2px; }
        @media (max-width: 1180px) { .docs-shell { grid-template-columns: 232px minmax(0, 1fr); } .docs-toc { display: none; } }
        @media (max-width: 860px) {
            .docs-shell { grid-template-columns: 1fr; gap: 24px; padding-top: 22px; }
            .docs-sidebar, .docs-toc { position: static; max-height: none; }
            .article-nav { flex-direction: column; }
            .article-nav__link { max-width: none; margin-left: 0 !important; text-align: left !important; }
        }
        @media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; transition: none !important; } }
        @media print { .docs-sidebar, .docs-toc, .article-nav, .copy-endpoint, .copy-code, .site-header, .site-footer { display: none !important; } .docs-shell { display: block; } .code-pane[hidden] { display: block !important; } }
    </style>
</head>
<body>
<a class="skip-link" href="#main"><?= $esc($t('docs.a11y.skip')) ?></a>

<header class="site-header">
    <div class="container header-inner">
        <a class="brand" href="<?= $esc($homePath) ?>" aria-label="Origen Salud">
            <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="brand-name">Origen<span>Salud</span></span>
        </a>

        <nav class="site-nav" aria-label="<?= $esc($t('nav.label')) ?>">
            <?php $activeNav = 'docs'; require dirname(__DIR__) . '/portal/Views/partials/nav-links.php'; ?>
        </nav>

        <div class="header-actions">
            <div class="docs-lang-switch" role="group" aria-label="<?= $esc($t('docs.lang.label')) ?>">
                <?php foreach ($alternates as $alternate): ?>
                    <a href="<?= $esc($alternate['href']) ?>" hreflang="<?= $esc($alternate['hreflang']) ?>"
                       lang="<?= $esc($alternate['hreflang']) ?>"
                       <?= $alternate['active'] ? 'aria-current="true"' : '' ?>
                       data-lang-link title="<?= $esc($alternate['label']) ?>"><?= $esc($alternate['short']) ?></a>
                <?php endforeach; ?>
            </div>
            <a class="button button-small" href="<?= $esc($accessMailto) ?>"><?= $esc($t('nav.access')) ?></a>
        </div>
    </div>
</header>

<main id="main">
    <div class="container docs-shell">
        <aside class="docs-sidebar" aria-label="<?= $esc($t('docs.nav.index')) ?>">
            <p class="docs-sidebar__title"><?= $esc($t('docs.nav.index')) ?></p>
            <div class="docs-search">
                <label class="sr-only" for="docs-search-input"><?= $esc($t('docs.a11y.search_label')) ?></label>
                <input id="docs-search-input" type="search" autocomplete="off"
                       placeholder="<?= $esc($t('docs.a11y.search_placeholder')) ?>">
                <button type="button" class="docs-search__clear" id="docs-search-clear"
                        aria-label="<?= $esc($t('docs.a11y.search_clear')) ?>">&times;</button>
            </div>
            <p class="docs-search__empty" id="docs-search-empty"><?= $esc($t('docs.a11y.search_no_results')) ?></p>

            <nav aria-label="<?= $esc($t('docs.nav.index')) ?>">
                <?php foreach ($grouped as $group => $groupArticles): ?>
                    <div class="docs-nav-group">
                        <h3><?= $esc($t('docs.nav.groups.' . $group)) ?></h3>
                        <ul>
                            <?php foreach ($groupArticles as $article): ?>
                                <?php
                                $articleKey = 'docs.article.' . $article['key'];
                                $searchText = $t($articleKey . '.title') . ' ' . $t($articleKey . '.lead') . ' ' . $t($articleKey . '.keywords');
                                ?>
                                <li>
                                    <a href="#<?= $esc($article['id']) ?>" data-nav-link
                                       data-search="<?= $esc(mb_strtolower($searchText, 'UTF-8')) ?>"><?= $esc($t($articleKey . '.title')) ?></a>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                <?php endforeach; ?>
            </nav>
        </aside>

        <div class="docs-main">
            <div class="docs-intro">
                <span class="docs-intro__badge"><?= $esc($t('docs.header.badge')) ?></span>
                <h1><?= $esc($t('docs.header.title')) ?></h1>
                <p><?= $esc($t('docs.header.lead')) ?></p>
            </div>

            <nav class="breadcrumb" aria-label="<?= $esc($t('docs.a11y.breadcrumb_label')) ?>">
                <ol>
                    <li><a href="<?= $esc($homePath) ?>"><?= $esc($t('breadcrumb.home')) ?></a></li>
                    <li><a href="<?= $esc($canonical) ?>"><?= $esc($t('breadcrumb.docs')) ?></a></li>
                    <li data-breadcrumb-group><?= $esc($t('docs.nav.groups.start')) ?></li>
                    <li aria-current="page" data-breadcrumb-article><?= $esc($t('docs.article.overview.title')) ?></li>
                </ol>
            </nav>

            <section id="overview" class="docs-section" data-article="overview">
                <h2><?= $esc($t('docs.article.overview.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.overview.lead')) ?></p>

                <?php $renderSubhead('overview-urls', $t('docs.overview.title')); ?>
                <div class="table-wrap">
                    <table class="param-table">
                        <thead><tr><th scope="col"><?= $esc($t('docs.overview.env_col')) ?></th><th scope="col"><?= $esc($t('docs.overview.url_col')) ?></th><th scope="col"><?= $esc($t('docs.overview.access_col')) ?></th></tr></thead>
                        <tbody>
                            <tr><td><strong><?= $esc($t('common.production')) ?></strong><br><small><?= $esc($t('docs.overview.rest_desc')) ?></small></td><td><code><?= $esc($apiBase) ?></code></td><td><?= $esc($t('common.authenticated')) ?></td></tr>
                            <tr><td><strong><?= $esc($t('common.public')) ?></strong><br><small><?= $esc($t('docs.overview.health_desc')) ?></small></td><td><code><?= $esc($apiBase) ?>/health</code></td><td><?= $esc($t('common.public')) ?></td></tr>
                        </tbody>
                    </table>
                </div>
                <?php $renderEndpoint('/health', 'public'); ?>

                <?php $renderSubhead('overview-health', $t('docs.overview.health_title')); ?>
                <?php $renderResponse($t('docs.overview.health_title'), $healthResponse, $t('docs.overview.health_note') . ' ' . $t('common.illustrative')); ?>

                <?php $renderSubhead('overview-format', $t('docs.overview.response_title')); ?>
                <p><?= $esc($t('docs.overview.response_text')) ?></p>
                <?php $renderCallout('', $t('common.note'), $t('common.json_only')); ?>
                <?php $renderArticleNav('overview'); ?>
            </section>

            <section id="auth" class="docs-section" data-article="auth">
                <h2><?= $esc($t('docs.article.auth.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.auth.lead')) ?></p>

                <?php $renderSubhead('auth-headers', $t('docs.auth.header_title')); ?>
                <p><?= $esc($t('docs.auth.header_text')) ?></p>
                <div class="table-wrap">
                    <table class="param-table">
                        <thead><tr><th scope="col"><?= $esc($t('auth.header')) ?></th><th scope="col"><?= $esc($t('docs.auth.header_title')) ?></th></tr></thead>
                        <tbody>
                            <tr><td><code>X-API-Key</code></td><td><code><?= $esc($t('docs.auth.xapikey')) ?></code></td></tr>
                            <tr><td><code>Authorization</code></td><td><code><?= $esc($t('docs.auth.bearer')) ?></code></td></tr>
                        </tbody>
                    </table>
                </div>

                <?php $renderSubhead('auth-format', $t('docs.auth.format_title')); ?>
                <p><?= $esc($t('docs.auth.format_text')) ?></p>

                <?php $renderSubhead('auth-management', $t('docs.auth.management_title')); ?>
                <p><?= $esc($t('docs.auth.management_text')) ?></p>
                <?php $renderCallout('danger', $t('docs.auth.warning_title'), $t('docs.auth.warning_text')); ?>
                <?php $renderArticleNav('auth'); ?>
            </section>

            <section id="conventions" class="docs-section" data-article="conventions">
                <h2><?= $esc($t('docs.article.conventions.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.conventions.lead')) ?></p>

                <?php $renderSubhead('conventions-success', $t('docs.conventions.success_title')); ?>
                <?php $renderResponse($t('docs.conventions.success_title'), $successResponse); ?>

                <?php $renderSubhead('conventions-error', $t('docs.conventions.error_title')); ?>
                <?php $renderResponse($t('docs.conventions.error_title'), $errorResponse); ?>
                <div class="table-wrap">
                    <table class="param-table">
                        <thead><tr><th scope="col"><?= $esc($t('docs.conventions.codes_col')) ?></th><th scope="col"><?= $esc($t('docs.conventions.code_col')) ?></th><th scope="col"><?= $esc($t('docs.conventions.meaning_col')) ?></th></tr></thead>
                        <tbody>
                            <tr><td>400</td><td><code>bad_request</code></td><td><?= $esc($t('docs.conventions.err_400')) ?></td></tr>
                            <tr><td>401</td><td><code>unauthorized</code></td><td><?= $esc($t('docs.conventions.err_401')) ?></td></tr>
                            <tr><td>404</td><td><code>not_found</code></td><td><?= $esc($t('docs.conventions.err_404')) ?></td></tr>
                            <tr><td>405</td><td><code>method_not_allowed</code></td><td><?= $esc($t('docs.conventions.err_405')) ?></td></tr>
                            <tr><td>500</td><td><code>internal_error</code></td><td><?= $esc($t('docs.conventions.err_500')) ?></td></tr>
                            <tr><td>503</td><td><code>service_unavailable</code></td><td><?= $esc($t('docs.conventions.err_503')) ?></td></tr>
                        </tbody>
                    </table>
                </div>
                <?php $renderCallout('warning', $t('common.warning'), $t('docs.conventions.no_403')); ?>

                <?php $renderSubhead('conventions-request-id', $t('docs.conventions.request_id_title')); ?>
                <p><?= $esc($t('docs.conventions.request_id_text')) ?></p>

                <?php $renderSubhead('conventions-language', $t('docs.conventions.lang_title')); ?>
                <p><?= $esc($t('docs.conventions.lang_text')) ?></p>

                <?php $renderSubhead('conventions-pagination', $t('docs.conventions.pagination_title')); ?>
                <p><?= $esc($t('docs.conventions.pagination_text')) ?></p>

                <?php $renderSubhead('conventions-methods', $t('docs.conventions.methods_title')); ?>
                <p><?= $esc($t('docs.conventions.methods_text')) ?></p>

                <?php $renderSubhead('conventions-headers', $t('docs.conventions.headers_title')); ?>
                <p><?= $esc($t('docs.conventions.headers_text')) ?></p>
                <?php $renderArticleNav('conventions'); ?>
            </section>

            <section id="quickstart" class="docs-section" data-article="quickstart">
                <h2><?= $esc($t('docs.article.quickstart.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.quickstart.lead')) ?></p>
                <?php $renderEndpoint('/v1/catalogs/dentar-pr/items?q=evaluacion&limit=5'); ?>
                <p><strong><?= $esc($t('docs.quickstart.endpoint_label')) ?>:</strong> <code><?= $esc($apiBase . '/v1/catalogs/dentar-pr/items') ?></code></p>

                <?php $renderSubhead('quickstart-steps', $t('docs.quickstart.code_title')); ?>
                <ol><li><?= $esc($t('docs.quickstart.step1')) ?></li><li><?= $esc($t('docs.quickstart.step2')) ?></li><li><?= $esc($t('docs.quickstart.step3')) ?></li></ol>
                <?php $renderCode('quickstart', $quickstartSnippets); ?>

                <?php $renderSubhead('quickstart-response', $t('docs.quickstart.response_title')); ?>
                <?php $renderResponse($t('docs.quickstart.response_title'), $quickstartResponse, $t('docs.quickstart.response_note') . ' ' . $t('common.illustrative')); ?>
                <?php $renderCallout('danger', $t('docs.auth.warning_title'), $t('docs.quickstart.security_note')); ?>
                <?php $renderArticleNav('quickstart'); ?>
            </section>

            <section id="search" class="docs-section" data-article="search">
                <h2><?= $esc($t('docs.article.search.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.search.lead')) ?></p>

                <?php $renderSubhead('search-routes', $t('docs.search.endpoints_title')); ?>
                <p><?= $esc($t('docs.search.endpoints_text')) ?></p>
                <?php $renderEndpoint('/v1/search'); ?>
                <?php $renderEndpoint('/v1/search/{domain}'); ?>
                <?php $renderEndpoint('/v1/concepts/search'); ?>

                <?php $renderSubhead('search-domains', $t('docs.search.domains_title')); ?>
                <p><?= $esc($t('docs.search.domains_text')) ?></p>

                <?php $renderSubhead('search-params', $t('docs.search.params_title')); ?>
                <?php $renderParams([
                    ['name' => 'q', 'type' => 'string', 'default' => '—', 'required' => $t('common.required'), 'text' => $t('docs.search.param_q')],
                    ['name' => 'domains', 'type' => 'csv', 'default' => 'snomed,cie10,anmat', 'required' => $t('common.optional'), 'text' => $t('docs.search.param_domains')],
                    ['name' => 'lang', 'type' => 'string', 'default' => 'es', 'required' => $t('common.optional'), 'text' => $t('docs.search.param_lang')],
                    ['name' => 'limit', 'type' => 'integer', 'default' => '20', 'required' => $t('common.optional'), 'text' => $t('docs.search.param_limit')],
                    ['name' => 'offset', 'type' => 'integer', 'default' => '0', 'required' => $t('common.optional'), 'text' => $t('docs.search.param_offset')],
                    ['name' => 'cie10_type', 'type' => 'enum', 'default' => '—', 'required' => $t('common.optional'), 'text' => $t('docs.search.param_cie10')],
                    ['name' => 'refset', 'type' => 'csv', 'default' => '—', 'required' => $t('common.optional'), 'text' => $t('docs.search.param_refset')],
                ]); ?>

                <?php $renderSubhead('search-example', $t('docs.search.example_title')); ?>
                <?php $renderCode('search', ['curl' => $searchCurl]); ?>
                <?php $renderResponse($t('docs.quickstart.response_title'), $searchResponse, $t('common.illustrative')); ?>

                <?php $renderSubhead('search-meta', $t('docs.search.meta_title')); ?>
                <p><?= $esc($t('docs.search.meta_text')) ?></p>

                <?php $renderSubhead('search-concepts', $t('docs.search.concepts_title')); ?>
                <p><?= $esc($t('docs.search.concepts_text')) ?></p>
                <?php $renderArticleNav('search'); ?>
            </section>

            <section id="catalogs" class="docs-section" data-article="catalogs">
                <h2><?= $esc($t('docs.article.catalogs.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.catalogs.lead')) ?></p>

                <?php $renderSubhead('catalogs-list', $t('docs.catalogs.list_title')); ?>
                <p><?= $esc($t('docs.catalogs.list_text')) ?></p>
                <?php $renderEndpoint('/v1/catalogs'); ?>

                <?php $renderSubhead('catalogs-releases', $t('docs.catalogs.releases_title')); ?>
                <p><?= $esc($t('docs.catalogs.releases_text')) ?></p>
                <?php $renderEndpoint('/v1/catalogs/{catalog_code}/releases'); ?>

                <?php $renderSubhead('catalogs-items', $t('docs.catalogs.items_title')); ?>
                <p><?= $esc($t('docs.catalogs.items_text')) ?></p>
                <?php $renderEndpoint('/v1/catalogs/{catalog_code}/items'); ?>

                <?php $renderSubhead('catalogs-detail', $t('docs.catalogs.detail_title')); ?>
                <p><?= $esc($t('docs.catalogs.detail_text')) ?></p>
                <?php $renderEndpoint('/v1/catalogs/{catalog_code}/items/{item}'); ?>

                <?php $renderSubhead('catalogs-codes', $t('docs.catalogs.codes_title')); ?>
                <p><?= $esc($t('docs.catalogs.codes_text')) ?></p>
                <div class="table-wrap">
                    <table class="param-table">
                        <thead><tr><th scope="col"><?= $esc($t('table.catalog_code')) ?></th><th scope="col"><?= $esc($t('docs.search.domains_title')) ?></th></tr></thead>
                        <tbody>
                            <tr><td><code>dentar-pr</code></td><td><?= $esc($t('docs.catalogs.code_dentar_pr')) ?></td></tr>
                            <tr><td><code>dentar-dx</code></td><td><?= $esc($t('docs.catalogs.code_dentar_dx')) ?></td></tr>
                            <tr><td><code>nomenclador-odontologico-ar</code></td><td><?= $esc($t('docs.catalogs.code_nomenclador')) ?></td></tr>
                            <tr><td><code>nbu</code></td><td><?= $esc($t('docs.catalogs.code_nbu')) ?></td></tr>
                            <tr><td><code>nn-pmo</code></td><td><?= $esc($t('docs.catalogs.code_nn_pmo')) ?></td></tr>
                        </tbody>
                    </table>
                </div>

                <?php $renderSubhead('catalogs-editorial', $t('docs.catalogs.editorial_title')); ?>
                <p><?= $esc($t('docs.catalogs.editorial_text')) ?></p>

                <?php $renderSubhead('catalogs-pricing', $t('docs.catalogs.pricing_title')); ?>
                <p><?= $esc($t('docs.catalogs.pricing_text')) ?></p>
                <?php $renderArticleNav('catalogs'); ?>
            </section>

            <section id="mappings" class="docs-section" data-article="mappings">
                <h2><?= $esc($t('docs.article.mappings.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.mappings.lead')) ?></p>

                <?php $renderSubhead('mappings-search', $t('docs.mappings.search_title')); ?>
                <p><?= $esc($t('docs.mappings.search_text')) ?></p>
                <?php $renderEndpoint('/v1/mappings'); ?>
                <?php $renderCode('mappings', ['curl' => $mappingsCurl]); ?>
                <?php $renderParams([
                    ['name' => 'system', 'type' => 'string', 'default' => '—', 'required' => $t('common.optional'), 'text' => $t('docs.mappings.param_system')],
                    ['name' => 'code', 'type' => 'string', 'default' => '—', 'required' => $t('common.optional'), 'text' => $t('docs.mappings.param_code')],
                    ['name' => 'catalog', 'type' => 'string', 'default' => '—', 'required' => $t('common.optional'), 'text' => $t('docs.mappings.param_catalog')],
                ]); ?>

                <?php $renderSubhead('mappings-units', $t('docs.mappings.units_title')); ?>
                <p><?= $esc($t('docs.mappings.units_text')) ?></p>
                <?php $renderEndpoint('/v1/pricing-units'); ?>

                <?php $renderSubhead('mappings-pharma', $t('docs.mappings.pharma_title')); ?>
                <p><?= $esc($t('docs.mappings.pharma_text')) ?></p>
                <?php $renderEndpoint('/v1/medicines/identifiers/{system}/{code}'); ?>
                <?php $renderArticleNav('mappings'); ?>
            </section>

            <section id="clinical" class="docs-section" data-article="clinical">
                <h2><?= $esc($t('docs.article.clinical.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.clinical.lead')) ?></p>

                <?php $renderSubhead('clinical-snomed', $t('docs.clinical.snomed_title')); ?>
                <p><?= $esc($t('docs.clinical.snomed_text')) ?></p>
                <?php $renderEndpoint('/v1/snomed/{sctid}'); ?>
                <?php $renderEndpoint('/v1/concepts/{id}'); ?>

                <?php $renderSubhead('clinical-cie10', $t('docs.clinical.cie10_title')); ?>
                <p><?= $esc($t('docs.clinical.cie10_text')) ?></p>
                <?php $renderEndpoint('/v1/cie10/{codigo}'); ?>

                <?php $renderSubhead('clinical-loinc', $t('docs.clinical.loinc_title')); ?>
                <p><?= $esc($t('docs.clinical.loinc_text')) ?></p>
                <?php $renderEndpoint('/v1/loinc'); ?>
                <?php $renderEndpoint('/v1/loinc/{code}'); ?>

                <?php $renderSubhead('clinical-anmat', $t('docs.clinical.anmat_title')); ?>
                <p><?= $esc($t('docs.clinical.anmat_text')) ?></p>
                <?php $renderEndpoint('/v1/anmat/{id}'); ?>

                <?php $renderSubhead('clinical-nomenclador', $t('docs.clinical.nomenclador_title')); ?>
                <p><?= $esc($t('docs.clinical.nomenclador_text')) ?></p>
                <?php $renderEndpoint('/v1/nomenclador'); ?>

                <?php $renderSubhead('clinical-vademecum', $t('docs.clinical.vademecum_title')); ?>
                <p><?= $esc($t('docs.clinical.vademecum_text')) ?></p>
                <?php $renderEndpoint('/v1/vademecum'); ?>

                <?php $renderSubhead('clinical-pmo', $t('docs.clinical.pmo_title')); ?>
                <p><?= $esc($t('docs.clinical.pmo_text')) ?></p>
                <?php $renderEndpoint('/v1/pmo/practicas'); ?>
                <?php $renderEndpoint('/v1/pmo/practicas/{code}'); ?>
                <?php $renderEndpoint('/v1/pmo/medicamentos'); ?>
                <?php $renderEndpoint('/v1/pmo/normativa'); ?>

                <?php $renderSubhead('clinical-local', $t('docs.clinical.local_title')); ?>
                <p><?= $esc($t('docs.clinical.local_text')) ?></p>
                <?php $renderEndpoint('/v1/{catalogo}/{id}'); ?>
                <?php $renderArticleNav('clinical'); ?>
            </section>

            <section id="dental" class="docs-section" data-article="dental">
                <h2><?= $esc($t('docs.article.dental.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.dental.lead')) ?></p>

                <?php $renderSubhead('dental-codes', $t('docs.dental.codes_title')); ?>
                <p><?= $esc($t('docs.dental.codes_text')) ?></p>

                <?php $renderSubhead('dental-pr', $t('docs.dental.pr_title')); ?>
                <p><?= $esc($t('docs.dental.pr_text')) ?></p>
                <?php $renderEndpoint('/v1/catalogs/dentar-pr/items'); ?>
                <?php $renderEndpoint('/v1/catalogs/dentar-pr/items/{item}'); ?>

                <?php $renderSubhead('dental-dx', $t('docs.dental.dx_title')); ?>
                <p><?= $esc($t('docs.dental.dx_text')) ?></p>
                <?php $renderEndpoint('/v1/odontologia/diagnosticos'); ?>
                <?php $renderEndpoint('/v1/odontologia/diagnosticos/{code}'); ?>
                <?php $renderCode('dental', ['curl' => $dentalCurl]); ?>

                <?php $renderSubhead('dental-just', $t('docs.dental.just_title')); ?>
                <p><?= $esc($t('docs.dental.just_text')) ?></p>
                <?php $renderEndpoint('/v1/odontologia/{code}/diagnosticos'); ?>

                <?php $renderSubhead('dental-snomed', $t('docs.dental.snomed_title')); ?>
                <p><?= $esc($t('docs.dental.snomed_text')) ?></p>
                <?php $renderEndpoint('/v1/odontologia/snomed/{sctid}'); ?>

                <?php $renderSubhead('dental-nomenclador', $t('docs.dental.nomenclador_title')); ?>
                <p><?= $esc($t('docs.dental.nomenclador_text')) ?></p>
                <?php $renderEndpoint('/v1/catalogs/nomenclador-odontologico-ar/items'); ?>

                <?php $renderSubhead('dental-cdt', $t('docs.dental.cdt_title')); ?>
                <p><?= $esc($t('docs.dental.cdt_text')) ?></p>
                <?php $renderCallout('warning', $t('common.warning'), $t('docs.dental.cdt_no_endpoint')); ?>
                <p><?= $esc($t('docs.dental.nn_text')) ?></p>

                <?php $renderSubhead('dental-relations', $t('docs.dental.relations_title')); ?>
                <p><?= $esc($t('docs.dental.relations_text')) ?></p>
                <?php $renderArticleNav('dental'); ?>
            </section>

            <section id="pending" class="docs-section" data-article="pending">
                <h2><?= $esc($t('docs.article.pending.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.pending.lead')) ?></p>
                <span class="badge badge--pending"><?= $esc($t('common.not_implemented')) ?></span>

                <?php $renderSubhead('pending-fhir', $t('docs.pending.fhir_title')); ?>
                <p><?= $esc($t('docs.pending.fhir_text')) ?></p>

                <?php $renderSubhead('pending-uvr', $t('docs.pending.uvr_title')); ?>
                <p><?= $esc($t('docs.pending.uvr_text')) ?></p>
                <p><a href="/uvr?lang=<?= $esc(rawurlencode($locale)) ?>"><?= $esc($t('uvr.nav.label')) ?></a></p>

                <?php $renderSubhead('pending-oauth', $t('docs.pending.oauth_title')); ?>
                <p><?= $esc($t('docs.pending.oauth_text')) ?></p>

                <?php $renderSubhead('pending-writes', $t('docs.pending.writes_title')); ?>
                <p><?= $esc($t('docs.pending.writes_text')) ?></p>

                <?php $renderSubhead('pending-console', $t('docs.pending.console_title')); ?>
                <p><?= $esc($t('docs.pending.console_text')) ?></p>

                <?php $renderSubhead('pending-catalogs', $t('docs.pending.catalogs_title')); ?>
                <p><?= $esc($t('docs.pending.catalogs_text')) ?></p>

                <?php $renderSubhead('pending-alignment', $t('docs.pending.alignment_title')); ?>
                <p><?= $esc($t('docs.pending.alignment_text')) ?></p>
                <?php $renderArticleNav('pending'); ?>
            </section>

            <section id="openapi" class="docs-section" data-article="openapi">
                <h2><?= $esc($t('docs.article.openapi.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.openapi.lead')) ?></p>

                <?php $renderSubhead('openapi-spec', $t('docs.openapi.spec_title')); ?>
                <p><?= $esc($t('docs.openapi.spec_text')) ?></p>
                <p><strong><?= $esc($t('docs.openapi.spec_link')) ?></strong> <code>docs/api/openapi-3.1.yaml</code></p>
                <?php $renderCallout('', $t('common.note'), $t('common.see_openapi')); ?>

                <?php $renderSubhead('openapi-divergences', $t('docs.openapi.divergences_title')); ?>
                <p><?= $esc($t('docs.openapi.divergences_text')) ?></p>
                <ul>
                    <li><?= $esc($t('docs.openapi.div_q')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_lang')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_limit')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_request_id')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_health')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_domains')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_params')) ?></li>
                    <li><?= $esc($t('docs.openapi.div_methods')) ?></li>
                </ul>

                <?php $renderSubhead('openapi-generate', $t('docs.openapi.generate_title')); ?>
                <p><?= $esc($t('docs.openapi.generate_text')) ?></p>
                <?php $renderArticleNav('openapi'); ?>
            </section>

            <section id="support" class="docs-section" data-article="support">
                <h2><?= $esc($t('docs.article.support.title')) ?></h2>
                <p class="lead"><?= $esc($t('docs.support.lead')) ?></p>

                <?php $renderSubhead('support-security', $t('docs.support.security_title')); ?>
                <p><?= $esc($t('docs.support.security_text')) ?></p>

                <?php $renderSubhead('support-logging', $t('docs.support.logging_title')); ?>
                <p><?= $esc($t('docs.support.logging_text')) ?></p>

                <?php $renderSubhead('support-contact', $t('docs.support.contact_title')); ?>
                <p><?= $esc($t('docs.support.contact_text')) ?> <a href="<?= $esc($contactMailto) ?>">contacto@origen.ar</a>. <?= $esc($t('docs.support.no_credentials')) ?></p>

                <?php $renderSubhead('support-legal', $t('docs.support.legal_title')); ?>
                <p><?= $esc($t('docs.support.legal_text')) ?></p>
                <?php $renderArticleNav('support'); ?>
            </section>
        </div>

        <aside class="docs-toc" id="docs-toc" aria-label="<?= $esc($t('docs.a11y.toc_label')) ?>">
            <h2><?= $esc($t('docs.a11y.toc_label')) ?></h2>
            <ol id="docs-toc-list"></ol>
        </aside>
    </div>
</main>

<footer class="site-footer">
    <div class="container footer-inner">
        <div>
            <a href="<?= $esc($legalMailto) ?>" class="footer-link"><?= $esc($t('footer.legal')) ?></a>
            <a href="<?= $esc($privacyMailto) ?>" class="footer-link"><?= $esc($t('footer.legal_privacy')) ?></a>
        </div>
        <p><?= $esc(str_replace('%year%', (string) $year, $t('footer.rights'))) ?></p>
        <p><small><?= $esc($t('docs.footer.disclaimer')) ?></small></p>
    </div>
</footer>

<script>
(function () {
    'use strict';

    var searchInput = document.getElementById('docs-search-input');
    var searchClear = document.getElementById('docs-search-clear');
    var searchEmpty = document.getElementById('docs-search-empty');
    var navLinks = Array.prototype.slice.call(document.querySelectorAll('[data-nav-link]'));
    var sections = Array.prototype.slice.call(document.querySelectorAll('[data-article]'));
    var articleMap = {};
    sections.forEach(function (section) { articleMap[section.id] = section; });

    var articleData = {};
    navLinks.forEach(function (link) {
        articleData[link.getAttribute('href').slice(1)] = {
            link: link,
            search: link.getAttribute('data-search') || '',
            title: link.textContent.trim()
        };
    });

    function filterDocs() {
        var term = (searchInput.value || '').trim().toLocaleLowerCase();
        var visible = 0;
        navLinks.forEach(function (link) {
            var haystack = (link.getAttribute('data-search') || '');
            var match = term === '' || haystack.indexOf(term) !== -1;
            link.parentElement.hidden = !match;
            if (match) { visible++; }
        });
        searchEmpty.style.display = visible === 0 ? 'block' : 'none';
    }

    if (searchInput) {
        searchInput.addEventListener('input', filterDocs);
        searchClear.addEventListener('click', function () {
            searchInput.value = '';
            filterDocs();
            searchInput.focus();
        });
    }

    document.addEventListener('keydown', function (event) {
        var tag = (event.target.tagName || '').toLowerCase();
        var typing = tag === 'input' || tag === 'textarea' || event.target.isContentEditable;
        if ((event.key === '/' && !typing) || ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k')) {
            event.preventDefault();
            if (searchInput) { searchInput.focus(); }
        }
    });

    var codeBlocks = Array.prototype.slice.call(document.querySelectorAll('[data-code-block]'));
    var storageKey = 'origen_docs_code_lang';
    var preferredLang = null;
    try { preferredLang = window.localStorage.getItem(storageKey); } catch (error) { preferredLang = null; }

    function availableLanguages() {
        for (var i = 0; i < codeBlocks.length; i++) {
            var tabs = codeBlocks[i].querySelectorAll('[data-code-lang]');
            if (tabs.length) { return Array.prototype.map.call(tabs, function (tab) { return tab.getAttribute('data-code-lang'); }); }
        }
        return [];
    }

    function selectCodeLanguage(lang) {
        var available = availableLanguages();
        if (available.indexOf(lang) === -1) { lang = available[0]; }
        if (!lang) { return; }
        codeBlocks.forEach(function (block) {
            var tabs = Array.prototype.slice.call(block.querySelectorAll('[data-code-lang]'));
            var panes = Array.prototype.slice.call(block.querySelectorAll('[data-code-pane]'));
            var matched = tabs.filter(function (tab) { return tab.getAttribute('data-code-lang') === lang; })[0];
            var chosen = matched ? lang : (tabs[0] ? tabs[0].getAttribute('data-code-lang') : null);
            tabs.forEach(function (tab) {
                var active = tab.getAttribute('data-code-lang') === chosen;
                tab.setAttribute('aria-selected', active ? 'true' : 'false');
                tab.tabIndex = active ? 0 : -1;
            });
            panes.forEach(function (pane) { pane.hidden = pane.getAttribute('data-code-pane') !== chosen; });
        });
        try { window.localStorage.setItem(storageKey, lang); } catch (error) { /* almacenamiento no disponible */ }
    }

    codeBlocks.forEach(function (block) {
        block.addEventListener('click', function (event) {
            var tab = event.target.closest('[data-code-lang]');
            if (tab) { selectCodeLanguage(tab.getAttribute('data-code-lang')); }
        });
        block.addEventListener('keydown', function (event) {
            var tab = event.target.closest('[data-code-lang]');
            if (!tab || ['ArrowLeft', 'ArrowRight', 'Home', 'End'].indexOf(event.key) === -1) { return; }
            var tabs = Array.prototype.slice.call(block.querySelectorAll('[data-code-lang]'));
            var index = tabs.indexOf(tab);
            var nextIndex = index;
            if (event.key === 'ArrowLeft') { nextIndex = (index - 1 + tabs.length) % tabs.length; }
            if (event.key === 'ArrowRight') { nextIndex = (index + 1) % tabs.length; }
            if (event.key === 'Home') { nextIndex = 0; }
            if (event.key === 'End') { nextIndex = tabs.length - 1; }
            event.preventDefault();
            var next = tabs[nextIndex];
            selectCodeLanguage(next.getAttribute('data-code-lang'));
            next.focus();
        });
    });
    selectCodeLanguage(preferredLang);

    function copyText(text, button, doneLabel, originalLabel) {
        function finish() {
            var old = button.textContent;
            button.textContent = doneLabel;
            window.setTimeout(function () { button.textContent = originalLabel || old; }, 1600);
        }
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(finish).catch(function () { fallback(); });
        } else {
            fallback();
        }
        function fallback() {
            var area = document.createElement('textarea');
            area.value = text;
            area.setAttribute('readonly', '');
            area.style.position = 'fixed';
            area.style.opacity = '0';
            document.body.appendChild(area);
            area.select();
            try { document.execCommand('copy'); finish(); } catch (error) { /* sin portapapeles */ }
            document.body.removeChild(area);
        }
    }

    document.addEventListener('click', function (event) {
        var endpointButton = event.target.closest('[data-endpoint]');
        if (endpointButton) {
            copyText(endpointButton.getAttribute('data-endpoint'), endpointButton,
                <?= json_encode($t('docs.a11y.endpoint_copied'), JSON_UNESCAPED_UNICODE) ?>,
                <?= json_encode($t('docs.a11y.copy_endpoint'), JSON_UNESCAPED_UNICODE) ?>);
            return;
        }
        var copyButton = event.target.closest('[data-copy-code]');
        if (copyButton) {
            var block = copyButton.closest('[data-code-block]');
            var activePane = block ? block.querySelector('[data-code-pane]:not([hidden])') : null;
            if (activePane) {
                copyText(activePane.textContent, copyButton,
                    <?= json_encode($t('docs.a11y.copied'), JSON_UNESCAPED_UNICODE) ?>,
                    <?= json_encode($t('docs.a11y.copy'), JSON_UNESCAPED_UNICODE) ?>);
            }
        }
    });

    var breadcrumbGroup = document.querySelector('[data-breadcrumb-group]');
    var breadcrumbArticle = document.querySelector('[data-breadcrumb-article]');
    var tocList = document.getElementById('docs-toc-list');
    var activeId = 'overview';

    function renderToc(section) {
        if (!tocList || !section) { return; }
        tocList.innerHTML = '';
        var headings = Array.prototype.slice.call(section.querySelectorAll('h3[id]'));
        headings.forEach(function (heading) {
            var li = document.createElement('li');
            var link = document.createElement('a');
            link.href = '#' + heading.id;
            link.textContent = heading.textContent;
            link.setAttribute('data-toc-link', heading.id);
            li.appendChild(link);
            tocList.appendChild(li);
        });
    }

    function activate(id) {
        if (!articleMap[id] || id === activeId && breadcrumbArticle.textContent) {
            renderToc(articleMap[id]);
            return;
        }
        activeId = id;
        var data = articleData[id];
        navLinks.forEach(function (link) { link.classList.toggle('is-active', link.getAttribute('href') === '#' + id); });
        if (data && breadcrumbArticle) {
            breadcrumbArticle.textContent = data.title;
            var group = articleMap[id].getAttribute('data-group-label');
            if (group && breadcrumbGroup) { breadcrumbGroup.textContent = group; }
        }
        renderToc(articleMap[id]);
    }

    sections.forEach(function (section) {
        var index = articleData[section.id];
        if (index) {
            section.setAttribute('data-group-label', index.link.closest('.docs-nav-group').querySelector('h3').textContent);
        }
    });

    if ('IntersectionObserver' in window) {
        var observer = new IntersectionObserver(function (entries) {
            var best = null;
            entries.forEach(function (entry) {
                if (entry.isIntersecting && (!best || entry.intersectionRatio > best.intersectionRatio)) { best = entry; }
            });
            if (best) { activate(best.target.id); }
        }, { rootMargin: '-15% 0px -70% 0px', threshold: [0, 0.25, 0.5, 1] });
        sections.forEach(function (section) { observer.observe(section); });
    }

    window.addEventListener('hashchange', function () {
        var id = window.location.hash.slice(1);
        if (articleMap[id]) { activate(id); }
    });
    if (window.location.hash) {
        var initial = window.location.hash.slice(1);
        if (articleMap[initial]) { activate(initial); }
    } else {
        activate('overview');
    }

    document.querySelectorAll('[data-lang-link]').forEach(function (link) {
        if (window.location.hash) { link.href += window.location.hash; }
    });
}());
</script>
</body>
</html>
