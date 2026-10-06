#!/bin/bash
# Один раз: разрешить ровно два вызова pmset без пароля.
# Пароль спрашивается системным диалогом (sudo требует tty, osascript — нет).
set -e
cd "$(dirname "$0")"

TMP=$(mktemp)
printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0\n' "$(id -un)" > "$TMP"

osascript -e "do shell script \"install -m 440 -o root -g wheel '$TMP' /etc/sudoers.d/aimode && /usr/sbin/visudo -c -f /etc/sudoers.d/aimode || rm -f /etc/sudoers.d/aimode\" with administrator privileges"
rm -f "$TMP"

if sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null; then
  echo "OK: переключение без пароля работает"
else
  echo "FAIL: правило не применилось, /etc/sudoers.d/aimode не установлен"
  exit 1
fi
