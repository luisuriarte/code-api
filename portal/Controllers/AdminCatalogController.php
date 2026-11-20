<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\CatalogGovernanceService;
use OrigenSalud\Portal\Admin\UvrGovernanceException;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Gestión de catálogos y códigos.
 *
 * El editor nunca escribe directamente en public.os_catalog_*: crea propuestas
 * y delega la publicación al aplicador SECURITY DEFINER de la base. Todas las
 * rutas pasan por AdminGuard, validan CSRF en POST y usan RBAC en backend.
 */
final class AdminCatalogController
{
    /** Selector de catálogos; el listado de códigos se carga al elegir uno. */
    public static function index(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);
        $code = $_GET['code'] ?? '';

        if (is_string($code) && self::cleanCode($code) !== '') {
            $target = '/admin/catalogs/' . rawurlencode(self::cleanCode($code));
            $query = self::query();

            if ($query !== '') {
                $target .= '?q=' . rawurlencode($query);
            }

            header('Location: ' . $target, true, 303);
            exit;
        }

        self::render('admin/catalogs/index', $current, [
            'catalogs' => self::catalogs($current),
            'catalogCode' => '',
            'items' => [],
            'query' => '',
        ]);
    }

    /** Códigos de un catálogo, con búsqueda opcional por `q`. */
    public static function show(string $code): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);
        $code = self::cleanCode($code);
        $query = self::query();

        try {
            $items = $code === '' ? [] : self::service()->items($code, $query, $current);
        } catch (RepositoryException) {
            $items = [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
            $items = [];
        }

        self::render('admin/catalogs/index', $current, [
            'catalogs' => self::catalogs($current),
            'catalogCode' => $code,
            'items' => $items,
            'query' => $query,
        ]);
    }

    /** Detalle de un código: versiones, relaciones, idiomas y acceso UVR. */
    public static function item(string $code, int $itemId): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);
        $code = self::cleanCode($code);
        $detail = ['item' => null, 'versions' => [], 'relations' => [], 'releases' => [], 'languages' => []];

        try {
            $detail = self::service()->item($code, $itemId, $current);
        } catch (RepositoryException) {
            // Sin catálogos disponibles: se muestra el estado vacío.
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
        }

        self::render('admin/catalogs/item', $current, $detail + [
            'catalogCode' => $code,
            'catalogs' => self::catalogs($current),
        ]);
    }

    /** Bandeja de solicitudes de cambio de catálogo. */
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

        self::render('admin/catalogs/proposals', $current, [
            'catalogs' => self::catalogs($current),
            'proposals' => $proposals,
        ]);
    }

    /** Detalle de una solicitud con revisiones, decisión y publicación. */
    public static function proposal(int $id): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);
        $detail = ['proposal' => null, 'reviews' => [], 'decisions' => []];

        try {
            $detail = self::service()->proposal($id, $current);
        } catch (RepositoryException) {
            // Sin base administrativa: se muestra el estado vacío.
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);
        }

        self::render('admin/catalogs/proposal', $current, $detail + [
            'catalogs' => self::catalogs($current),
        ]);
    }

    /** Alta de una propuesta gestionada, nunca escritura directa. */
    public static function propose(): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.propose']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/catalogs/proposals', 'csrf', self::values());

            return;
        }

        $input = self::values();
        $input['relations'] = self::rows('relations');
        $input['languages'] = self::rows('languages');

        try {
            $id = self::service()->propose($input, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/catalogs/proposals', $exception, self::values());

            return;
        }

        AdminForm::success('/admin/catalogs/proposals/' . $id, 'catalog_proposed');
    }

    /** Revisión clínica o técnica por actores distintos. */
    public static function review(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.review']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/catalogs/proposals/' . $id, 'csrf');

            return;
        }

        try {
            self::service()->recordReview($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/catalogs/proposals/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/catalogs/proposals/' . $id, 'catalog_reviewed');
    }

    /** Decisión con evidencia y separación de funciones. */
    public static function decide(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.approve']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/catalogs/proposals/' . $id, 'csrf');

            return;
        }

        try {
            self::service()->decide($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/catalogs/proposals/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/catalogs/proposals/' . $id, 'catalog_decided');
    }

    /** Publicación controlada por el aplicador gestionado de la base. */
    public static function publish(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'catalog.publish']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/catalogs/proposals/' . $id, 'csrf');

            return;
        }

        try {
            self::service()->publish($id, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/catalogs/proposals/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/catalogs/proposals/' . $id, 'catalog_published');
    }

    /** @param array<string, mixed> $extra */
    private static function render(string $template, array $current, array $extra): void
    {
        View::render($template, $extra + [
            'pageTitle' => 'Catálogos | Origen Salud',
            'pageDescription' => 'Gestión de catálogos y códigos.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin/catalogs',
            'adminUser' => $current['user'],
            'current' => $current,
            'flash' => AdminForm::pull(),
        ], 'admin');
    }

    /** @return list<array<string, mixed>> */
    private static function catalogs(array $current): array
    {
        try {
            return self::service()->catalogs('', $current);
        } catch (RepositoryException) {
            return [];
        } catch (UvrGovernanceException $exception) {
            self::guardDenied($current, $exception);

            return [];
        }
    }

    private static function cleanCode(string $code): string
    {
        $code = trim(rawurldecode($code));

        return preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $code) === 1 ? $code : '';
    }

    private static function query(): string
    {
        $query = $_GET['q'] ?? '';

        return is_string($query) ? trim(mb_substr($query, 0, 80)) : '';
    }

    /** @param array<string, mixed>|null $current */
    private static function guardDenied(?array $current, UvrGovernanceException $exception): void
    {
        $code = $exception->getMessage();

        if (str_starts_with($code, 'catalog_permission') || str_starts_with($code, 'catalog_grant')) {
            AdminGuard::denied($current);
        }
    }

    /** @return array<string, mixed> */
    private static function values(): array
    {
        $keys = [
            'code', 'operation', 'item_id', 'permanent_code', 'status',
            'release_id', 'version_tag', 'valid_from', 'valid_to', 'release_status',
            'preferred_term', 'definition', 'clinical_criteria', 'language_code',
            'source_reference', 'review_role', 'rationale', 'outcome', 'evidence_reference',
        ];
        $values = [];

        foreach ($keys as $key) {
            if (isset($_POST[$key]) && is_string($_POST[$key])) {
                $values[$key] = $_POST[$key];
            }
        }

        return $values;
    }

    /** @return list<array<string, mixed>> */
    private static function rows(string $name): array
    {
        $posted = $_POST[$name] ?? [];

        if (!is_array($posted)) {
            return [];
        }

        $rows = [];

        foreach ($posted as $row) {
            if (is_array($row)) {
                $rows[] = $row;
            }
        }

        return $rows;
    }

    private static function service(): CatalogGovernanceService
    {
        return new CatalogGovernanceService();
    }
}
