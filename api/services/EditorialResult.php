<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

/**
 * Contrato de salida con idioma efectivo por campo (D-38).
 */
final class EditorialResult
{
    /**
     * @param array<string, mixed> $values
     * @param array<string, array<string, mixed>> $fieldLanguages
     * @param array<string, mixed> $meta
     * @param list<array{code: string, selectable: bool}> $availableLanguages
     */
    public function __construct(
        private readonly array $values,
        private readonly array $fieldLanguages,
        private readonly array $meta,
        private readonly array $availableLanguages,
        private readonly ?string $contentLanguage,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function values(): array
    {
        return $this->values;
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    public function fieldLanguages(): array
    {
        return $this->fieldLanguages;
    }

    /**
     * @return array<string, mixed>
     */
    public function meta(): array
    {
        return $this->meta;
    }

    /**
     * @return array<string, string>
     */
    public function headers(): array
    {
        $headers = ['Vary' => 'Accept-Language'];

        if ($this->contentLanguage !== null && $this->contentLanguage !== '') {
            $headers['Content-Language'] = $this->contentLanguage;
        }

        return $headers;
    }

    /**
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function toArray(): array
    {
        $meta = $this->meta;
        $meta['available_languages'] = $this->availableLanguages;
        $meta['field_languages'] = $this->fieldLanguages;

        return [
            'data' => $this->values,
            'meta' => $meta,
        ];
    }
}
