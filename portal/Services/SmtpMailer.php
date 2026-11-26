<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

use OrigenSalud\Portal\Config;

/**
 * Cliente SMTP mínimo sobre streams de PHP, sin dependencias nuevas.
 *
 * Soporta STARTTLS (puerto 587) y TLS implícito (puerto 465), AUTH LOGIN
 * y mensajes SMTPUTF8 cuando el servidor lo anuncia.
 */
final class SmtpMailer
{
    private const TIMEOUT = 10;

    /**
     * @param string|null $replyTo Dirección validada del remitente humano; nunca reemplaza al destinatario.
     * @param list<string> $bcc Copias ocultas: se agregan como RCPT TO, nunca como cabecera.
     * @return array{ok: bool, error: ?string, detail?: ?string}
     */
    public static function send(
        string $to,
        string $subject,
        string $textBody,
        string $htmlBody = '',
        ?string $replyTo = null,
        array $bcc = []
    ): array
    {
        $config = Config::smtp();

        if ($config['host'] === '' || $config['from'] === '' || $config['user'] === '') {
            return self::fail('smtp_not_configured');
        }

        if (!self::validEmail($to)) {
            return self::fail('invalid_recipient');
        }

        $socket = self::connect($config['host'], $config['port']);
        if ($socket === null) {
            return self::fail('smtp_connect_failed');
        }

        try {
            $greeting = self::read($socket);
            if (!self::hasCode($greeting, 220)) {
                return self::fail('smtp_greeting_failed', $greeting);
            }

            $helloDomain = self::helloDomain($config['host']);
            self::write($socket, 'EHLO ' . $helloDomain);
            $ehlo = self::readMultiline($socket);

            $supportsUtf8 = stripos($ehlo, 'SMTPUTF8') !== false;
            $supportsStarttls = stripos($ehlo, 'STARTTLS') !== false;
            $usesImplicitTls = $config['port'] === 465;

            if ($usesImplicitTls) {
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    return self::fail('smtp_tls_failed');
                }

                self::write($socket, 'EHLO ' . $helloDomain);
                $ehlo = self::readMultiline($socket);
                $supportsUtf8 = stripos($ehlo, 'SMTPUTF8') !== false;
            } elseif ($supportsStarttls) {
                self::write($socket, 'STARTTLS');
                $starttls = self::read($socket);
                if (!self::hasCode($starttls, 220)) {
                    return self::fail('smtp_starttls_failed', $starttls);
                }

                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    return self::fail('smtp_tls_failed');
                }

                self::write($socket, 'EHLO ' . $helloDomain);
                $ehlo = self::readMultiline($socket);
                $supportsUtf8 = stripos($ehlo, 'SMTPUTF8') !== false;
            } elseif (strtolower((string) env('SMTP_ALLOW_INSECURE', 'false')) !== 'true') {
                return self::fail('smtp_requires_tls');
            }

            if (!self::authenticate($socket, $config['user'], $config['pass'], $ehlo)) {
                return self::fail('smtp_auth_failed');
            }

            self::write($socket, 'MAIL FROM:<' . $config['from'] . '>' . ($supportsUtf8 ? ' SMTPUTF8' : ''));
            $mailFrom = self::read($socket);
            if (!self::hasCode($mailFrom, 250)) {
                return self::fail('smtp_mail_from_failed', $mailFrom);
            }

            $recipients = [$to];
            foreach ($bcc as $bccAddress) {
                if (is_string($bccAddress) && strcasecmp($bccAddress, $to) !== 0) {
                    $recipients[] = $bccAddress;
                }
            }

            $rejectedBcc = 0;
            foreach ($recipients as $index => $recipient) {
                self::write($socket, 'RCPT TO:<' . $recipient . '>');
                $rcpt = self::read($socket);

                if (self::hasCode($rcpt, [250, 251])) {
                    continue;
                }

                // Si falla el destinatario principal no hay mensaje que enviar.
                if ($index === 0) {
                    return self::fail('smtp_rcpt_failed', $rcpt);
                }

                // Una copia oculta rechazada no debe impedir la notificación principal.
                $rejectedBcc++;
            }

            self::write($socket, 'DATA');
            $data = self::read($socket);
            if (!self::hasCode($data, 354)) {
                return self::fail('smtp_data_failed', $data);
            }

            $message = self::buildMessage($config, $to, $subject, $textBody, $htmlBody, $replyTo);
            self::writeData($socket, $message);

            $sent = self::read($socket);
            if (!self::hasCode($sent, 250)) {
                return self::fail('smtp_send_failed', $sent);
            }

            self::write($socket, 'QUIT');
            self::read($socket);

            return [
                'ok' => true,
                'error' => null,
                'detail' => $rejectedBcc > 0 ? 'bcc_rejected:' . $rejectedBcc : null,
            ];
        } finally {
            fclose($socket);
        }
    }

    /**
     * Error uniforme. `detail` es la respuesta cruda del servidor SMTP, ya
     * aplanada y truncada: nunca incluye credenciales, solo el código y el
     * mensaje (por ejemplo `550 5.1.1 ... User unknown`).
     *
     * @return array{ok: false, error: string, detail: ?string}
     */
    private static function fail(string $error, string $detail = ''): array
    {
        $detail = trim(preg_replace('/[\r\n]+/', ' ', $detail) ?? '');

        return [
            'ok' => false,
            'error' => $error,
            'detail' => $detail === '' ? null : mb_substr($detail, 0, 300),
        ];
    }

    private static function connect(string $host, int $port)
    {
        $context = stream_context_create([
            'ssl' => [
                'verify_peer' => true,
                'verify_peer_name' => true,
                'SNI_enabled' => true,
                'peer_name' => $host,
            ],
        ]);

        $remote = 'tcp://' . $host . ':' . $port;

        return @stream_socket_client($remote, $errno, $error, self::TIMEOUT, STREAM_CLIENT_CONNECT, $context) ?: null;
    }

    private static function authenticate($socket, string $user, string $password, string $ehlo): bool
    {
        if (stripos($ehlo, 'AUTH ') === false) {
            return false;
        }

        self::write($socket, 'AUTH LOGIN');
        if (!self::hasCode(self::read($socket), 334)) {
            return false;
        }

        self::write($socket, base64_encode($user));
        if (!self::hasCode(self::read($socket), 334)) {
            return false;
        }

        self::write($socket, base64_encode($password));

        return self::hasCode(self::read($socket), 235);
    }

    /** @param list<int>|int $codes */
    private static function hasCode(string $response, int|array $codes): bool
    {
        $codes = is_array($codes) ? $codes : [$codes];

        foreach ($codes as $code) {
            if (str_starts_with($response, (string) $code)) {
                return true;
            }
        }

        return false;
    }

    private static function read($socket): string
    {
        $line = fgets($socket, 8192);

        return $line === false ? '' : rtrim($line, "\r\n");
    }

    private static function readMultiline($socket): string
    {
        $output = '';

        for ($i = 0; $i < 100; $i++) {
            $line = self::read($socket);

            if ($line === '') {
                break;
            }

            $output .= $line . "\n";

            if (strlen($line) < 4 || $line[3] !== '-') {
                break;
            }
        }

        return $output;
    }

    private static function write($socket, string $line): void
    {
        fwrite($socket, $line . "\r\n");
    }

    private static function writeData($socket, string $message): void
    {
        fwrite($socket, self::dotStuff($message) . "\r\n.\r\n");
    }

    private static function dotStuff(string $message): string
    {
        $message = str_replace(["\r\n", "\r"], "\n", $message);
        $message = preg_replace('/(?m)^\./', '..', $message) ?? $message;

        return str_replace("\n", "\r\n", $message);
    }

    /**
     * @param array{from: string, from_name: string} $config
     * @param string|null $replyTo Solo se usa si pasa validación de email.
     */
    private static function buildMessage(array $config, string $to, string $subject, string $textBody, string $htmlBody, ?string $replyTo = null): string
    {
        $boundary = 'origen-' . bin2hex(random_bytes(16));
        $from = self::encodeHeader($config['from_name']) . ' <' . $config['from'] . '>';
        $headers = [
            'From: ' . $from,
            'To: ' . $to,
            'Subject: ' . self::encodeHeader($subject),
            'Date: ' . date(DATE_RFC2822),
            'Message-ID: <' . bin2hex(random_bytes(16)) . '@origen.ar>',
            'MIME-Version: 1.0',
            'Content-Type: multipart/alternative; boundary="' . $boundary . '"',
            'Content-Transfer-Encoding: 8bit',
        ];

        if ($replyTo !== null && self::validEmail($replyTo)) {
            $headers[] = 'Reply-To: <' . $replyTo . '>';
        }

        $body = '--' . $boundary . "\n";
        $body .= "Content-Type: text/plain; charset=UTF-8\n";
        $body .= "Content-Transfer-Encoding: 8bit\n\n";
        $body .= $textBody . "\n\n";

        if ($htmlBody !== '') {
            $body .= '--' . $boundary . "\n";
            $body .= "Content-Type: text/html; charset=UTF-8\n";
            $body .= "Content-Transfer-Encoding: 8bit\n\n";
            $body .= $htmlBody . "\n\n";
        }

        $body .= '--' . $boundary . "--\n";

        return implode("\r\n", $headers) . "\r\n\r\n" . $body;
    }

    private static function encodeHeader(string $value): string
    {
        return mb_check_encoding($value, 'ASCII') ? $value : '=?UTF-8?B?' . base64_encode($value) . '?=';
    }

    private static function helloDomain(string $host): string
    {
        $domain = filter_var($host, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME);

        return $domain === false ? 'localhost' : $domain;
    }

    private static function validEmail(string $email): bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }
}
