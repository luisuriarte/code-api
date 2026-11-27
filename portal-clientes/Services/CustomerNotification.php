<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\Portal\Services\SmtpMailer;

/**
 * Notificaciones transaccionales del portal de clientes.
 *
 * Reutiliza el transporte SMTP ya existente del portal público sin iniciar su
 * sesión. El token sin cifrar viaja solo por correo al destinatario legítimo:
 * nunca se devuelve en pantalla, se guarda en flash ni se escribe en logs.
 */
final class CustomerNotification
{
    /** @return array{ok: bool, error: ?string} */
    public static function passwordReset(string $email, string $rawToken): array
    {
        $link = Config::baseUrl() . '/' . CustomerI18n::locale() . '/reset/' . rawurlencode($rawToken);
        $subject = CustomerI18n::t('customer.mail.reset.subject');
        $text = CustomerI18n::t('customer.mail.reset.text', ['%link%' => $link]);

        return self::send($email, $subject, $text, 'password_reset');
    }

    /** @return array{ok: bool, error: ?string} */
    public static function invitation(string $email, string $organization, string $rawToken): array
    {
        $link = Config::baseUrl() . '/' . CustomerI18n::locale() . '/invitations/' . rawurlencode($rawToken);
        $subject = CustomerI18n::t('customer.mail.invitation.subject');
        $text = CustomerI18n::t('customer.mail.invitation.text', [
            '%organization%' => $organization,
            '%link%' => $link,
        ]);

        return self::send($email, $subject, $text, 'invitation');
    }

    /**
     * @return array{ok: bool, error: ?string}
     */
    private static function send(string $email, string $subject, string $text, string $kind): array
    {
        $result = SmtpMailer::send(
            $email,
            $subject,
            $text,
            nl2br(e($text), false),
            null,
            self::bcc()
        );

        if ($result['ok']) {
            return ['ok' => true, 'error' => null];
        }

        // Solo el código de error y un detalle aplanado; nunca el token ni credenciales.
        error_log('customer notification failed: ' . $kind . ' | ' . (string) ($result['error'] ?? 'unknown'));

        return ['ok' => false, 'error' => is_string($result['error'] ?? null) ? $result['error'] : 'mail_failed'];
    }

    /** @return list<string> */
    private static function bcc(): array
    {
        $raw = trim((string) env('PORTAL_CUSTOMER_NOTIFICATION_BCC', ''));

        if ($raw === '') {
            return [];
        }

        $addresses = [];
        foreach (preg_split('/[,;]/', $raw) ?: [] as $candidate) {
            $email = strtolower(trim($candidate));

            if ($email !== '' && filter_var($email, FILTER_VALIDATE_EMAIL) !== false
                && count($addresses) < 5 && !in_array($email, $addresses, true)) {
                $addresses[] = $email;
            }
        }

        return $addresses;
    }
}
