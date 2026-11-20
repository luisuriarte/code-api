<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\CatalogGovernanceService;
use OrigenSalud\Portal\Admin\UvrGovernanceException;
use OrigenSalud\Portal\Admin\UvrGovernanceService;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Panel gestionado de valoración relativa UVR (vistas A–G).
 *
 * Todas las rutas cuelgan de /admin: AdminGuard exige sesión, el permiso se
 * comprueba en backend y los formularios usan CSRF. No se crean rutas de API
 * pública ni de FHIR, y ninguna vista publica valores no aprobados.
 */
final class AdminUvrController
{
    private const COMPONENT_TYPES = ['work', 'practice_expense', 'professional_liability'];

    /** A · Valoraciones. */
    public static function index(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $valuations = self::service()->valuationsWithImporte($current);
        } catch (RepositoryException) {
            $valuations = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $valuations = [];
        }

        self::render('admin/uvr/index', 'A', '/admin/uvr', $current, [
            'valuations' => $valuations,
        ]);
    }

    /** B · Catálogos sobre los que se puede proponer (sin crear catálogos). */
    public static function catalogs(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $catalogs = self::service()->editableCatalogs($current);
        } catch (RepositoryException) {
            $catalogs = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $catalogs = [];
        }

        self::render('admin/uvr/catalogs', 'B', '/admin/uvr/catalogs', $current, [
            'catalogs' => $catalogs,
        ]);
    }

    /** C · Bandeja de propuestas y formulario de propuesta. */
    public static function proposals(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $proposals = self::service()->proposals($current);
        } catch (RepositoryException) {
            $proposals = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $proposals = [];
        }

        $catalogs = [];

        try {
            $catalogs = self::service()->proposalCatalogs($current);
        } catch (RepositoryException) {
            $catalogs = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $catalogs = [];
        }

        $codes = array_column($catalogs, 'code');
        $requestedCatalog = $_GET['catalog'] ?? '';
        $requestedCatalog = is_string($requestedCatalog)
            && preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $requestedCatalog) === 1
                ? $requestedCatalog
                : '';
        $catalogCode = in_array($requestedCatalog, $codes, true)
            ? $requestedCatalog
            : (string) ($codes[0] ?? '');

        $query = $_GET['q'] ?? '';
        $query = is_string($query) ? trim(mb_substr($query, 0, 100)) : '';

        // `service_item_id` es el enlace histórico desde Gestión de Catálogos;
        // `item` es el parámetro del nuevo flujo catálogo → código → propuesta.
        $requestedItem = $_GET['item'] ?? $_GET['service_item_id'] ?? null;
        $itemId = is_string($requestedItem) && ctype_digit($requestedItem) ? (int) $requestedItem : 0;

        $prefill = [];
        $selectedItem = null;
        $itemError = $itemId > 0;
        $catalogService = new CatalogGovernanceService();

        if ($itemId > 0 && $catalogCode !== '') {
            try {
                $detail = $catalogService->item($catalogCode, $itemId, $current);

                if ((int) ($detail['item']['id'] ?? 0) === $itemId) {
                    $selectedItem = $detail['item'];
                    $itemError = false;
                    $prefill['service_item_id'] = (string) $itemId;
                    $version = is_array($detail['versions'][0] ?? null) ? $detail['versions'][0] : [];

                    if ((int) ($version['release_id'] ?? 0) > 0) {
                        $prefill['release_id'] = (string) (int) $version['release_id'];
                    }
                    if ((string) ($version['version_tag'] ?? '') !== '') {
                        $prefill['version_tag'] = (string) $version['version_tag'];
                    }
                }
            } catch (RepositoryException) {
                // Se muestra el aviso de código no encontrado.
            } catch (UvrGovernanceException $exception) {
                self::guardDenied($current, $exception);
            }
        }

        $items = [];
        if ($catalogCode !== '') {
            $itemQuery = $query !== '' ? $query : (string) ($selectedItem['permanent_code'] ?? '');

            if ($itemQuery !== '') {
                try {
                    $items = $catalogService->items($catalogCode, $itemQuery, $current);
                } catch (RepositoryException) {
                    $items = [];
                } catch (UvrGovernanceException $exception) {
                    self::guardDenied($current, $exception);
                }
            }
        }

        $service = self::service();
        $transversal = $service->transversal();
        $prestaciones = [];
        $profiles = [];
        $profileComponents = [];

        try {
            if ($transversal && $catalogCode !== '' && $itemId > 0) {
                $prestaciones = $service->linkedPrestaciones($itemId, $catalogCode, $current);
            }
            if ($transversal) {
                $profiles = $service->profiles($current);

                foreach ($profiles as $profile) {
                    $profileId = (int) ($profile['id'] ?? 0);
                    $components = [];

                    foreach ($service->profileComponents($profileId, $current) as $type => $state) {
                        if ($state === 'applicable') {
                            $components[] = (string) $type;
                        }
                    }

                    $profileComponents[$profileId] = implode(',', $components);
                }
            }
        } catch (RepositoryException) {
            $prestaciones = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $prestaciones = [];
        }

        self::render('admin/uvr/proposals', 'C', '/admin/uvr/proposals', $current, [
            'proposals' => $proposals,
            'catalogs' => $catalogs,
            'catalogCode' => $catalogCode,
            'query' => $query,
            'items' => $items,
            'itemId' => $itemId,
            'selectedItem' => $selectedItem,
            'itemError' => $itemError,
            'prefill' => $prefill,
            'transversal' => $transversal,
            'prestaciones' => $prestaciones,
            'profiles' => $profiles,
            'profileComponents' => $profileComponents,
        ]);
    }

    /** C · Detalle de una propuesta con revisiones y decisión. */
    public static function proposal(int $id): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $detail = self::service()->proposalDetail($id, $current);
        } catch (RepositoryException) {
            $detail = ['proposal' => null, 'reviews' => [], 'decisions' => []];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $detail = ['proposal' => null, 'reviews' => [], 'decisions' => []];
        }

        self::render('admin/uvr/proposal', 'C', '/admin/uvr/proposals/' . $id, $current, $detail);
    }

    /** D · Cola de trabajo derivada, sin tabla de tareas nueva. */
    public static function tasks(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.review']);

        try {
            $tasks = self::service()->tasks($current);
        } catch (RepositoryException) {
            $tasks = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $tasks = [];
        }

        self::render('admin/uvr/tasks', 'D', '/admin/uvr/tasks', $current, [
            'tasks' => $tasks,
        ]);
    }

    /** E · Comparación de versiones; nunca muestra valores inventados. */
    public static function compare(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $valuations = self::service()->valuations($current);
        } catch (RepositoryException) {
            $valuations = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $valuations = [];
        }

        self::render('admin/uvr/compare', 'E', '/admin/uvr/compare', $current, [
            'valuations' => array_slice($valuations, 0, 5),
        ]);
    }

    /** F · Metodologías y vigencia, derivadas de las valoraciones. */
    public static function methodologies(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $valuations = self::service()->valuations($current);
        } catch (RepositoryException) {
            $valuations = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $valuations = [];
        }

        $grouped = [];

        foreach ($valuations as $valuation) {
            $key = (string) ($valuation['methodology'] ?? '') . '|' . (string) ($valuation['version_tag'] ?? '');
            $grouped[$key] ??= [
                'methodology' => (string) ($valuation['methodology'] ?? ''),
                'version_tag' => (string) ($valuation['version_tag'] ?? ''),
                'count' => 0,
                'source_reference' => (string) ($valuation['source_reference'] ?? ''),
                'review_status' => (string) ($valuation['review_status'] ?? ''),
            ];
            $grouped[$key]['count']++;
        }

        self::render('admin/uvr/methodologies', 'F', '/admin/uvr/methodologies', $current, [
            'methodologies' => array_values($grouped),
        ]);
    }

    /** G · Conversión e índices geográficos; importe siempre derivado. */
    public static function monetary(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);

        try {
            $conversions = self::service()->conversions($current);
            $indexes = self::service()->geoIndexes($current);
        } catch (RepositoryException) {
            $conversions = [];
            $indexes = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $conversions = [];
            $indexes = [];
        }

        self::render('admin/uvr/monetary', 'G', '/admin/uvr/monetary', $current, [
            'conversions' => $conversions,
            'indexes' => $indexes,
        ]);
    }

    /** Alta de valoración + propuesta, con componentes gestionados. */
    public static function propose(): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.propose']);

        $input = self::values();
        $back = self::proposalBack($input);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail($back, 'csrf', $input);

            return;
        }

        $components = [];
        $posted = $_POST['components'] ?? [];

        if (is_array($posted)) {
            foreach (self::COMPONENT_TYPES as $type) {
                $raw = $posted[$type] ?? null;

                if (!is_array($raw)) {
                    continue;
                }

                $components[] = [
                    'component_type' => $type,
                    'value' => $raw['value'] ?? '',
                    'is_not_applicable' => isset($raw['not_applicable']),
                    'negative_adjustment_evidence' => $raw['evidence'] ?? null,
                    'calculation_note' => $raw['note'] ?? null,
                ];
            }
        }

        $input['components'] = $components;

        try {
            $id = self::service()->propose($input, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception($back, $exception, $input);

            return;
        }

        AdminForm::success('/admin/uvr/proposals/' . $id, 'uvr_proposed');
    }

    /** Revisión clínica o económica por actores distintos. */
    public static function review(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.review']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/uvr/proposals/' . $id, 'csrf');

            return;
        }

        try {
            self::service()->recordReview($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/uvr/proposals/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/uvr/proposals/' . $id, 'uvr_reviewed');
    }

    /** Decisión con evidencia, previa separación de funciones. */
    public static function decide(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.approve']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/uvr/proposals/' . $id, 'csrf');

            return;
        }

        try {
            self::service()->decide($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/uvr/proposals/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/uvr/proposals/' . $id, 'uvr_decided');
    }

    /** Publicación controlada por el guardián de la base. */
    public static function publish(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.publish']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/uvr', 'csrf');

            return;
        }

        try {
            self::service()->publish($id, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/uvr', $exception);

            return;
        }

        AdminForm::success('/admin/uvr', 'uvr_published');
    }

    /** @param array<string, mixed> $extra */
    private static function render(
        string $template,
        string $section,
        string $path,
        array $current,
        array $extra
    ): void {
        View::render($template, $extra + [
            'pageTitle' => 'UVR | Origen Salud',
            'pageDescription' => 'Gestión de valoración relativa UVR.',
            'locale' => I18n::locale(),
            'currentPath' => $path,
            'adminUser' => $current['user'],
            'current' => $current,
            'section' => $section,
            'flash' => AdminForm::pull(),
        ], 'admin');
    }

    /** @param array<string, mixed>|null $current */
    private static function guardDenied(?array $current, UvrGovernanceException $exception): void
    {
        $code = $exception->getMessage();

        if (str_starts_with($code, 'uvr_permission') || str_starts_with($code, 'uvr_grant')) {
            AdminGuard::denied($current);
        }
    }

    /** @return array<string, mixed> */
    private static function values(): array
    {
        $keys = [
            'catalog', 'q', 'service_item_id', 'release_id', 'version_tag', 'methodology',
            'prestacion_id', 'profile_id', 'source_reference', 'evaluated_at',
            'valid_from', 'valid_to', 'review_role', 'rationale', 'outcome',
            'evidence_reference',
        ];
        $values = [];

        foreach ($keys as $key) {
            if (isset($_POST[$key]) && is_string($_POST[$key])) {
                $values[$key] = $_POST[$key];
            }
        }

        return $values;
    }

    /** Conserva catálogo, búsqueda y código al volver por un error de formulario. */
    private static function proposalBack(array $values): string
    {
        $params = [];

        foreach (['catalog', 'q'] as $key) {
            if (isset($values[$key]) && is_string($values[$key]) && $values[$key] !== '') {
                $params[$key] = $values[$key];
            }
        }

        $item = $values['service_item_id'] ?? '';

        if (is_string($item) && ctype_digit($item) && (int) $item > 0) {
            $params['item'] = $item;
        }

        return $params === []
            ? '/admin/uvr/proposals'
            : '/admin/uvr/proposals?' . http_build_query($params);
    }

    private static function service(): UvrGovernanceService
    {
        return new UvrGovernanceService();
    }
}
