<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\InvitationRepository;
use OrigenSalud\CustomerPortal\Services\AuthService;
use OrigenSalud\CustomerPortal\Services\CustomerCsrf;
use OrigenSalud\CustomerPortal\Services\CustomerSession;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\CustomerPortal\Services\Token;
use OrigenSalud\CustomerPortal\View;

final class InvitationController
{
    public static function show(string $token): void
    {
        $invitation = Token::isValidHex($token)
            ? InvitationRepository::findPendingByHash(Token::hash($token))
            : null;

        View::render('invitation/accept', [
            'title' => CustomerI18n::t('customer.invitation.title'),
            'token' => $token,
            'invitation' => $invitation,
        ]);
    }

    public static function acceptSubmit(string $token): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $post = Http::post();
        $fullName = trim((string) ($post['full_name'] ?? ''));
        $password = (string) ($post['password'] ?? '');

        if ($fullName === '' || mb_strlen($fullName) > 200 || mb_strlen($password) < 12) {
            CustomerSession::set('flash', ['key' => 'customer.invitation.invalid_data', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/invitations/' . rawurlencode($token));
        }

        $result = AuthService::acceptInvitation($token, $fullName, $password);

        CustomerSession::set('flash', [
            'key' => $result['ok'] ? 'customer.invitation.accepted' : (string) ($result['error_key'] ?? 'customer.invitation.invalid'),
            'params' => [],
        ]);
        Http::redirect(CustomerI18n::locale() . '/login');
    }
}
