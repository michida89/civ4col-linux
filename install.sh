#!/usr/bin/env bash
# install.sh — установщик Civilization IV: Colonization (RaR/KLT) для Linux.
#
# Что делает:
#   1. ставит Wine и 32-битные библиотеки (apt / dnf / pacman / zypper);
#   2. создаёт отдельный префикс Wine (~/.wine-civ4col);
#   3. распаковывает игру из архива (или берёт уже распакованную папку);
#   4. ставит лаунчер ~/.local/bin/civ4col, ярлык в меню и на рабочий стол.
#
# Запуск:  ./install.sh                      — всё найдёт и спросит сам
#          ./install.sh --archive "~/Загрузки/Telegram Desktop/Civilization 4.zip"
#          ./install.sh --game-dir "~/Games/Civ4ColKLT для распространения"
#          ./install.sh --help
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/civ4col"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
GAME_EXE="Colonization.exe"

ARCHIVE=""
GAME_DIR=""
DEST="$HOME/Games"
PREFIX="$HOME/.wine-civ4col"
SKIP_DEPS=0
ASSUME_YES=0
NO_DESKTOP=0

# ---------- вывод ----------
if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B= G= Y= R= N=; fi
step() { echo; echo "${B}==> $*${N}"; }
info() { echo "    $*"; }
ok()   { echo "    ${G}✓${N} $*"; }
warn() { echo "    ${Y}!${N} $*" >&2; }
die()  { echo "${R}Ошибка:${N} $*" >&2; exit 1; }

ask() {  # ask "Вопрос" -> 0 если да
    [ $ASSUME_YES = 1 ] && return 0
    local a; read -r -p "    $1 [Y/n] " a </dev/tty || return 1
    [[ -z "$a" || "$a" =~ ^[YyДд] ]]
}

usage() {
    cat <<EOF
Установщик Civilization IV: Colonization (RaR/KLT) для Linux

Опции:
  --archive ФАЙЛ     архив с игрой (.zip / .7z / .rar / .tar.*)
  --game-dir ПАПКА   использовать уже распакованную игру (без копирования)
  --dest ПАПКА       куда распаковать архив (по умолчанию ~/Games)
  --prefix ПАПКА     префикс Wine (по умолчанию ~/.wine-civ4col)
  --skip-deps        не устанавливать пакеты (Wine уже стоит)
  --no-desktop       не создавать ярлык на рабочем столе
  -y, --yes          отвечать «да» на все вопросы
  -h, --help         эта справка
EOF
}

expand() { local p="$1"; [[ "$p" == "~"* ]] && p="$HOME${p:1}"; printf '%s' "$p"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --archive)    ARCHIVE="$(expand "${2:?}")"; shift ;;
        --game-dir)   GAME_DIR="$(expand "${2:?}")"; shift ;;
        --dest)       DEST="$(expand "${2:?}")"; shift ;;
        --prefix)     PREFIX="$(expand "${2:?}")"; shift ;;
        --skip-deps)  SKIP_DEPS=1 ;;
        --no-desktop) NO_DESKTOP=1 ;;
        -y|--yes)     ASSUME_YES=1 ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage >&2; die "неизвестная опция: $1" ;;
    esac
    shift
done

[ "$(id -u)" -ne 0 ] || die "не запускайте через sudo — скрипт сам спросит пароль, когда нужно."
[ "$(uname -m)" = "x86_64" ] || die "нужен компьютер x86_64 (у вас $(uname -m))."

# ---------- 1. пакеты ----------
install_deps_apt() {
    if ! dpkg --print-foreign-architectures | grep -qx i386; then
        info "Включаю 32-битную архитектуру (i386)…"
        sudo dpkg --add-architecture i386
    fi
    sudo apt-get update
    local want=(wine wine64 wine32:i386 libwine:i386 fonts-wine
                libgl1-mesa-dri:i386 libvulkan1:i386 mesa-vulkan-drivers:i386
                libasound2-plugins:i386 libpulse0:i386 gstreamer1.0-plugins-good:i386
                unzip p7zip-full zenity icoutils winetricks)
    local have=() p
    for p in "${want[@]}"; do
        apt-cache show "$p" >/dev/null 2>&1 && have+=("$p") || warn "пакет $p недоступен — пропускаю"
    done
    sudo apt-get install -y "${have[@]}"
}

install_deps() {
    step "1/4  Установка Wine и библиотек"
    if [ $SKIP_DEPS = 1 ]; then info "пропущено (--skip-deps)"; return; fi
    local id like
    id="$(. /etc/os-release 2>/dev/null; echo "${ID:-}")"
    like="$(. /etc/os-release 2>/dev/null; echo "${ID_LIKE:-}")"
    info "Система: $id ${like:+($like)}. Понадобится пароль sudo."
    if command -v apt-get >/dev/null 2>&1; then
        install_deps_apt
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y wine winetricks unzip p7zip p7zip-plugins zenity icoutils \
            mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 alsa-plugins-pulseaudio.i686 || \
        sudo dnf install -y wine unzip zenity
    elif command -v pacman >/dev/null 2>&1; then
        grep -q '^\[multilib\]' /etc/pacman.conf || die "в /etc/pacman.conf не включён [multilib].
    Раскомментируйте секцию [multilib] и выполните: sudo pacman -Syu"
        sudo pacman -S --needed --noconfirm wine winetricks unzip p7zip zenity icoutils \
            lib32-mesa lib32-vulkan-icd-loader lib32-alsa-plugins lib32-libpulse lib32-gnutls
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive install wine wine-32bit winetricks unzip p7zip zenity icoutils
    else
        die "не знаю пакетный менеджер этой системы. Установите Wine вручную и запустите: $0 --skip-deps"
    fi
    command -v wine >/dev/null 2>&1 || die "Wine так и не появился в системе."
    ok "$(wine --version)"
}

# ---------- 2. префикс Wine ----------
PREFIX_ARCH=""
setup_prefix() {
    step "2/4  Префикс Wine: $PREFIX"
    export WINEDEBUG=-all
    # mscoree/mshtml пустые — чтобы Wine не предлагал ставить Mono и Gecko (игре не нужны)
    export WINEDLLOVERRIDES="mscoree,mshtml="
    if [ -f "$PREFIX/system.reg" ]; then
        PREFIX_ARCH="$(grep -m1 '^#arch=' "$PREFIX/system.reg" | cut -d= -f2)"
        ok "уже есть ($PREFIX_ARCH), использую его"
        return
    fi
    info "Создаю 32-битный префикс (первый запуск Wine займёт минуту)…"
    if WINEPREFIX="$PREFIX" WINEARCH=win32 wineboot --init >/dev/null 2>&1 \
       && WINEPREFIX="$PREFIX" wineserver -w && [ -f "$PREFIX/system.reg" ]; then
        PREFIX_ARCH=win32
    else
        # В новых сборках Wine (режим WoW64) win32-префиксов нет — 64-битный тоже подходит
        warn "32-битный префикс не создался, пробую 64-битный (это нормально для новых Wine)"
        rm -rf "$PREFIX"
        WINEPREFIX="$PREFIX" WINEARCH=win64 wineboot --init >/dev/null 2>&1 || true
        WINEPREFIX="$PREFIX" wineserver -w || true
        [ -f "$PREFIX/system.reg" ] || die "не удалось создать префикс Wine. Попробуйте: WINEPREFIX=$PREFIX winecfg"
        PREFIX_ARCH=win64
    fi
    unset WINEDLLOVERRIDES
    ok "префикс создан ($PREFIX_ARCH)"
}

# ---------- 3. файлы игры ----------
find_game_in() {  # печатает папки с Colonization.exe
    find "$@" -maxdepth 3 -type f -name "$GAME_EXE" -printf '%h\n' 2>/dev/null | sort -u
}

find_archives() {
    local dirs=("$KIT_DIR" "$HOME/Загрузки" "$HOME/Downloads" "$HOME/Загрузки/Telegram Desktop"
                "$HOME/Downloads/Telegram Desktop" "$(xdg-user-dir DOWNLOAD 2>/dev/null || true)")
    local d
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        find "$d" -maxdepth 1 -type f \( -iname '*civ*' -o -iname '*colonization*' -o -iname '*RaR*' \) \
            \( -iname '*.zip' -o -iname '*.7z' -o -iname '*.rar' -o -iname '*.tar*' \) 2>/dev/null
    done | sort -u
}

pick() {  # pick "заголовок" элементы... -> печатает выбранный
    local title="$1"; shift
    if [ $# -eq 1 ] || [ $ASSUME_YES = 1 ]; then printf '%s' "$1"; return; fi
    echo "    $title" >&2
    local i=1 x
    for x in "$@"; do echo "      $i) $x" >&2; i=$((i+1)); done
    local n; read -r -p "    Номер [1]: " n </dev/tty; n="${n:-1}"
    [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le $# ] || die "неверный номер"
    printf '%s' "${!n}"
}

extract() {
    local a="$1" to="$2" need avail
    mkdir -p "$to"
    if [[ "${a,,}" == *.zip ]] && command -v unzip >/dev/null; then
        need=$(unzip -l "$a" | tail -n1 | awk '{print int($1/1024)}')
        avail=$(df --output=avail -k "$to" | tail -n1)
        [ "$avail" -gt $((need + need / 10)) ] || \
            die "мало места в $to: нужно ~$((need/1024/1024)) ГБ, свободно $((avail/1024/1024)) ГБ"
        info "Распаковываю (~$((need/1024)) МБ), это несколько минут…"
        unzip -q -o "$a" -d "$to"
    elif command -v 7z >/dev/null; then
        info "Распаковываю через 7z…"
        7z x -y -bso0 -bsp1 "$a" -o"$to"
    elif [[ "${a,,}" == *.tar* ]]; then
        tar -xf "$a" -C "$to"
    elif command -v bsdtar >/dev/null; then
        bsdtar -xf "$a" -C "$to"
    else
        die "нечем распаковать $a — установите unzip или p7zip"
    fi
}

setup_game() {
    step "3/4  Файлы игры"
    if [ -z "$GAME_DIR" ] && [ -z "$ARCHIVE" ]; then
        # 1) уже распакованная игра?
        mapfile -t found < <(find_game_in "$DEST" "$HOME/Games" "$KIT_DIR" "$HOME/Загрузки" "$HOME/Downloads" \
                                          "$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")")
        if [ ${#found[@]} -gt 0 ]; then
            local g; g="$(pick "Найдена распакованная игра:" "${found[@]}")"
            if ask "Использовать «$g» (без копирования)?"; then GAME_DIR="$g"; fi
        fi
    fi
    if [ -z "$GAME_DIR" ] && [ -z "$ARCHIVE" ]; then
        # 2) архив?
        mapfile -t found < <(find_archives)
        if [ ${#found[@]} -gt 0 ]; then
            ARCHIVE="$(pick "Найден архив с игрой:" "${found[@]}")"
        elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v zenity >/dev/null; then
            info "Архив не найден — выберите его в окне…"
            ARCHIVE="$(zenity --file-selection --title="Выберите архив с Civ4 Colonization" \
                       --file-filter="Архивы | *.zip *.7z *.rar *.tar.gz *.tar.xz" 2>/dev/null)" || true
        fi
        [ -n "$ARCHIVE" ] || read -r -p "    Путь к архиву или папке с игрой: " ARCHIVE </dev/tty
        ARCHIVE="$(expand "$ARCHIVE")"
        if [ -d "$ARCHIVE" ]; then GAME_DIR="$ARCHIVE"; ARCHIVE=""; fi
    fi

    INSTALLED_BY_US=0
    if [ -n "$ARCHIVE" ]; then
        [ -f "$ARCHIVE" ] || die "нет такого файла: $ARCHIVE"
        info "Архив: $ARCHIVE"
        info "Куда:  $DEST"
        extract "$ARCHIVE" "$DEST"
        mapfile -t found < <(find_game_in "$DEST")
        [ ${#found[@]} -gt 0 ] || die "в архиве не найден $GAME_EXE"
        GAME_DIR="$(pick "В архиве несколько копий игры:" "${found[@]}")"
        INSTALLED_BY_US=1
    fi

    GAME_DIR="$(cd "$GAME_DIR" && pwd)" || die "нет такой папки: $GAME_DIR"
    [ -f "$GAME_DIR/$GAME_EXE" ] || die "в «$GAME_DIR» нет $GAME_EXE"
    ok "игра: $GAME_DIR"
}

# ---------- 4. лаунчер и ярлыки ----------
setup_launcher() {
    step "4/4  Лаунчер и ярлыки"
    mkdir -p "$CONF_DIR" "$BIN_DIR" "$APPS_DIR"
    {
        echo "# Создано install.sh $(date '+%F %T')"
        printf 'GAME_DIR=%q\n'  "$GAME_DIR"
        printf 'GAME_EXE=%q\n'  "$GAME_EXE"
        printf 'WINEPREFIX=%q\n' "$PREFIX"
        printf 'WINEARCH=%q\n'  "$PREFIX_ARCH"
        printf 'INSTALLED_BY_US=%q\n' "$INSTALLED_BY_US"
    } > "$CONF_DIR/civ4col.conf"
    ok "настройки: $CONF_DIR/civ4col.conf"

    install -m 755 "$KIT_DIR/civ4col" "$BIN_DIR/civ4col"
    install -m 755 "$KIT_DIR/uninstall.sh" "$CONF_DIR/uninstall.sh"
    ok "лаунчер: $BIN_DIR/civ4col"

    # Иконка: вытаскиваем PNG из .ico, если есть icoutils
    local ico="$GAME_DIR/RaR_desktop_icon.ico" icon
    [ -f "$ico" ] || ico="$GAME_DIR/ColonizationIcon.ico"
    icon="$ico"
    if [ -f "$ico" ] && command -v icotool >/dev/null; then
        local tmp; tmp="$(mktemp -d)"
        if icotool -x -o "$tmp" "$ico" 2>/dev/null; then
            local best; best="$(ls -S "$tmp"/*.png 2>/dev/null | head -n1)"
            if [ -n "$best" ]; then
                mkdir -p "$ICON_DIR"; cp "$best" "$ICON_DIR/civ4col.png"; icon="civ4col"
            fi
        fi
        rm -rf "$tmp"
    fi

    local desktop="$APPS_DIR/civ4col.desktop"
    cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Civ4 Colonization (RaR/KLT)
Comment=Sid Meier's Civilization IV: Colonization — мод Rise and Fall / KLT (Wine)
Exec="$BIN_DIR/civ4col"
Icon=$icon
Terminal=false
Categories=Game;StrategyGame;
StartupNotify=true
Actions=Window;

[Desktop Action Window]
Name=Запустить в окне
Exec="$BIN_DIR/civ4col" --window
EOF
    chmod +x "$desktop"
    command -v update-desktop-database >/dev/null && update-desktop-database -q "$APPS_DIR" 2>/dev/null || true
    ok "ярлык в меню приложений"

    if [ $NO_DESKTOP = 0 ]; then
        local dd; dd="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
        if [ -d "$dd" ]; then
            cp "$desktop" "$dd/civ4col.desktop"; chmod +x "$dd/civ4col.desktop"
            gio set "$dd/civ4col.desktop" metadata::trusted true 2>/dev/null || true
            ok "ярлык на рабочем столе: $dd"
        fi
    fi

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) warn "$BIN_DIR нет в PATH — команда «civ4col» заработает после перелогина
      (или запускайте по полному пути: $BIN_DIR/civ4col)" ;;
    esac
}

echo "${B}Civilization IV: Colonization (RaR/KLT) — установка на Linux${N}"
install_deps
setup_prefix
setup_game
setup_launcher

echo
echo "${G}${B}Готово!${N}"
echo "  Запуск:            civ4col          (или ярлык «Civ4 Colonization» в меню)"
echo "  В окне:            civ4col --window"
echo "  Проверка:          civ4col --doctor"
echo "  Удаление:          $CONF_DIR/uninstall.sh"
echo
if [ $ASSUME_YES = 0 ] && ask "Запустить игру сейчас?"; then
    nohup "$BIN_DIR/civ4col" >/dev/null 2>&1 &
fi
