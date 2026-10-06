#!/bin/bash
# Проверка парсинга pmset: вывод --status должен совпадать с реальным флагом.
set -e
cd "$(dirname "$0")"
BIN="./AI Sleep.app/Contents/MacOS/AISleep"
want=$(pmset -g | awk '/SleepDisabled/ {print $2}'); want=${want:-0}
got=$("$BIN" --status)
[ "$want" = "$got" ] || { echo "FAIL: pmset=$want app=$got"; exit 1; }
echo "OK: SleepDisabled=$got"
