#!/bin/sh
#
# proton2025.sh — управление темой luci-theme-proton2025 на OpenWrt (менеджер apk)
# Сам подтягивает последнюю версию с GitHub (без ручного ввода имени файла).
#
# Проект: https://github.com/lastik9/openwrt-luci-theme-proton2025
# Тема:   https://github.com/ChesterGoodiny/luci-theme-proton2025
# Запуск:  sh proton2025.sh
#
# ВАЖНО: сохраняйте файл с переводами строк LF (Unix). CRLF ломает запуск на роутере.
#

# ---- Настройки ----
THEME_REPO="ChesterGoodiny/luci-theme-proton2025"
THEME_PKG="luci-theme-proton2025"
MEDIA="/luci-static/proton2025"          # путь темы для luci.main.mediaurlbase
# -------------------

# Проверка root
if [ "$(id -u)" != "0" ]; then
    echo "Запустите скрипт от root."
    exit 1
fi

# Проверка apk
if ! command -v apk >/dev/null 2>&1; then
    echo "Не найден apk. Похоже, сборка на opkg — этот скрипт не подойдёт."
    echo "Для opkg-сборок ставьте .ipk по инструкции из репозитория темы."
    exit 1
fi

# --- Загрузка в stdout (curl или wget) ---
fetch_stdout() {
    _url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -H "User-Agent: proton2025-installer" "$_url"
    else
        wget -q -O - "$_url" 2>/dev/null
    fi
}

# --- Загрузка в файл ---
fetch_file() {
    _url="$1"; _out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fSL -H "User-Agent: proton2025-installer" -o "$_out" "$_url"
    else
        wget --no-check-certificate -O "$_out" "$_url"
    fi
}

restart_ui() {
    /etc/init.d/uhttpd restart >/dev/null 2>&1
}

# --- Способ 1: GitHub API (быстро, но лимит 60/час) ---
resolve_via_api() {
    _json="$(fetch_stdout "https://api.github.com/repos/${THEME_REPO}/releases/latest")"
    LATEST_URL="$(printf '%s' "$_json" \
        | grep -oE '"browser_download_url":[[:space:]]*"[^"]+\.apk"' \
        | grep "$THEME_PKG" \
        | head -n1 \
        | sed -E 's/.*"(https[^"]+)".*/\1/')"
    LATEST_TAG="$(printf '%s' "$_json" \
        | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)".*/\1/')"
}

# --- Способ 2: атом-фид + expanded_assets (без лимита, запасной) ---
resolve_via_html() {
    _tag="$(fetch_stdout "https://github.com/${THEME_REPO}/releases.atom" \
        | grep -oE 'releases/tag/[^"<]+' | head -n1 | sed -E 's#.*/tag/##')"
    [ -z "$_tag" ] && return 1
    _href="$(fetch_stdout "https://github.com/${THEME_REPO}/releases/expanded_assets/${_tag}" \
        | grep -oE '/[^"]+\.apk' | grep "$THEME_PKG" | head -n1)"
    [ -z "$_href" ] && return 1
    LATEST_URL="https://github.com${_href}"
    LATEST_TAG="$_tag"
}

resolve_latest() {
    LATEST_URL=""; LATEST_TAG=""
    resolve_via_api
    if [ -z "$LATEST_URL" ]; then
        echo "    API не дал результат, пробую запасной способ ..."
        resolve_via_html
    fi
}

install_theme() {
    echo "==> Узнаю последнюю версию с GitHub ..."
    resolve_latest
    if [ -z "$LATEST_URL" ]; then
        echo "Не удалось определить ссылку на .apk. Проверьте интернет/DNS на роутере"
        echo "или скачайте .apk вручную со страницы релизов и поставьте:"
        echo "  apk add --allow-untrusted <файл>.apk"
        return 1
    fi

    _file="/tmp/$(basename "$LATEST_URL")"
    echo "==> Версия: ${LATEST_TAG}"
    echo "==> Скачиваю $(basename "$LATEST_URL") ..."
    rm -f "$_file"
    if ! fetch_file "$LATEST_URL" "$_file"; then
        echo "Ошибка загрузки. Проверьте интернет/DNS на роутере."
        return 1
    fi

    echo "==> Устанавливаю пакет ..."
    if ! apk add --allow-untrusted "$_file"; then
        echo "Ошибка установки пакета."
        rm -f "$_file"
        return 1
    fi

    echo "==> Делаю Proton2025 активной темой ..."
    uci set luci.main.mediaurlbase="$MEDIA"
    uci commit luci
    restart_ui
    rm -f "$_file"

    echo ""
    echo "Готово! Тема Proton2025 (${LATEST_TAG}) установлена и включена."
    echo "Если интерфейс выглядит по-старому — обновите страницу с Ctrl+F5."
}

status_argon() {
    echo "----------------------------------"
    echo "Активная тема (mediaurlbase): $(uci get luci.main.mediaurlbase 2>/dev/null)"
    if apk info -e "$THEME_PKG" >/dev/null 2>&1; then
        _v="$(apk list --installed 2>/dev/null | grep -i "$THEME_PKG" | head -n1)"
        echo "Тема: установлена  [${_v:-$THEME_PKG}]"
    else
        echo "Тема: не установлена"
    fi
    echo "----------------------------------"
}

remove_theme() {
    echo "==> Возвращаю стандартную тему (bootstrap) ..."
    uci set luci.main.mediaurlbase='/luci-static/bootstrap'
    uci commit luci

    echo "==> Удаляю пакет ${THEME_PKG} ..."
    if apk info -e "$THEME_PKG" >/dev/null 2>&1; then
        apk del "$THEME_PKG"          # вывод НЕ прячем — ошибки должны быть видны
    else
        echo "    пакет не установлен (в системе его нет)"
    fi

    echo "==> Чищу остатки (apk сохраняет изменённые конфиги) ..."
    rm -rf /www/luci-static/proton2025
    rm -f  /etc/config/proton2025
    rm -f  /usr/share/luci/menu.d/luci-theme-proton2025.json
    rm -f  /usr/share/rpcd/acl.d/luci-theme-proton2025.json
    rm -f  /usr/share/ucode/template/themes/proton2025

    # убираем запись темы из списка Design в /etc/config/luci
    uci -q delete luci.themes.Proton2025
    uci commit luci

    echo "==> Сбрасываю кэш LuCI и перезапускаю сервисы ..."
    rm -f /tmp/luci-indexcache* 2>/dev/null
    rm -rf /tmp/luci-modulecache 2>/dev/null
    /etc/init.d/rpcd restart >/dev/null 2>&1
    restart_ui

    echo ""
    echo "Готово! Тема удалена, вернулась стандартная."
    echo "Выйди из LuCI (Log out), обнови страницу с Ctrl+F5 и зайди заново."
}

# ---- Меню ----
echo "======================================="
echo " luci-theme-proton2025 для OpenWrt (apk)"
echo "======================================="
echo " 1) Установить / обновить тему (последняя версия)"
echo " 2) Показать статус"
echo " 3) Удалить тему"
echo " 4) Выход"
echo "---------------------------------------"
printf "Выберите пункт [1-4]: "
read choice

case "$choice" in
    1) install_theme ;;
    2) status_argon ;;
    3) remove_theme ;;
    4) echo "Выход." ; exit 0 ;;
    *) echo "Неверный выбор." ; exit 1 ;;
esac
