#!/usr/bin/env bash

## COMO USAR:
## export USER_ACCESS_KEY='SUA_ACCESS_KEY'
## export USER_SECRET_KEY='SUA_SECRET_KEY'
# export MC_INSECURE=1
##
## Para arquivo:
## export LOGS_PATH='/var/log/alternatives.log'
##
## Para pasta:
## export LOGS_PATH='/var/log/'
##
## bash ./cli-bucket-minio-s3.sh

set -euo pipefail

## ======== CONFIG ========
MINIO_ENDPOINT="${MINIO_ENDPOINT:-https://s3-api.edu.br}"

# credenciais obrigatórias
: "${USER_ACCESS_KEY:?defina USER_ACCESS_KEY no ambiente}"
: "${USER_SECRET_KEY:?defina USER_SECRET_KEY no ambiente}"

# bucket
BUCKET="backup-logs"
LOGS_PATH="${LOGS_PATH:-/var/log/alternatives.log}"   # ex.: /var/log/  ou  /var/log/alternatives.log
S3_PREFIX="${S3_PREFIX:-logs}"                        # subpasta no bucket
ALIAS="s3"

# flags por comando
# -> alias set aceita --api/--path
MC_ALIAS_FLAGS=(--api S3v4 --path on)
# -> cp NÃO aceita --api/--path; só --insecure (global)
MC_CP_FLAGS=()
if [[ "${MC_INSECURE:-0}" == "1" ]]; then
  MC_ALIAS_FLAGS=(--insecure "${MC_ALIAS_FLAGS[@]}")
  MC_CP_FLAGS=(--insecure)
fi

## instalar CLI
if ! command -v mc >/dev/null 2>&1; then
  echo "[INFO] Instalando MinIO Client (mc)..."
  curl -sSLo mc https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod +x mc
  if command -v sudo >/dev/null 2>&1; then sudo mv mc /usr/local/bin/; else mv mc /usr/local/bin/; fi
fi

## alias mc
echo "[INFO] Removendo alias existente..."
mc alias rm "$ALIAS" >/dev/null 2>&1 || true

echo "[INFO] Configurando alias '$ALIAS'..."
mc alias set "$ALIAS" "$MINIO_ENDPOINT" "$USER_ACCESS_KEY" "$USER_SECRET_KEY" "${MC_ALIAS_FLAGS[@]}" >/dev/null

## API bucket
if mc ls "$ALIAS/$BUCKET" >/dev/null 2>&1; then
  echo "[INFO] Bucket '$BUCKET' já existe."
else
  echo "[INFO] Criando bucket '$BUCKET'..."
  mc mb "$ALIAS/$BUCKET"
fi

if [[ ! -e "$LOGS_PATH" ]]; then
  echo "[ERRO] Origem '$LOGS_PATH' não existe."; exit 1
fi

## destino
HOSTNAME_TAG="${HOSTNAME_TAG:-$(hostname -s || echo host)}"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"
DEST="$ALIAS/$BUCKET/$S3_PREFIX/$HOSTNAME_TAG/$DATE_TAG/"

## upload para bucket
if [[ -d "$LOGS_PATH" ]]; then
  echo "[INFO] Detectado diretório. Enviando recursivamente..."
  SRC_DIR="${LOGS_PATH%/}"
  mc cp --recursive --attr "x-amz-meta-source=$HOSTNAME_TAG" "${MC_CP_FLAGS[@]}" "$SRC_DIR" "$DEST"
else
  echo "[INFO] Detectado arquivo. Enviando arquivo..."
  mc cp --attr "x-amz-meta-source=$HOSTNAME_TAG" "${MC_CP_FLAGS[@]}" "$LOGS_PATH" "$DEST"
fi

echo "====================================================="
echo "Upload concluído."
echo "Endpoint:   $MINIO_ENDPOINT"
echo "Bucket:     $BUCKET"
echo "Destino:    s3://$BUCKET/$S3_PREFIX/$HOSTNAME_TAG/$DATE_TAG/"
echo "Origem:     $LOGS_PATH"
echo "Path-Style: on"
echo "Insecure:   ${MC_INSECURE:-0}"
echo "====================================================="
