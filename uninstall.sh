#!/usr/bin/env bash
# uninstall.sh — удаление Civ4 Colonization, установленной через install.sh.
# По умолчанию удаляет только лаунчер и ярлыки. Префикс Wine и саму игру —
# только если вы подтвердите (сохранения лежат в папке игры → Saves).
set -uo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/civ4col"
CONF="$CONF_DIR/civ4col.conf"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

ask() { local a; read -r -p "$1 [y/N] " a </dev/tty; [[ "$a" =~ ^[YyДд] ]]; }

GAME_DIR="" WINEPREFIX="" INSTALLED_BY_US=0
# shellcheck source=/dev/null
[ -f "$CONF" ] && . "$CONF"

echo "Удаление Civ4 Colonization (RaR/KLT)"
rm -f "$HOME/.local/bin/civ4col" "$APPS_DIR/civ4col.desktop" \
      "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps/civ4col.png"
dd="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
rm -f "$dd/civ4col.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database -q "$APPS_DIR" 2>/dev/null
echo "✓ лаунчер и ярлыки удалены"

if [ -n "$WINEPREFIX" ] && [ -d "$WINEPREFIX" ]; then
    if ask "Удалить префикс Wine $WINEPREFIX ($(du -sh "$WINEPREFIX" 2>/dev/null | cut -f1))?"; then
        WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null
        rm -rf -- "$WINEPREFIX" && echo "✓ префикс удалён"
    fi
fi

if [ "$INSTALLED_BY_US" = 1 ] && [ -n "$GAME_DIR" ] && [ -d "$GAME_DIR" ]; then
    echo "ВНИМАНИЕ: в $GAME_DIR/Saves лежат ваши сохранения."
    if ask "Удалить папку игры $GAME_DIR ($(du -sh "$GAME_DIR" 2>/dev/null | cut -f1))?"; then
        rm -rf -- "$GAME_DIR" && echo "✓ игра удалена"
    fi
elif [ -n "$GAME_DIR" ]; then
    echo "Папку игры $GAME_DIR не трогаю — она была у вас до установки."
fi

echo "Готово. Пакеты Wine остаются в системе (удалить: sudo apt remove wine …)."
rm -rf -- "$CONF_DIR"
