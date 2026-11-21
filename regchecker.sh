#!/usr/bin/env bash
#
# regchecker.sh: как ИИ-сервисы видят твой IP (регион и доступность).
# Репозиторий: https://github.com/ShellGross/ipregchck
#
# Этап 1: страна по IP из нескольких независимых GeoIP-источников.
# Зависимости: bash, curl, jq.

VERSION="0.1.0"

LANG_UI="ru"
IP_MODE=""
PROXY=""
IFACE=""
TIMEOUT=8
JSON=0
DEBUG=0
NO_COLOR_FLAG=0
SHOW_HELP=0
SHOW_VERSION=0
MY_IP=""
TMPD=""

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

# Цвета: только 31/32/35 и жирный. Они читаются и на тёмной, и на светлой теме.
# Не используем циан, жёлтый, синий, белый, чёрный и серые оттенки.
C_BOLD=""
C_OK=""
C_BAD=""
C_WARN=""
C_RST=""

# ---------------------------------------------------------------------------
# Локализация (ru по умолчанию, en по флагу)
# ---------------------------------------------------------------------------

t() {
  case "$LANG_UI:$1" in
    ru:subtitle) printf '%s' 'как ИИ-сервисы видят твой IP' ;;
    en:subtitle) printf '%s' 'how AI services see your IP' ;;
    ru:ip) printf '%s' 'Твой IP' ;;
    en:ip) printf '%s' 'Your IP' ;;
    ru:geo_head) printf '%s' 'GeoIP: страна по IP' ;;
    en:geo_head) printf '%s' 'GeoIP: country by IP' ;;
    ru:result) printf '%s' 'Итог: %s (%s из %s источников)' ;;
    en:result) printf '%s' 'Result: %s (%s of %s sources)' ;;
    ru:tie) printf '%s' 'Итог: единого мнения нет, источники разделились' ;;
    en:tie) printf '%s' 'Result: no consensus, sources are split' ;;
    ru:disagree) printf '%s' 'Источники расходятся: %s' ;;
    en:disagree) printf '%s' 'Sources disagree: %s' ;;
    ru:ip_fail) printf '%s' 'Не удалось определить IP' ;;
    en:ip_fail) printf '%s' 'Could not detect your IP' ;;
    ru:no_results) printf '%s' 'Ни один источник не ответил: проверь сеть, прокси или --timeout' ;;
    en:no_results) printf '%s' 'No source responded: check your network, proxy or --timeout' ;;
    ru:missing_deps) printf '%s' 'Не найдены зависимости: %s' ;;
    en:missing_deps) printf '%s' 'Missing dependencies: %s' ;;
    ru:install_hint) printf '%s' 'Установка: apt install curl jq (Debian/Ubuntu) | dnf install curl jq (Fedora) | pacman -S curl jq (Arch) | pkg install curl jq (Termux)' ;;
    en:install_hint) printf '%s' 'Install: apt install curl jq (Debian/Ubuntu) | dnf install curl jq (Fedora) | pacman -S curl jq (Arch) | pkg install curl jq (Termux)' ;;
    ru:err_unknown) printf '%s' 'Неизвестный параметр: %s' ;;
    en:err_unknown) printf '%s' 'Unknown option: %s' ;;
    ru:err_value) printf '%s' 'Параметр %s: значение пропущено или недопустимо' ;;
    en:err_value) printf '%s' 'Option %s: value is missing or invalid' ;;
    ru:see_help) printf '%s' 'Справка: regchecker.sh --help' ;;
    en:see_help) printf '%s' 'Help: regchecker.sh --help' ;;
    *) printf '%s' "$1" ;;
  esac
}

# msg KEY [ARGS...]: печатает шаблон из t() с подстановкой аргументов
msg() {
  local tpl
  tpl=$(t "$1")
  shift
  # shellcheck disable=SC2059
  printf "$tpl" "$@"
}

usage() {
  if [[ $LANG_UI == "en" ]]; then
    cat <<EOF
regchecker $VERSION: how AI services see your IP

Usage: regchecker.sh [options]

Options:
  -4, --ipv4          check over IPv4 only
  -6, --ipv6          check over IPv6 only
      --proxy H:P     SOCKS5 proxy (host:port)
      --interface IF  network interface to use
      --timeout N     request timeout in seconds (default: 8)
      --lang ru|en    output language (default: ru); also --ru and --en
      --json          JSON output
      --no-color      disable colors (NO_COLOR is respected too)
      --debug         debug output to stderr
  -v, --version       show version
  -h, --help          show this help
EOF
  else
    cat <<EOF
regchecker $VERSION: как ИИ-сервисы видят твой IP

Использование: regchecker.sh [параметры]

Параметры:
  -4, --ipv4          проверять только по IPv4
  -6, --ipv6          проверять только по IPv6
      --proxy H:P     SOCKS5-прокси (host:port)
      --interface IF  сетевой интерфейс
      --timeout N     таймаут запроса в секундах (по умолчанию 8)
      --lang ru|en    язык вывода (по умолчанию ru); также --ru и --en
      --json          вывод в JSON
      --no-color      без цвета (переменная NO_COLOR тоже учитывается)
      --debug         отладочный вывод в stderr
  -v, --version       версия
  -h, --help          эта справка
EOF
  fi
}

# ---------------------------------------------------------------------------
# Разбор параметров
# ---------------------------------------------------------------------------

set_lang() {
  case "$1" in
    ru | en) LANG_UI="$1" ;;
    *) return 1 ;;
  esac
}

# Язык нужен до основного разбора, чтобы ошибки печатались на нужном языке
pre_scan_lang() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ru) LANG_UI="ru" ;;
      --en) LANG_UI="en" ;;
      --lang=*) set_lang "${1#*=}" ;;
      --lang)
        if [[ $# -ge 2 ]]; then
          set_lang "$2"
        fi
        ;;
    esac
    shift
  done
}

fail_usage() {
  {
    "$@"
    printf '\n'
    msg see_help
    printf '\n'
  } >&2
  exit 2
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help) SHOW_HELP=1 ;;
      -v | --version) SHOW_VERSION=1 ;;
      --ru) set_lang ru ;;
      --en) set_lang en ;;
      --lang=*)
        set_lang "${1#*=}" || fail_usage msg err_value "--lang"
        ;;
      --lang)
        if [[ $# -lt 2 ]] || ! set_lang "$2"; then
          fail_usage msg err_value "--lang"
        fi
        shift
        ;;
      -4 | --ipv4) IP_MODE="-4" ;;
      -6 | --ipv6) IP_MODE="-6" ;;
      --proxy)
        [[ $# -ge 2 && $2 =~ ^[^[:space:]]+:[0-9]{1,5}$ ]] || fail_usage msg err_value "--proxy"
        PROXY="$2"
        shift
        ;;
      --interface)
        [[ $# -ge 2 && $2 =~ ^[A-Za-z0-9._:-]+$ ]] || fail_usage msg err_value "--interface"
        IFACE="$2"
        shift
        ;;
      --timeout)
        [[ $# -ge 2 && $2 =~ ^[1-9][0-9]{0,2}$ && $2 -le 120 ]] || fail_usage msg err_value "--timeout"
        TIMEOUT="$2"
        shift
        ;;
      --json) JSON=1 ;;
      --no-color) NO_COLOR_FLAG=1 ;;
      --debug) DEBUG=1 ;;
      *) fail_usage msg err_unknown "$1" ;;
    esac
    shift
  done
}

setup_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" && $NO_COLOR_FLAG -eq 0 && $JSON -eq 0 ]]; then
    C_BOLD=$'\033[1m'
    # shellcheck disable=SC2034  # зелёный понадобится для вердиктов «доступен»
    C_OK=$'\033[32m'
    C_BAD=$'\033[31m'
    C_WARN=$'\033[35m'
    C_RST=$'\033[0m'
  fi
}

check_deps() {
  local missing=() c
  for c in curl jq; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if ((${#missing[@]})); then
    {
      msg missing_deps "${missing[*]}"
      printf '\n'
      msg install_hint
      printf '\n'
    } >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Сеть
# ---------------------------------------------------------------------------

http_get() {
  local url="$1"
  local args=(-s -f -L --connect-timeout 5 --max-time "$TIMEOUT" -A "$UA")
  [[ -n $IP_MODE ]] && args+=("$IP_MODE")
  [[ -n $PROXY ]] && args+=(--proxy "socks5h://$PROXY")
  [[ -n $IFACE ]] && args+=(--interface "$IFACE")
  if ((DEBUG)); then
    printf '[debug] GET %s\n' "$url" >&2
    curl "${args[@]}" "$url"
  else
    curl "${args[@]}" "$url" 2>/dev/null
  fi
}

# Приводит ответ к ISO-коду из двух букв; иначе пусто
norm_cc() {
  local v
  v=$(printf '%s' "$1" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if [[ $v =~ ^[A-Z]{2}$ && $v != "XX" ]]; then
    printf '%s' "$v"
  fi
}

detect_ip() {
  local v
  v=$(http_get "https://www.cloudflare.com/cdn-cgi/trace" | sed -n 's/^ip=//p' | head -n1)
  if [[ -z $v ]]; then
    v=$(http_get "https://ipwho.is/" | jq -r 'select(.success == true) | .ip // empty' 2>/dev/null)
  fi
  v=$(printf '%s' "$v" | tr -d '[:space:]')
  if [[ $v =~ ^[0-9A-Fa-f:.]+$ ]]; then
    printf '%s' "$v"
  fi
}

# ---------------------------------------------------------------------------
# GeoIP-источники: каждая функция печатает сырой код страны (или ничего)
# ---------------------------------------------------------------------------

geo_cloudflare() {
  http_get "https://www.cloudflare.com/cdn-cgi/trace" | sed -n 's/^loc=//p' | head -n1
}

geo_ipinfo() {
  http_get "https://ipinfo.io/json" | jq -r '.country // empty' 2>/dev/null
}

geo_ipwhois() {
  http_get "https://ipwho.is/" | jq -r 'select(.success == true) | .country_code // empty' 2>/dev/null
}

geo_ipapico() {
  http_get "https://ipapi.co/json/" | jq -r '.country_code // .country // empty' 2>/dev/null
}

geo_ipaddress() {
  http_get "https://api.ipaddress.com/iptocountry?format=json" | jq -r '.country_code // empty' 2>/dev/null
}

GEO_NAMES=("Cloudflare" "ipinfo.io" "ipwho.is" "ipapi.co" "ipaddress.com")
GEO_FUNCS=(geo_cloudflare geo_ipinfo geo_ipwhois geo_ipapico geo_ipaddress)
GEO_CODES=()

cleanup() {
  if [[ -n $TMPD && -d $TMPD ]]; then
    rm -rf "$TMPD"
  fi
}

# Запрашивает все источники параллельно и заполняет GEO_CODES
run_geoip() {
  local i raw
  TMPD=$(mktemp -d) || return 1
  for i in "${!GEO_FUNCS[@]}"; do
    if ((DEBUG)); then
      "${GEO_FUNCS[$i]}" >"$TMPD/$i" &
    else
      "${GEO_FUNCS[$i]}" >"$TMPD/$i" 2>/dev/null &
    fi
  done
  wait
  for i in "${!GEO_FUNCS[@]}"; do
    raw=$(cat "$TMPD/$i" 2>/dev/null)
    GEO_CODES[i]=$(norm_cc "$raw")
  done
}

# ---------------------------------------------------------------------------
# Вывод
# ---------------------------------------------------------------------------

# Печатает строки "КОД ЧИСЛО", самые частые первыми
tally_codes() {
  local codes=() c
  for c in "${GEO_CODES[@]}"; do
    [[ -n $c ]] && codes+=("$c")
  done
  ((${#codes[@]})) || return 0
  printf '%s\n' "${codes[@]}" | sort | uniq -c | sort -k1,1nr -k2,2 | awk '{print $2 " " $1}'
}

print_json() {
  local top="$1" i rows=""
  for i in "${!GEO_NAMES[@]}"; do
    rows+="${GEO_NAMES[$i]}"$'\t'"${GEO_CODES[$i]}"$'\n'
  done
  printf '%s' "$rows" | jq -R -s \
    --arg ver "$VERSION" --arg ip "$MY_IP" --arg top "$top" '
    split("\n")
    | map(select(length > 0) | split("\t") | {source: .[0], country: (if (.[1] // "") == "" then null else .[1] end)})
    as $rows
    | {version: $ver,
       ip: (if $ip == "" then null else $ip end),
       geoip: $rows,
       consensus: (if $top == "" then null else $top end)}'
}

print_text() {
  local top="$1" tally="$2" votes="$3" total="$4"
  local i code line parts=""

  printf '%sregchecker %s%s: %s\n\n' "$C_BOLD" "$VERSION" "$C_RST" "$(t subtitle)"
  printf '%s%s:%s %s\n\n' "$C_BOLD" "$(t ip)" "$C_RST" "${MY_IP:-"-"}"

  printf '%s%s%s\n' "$C_BOLD" "$(t geo_head)" "$C_RST"
  for i in "${!GEO_NAMES[@]}"; do
    code="${GEO_CODES[$i]}"
    if [[ -n $code ]]; then
      printf '  %-16s %s%s%s\n' "${GEO_NAMES[$i]}" "$C_BOLD" "$code" "$C_RST"
    else
      printf '  %-16s %s-%s\n' "${GEO_NAMES[$i]}" "$C_WARN" "$C_RST"
    fi
  done
  printf '\n'

  # Итог: сколько источников из всех опрошенных назвали эту страну
  if [[ -n $top ]]; then
    # shellcheck disable=SC2059
    printf "%s$(t result)%s\n" "$C_BOLD" "$top" "$votes" "$total" "$C_RST"
  elif [[ -n $tally ]]; then
    printf '%s%s%s\n' "$C_BOLD" "$(t tie)" "$C_RST"
  fi

  # Расхождения между источниками
  if [[ $(printf '%s\n' "$tally" | grep -c .) -gt 1 ]]; then
    while read -r code line; do
      parts+="${parts:+, }${code}x${line}"
    done <<<"$tally"
    printf '%s' "$C_WARN"
    msg disagree "$parts"
    printf '%s\n' "$C_RST"
  fi
}

main() {
  local tally top votes second answered=0 total c

  pre_scan_lang "$@"
  parse_args "$@"

  if ((SHOW_HELP)); then
    usage
    exit 0
  fi
  if ((SHOW_VERSION)); then
    printf 'regchecker %s\n' "$VERSION"
    exit 0
  fi

  setup_colors
  check_deps
  trap cleanup EXIT

  MY_IP=$(detect_ip)
  run_geoip

  total=${#GEO_NAMES[@]}
  for c in "${GEO_CODES[@]}"; do
    [[ -n $c ]] && answered=$((answered + 1))
  done

  tally=$(tally_codes)
  read -r top votes <<<"$(printf '%s\n' "$tally" | sed -n '1p')"
  votes=${votes:-0}
  second=$(printf '%s\n' "$tally" | sed -n '2p' | cut -d' ' -f2)
  # Ничья за первое место: единого результата нет
  if [[ -n $top && ${second:-0} -eq $votes ]]; then
    top=""
  fi

  if ((JSON)); then
    print_json "$top"
  else
    if [[ -z $MY_IP ]]; then
      printf '%s%s%s\n' "$C_WARN" "$(t ip_fail)" "$C_RST" >&2
    fi
    if ((answered == 0)); then
      printf '%s%s%s\n' "$C_BAD" "$(t no_results)" "$C_RST" >&2
    fi
    print_text "$top" "$tally" "$votes" "$total"
  fi

  ((answered > 0)) || exit 1
}

main "$@"
