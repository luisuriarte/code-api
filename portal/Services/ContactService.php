<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

use OrigenSalud\Portal\Config;

/**
 * Procesa el formulario de contacto: valida, aplica defensas anti-spam y
 * notifica por SMTP y opcionalmente por OpenWA. Nunca expone credenciales.
 */
final class ContactService
{
    private const TYPES = ['commercial', 'technical', 'integration', 'catalogs', 'docs', 'other'];

    /** @return array{ok: bool, error: ?string, fields: array<string, string>} */
    public static function submit(array $post, string $locale): array
    {
        $name = Validator::text($post['name'] ?? '', 120);
        $company = Validator::text($post['company'] ?? '', 160);
        $email = Validator::email($post['email'] ?? '');
        $country = Validator::text($post['country'] ?? '', 100);
        $type = Validator::choice($post['type'] ?? '', self::TYPES);
        $message = Validator::text($post['message'] ?? '', 5000);
        $website = Validator::text($post['website'] ?? '', 255);

        $fields = [
            'name' => $name,
            'company' => $company,
            'email' => $email,
            'country' => $country,
            'type' => $type,
            'message' => $message,
        ];

        if (!Csrf::valid(isset($post[Csrf::FIELD]) && is_string($post[Csrf::FIELD]) ? $post[Csrf::FIELD] : null)) {
            return self::failure('csrf_error', $fields);
        }

        if ($website !== '') {
            return self::failure('spam_error', $fields);
        }

        $createdAt = Validator::text($post['created_at'] ?? '', 64);
        if ($createdAt === '' || !ctype_digit($createdAt) || time() - (int) $createdAt < 3) {
            return self::failure('spam_error', $fields);
        }

        if ($name === '' || $email === '' || $type === '') {
            return self::failure('validation_required', $fields);
        }

        $messageLength = mb_strlen($message);
        if ($messageLength < 10 || $messageLength > 5000) {
            return self::failure('validation_message_length', $fields);
        }

        $limits = Config::rateLimits();
        if (!RateLimiter::hit('contact', $limits['contact'], $limits['window'])) {
            return self::failure('rate_error', $fields);
        }

        $t = static fn (string $key): string => trans('contact.' . $key, [], $locale);
        $typeLabel = $t('type_' . $type);
        $subject = $t('email_subject') . ' — ' . $typeLabel . ' (' . $locale . ')';
        $lines = [
            'Nombre: ' . $name,
            'Empresa: ' . ($company !== '' ? $company : '-'),
            'Email: ' . $email,
            'País: ' . ($country !== '' ? $country : '-'),
            'Tipo: ' . $typeLabel,
            'Idioma: ' . $locale,
            '',
            $message,
        ];
        $textBody = implode("\n", $lines);
        $htmlBody = nl2br(e($textBody), false);

        $mail = SmtpMailer::send(Config::contactEmail(), $subject, $textBody, $htmlBody, $email, Config::contactBcc());
        if (!$mail['ok']) {
            $reason = is_string($mail['error'] ?? null) ? $mail['error'] : 'mail_failed';
            $detail = is_string($mail['detail'] ?? null) ? trim($mail['detail']) : '';
            error_log('contact mail failed: ' . $reason . ($detail !== '' ? ' | ' . $detail : ''));
            return self::failure('error_text', $fields, $reason);
        }

        if (OpenWaClient::configured()) {
            OpenWaClient::notify(
                $t('whatsapp_prefix') . ': ' . $name . ' (' . $email . ")\n" . mb_substr($message, 0, 800)
            );
        }

        Csrf::rotate();

        return ['ok' => true, 'error' => null, 'fields' => []];
    }

    /**
     * @param array<string, string> $fields
     * @return array{ok: bool, error: ?string, fields: array<string, string>, reason: ?string}
     */
    private static function failure(string $error, array $fields, ?string $reason = null): array
    {
        return ['ok' => false, 'error' => $error, 'fields' => $fields, 'reason' => $reason];
    }
}
