#!/usr/bin/env bash
# Rota la API Key del cliente de verificación OFTAR y la guarda sin mostrarla.
# Uso: sudo bash tools/rotar_clave_api.sh
set -euo pipefail

KEYFILE="/root/.origen_api_key"
CLIENTE="OFTAR · Verificación Browse/API"

sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes -Atc \
"UPDATE public.api_clients
    SET api_key = encode(gen_random_bytes(32), 'hex')
  WHERE institution_name = '${CLIENTE}' AND is_active = TRUE
  RETURNING api_key;" > "$KEYFILE"

chmod 600 "$KEYFILE"

printf 'Clave rotada y guardada en %s (%s bytes). No se mostró en pantalla.\n' \
  "$KEYFILE" "$(wc -c < "$KEYFILE")"
