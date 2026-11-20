<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\UvrGovernanceException;
use OrigenSalud\Portal\Admin\UvrGovernanceService;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Panel gobernado de valoración relativa UVR (vistas A–G).
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

        self::render('admin/uvr/proposals', 'C', '/admin/uvr/proposals', $current, [
            'proposals' => $proposals,
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

    /** Alta de valoración + propuesta, con componentes gobernados. */
    public static function propose(): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.propose']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/uvr/proposals', 'csrf', self::values());

            return;
        }

        $input = self::values();
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
            AdminForm::exception('/admin/uvr/proposals', $exception, self::values());

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
            'pageDescription' => 'Gobernanza de valoración relativa UVR.',
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
            'service_item_id', 'release_id', 'version_tag', 'methodology',
            'source_reference', 'evaluated_at', 'valid_from', 'valid_to',
            'review_role', 'rationale', 'outcome', 'evidence_reference',
        ];
        $values = [];

        foreach ($keys as $key) {
            if (isset($_POST[$key]) && is_string($_POST[$key])) {
                $values[$key] = $_POST[$key];
            }
        }

        return $values;
    }

    private static function service(): UvrGovernanceService
    {
        return new UvrGovernanceService();
    }
}
