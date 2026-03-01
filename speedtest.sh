#!/bin/bash
# ============================================
# NETWORK SPEED TEST TOOL - BASH VERSION
# ============================================
# Developer: Md. Mainul Islam
# Owner: MAINUL - X
# GitHub: M41NUL
# WhatsApp: +8801308850528
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Speed test servers (fast.com, google.com, cloudflare)
TEST_URLS=(
    "http://speedtest.tele2.net/100MB.zip"
    "http://speedtest.tele2.net/10MB.zip"
    "http://speedtest.tele2.net/1MB.zip"
    "https://proof.ovh.net/files/100Mb.dat"
    "https://proof.ovh.net/files/10Mb.dat"
)

# Function to convert bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes} B/s"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB/s"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB/s"
    else
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB/s"
    fi
}

# Function to test download speed
test_download_speed() {
    local url=$1
    local file_size=$2
    local temp_file="/tmp/speedtest_temp_$$"
    
    echo -ne "${CYAN}Testing download speed...${NC}"
    
    # Start timer
    start_time=$(date +%s.%N)
    
    # Download file
    curl -s -o "$temp_file" "$url" &
    curl_pid=$!
    
    # Show progress
    while kill -0 $curl_pid 2>/dev/null; do
        echo -n "."
        sleep 0.5
    done
    
    # End timer
    end_time=$(date +%s.%N)
    
    # Calculate speed
    elapsed=$(echo "$end_time - $start_time" | bc)
    speed=$(echo "$file_size / $elapsed" | bc)
    
    # Cleanup
    rm -f "$temp_file"
    
    echo -e "${GREEN} Done!${NC}"
    echo -e "${YELLOW}Download Speed:${NC} $(format_bytes $speed)"
}

# Function to test upload speed
test_upload_speed() {
    local size=$1
    local temp_file="/tmp/upload_test_$$"
    
    # Create dummy file
    dd if=/dev/zero of="$temp_file" bs=1M count=$size 2>/dev/null
    
    echo -ne "${CYAN}Testing upload speed...${NC}"
    
    # Start timer
    start_time=$(date +%s.%N)
    
    # Upload to dummy server (using transfer.sh for testing)
    curl -s -F "file=@$temp_file" https://transfer.sh/ > /dev/null &
    curl_pid=$!
    
    # Show progress
    while kill -0 $curl_pid 2>/dev/null; do
        echo -n "."
        sleep 0.5
    done
    
    # End timer
    end_time=$(date +%s.%N)
    
    # Calculate speed
    elapsed=$(echo "$end_time - $start_time" | bc)
    bytes=$((size * 1048576))
    speed=$(echo "$bytes / $elapsed" | bc)
    
    # Cleanup
    rm -f "$temp_file"
    
    echo -e "${GREEN} Done!${NC}"
    echo -e "${YELLOW}Upload Speed:${NC} $(format_bytes $speed)"
}

# Function to test ping
test_ping() {
    local host=$1
    local count=5
    
    echo -e "${CYAN}Pinging $host...${NC}"
    
    # Do ping test
    ping_result=$(ping -c $count $host 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
    
    if [ ! -z "$ping_result" ]; then
        echo -e "${GREEN}Average Ping:${NC} ${ping_result} ms"
    else
        echo -e "${RED}Ping failed!${NC}"
    fi
}

# Function to test jitter
test_jitter() {
    local host=$1
    local count=10
    local times=()
    
    echo -ne "${CYAN}Testing jitter...${NC}"
    
    for i in $(seq 1 $count); do
        start=$(date +%s%N)
        ping -c 1 -W 1 $host >/dev/null 2>&1
        end=$(date +%s%N)
        
        if [ $? -eq 0 ]; then
            elapsed=$(( ($end - $start) / 1000000 ))
            times+=($elapsed)
        fi
        echo -n "."
    done
    
    # Calculate jitter (mean deviation)
    if [ ${#times[@]} -gt 1 ]; then
        sum=0
        for t in "${times[@]}"; do
            sum=$((sum + t))
        done
        avg=$((sum / ${#times[@]}))
        
        dev_sum=0
        for t in "${times[@]}"; do
            dev=$((t - avg))
            if [ $dev -lt 0 ]; then
                dev=$((dev * -1))
            fi
            dev_sum=$((dev_sum + dev))
        done
        jitter=$((dev_sum / ${#times[@]}))
        
        echo -e "${GREEN} Done!${NC}"
        echo -e "${YELLOW}Jitter:${NC} ${jitter} ms"
    else
        echo -e "${RED} Failed!${NC}"
    fi
}

# Function to get network interface info
get_interface_info() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [ -z "$interface" ]; then
        interface="eth0"
    fi
    
    echo -e "${CYAN}Network Interface:${NC} $interface"
    
    # Get IP address
    ip_addr=$(ip addr show $interface | grep -o 'inet [0-9.]*' | cut -d' ' -f2)
    echo -e "${CYAN}IP Address:${NC} $ip_addr"
    
    # Get MAC address
    mac_addr=$(ip link show $interface | grep -o 'link/ether [0-9a-f:]*' | cut -d' ' -f2)
    echo -e "${CYAN}MAC Address:${NC} $mac_addr"
}

# Function to test DNS resolution
test_dns() {
    local domain="google.com"
    
    echo -ne "${CYAN}Testing DNS resolution...${NC}"
    
    start_time=$(date +%s%N)
    nslookup $domain >/dev/null 2>&1
    end_time=$(date +%s%N)
    
    dns_time=$(( ($end_time - $start_time) / 1000000 ))
    
    echo -e "${GREEN} Done!${NC}"
    echo -e "${YELLOW}DNS Resolution Time:${NC} ${dns_time} ms"
}

# Function to show network stats
show_network_stats() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [ -z "$interface" ]; then
        interface="eth0"
    fi
    
    # Get initial stats
    rx1=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
    tx1=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null)
    
    if [ -z "$rx1" ] || [ -z "$tx1" ]; then
        echo -e "${RED}Could not get network stats!${NC}"
        return
    fi
    
    sleep 1
    
    # Get stats after 1 second
    rx2=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
    tx2=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null)
    
    # Calculate speeds
    rx_speed=$((rx2 - rx1))
    tx_speed=$((tx2 - tx1))
    
    echo -e "${GREEN}Current Network Usage:${NC}"
    echo -e "${YELLOW}Download:${NC} $(format_bytes $rx_speed)"
    echo -e "${YELLOW}Upload:${NC} $(format_bytes $tx_speed)"
}

# Function to test with fast.com (Netflix)
test_fast_com() {
    echo -e "${CYAN}Testing with fast.com (Netflix)...${NC}"
    
    # Get fast.com API
    token=$(curl -s https://fast.com/app-ed402d.js | grep -o 'token:"[^"]*"' | cut -d'"' -f2)
    
    if [ ! -z "$token" ]; then
        # Get fastest server
        server=$(curl -s "https://api.fast.com/netflix/speedtest?https=true&token=$token" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ ! -z "$server" ]; then
            # Test download
            start_time=$(date +%s.%N)
            curl -s -o /dev/null "$server" &
            curl_pid=$!
            
            while kill -0 $curl_pid 2>/dev/null; do
                echo -n "."
                sleep 0.2
            done
            
            end_time=$(date +%s.%N)
            elapsed=$(echo "$end_time - $start_time" | bc)
            
            # Estimate speed (25MB test file)
            speed=$(echo "26214400 / $elapsed" | bc)
            
            echo -e "${GREEN} Done!${NC}"
            echo -e "${YELLOW}Fast.com Speed:${NC} $(format_bytes $speed)"
        fi
    fi
}

# Main menu
while true; do
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              NETWORK SPEED TEST TOOL                     ║"
    echo "║                  by MAINUL - X                           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Developer: Md. Mainul Islam${NC}"
    echo -e "${YELLOW}Contact: +8801308850528${NC}"
    echo -e "${YELLOW}GitHub: M41NUL${NC}"
    echo ""
    
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}1.${NC} Quick Speed Test (Download & Upload)"
    echo -e "${GREEN}2.${NC} Ping Test"
    echo -e "${GREEN}3.${NC} Jitter Test"
    echo -e "${GREEN}4.${NC} Network Interface Info"
    echo -e "${GREEN}5.${NC} DNS Resolution Test"
    echo -e "${GREEN}6.${NC} Live Network Usage"
    echo -e "${GREEN}7.${NC} Fast.com Speed Test"
    echo -e "${GREEN}8.${NC} Comprehensive Network Analysis"
    echo -e "${RED}0.${NC} Exit"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    
    read -p $'\e[32mEnter option: \e[0m' option
    
    case $option in
        1)
            echo ""
            echo -e "${YELLOW}Starting speed test...${NC}"
            
            # Download test
            test_download_speed "${TEST_URLS[1]}" 10485760  # 10MB
            
            # Upload test
            test_upload_speed 5  # 5MB upload
            ;;
            
        2)
            echo ""
            read -p $'\e[33mEnter host to ping (default: google.com): \e[0m' host
            host=${host:-google.com}
            test_ping "$host"
            ;;
            
        3)
            echo ""
            read -p $'\e[33mEnter host to test jitter (default: google.com): \e[0m' host
            host=${host:-google.com}
            test_jitter "$host"
            ;;
            
        4)
            echo ""
            get_interface_info
            ;;
            
        5)
            echo ""
            test_dns
            ;;
            
        6)
            echo ""
            echo -e "${YELLOW}Monitoring network usage (Ctrl+C to stop)...${NC}"
            echo ""
            
            # Live monitoring
            while true; do
                show_network_stats
                sleep 1
                echo -e "${CYAN}────────────────────────────────────────────${NC}"
            done
            ;;
            
        7)
            echo ""
            test_fast_com
            ;;
            
        8)
            echo ""
            echo -e "${YELLOW}Running comprehensive network analysis...${NC}"
            echo ""
            
            # Interface info
            get_interface_info
            echo ""
            
            # DNS test
            test_dns
            echo ""
            
            # Ping test
            test_ping "google.com"
            echo ""
            
            # Jitter test
            test_jitter "google.com"
            echo ""
            
            # Download test
            test_download_speed "${TEST_URLS[2]}" 1048576  # 1MB
            echo ""
            
            # Fast.com test
            test_fast_com
            ;;
            
        0)
            echo ""
            echo -e "${GREEN}Thank you for using Network Speed Test Tool!${NC}"
            echo -e "${CYAN}Developer: Md. Mainul Islam (MAINUL - X)${NC}"
            echo -e "${CYAN}GitHub: M41NUL | WhatsApp: +8801308850528${NC}"
            break
            ;;
            
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
