<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use PDO;

/**
 * Configuración lingüística del sistema (D-15, D-27, D-30, D-39).
 *
 * Solo expone os_language, os_language_alias y os_catalog_language.
 * No consulta tablas de contenido, estados editoriales ni texto: eso
 * pertenece al evaluador editorial (D-30).
 */
final class LanguageCatalog
{
    /**
     * @param array<string, array{
     *     code: string,
     *     display_name: string,
     *     primary_tag: string,
     *     is_active: bool,
     *     is_source_only: bool
     * }> $languages
     * @param array<string, string> $aliases alias normalizado => código canónico
     * @param array<int, array<string, array{
     *     is_default: bool,
     *     is_fallback: bool,
     *     is_bridge: bool,
     *     coverage_status: string
     * }>> $catalogLanguages
     */
    private function __construct(
        private readonly array $languages,
        private readonly array $aliases,
        private readonly array $catalogLanguages,
        /** @var array<string, string> */
        private readonly array $index,
    ) {
    }

    /**
     * Carga únicamente las tablas de configuración idiomática.
     */
    public static function fromPdo(PDO $pdo, ?int $catalogId): self
    {
        $languages = [];
        $statement = $pdo->query(
            'SELECT code, display_name, primary_tag, is_active, is_source_only
               FROM os_language ORDER BY code'
        );

        foreach ($statement->fetchAll() as $row) {
            $code = (string) $row['code'];
            $languages[$code] = [
                'code' => $code,
                'display_name' => (string) $row['display_name'],
                'primary_tag' => (string) $row['primary_tag'],
                'is_active' => (bool) $row['is_active'],
                'is_source_only' => (bool) $row['is_source_only'],
            ];
        }

        $aliases = [];
        $statement = $pdo->query(
            'SELECT lower(alias) AS alias, language_code FROM os_language_alias'
        );

        foreach ($statement->fetchAll() as $row) {
            $aliases[strtolower(trim((string) $row['alias']))] = (string) $row['language_code'];
        }

        $catalogLanguages = [];

        if ($catalogId !== null) {
            $statement = $pdo->prepare(
                'SELECT language_code, is_default, is_fallback, is_bridge, coverage_status
                   FROM os_catalog_language
                  WHERE catalog_id = :catalog_id
                  ORDER BY language_code'
            );
            $statement->execute(['catalog_id' => $catalogId]);

            foreach ($statement->fetchAll() as $row) {
                $catalogLanguages[$catalogId][(string) $row['language_code']] = [
                    'is_default' => (bool) $row['is_default'],
                    'is_fallback' => (bool) $row['is_fallback'],
                    'is_bridge' => (bool) $row['is_bridge'],
                    'coverage_status' => (string) $row['coverage_status'],
                ];
            }
        }

        return self::fromArrays($languages, $aliases, $catalogLanguages);
    }

    /**
     * Constructor para pruebas y consumidores que ya cargaron la configuración.
     *
     * @param array<string, array{
     *     code: string,
     *     display_name: string,
     *     primary_tag: string,
     *     is_active: bool,
     *     is_source_only: bool
     * }> $languages
     * @param array<string, string> $aliases
     * @param array<int, array<string, array{
     *     is_default: bool,
     *     is_fallback: bool,
     *     is_bridge: bool,
     *     coverage_status: string
     * }>> $catalogLanguages
     */
    public static function fromArrays(array $languages, array $aliases, array $catalogLanguages = []): self
    {
        $canonical = [];
        $normalizedAliases = [];

        foreach ($languages as $code => $language) {
            $canonicalCode = (string) ($language['code'] ?? $code);
            $canonical[$canonicalCode] = [
                'code' => $canonicalCode,
                'display_name' => (string) ($language['display_name'] ?? $canonicalCode),
                'primary_tag' => (string) ($language['primary_tag'] ?? 'und'),
                'is_active' => (bool) ($language['is_active'] ?? false),
                'is_source_only' => (bool) ($language['is_source_only'] ?? false),
            ];
        }

        foreach ($aliases as $alias => $languageCode) {
            $normalizedAliases[strtolower(trim((string) $alias))] = (string) $languageCode;
        }

        return new self($canonical, $normalizedAliases, $catalogLanguages, self::buildIndex($canonical));
    }

    /**
     * Canonicaliza un código de contenido. NO aplica alias: `es` es una
     * etiqueta de origen válida y no debe reescribirse a `es-AR` (D-27).
     */
    public function canonical(?string $input): ?string
    {
        if ($input === null) {
            return null;
        }

        $value = strtolower(trim($input));

        return $value === '' ? null : ($this->index[$value] ?? null);
    }

    /**
     * Resuelve un input del cliente: alias primero, después código canónico.
     */
    public function resolveAlias(?string $input): ?string
    {
        if ($input === null) {
            return null;
        }

        $value = strtolower(trim($input));

        if ($value === '') {
            return null;
        }

        if (isset($this->aliases[$value])) {
            return $this->aliases[$value];
        }

        return $this->index[$value] ?? null;
    }

    /**
     * Código que el cliente puede pedir: activo y no source-only.
     */
    public function selectable(?string $input): ?string
    {
        $code = $this->resolveAlias($input);

        if ($code === null || !$this->isSelectable($code)) {
            return null;
        }

        return $code;
    }

    public function isSelectable(string $code): bool
    {
        return isset($this->languages[$code])
            && $this->languages[$code]['is_active']
            && !$this->languages[$code]['is_source_only'];
    }

    public function isSourceOnly(string $code): bool
    {
        return isset($this->languages[$code]) && $this->languages[$code]['is_source_only'];
    }

    public function primaryTag(string $code): ?string
    {
        return $this->languages[$code]['primary_tag'] ?? null;
    }

    /**
     * @return list<string>
     */
    public function activeCodes(): array
    {
        $codes = array_keys(array_filter(
            $this->languages,
            static fn (array $language): bool => $language['is_active'] && !$language['is_source_only']
        ));

        sort($codes, SORT_STRING);

        return $codes;
    }

    /**
     * @return array{is_default: bool, is_fallback: bool, is_bridge: bool, coverage_status: string}
     */
    public function catalogFlags(?int $catalogId, string $code): array
    {
        if ($catalogId === null) {
            return [
                'is_default' => false,
                'is_fallback' => false,
                'is_bridge' => false,
                'coverage_status' => 'undetermined',
            ];
        }

        return $this->catalogLanguages[$catalogId][$code] ?? [
            'is_default' => false,
            'is_fallback' => false,
            'is_bridge' => false,
            'coverage_status' => 'undetermined',
        ];
    }

    /**
     * Códigos configurados con una bandera determinada (is_fallback, is_bridge, is_default).
     *
     * @return list<string>
     */
    public function configuredCodes(?int $catalogId, string $flag): array
    {
        if ($catalogId === null || !isset($this->catalogLanguages[$catalogId])) {
            return [];
        }

        $codes = [];

        foreach ($this->catalogLanguages[$catalogId] as $code => $flags) {
            if (!empty($flags[$flag]) && $this->isKnown($code)) {
                $codes[] = $code;
            }
        }

        sort($codes, SORT_STRING);

        return $codes;
    }

    public function isKnown(string $code): bool
    {
        return isset($this->languages[$code]);
    }

    /**
     * @param array<string, array{code: string}> $languages
     *
     * @return array<string, string>
     */
    private static function buildIndex(array $languages): array
    {
        $index = [];

        foreach ($languages as $code => $language) {
            $index[strtolower($code)] = $code;
        }

        return $index;
    }
}
