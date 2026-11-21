#!/usr/bin/env bash
#
# regchecker.sh: как ИИ-сервисы видят твой IP (регион и доступность).
# Репозиторий: https://github.com/ShellGross/ipregchck
#
# Этап 1: страна по IP из нескольких независимых GeoIP-источников.
# Этап 2: ChatGPT / OpenAI (регион из trace, живая проба API, список стран OpenAI).
# Зависимости: bash, curl, jq.

VERSION="0.2.0"

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
GEO_TOP=""
CURL_ARGS=()
PROBE_CODE=""
PROBE_BODY=""
MIN_LIST=100

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
    ru:svc_chatgpt) printf '%s' 'ChatGPT / OpenAI' ;;
    en:svc_chatgpt) printf '%s' 'ChatGPT / OpenAI' ;;
    ru:l_region) printf '%s' 'Регион' ;;
    en:l_region) printf '%s' 'Region' ;;
    ru:l_live) printf '%s' 'Проба API' ;;
    en:l_live) printf '%s' 'API probe' ;;
    ru:l_list_openai) printf '%s' 'Список OpenAI' ;;
    en:l_list_openai) printf '%s' 'OpenAI list' ;;
    ru:l_verdict) printf '%s' 'Вердикт' ;;
    en:l_verdict) printf '%s' 'Verdict' ;;
    ru:src_trace) printf '%s' 'по trace сервиса' ;;
    en:src_trace) printf '%s' 'service trace' ;;
    ru:src_geoip) printf '%s' 'по GeoIP, trace недоступен' ;;
    en:src_geoip) printf '%s' 'GeoIP, trace unavailable' ;;
    ru:region_none) printf '%s' 'нет данных' ;;
    en:region_none) printf '%s' 'no data' ;;
    ru:live_ok) printf '%s' 'ответ получен, блока нет (HTTP %s)' ;;
    en:live_ok) printf '%s' 'responded, no block (HTTP %s)' ;;
    ru:live_blocked) printf '%s' 'региональный блок (HTTP %s)' ;;
    en:live_blocked) printf '%s' 'region block (HTTP %s)' ;;
    ru:live_unknown) printf '%s' 'нет внятного ответа (HTTP %s)' ;;
    en:live_unknown) printf '%s' 'no clear answer (HTTP %s)' ;;
    ru:list_supported) printf '%s' 'в списке' ;;
    en:list_supported) printf '%s' 'listed' ;;
    ru:list_unsupported) printf '%s' 'нет в списке' ;;
    en:list_unsupported) printf '%s' 'not listed' ;;
    ru:list_partial) printf '%s' 'с оговорками' ;;
    en:list_partial) printf '%s' 'with exceptions' ;;
    ru:list_unknown) printf '%s' 'нет данных' ;;
    en:list_unknown) printf '%s' 'no data' ;;
    ru:list_web) printf '%s' 'сайт' ;;
    en:list_web) printf '%s' 'live page' ;;
    ru:list_snapshot) printf '%s' 'снимок %s' ;;
    en:list_snapshot) printf '%s' 'snapshot %s' ;;
    ru:v_ok) printf '%s' 'доступен' ;;
    en:v_ok) printf '%s' 'available' ;;
    ru:v_blocked) printf '%s' 'не доступен' ;;
    en:v_blocked) printf '%s' 'not available' ;;
    ru:v_partial) printf '%s' 'частично' ;;
    en:v_partial) printf '%s' 'partially' ;;
    ru:v_conflict) printf '%s' 'расхождение' ;;
    en:v_conflict) printf '%s' 'conflict' ;;
    ru:v_unknown) printf '%s' 'нет данных' ;;
    en:v_unknown) printf '%s' 'no data' ;;
    ru:note_conflict) printf '%s' 'API отвечает, а страны нет в списке' ;;
    en:note_conflict) printf '%s' 'API responds, but the country is not listed' ;;
    ru:note_partial) printf '%s' 'доступ зависит от области, по IP не проверить' ;;
    en:note_partial) printf '%s' 'depends on the area, cannot tell from the IP' ;;
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

build_curl_args() {
  CURL_ARGS=(-s -L --connect-timeout 5 --max-time "$TIMEOUT" -A "$UA")
  [[ -n $IP_MODE ]] && CURL_ARGS+=("$IP_MODE")
  [[ -n $PROXY ]] && CURL_ARGS+=(--proxy "socks5h://$PROXY")
  [[ -n $IFACE ]] && CURL_ARGS+=(--interface "$IFACE")
}

# GET с отказом на HTTP-ошибках (-f): печатает тело ответа
http_get() {
  local url="$1"
  if ((DEBUG)); then
    printf '[debug] GET %s\n' "$url" >&2
    curl "${CURL_ARGS[@]}" -f "$url"
  else
    curl "${CURL_ARGS[@]}" -f "$url" 2>/dev/null
  fi
}

# GET без -f: заполняет PROBE_CODE (000, если ответа нет) и PROBE_BODY
http_probe() {
  local url="$1" out
  PROBE_CODE="000"
  PROBE_BODY=""
  if ((DEBUG)); then
    printf '[debug] PROBE %s\n' "$url" >&2
  fi
  out=$(curl "${CURL_ARGS[@]}" -w $'\n%{http_code}' "$url" 2>/dev/null)
  if [[ ${out##*$'\n'} =~ ^[0-9]{3}$ ]]; then
    PROBE_CODE="${out##*$'\n'}"
    PROBE_BODY="${out%$'\n'*}"
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


# ---------------------------------------------------------------------------
# Официальные списки стран
# ---------------------------------------------------------------------------

# Таблица «название страны -> ISO»: ключ = только латинские буквы, нижний регистр.
# Диакритика просто вырезается, поэтому «Côte d’Ivoire» и «Cote d'Ivoire» есть оба.
COUNTRY_KEYS='afghanistan AF
alandislands AX
albania AL
algeria DZ
americansamoa AS
andorra AD
angola AO
anguilla AI
antarctica AQ
antiguaandbarbuda AG
arabrepublicofegypt EG
argentina AR
argentinerepublic AR
armenia AM
aruba AW
australia AU
austria AT
azerbaijan AZ
bahamas BS
bahrain BH
bangladesh BD
barbados BB
belarus BY
belgium BE
belize BZ
benin BJ
bermuda BM
bhutan BT
bolivarianrepublicofvenezuela VE
bolivia BO
boliviaplurinationalstateof BO
bonairesinteustatiusandsaba BQ
bosniaandherzegovina BA
botswana BW
bouvetisland BV
brazil BR
britishindianoceanterritory IO
britishvirginislands VG
brunei BN
bruneidarussalam BN
bulgaria BG
burkinafaso BF
burma MM
burundi BI
caboverde CV
cambodia KH
cameroon CM
canada CA
capeverde CV
caribbeannetherlands BQ
caymanislands KY
centralafricanrepublic CF
chad TD
chile CL
china CN
christmasisland CX
cocosislands CC
cocoskeelingislands CC
colombia CO
commonwealthofdominica DM
commonwealthofthebahamas BS
commonwealthofthenorthernmarianaislands MP
comoros KM
congo CG
congobrazzaville CG
congodrc CD
congokinshasa CD
congothedemocraticrepublicofthe CD
cookislands CK
costarica CR
cotedivoire CI
croatia HR
ctedivoire CI
cuba CU
curaao CW
curacao CW
cyprus CY
czechia CZ
czechrepublic CZ
democraticpeoplesrepublicofkorea KP
democraticrepublicofsaotomeandprincipe ST
democraticrepublicofthecongo CD
democraticrepublicoftimorleste TL
democraticsocialistrepublicofsrilanka LK
denmark DK
djibouti DJ
dominica DM
dominicanrepublic DO
drcongo CD
easternrepublicofuruguay UY
easttimor TL
ecuador EC
egypt EG
elsalvador SV
equatorialguinea GQ
eritrea ER
estonia EE
eswatini SZ
eswatiniswaziland SZ
ethiopia ET
falklandislands FK
falklandislandsmalvinas FK
faroeislands FO
federaldemocraticrepublicofethiopia ET
federaldemocraticrepublicofnepal NP
federalrepublicofgermany DE
federalrepublicofnigeria NG
federalrepublicofsomalia SO
federatedstatesofmicronesia FM
federativerepublicofbrazil BR
fiji FJ
finland FI
france FR
frenchguiana GF
frenchpolynesia PF
frenchrepublic FR
frenchsouthernterritories TF
gabon GA
gaboneserepublic GA
gambia GM
georgia GE
germany DE
ghana GH
gibraltar GI
grandduchyofluxembourg LU
greatbritain GB
greece GR
greenland GL
grenada GD
guadeloupe GP
guam GU
guatemala GT
guernsey GG
guinea GN
guineabissau GW
guyana GY
haiti HT
hashemitekingdomofjordan JO
heardislandandmcdonaldislands HM
hellenicrepublic GR
holysee VA
holyseevaticancitystate VA
honduras HN
hongkong HK
hongkongsar HK
hongkongspecialadministrativeregionofchina HK
hungary HU
iceland IS
independentstateofpapuanewguinea PG
independentstateofsamoa WS
india IN
indonesia ID
iran IR
iranislamicrepublicof IR
iraq IQ
ireland IE
islamicrepublicofafghanistan AF
islamicrepublicofiran IR
islamicrepublicofmauritania MR
islamicrepublicofpakistan PK
isleofman IM
israel IL
italianrepublic IT
italy IT
ivorycoast CI
jamaica JM
japan JP
jersey JE
jordan JO
kazakhstan KZ
kenya KE
kingdomofbahrain BH
kingdomofbelgium BE
kingdomofbhutan BT
kingdomofcambodia KH
kingdomofdenmark DK
kingdomofeswatini SZ
kingdomoflesotho LS
kingdomofmorocco MA
kingdomofnorway NO
kingdomofsaudiarabia SA
kingdomofspain ES
kingdomofsweden SE
kingdomofthailand TH
kingdomofthenetherlands NL
kingdomoftonga TO
kiribati KI
koreademocraticpeoplesrepublicof KP
korearepublicof KR
kosovo XK
kuwait KW
kyrgyzrepublic KG
kyrgyzstan KG
landislands AX
laopeoplesdemocraticrepublic LA
laos LA
latvia LV
lebaneserepublic LB
lebanon LB
lesotho LS
liberia LR
libya LY
liechtenstein LI
lithuania LT
luxembourg LU
macao MO
macaosar MO
macaospecialadministrativeregionofchina MO
macau MO
macedonia MK
madagascar MG
malawi MW
malaysia MY
maldives MV
mali ML
malta MT
marshallislands MH
martinique MQ
mauritania MR
mauritius MU
mayotte YT
mexico MX
micronesia FM
micronesiafederatedstatesof FM
moldova MD
moldovarepublicof MD
monaco MC
mongolia MN
montenegro ME
montserrat MS
morocco MA
mozambique MZ
myanmar MM
namibia NA
nauru NR
nepal NP
netherlands NL
newcaledonia NC
newzealand NZ
nicaragua NI
niger NE
nigeria NG
niue NU
norfolkisland NF
northernmarianaislands MP
northkorea KP
northmacedonia MK
norway NO
oman OM
pakistan PK
palau PW
palestine PS
palestinestateof PS
panama PA
papuanewguinea PG
paraguay PY
peoplesdemocraticrepublicofalgeria DZ
peoplesrepublicofbangladesh BD
peoplesrepublicofchina CN
peru PE
philippines PH
pitcairn PN
pitcairnislands PN
plurinationalstateofbolivia BO
poland PL
portugal PT
portugueserepublic PT
principalityofandorra AD
principalityofliechtenstein LI
principalityofmonaco MC
puertorico PR
qatar QA
republicofalbania AL
republicofangola AO
republicofarmenia AM
republicofaustria AT
republicofazerbaijan AZ
republicofbelarus BY
republicofbenin BJ
republicofbosniaandherzegovina BA
republicofbotswana BW
republicofbulgaria BG
republicofburundi BI
republicofcaboverde CV
republicofcameroon CM
republicofchad TD
republicofchile CL
republicofcolombia CO
republicofcostarica CR
republicofcotedivoire CI
republicofcroatia HR
republicofctedivoire CI
republicofcuba CU
republicofcyprus CY
republicofdjibouti DJ
republicofecuador EC
republicofelsalvador SV
republicofequatorialguinea GQ
republicofestonia EE
republicoffiji FJ
republicoffinland FI
republicofghana GH
republicofguatemala GT
republicofguinea GN
republicofguineabissau GW
republicofguyana GY
republicofhaiti HT
republicofhonduras HN
republicoficeland IS
republicofindia IN
republicofindonesia ID
republicofiraq IQ
republicofkazakhstan KZ
republicofkenya KE
republicofkiribati KI
republicofkorea KR
republicoflatvia LV
republicofliberia LR
republicoflithuania LT
republicofmadagascar MG
republicofmalawi MW
republicofmaldives MV
republicofmali ML
republicofmalta MT
republicofmauritius MU
republicofmoldova MD
republicofmozambique MZ
republicofmyanmar MM
republicofnamibia NA
republicofnauru NR
republicofnicaragua NI
republicofnorthmacedonia MK
republicofpalau PW
republicofpanama PA
republicofparaguay PY
republicofperu PE
republicofpoland PL
republicofsanmarino SM
republicofsenegal SN
republicofserbia RS
republicofseychelles SC
republicofsierraleone SL
republicofsingapore SG
republicofslovenia SI
republicofsouthafrica ZA
republicofsouthsudan SS
republicofsuriname SR
republicoftajikistan TJ
republicofthecongo CG
republicofthegambia GM
republicofthemarshallislands MH
republicoftheniger NE
republicofthephilippines PH
republicofthesudan SD
republicoftrinidadandtobago TT
republicoftrkiye TR
republicoftunisia TN
republicofturkiye TR
republicofuganda UG
republicofuzbekistan UZ
republicofvanuatu VU
republicofyemen YE
republicofzambia ZM
republicofzimbabwe ZW
reunion RE
romania RO
runion RE
russia RU
russianfederation RU
rwanda RW
rwandeserepublic RW
saintbarthelemy BL
saintbarthlemy BL
sainthelena SH
sainthelenaascensionandtristandacunha SH
saintkittsandnevis KN
saintlucia LC
saintmartin MF
saintmartinfrenchpart MF
saintpierreandmiquelon PM
saintvincentandthegrenadines VC
samoa WS
sanmarino SM
saotomeandprincipe ST
saudiarabia SA
senegal SN
serbia RS
seychelles SC
sierraleone SL
singapore SG
sintmaarten SX
sintmaartendutchpart SX
slovakia SK
slovakrepublic SK
slovenia SI
socialistrepublicofvietnam VN
solomonislands SB
somalia SO
sotomandprncipe ST
southafrica ZA
southgeorgiaandthesouthsandwichislands GS
southkorea KR
southsudan SS
spain ES
srilanka LK
stateofisrael IL
stateofkuwait KW
stateofqatar QA
sudan SD
sultanateofoman OM
suriname SR
svalbardandjanmayen SJ
swaziland SZ
sweden SE
swissconfederation CH
switzerland CH
syria SY
syrianarabrepublic SY
taiwan TW
taiwanprovinceofchina TW
tajikistan TJ
tanzania TZ
tanzaniaunitedrepublicof TZ
thailand TH
thebahamas BS
thegambia GM
thestateoferitrea ER
thestateofpalestine PS
timorleste TL
togo TG
togoleserepublic TG
tokelau TK
tonga TO
trinidadandtobago TT
trkiye TR
tunisia TN
turkey TR
turkiye TR
turkmenistan TM
turksandcaicosislands TC
tuvalu TV
uae AE
uganda UG
uk GB
ukraine UA
unionofthecomoros KM
unitedarabemirates AE
unitedkingdom GB
unitedkingdomofgreatbritainandnorthernireland GB
unitedmexicanstates MX
unitedrepublicoftanzania TZ
unitedstates US
unitedstatesminoroutlyingislands UM
unitedstatesofamerica US
uruguay UY
usa US
usminoroutlyingislands UM
usvirginislands VI
uzbekistan UZ
vanuatu VU
vatican VA
vaticancity VA
venezuela VE
venezuelabolivarianrepublicof VE
vietnam VN
virginislandsbritish VG
virginislandsoftheunitedstates VI
virginislandsus VI
wallisandfutuna WF
westernsahara EH
yemen YE
zambia ZM
zimbabwe ZW'

# Разбор текста/markdown/HTML: каждая строка, целиком равная названию страны,
# превращается в «CC» или «CC partial» (если в названии есть оговорка except).
# shellcheck disable=SC2016  # в awk-программе $0 и $1 должны остаться как есть
PARSE_AWK='
function key(s,   t) { t = s; gsub(/[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]/, "", t); return tolower(t) }
FNR == NR { T[$1] = $2; next }
{
  s = $0
  gsub(/\r/, "", s)
  sub(/^[ \t]*[-*+][ \t]+/, "", s)
  if (s == "" || length(s) > 80) next
  k = key(s); code = ""; partial = 0
  if (k in T) { code = T[k] }
  else {
    b = s; gsub(/\([^)]*\)/, "", b); kb = key(b)
    if (kb in T) { code = T[kb] }
    if (s ~ /[Ee]xcept/) { partial = 1 }
  }
  if (code != "") { print code (partial ? " partial" : "") }
}'

parse_country_list() {
  printf '%s\n' "$COUNTRY_KEYS" >"$TMPD/table"
  # shellcheck disable=SC2020  # '<' и '>' оба заменяются на перевод строки: теги HTML становятся отдельными строками
  tr '<>' '\n\n' | awk "$PARSE_AWK" "$TMPD/table" -
}

# Вшитый снимок списка OpenAI (запасной вариант, если страница недоступна)
SNAP_OPENAI_DATE="2026-11-21"
SNAP_OPENAI_CODES="AD AE AF AG AL AM AO AR AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BR BS BT BW BZ CA CD CF CG CH CI CL CM CO CR CV CY CZ DE DJ DK DM DO DZ EC EE EG ER ES ET FI FJ FM FO FR GA GB GD GE GF GH GL GM GN GP GQ GR GT GW GY HN HR HT HU ID IE IL IN IQ IS IT JM JO JP KE KG KH KI KM KN KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MQ MR MT MU MV MW MX MY MZ NA NC NE NG NI NL NO NP NR NZ OM PA PE PF PG PH PK PL PM PS PT PW PY QA RE RO RS RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SZ TD TF TG TH TJ TL TM TN TO TR TT TV TW TZ UG US UY UZ VA VC VN VU WF WS YE YT ZA ZM ZW"
SNAP_OPENAI_PARTIAL="UA"

LIST_CODES=""
LIST_PARTIAL=""
LIST_SRC=""
LIST_DATE=""

# load_country_list СНИМОК_КОДЫ СНИМОК_ОГОВОРКИ СНИМОК_ДАТА URL...
# Пробует страницы по очереди; если ни одна не дала разумный список, берёт снимок.
load_country_list() {
  local snap_codes="$1" snap_partial="$2" snap_date="$3" url body parsed n
  shift 3
  LIST_CODES=""
  LIST_PARTIAL=""
  LIST_SRC=""
  LIST_DATE=""
  for url in "$@"; do
    body=$(http_get "$url") || continue
    [[ -n $body ]] || continue
    parsed=$(printf '%s\n' "$body" | parse_country_list)
    n=$(printf '%s\n' "$parsed" | grep -c .)
    if ((n >= MIN_LIST)); then
      LIST_CODES=" $(printf '%s\n' "$parsed" | awk '$2 != "partial" {print $1}' | sort -u | tr '\n' ' ')"
      LIST_PARTIAL=" $(printf '%s\n' "$parsed" | awk '$2 == "partial" {print $1}' | sort -u | tr '\n' ' ')"
      LIST_SRC="web"
      return 0
    fi
  done
  LIST_CODES=" $snap_codes "
  LIST_PARTIAL=" $snap_partial "
  LIST_SRC="snapshot"
  LIST_DATE="$snap_date"
}

# Печатает: supported | partial | unsupported | unknown
list_state() {
  local cc="$1"
  if [[ -z $cc ]]; then
    printf 'unknown'
  elif [[ $LIST_PARTIAL == *" $cc "* ]]; then
    printf 'partial'
  elif [[ $LIST_CODES == *" $cc "* ]]; then
    printf 'supported'
  else
    printf 'unsupported'
  fi
}

# make_verdict LIVE LIST -> ok | blocked | partial | conflict | unknown
# Ответ API без ключа сам по себе доступность не доказывает: «ok» только вместе со списком.
make_verdict() {
  local live="$1" list="$2"
  if [[ $live == blocked ]]; then
    printf 'blocked'
  elif [[ $list == partial ]]; then
    printf 'partial'
  elif [[ $live == ok && $list == supported ]]; then
    printf 'ok'
  elif [[ $live == ok && $list == unsupported ]]; then
    printf 'conflict'
  elif [[ $live == unknown && $list == supported ]]; then
    printf 'ok'
  elif [[ $live == unknown && $list == unsupported ]]; then
    printf 'blocked'
  else
    printf 'unknown'
  fi
}

# ---------------------------------------------------------------------------
# ChatGPT / OpenAI
# ---------------------------------------------------------------------------

CG_REGION=""
CG_REGION_SRC=""
CG_LIVE=""
CG_LIVE_CODE=""
CG_LIST=""
CG_VERDICT=""

# Живая проба api.openai.com без ключа: при блоке по региону OpenAI отвечает
# 403 с кодом unsupported_country_region_territory.
classify_openai_probe() {
  case "$PROBE_CODE" in
    403)
      if [[ $PROBE_BODY == *unsupported_country_region_territory* ]]; then
        printf 'blocked'
      else
        printf 'unknown'
      fi
      ;;
    401 | 429 | 2??) printf 'ok' ;;
    *) printf 'unknown' ;;
  esac
}

check_chatgpt() {
  local trace loc
  trace=$(http_get "https://chatgpt.com/cdn-cgi/trace" | sed -n 's/^loc=//p' | head -n1)
  loc=$(norm_cc "$trace")
  if [[ -n $loc ]]; then
    CG_REGION="$loc"
    CG_REGION_SRC="trace"
  elif [[ -n $GEO_TOP ]]; then
    CG_REGION="$GEO_TOP"
    CG_REGION_SRC="geoip"
  fi

  http_probe "https://api.openai.com/v1/models"
  CG_LIVE_CODE="$PROBE_CODE"
  CG_LIVE=$(classify_openai_probe)

  load_country_list "$SNAP_OPENAI_CODES" "$SNAP_OPENAI_PARTIAL" "$SNAP_OPENAI_DATE" \
    "https://developers.openai.com/api/docs/supported-countries.md" \
    "https://developers.openai.com/api/docs/supported-countries"
  CG_LIST=$(list_state "$CG_REGION")
  CG_VERDICT=$(make_verdict "$CG_LIVE" "$CG_LIST")
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

chatgpt_json() {
  jq -n \
    --arg region "$CG_REGION" --arg rsrc "$CG_REGION_SRC" \
    --arg live "$CG_LIVE" --arg code "$CG_LIVE_CODE" \
    --arg list "$CG_LIST" --arg lsrc "$LIST_SRC" --arg ldate "$LIST_DATE" \
    --arg verdict "$CG_VERDICT" '
    {name: "ChatGPT",
     region: (if $region == "" then null else $region end),
     region_source: (if $rsrc == "" then null else $rsrc end),
     live: {state: $live, http: ($code | tonumber)},
     list: {state: $list, source: $lsrc, snapshot_date: (if $ldate == "" then null else $ldate end)},
     verdict: $verdict}'
}

# Цвет вердикта: зелёный, красный и маджента (читаются на тёмной и светлой теме)
verdict_color() {
  case "$1" in
    ok) printf '%s' "$C_OK" ;;
    blocked) printf '%s' "$C_BAD" ;;
    *) printf '%s' "$C_WARN" ;;
  esac
}

print_chatgpt() {
  local lsrc color

  printf '\n%s%s%s\n' "$C_BOLD" "$(t svc_chatgpt)" "$C_RST"

  if [[ -n $CG_REGION ]]; then
    printf '  %s: %s%s%s (%s)\n' "$(t l_region)" "$C_BOLD" "$CG_REGION" "$C_RST" "$(t "src_$CG_REGION_SRC")"
  else
    printf '  %s: %s%s%s\n' "$(t l_region)" "$C_WARN" "$(t region_none)" "$C_RST"
  fi

  printf '  %s: ' "$(t l_live)"
  msg "live_$CG_LIVE" "$CG_LIVE_CODE"
  printf '\n'

  if [[ $LIST_SRC == web ]]; then
    lsrc=$(t list_web)
  else
    lsrc=$(msg list_snapshot "$LIST_DATE")
  fi
  printf '  %s: %s (%s)\n' "$(t l_list_openai)" "$(t "list_$CG_LIST")" "$lsrc"

  color=$(verdict_color "$CG_VERDICT")
  printf '  %s: %s%s%s%s\n' "$(t l_verdict)" "$color" "$C_BOLD" "$(t "v_$CG_VERDICT")" "$C_RST"
  if [[ $CG_VERDICT == conflict ]]; then
    printf '  %s%s%s\n' "$C_WARN" "$(t note_conflict)" "$C_RST"
  elif [[ $CG_VERDICT == partial ]]; then
    printf '  %s%s%s\n' "$C_WARN" "$(t note_partial)" "$C_RST"
  fi
}

print_json() {
  local top="$1" i rows=""
  for i in "${!GEO_NAMES[@]}"; do
    rows+="${GEO_NAMES[$i]}"$'\t'"${GEO_CODES[$i]}"$'\n'
  done
  printf '%s' "$rows" | jq -R -s \
    --arg ver "$VERSION" --arg ip "$MY_IP" --arg top "$top" \
    --argjson services "[$(chatgpt_json)]" '
    split("\n")
    | map(select(length > 0) | split("\t") | {source: .[0], country: (if (.[1] // "") == "" then null else .[1] end)})
    as $rows
    | {version: $ver,
       ip: (if $ip == "" then null else $ip end),
       geoip: $rows,
       consensus: (if $top == "" then null else $top end),
       services: $services}'
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

  print_chatgpt
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
  TMPD=$(mktemp -d) || exit 1
  build_curl_args

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
  GEO_TOP="$top"

  check_chatgpt

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
