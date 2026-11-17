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

    /** @return array{ok: bool, error: ?string} */
    public static function send(string $to, string $subject, string $textBody, string $htmlBody = ''): array
    {
        $config = Config::smtp();

        if ($config['host'] === '' || $config['from'] === '' || $config['user'] === '') {
            return ['ok' => false, 'error' => 'smtp_not_configured'];
        }

        if (!self::validEmail($to)) {
            return ['ok' => false, 'error' => 'invalid_recipient'];
        }

        $socket = self::connect($config['host'], $config['port']);
        if ($socket === null) {
            return ['ok' => false, 'error' => 'smtp_connect_failed'];
        }

        try {
            $greeting = self::read($socket);
            if (!self::hasCode($greeting, 220)) {
                return ['ok' => false, 'error' => 'smtp_greeting_failed'];
            }

            $helloDomain = self::helloDomain($config['host']);
            self::write($socket, 'EHLO ' . $helloDomain);
            $ehlo = self::readMultiline($socket);

            $supportsUtf8 = stripos($ehlo, 'SMTPUTF8') !== false;
            $supportsStarttls = stripos($ehlo, 'STARTTLS') !== false;
            $usesImplicitTls = $config['port'] === 465;

            if ($usesImplicitTls) {
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    return ['ok' => false, 'error' => 'smtp_tls_failed'];
                }

                self::write($socket, 'EHLO ' . $helloDomain);
                $ehlo = self::readMultiline($socket);
                $supportsUtf8 = stripos($ehlo, 'SMTPUTF8') !== false;
            } elseif ($supportsStarttls) {
                self::write($socket, 'STARTTLS');
                if (!self::hasCode(self::read($socket), 220)) {
                    return ['ok' => false, 'error' => 'smtp_starttls_failed'];
                }

                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    return ['ok' => false, 'error' => 'smtp_tls_failed'];
                }

                self::write($socket, 'EHLO ' . $helloDomain);
                $ehlo = self::readMultiline($socket);
                $supportsUtf8 = stripos($ehlo, 'SMTPUTF8') !== false;
            } elseif (strtolower((string) env('SMTP_ALLOW_INSECURE', 'false')) !== 'true') {
                return ['ok' => false, 'error' => 'smtp_requires_tls'];
            }

            if (!self::authenticate($socket, $config['user'], $config['pass'], $ehlo)) {
                return ['ok' => false, 'error' => 'smtp_auth_failed'];
            }

            self::write($socket, 'MAIL FROM:<' . $config['from'] . '>' . ($supportsUtf8 ? ' SMTPUTF8' : ''));
            if (!self::hasCode(self::read($socket), 250)) {
                return ['ok' => false, 'error' => 'smtp_mail_from_failed'];
            }

            self::write($socket, 'RCPT TO:<' . $to . '>');
            if (!self::hasCode(self::read($socket), [250, 251])) {
                return ['ok' => false, 'error' => 'smtp_rcpt_failed'];
            }

            self::write($socket, 'DATA');
            if (!self::hasCode(self::read($socket), 354)) {
                return ['ok' => false, 'error' => 'smtp_data_failed'];
            }

            $message = self::buildMessage($config, $to, $subject, $textBody, $htmlBody);
            self::writeData($socket, $message);

            if (!self::hasCode(self::read($socket), 250)) {
                return ['ok' => false, 'error' => 'smtp_send_failed'];
            }

            self::write($socket, 'QUIT');
            self::read($socket);

            return ['ok' => true, 'error' => null];
        } finally {
            fclose($socket);
        }
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

    /** @param array{from: string, from_name: string} $config */
    private static function buildMessage(array $config, string $to, string $subject, string $textBody, string $htmlBody): string
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
