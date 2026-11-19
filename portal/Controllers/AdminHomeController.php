<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Repositories\AdminDatabase;
use OrigenSalud\Portal\Repositories\AuditRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/** Panel mínimo de la Fase 1: identidad, permisos efectivos y auditoría. */
final class AdminHomeController
{
    public static function index(): void
    {
        $current = AdminGuard::require();

        View::render('admin/home', [
            'pageTitle' => 'Panel de administración | Origen Salud',
            'pageDescription' => 'Gobernanza de catálogos: identidad y permisos.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin',
            'adminUser' => $current['user'],
            'current' => $current,
            'm1Applied' => AdminDatabase::available(),
        ], 'admin');
    }

    public static function audit(): void
    {
        $current = AdminGuard::require(['permission' => 'audit.view']);

        try {
            $events = AuditRepository::recent(50);
        } catch (RepositoryException) {
            $events = [];
        }

        View::render('admin/audit', [
            'pageTitle' => 'Auditoría de acceso | Origen Salud',
            'pageDescription' => 'Historial de autenticación y decisiones.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin/audit',
            'adminUser' => $current['user'],
            'events' => $events,
        ], 'admin');
    }
}
