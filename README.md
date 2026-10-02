# Civilization IV: Colonization (RaR/KLT) на Linux

Игра под Windows, на Linux она работает через **Wine**. Этот набор скриптов всё ставит сам:
Wine, 32-битные библиотеки, отдельный «Windows-префикс», распаковку игры, команду `civ4col`
и ярлыки в меню и на рабочем столе.

Проверено на Debian 13 + Wine 10.0. Должно работать на Ubuntu/Mint, Fedora, Arch и openSUSE.

## Что в папке

| Файл           | Что делает |
|----------------|------------|
| `install.sh`   | Установщик: пакеты → префикс Wine → игра → лаунчер и ярлыки |
| `civ4col`      | Лаунчер (ставится в `~/.local/bin/civ4col`) |
| `uninstall.sh` | Удаление (по умолчанию стирает только ярлыки, остальное — после вопроса) |

## Быстрый старт

1. Скачайте архив с игрой (например, `Civilization 4.zip` из Telegram) в «Загрузки».
   Можно положить его прямо рядом с `install.sh`.
2. Откройте терминал в этой папке и выполните:

   ```bash
   chmod +x install.sh civ4col uninstall.sh
   ./install.sh
   ```

3. Скрипт спросит пароль `sudo` (для установки Wine), найдёт архив, распакует его в `~/Games`
   и создаст ярлык **«Civ4 Colonization (RaR/KLT)»**.
4. Играйте: ярлык в меню или команда `civ4col`.

Нужно около **3 ГБ** свободного места: 2,2 ГБ игра и ~0,6 ГБ префикс Wine.

### Полезные варианты запуска установщика

```bash
./install.sh --archive "~/Загрузки/Telegram Desktop/Civilization 4.zip"   # указать архив
./install.sh --game-dir "~/Games/Civ4ColKLT для распространения"         # игра уже распакована
./install.sh --dest /mnt/games                                             # распаковать в другое место
./install.sh --skip-deps                                                   # Wine уже стоит, пакеты не трогать
./install.sh --help
```

Если архив не найден, откроется окно выбора файла (если стоит `zenity`). Если нет, скрипт
спросит путь в терминале.

## Команда `civ4col`

```bash
civ4col                    # запустить игру
civ4col --window           # в окне 1920x1080 (удобно, если полноэкранный режим глючит)
civ4col --window=1600x900  # в окне своего размера
civ4col --log              # подробный лог Wine → ~/.local/state/civ4col/last-run.log
civ4col --doctor           # проверить установку
civ4col --winecfg          # настройки Wine для игры
civ4col --kill             # закрыть зависшую игру
```

Пункт «Запустить в окне» есть и в контекстном меню ярлыка (правый клик).

## Что делает установщик, если хочется руками

**Debian / Ubuntu / Mint**

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install wine wine64 wine32:i386 fonts-wine \
    libgl1-mesa-dri:i386 libvulkan1:i386 mesa-vulkan-drivers:i386 \
    libasound2-plugins:i386 libpulse0:i386 unzip zenity
```

**Fedora:** `sudo dnf install wine unzip zenity`

**Arch:** включить `[multilib]` в `/etc/pacman.conf`, затем
`sudo pacman -Syu wine lib32-mesa lib32-vulkan-icd-loader lib32-alsa-plugins lib32-libpulse unzip zenity`

**Префикс и запуск:**

```bash
export WINEPREFIX=~/.wine-civ4col
WINEARCH=win32 wineboot --init          # в новых Wine (WoW64) — без WINEARCH=win32
unzip "Civilization 4.zip" -d ~/Games
cd ~/Games/"Civ4ColKLT для распространения"
wine Colonization.exe
```

Игра «портативная», устанавливать её не нужно: достаточно распаковать и запустить `Colonization.exe`.

## Где что лежит

| Что | Где |
|-----|-----|
| Игра | `~/Games/Civ4ColKLT для распространения/` (или папка из `--game-dir`) |
| Сохранения | папка игры → `Saves/`, а также `~/Документы/My Games/<имя папки игры>/` |
| Префикс Wine | `~/.wine-civ4col/` |
| Настройки лаунчера | `~/.config/civ4col/civ4col.conf` |
| Лог последнего запуска | `~/.local/state/civ4col/last-run.log` |

Сохранения и `My Games` привязаны к **имени папки игры**. Если её переименовать, игра не увидит
старые сохранения: перенесите их вручную.

## Если не работает

Сначала выполните `civ4col --doctor`. Потом посмотрите, нет ли вашего случая ниже.

| Симптом | Что делать |
|---------|-----------|
| Чёрный экран или вылет при старте | `civ4col --window`. Если помогло, в `CivilizationIV.ini` в папке игры поставьте `FullScreen = 0` |
| `wine: could not load kernel32.dll` / «Bad EXE format» | Не стоит 32-битный Wine: `sudo apt install wine32:i386` |
| Очень медленно / нет 3D | Нет 32-битных драйверов: `sudo apt install libgl1-mesa-dri:i386`. Для NVIDIA нужен `nvidia-driver-libs:i386` (Debian) или `lib32-nvidia-utils` (Arch) |
| Нет звука | `sudo apt install libasound2-plugins:i386 libpulse0:i386` |
| Ошибка загрузки XML при старте | `WINEDLLOVERRIDES="msxml3=n,b" civ4col` (берёт `msxml3.dll` из папки игры) |
| Квадратики вместо шрифтов | `WINEPREFIX=~/.wine-civ4col winetricks corefonts` |
| Игра зависла и не закрывается | `civ4col --kill` |
| Команда `civ4col` не найдена | Перелогиньтесь или запускайте `~/.local/bin/civ4col` |
| Wayland (GNOME, KDE, niri…) | Wine работает через XWayland, ничего делать не нужно. Если окно ведёт себя странно, используйте `--window` |

Подробный лог для разбора проблемы: `civ4col --log`, затем смотрите `~/.local/state/civ4col/last-run.log`.

## Как поделиться с другом

Заархивируйте эту папку (`civ4col-linux`) и положите рядом архив с игрой. Другу нужно только
распаковать и выполнить `./install.sh`: установщик сам найдёт архив рядом с собой.

## Удаление

```bash
~/.config/civ4col/uninstall.sh
```

Лаунчер и ярлыки удаляются сразу. Про префикс Wine и папку игры скрипт спросит отдельно. Папку
игры он предложит удалить, только если сам её распаковал. Пакеты Wine остаются в системе.
