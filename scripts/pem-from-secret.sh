#!/usr/bin/env bash
# Build a PEM file from a CI secret that holds the base64 body of a certificate
# or private key. Tolerates common copy/paste mistakes (BEGIN/END lines included,
# CRLF line endings, blank lines, everything on one line) and prints a diagnosis
# that does not reveal the secret if the result cannot be parsed.
#
# Usage: pem-from-secret.sh <CERTIFICATE|PRIVATE KEY> <env var name> <out.pem>
set -euo pipefail

TYPE="${1:?type}"; VAR="${2:?env var}"; OUT="${3:?output file}"
RAW="${!VAR:-}"

body=$(printf '%s' "$RAW" | tr -d '\r' | grep -v -- '-----' | tr -d ' \t\n')
{
  echo "-----BEGIN ${TYPE}-----"
  printf '%s\n' "$body" | fold -w 64
  echo "-----END ${TYPE}-----"
} > "$OUT"

if [ "$TYPE" = "CERTIFICATE" ]; then
  openssl x509 -in "$OUT" -noout 2>/dev/null && exit 0
else
  openssl pkey -in "$OUT" -noout 2>/dev/null && exit 0
fi

kind="unknown content"
if printf '%s' "$body" | base64 -d 2>/dev/null | openssl x509 -inform DER -noout 2>/dev/null; then
  kind="a certificate"
elif printf '%s' "$body" | base64 -d 2>/dev/null | openssl pkey -inform DER -noout 2>/dev/null; then
  kind="a private key"
elif ! printf '%s' "$body" | base64 -d >/dev/null 2>&1; then
  kind="not valid base64 (truncated or extra characters?)"
fi
echo "::error::Secret ${VAR} could not be parsed as ${TYPE}: ${#RAW} chars, $(printf '%s\n' "$RAW" | wc -l) lines, content looks like ${kind}."
exit 1
