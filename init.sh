#!/usr/bin/env bash
# init.sh — Verificación del entorno y del estado del proyecto.
#
# Se ejecuta al EMPEZAR cada sesión y antes de declarar cualquier feature
# como `done`. Si termina en rojo, la sesión no avanza.
#
# Uso:
#   ./init.sh           verificación completa (con pruebas)
#   ./init.sh --rapido  sin correr las pruebas (solo para mirar el estado)
#
# En Windows se corre desde Git Bash (la misma terminal que usa Claude Code).

set -u
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

RAPIDO=0
if [ "${1:-}" = "--rapido" ]; then RAPIDO=1; fi

cd "$(dirname "$0")" || exit 1
EXIT_CODE=0

echo "── 1. Entorno ──────────────────────────────────────────"

for herramienta in flutter dart; do
  if ! command -v "$herramienta" >/dev/null 2>&1; then
    fail "$herramienta no está instalado o no está en el PATH"
    exit 1
  fi
done
ok "$(flutter --version 2>/dev/null | head -1)"
ok "$(dart --version 2>&1 | head -1)"

echo ""
echo "── 2. Archivos base del arnés ──────────────────────────"

for f in AGENTS.md CLAUDE.md CHECKPOINTS.md feature_list.json \
         progress/current.md progress/history.md \
         docs/architecture.md docs/conventions.md docs/specs.md docs/verification.md \
         tool/validar_harness.dart; do
  if [ -f "$f" ]; then
    ok "Existe $f"
  else
    fail "Falta $f"
    EXIT_CODE=1
  fi
done

echo ""
echo "── 3. feature_list.json y specs ────────────────────────"

if dart run tool/validar_harness.dart; then
  :
else
  EXIT_CODE=1
fi

echo ""
echo "── 4. Dependencias y analizador ────────────────────────"

if flutter pub get >/dev/null 2>&1; then
  ok "flutter pub get"
else
  fail "flutter pub get falló (corré 'flutter pub get' para ver el error)"
  EXIT_CODE=1
fi

if (cd backend && dart pub get >/dev/null 2>&1); then
  ok "dart pub get en backend/"
else
  fail "dart pub get falló en backend/"
  EXIT_CODE=1
fi

if flutter analyze --no-pub; then
  ok "flutter analyze sin avisos"
else
  fail "flutter analyze encontró problemas"
  EXIT_CODE=1
fi

if (cd backend && dart analyze); then
  ok "dart analyze sin avisos en backend/"
else
  fail "dart analyze encontró problemas en backend/"
  EXIT_CODE=1
fi

echo ""
echo "── 5. Pruebas ──────────────────────────────────────────"

if [ $RAPIDO -eq 1 ]; then
  warn "Modo --rapido: no se corrieron las pruebas. No sirve para cerrar una feature."
else
  if flutter test --no-pub; then
    ok "Pruebas de la app"
  else
    fail "Hay pruebas de la app que fallan"
    EXIT_CODE=1
  fi

  if (cd backend && dart test); then
    ok "Pruebas del backend"
  else
    fail "Hay pruebas del backend que fallan"
    EXIT_CODE=1
  fi
fi

echo ""
echo "── 6. Resumen ──────────────────────────────────────────"

if [ $EXIT_CODE -eq 0 ]; then
  ok "Entorno listo. Podés empezar a trabajar."
else
  fail "El entorno NO está listo. Resolvé los errores antes de avanzar."
fi

exit $EXIT_CODE
