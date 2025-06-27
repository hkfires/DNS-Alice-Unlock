#!/bin/bash

VERSION="0.0.2"
LAST_UPDATED=$(date +"%Y-%m-%d")
AUTHOR="hKFirEs"

SCRIPT_NAME="dns-alice-unlock.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
SYMLINK_PATH="/usr/local/bin/dns"
CONFIG_FILE="/etc/dnsmasq.conf"
SMARTDNS_CONFIG_FILE="/etc/smartdns/smartdns.conf"

API_BASE_URL="https://dnsconfig.072899.xyz"

C_RESET='\033[0m'
C_BLACK='\033[0;30m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_PURPLE='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[0;37m'
C_B_BLACK='\033[1;30m'
C_B_RED='\033[1;31m'
C_B_GREEN='\033[1;32m'
C_B_YELLOW='\033[1;33m'
C_B_BLUE='\033[1;34m'
C_B_PURPLE='\033[1;35m'
C_B_CYAN='\033[1;36m'
C_B_WHITE='\033[1;37m'
C_HI_BLACK='\033[0;90m'
C_HI_RED='\033[0;91m'
C_HI_GREEN='\033[0;92m'
C_HI_YELLOW='\033[0;93m'
C_HI_BLUE='\033[0;94m'
C_HI_PURPLE='\033[0;95m'
C_HI_CYAN='\033[0;96m'
C_HI_WHITE='\033[0;97m'
C_BHI_BLACK='\033[1;90m'
C_BHI_RED='\033[1;91m'
C_BHI_GREEN='\033[1;92m'
C_BHI_YELLOW='\033[1;93m'
C_BHI_BLUE='\033[1;94m'
C_BHI_PURPLE='\033[1;95m'
C_BHI_CYAN='\033[1;96m'
C_BHI_WHITE='\033[1;97m'
C_PRIMARY=${C_B_CYAN}
C_SECONDARY=${C_B_BLUE}
C_TEXT=${C_WHITE}
C_SUCCESS=${C_B_GREEN}
C_WARNING=${C_B_YELLOW}
C_ERROR=${C_B_RED}
C_ACCENT=${C_B_PURPLE}
C_INFO=${C_B_BLUE}
C_BORDER=${C_HI_BLUE}
C_INPUT_PROMPT=${C_ACCENT}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${C_ERROR}[错误] 请以 root 权限运行此脚本！${C_RESET}"
        exit 1
    fi
}

check_dependencies() {
    for cmd in curl jq lsof; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${C_WARNING}$cmd 未安装，正在安装...${C_RESET}"
            apt-get update &>/dev/null && apt-get install -y $cmd &>/dev/null
            if ! command -v $cmd &> /dev/null; then
                echo -e "${C_ERROR}[错误] $cmd 安装失败，请手动安装。${C_RESET}"
                exit 1
            fi
        fi
    done
}

create_symlink() {
    if [ ! -L "$SYMLINK_PATH" ] || [ "$(readlink -f "$SYMLINK_PATH")" != "$SCRIPT_PATH" ]; then
        echo -e "${C_INFO}首次运行，创建快捷命令 dns...${C_RESET}"
        ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
        chmod +x "$SYMLINK_PATH"
        echo -e "${C_SUCCESS}快捷命令 dns 创建成功！${C_RESET}"
    fi
}

is_valid_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then return 1; fi
        done
        return 0
    else
        return 1
    fi
}

is_valid_ipv6() {
    if [[ "$1" =~ ^([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}$ || "$1" =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ || "$1" =~ ^:(:[0-9a-fA-F]{1,4}){1,7}$ || "$1" =~ ^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$ || "$1" =~ ^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$ || "$1" =~ ^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$ || "$1" =~ ^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$ || "$1" =~ ^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$ || "$1" =~ ^[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})$ || "$1" =~ ^(::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4})$ ]]; then
        return 0
    else
        return 1
    fi
}

select_unlock_ips() {
    unlock_ipv4=""
    unlock_ipv6=""

    while true; do
        echo -e "\n${C_SECONDARY}--- 请选择解锁 IPv4 DNS地址 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}香港 (181.215.*.*)${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}洛杉矶 (31.22.*.*)${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}纽约 (31.59.*.*)${C_RESET}"
        echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}自定义 IPv4 地址${C_RESET}"
        echo -e "  ${C_WARNING}5.${C_RESET} ${C_TEXT}跳过 (不设置 IPv4)${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项 [1-5]: ${C_RESET}")" ipv4_choice

        case $ipv4_choice in
            1) unlock_ipv4="181.215.6.75"; break ;;
            2) unlock_ipv4="31.22.111.126"; break ;;
            3) unlock_ipv4="31.59.111.6"; break ;;
            4)
                while true; do
                    read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入您的自定义解锁 IPv4 DNS地址: ${C_RESET}")" custom_ipv4
                    if is_valid_ipv4 "$custom_ipv4"; then
                        unlock_ipv4="$custom_ipv4"
                        break
                    else
                        echo -e "${C_ERROR}无效的 IPv4 地址格式，请重新输入。${C_RESET}"
                    fi
                done
                break
                ;;
            5) break ;;
            *) echo -e "${C_ERROR}无效选项，请输入 1 到 5 之间的数字。${C_RESET}" ;;
        esac
    done

    while true; do
        echo -e "\n${C_SECONDARY}--- 请选择解锁 IPv6 DNS地址 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}公共 DNS (大家都能用)${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}专用 DNS (Alice 用户专用)${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}自定义 IPv6 地址${C_RESET}"
        echo -e "  ${C_WARNING}4.${C_RESET} ${C_TEXT}跳过 (不设置 IPv6)${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项 [1-4]: ${C_RESET}")" ipv6_choice

        case $ipv6_choice in
            1) unlock_ipv6="2a14:67c0:118::1"; break ;;
            2) unlock_ipv6="2a14:67c0:103:c::a"; break ;;
            3)
                while true; do
                    read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入您的自定义解锁 IPv6 DNS地址: ${C_RESET}")" custom_ipv6
                    if is_valid_ipv6 "$custom_ipv6"; then
                        unlock_ipv6="$custom_ipv6"
                        break
                    else
                        echo -e "${C_ERROR}无效的 IPv6 地址格式，请重新输入。${C_RESET}"
                    fi
                done
                break
                ;;
            4) break ;;
            *) echo -e "${C_ERROR}无效选项，请输入 1 到 4 之间的数字。${C_RESET}" ;;
        esac
    done

    if [ -z "$unlock_ipv4" ] && [ -z "$unlock_ipv6" ]; then
        echo -e "${C_WARNING}未选择任何 IP 地址，操作取消。${C_RESET}"
        return 1
    fi
    return 0
}

generate_config_from_api() {
    local type=$1
    local output_file=$2
    local ipv4_address=$3
    local ipv6_address=$4
    local display_type
    if [ "$type" = "dnsmasq" ]; then
        display_type="Dnsmasq"
    elif [ "$type" = "smartdns" ]; then
        display_type="SmartDNS"
    else
        display_type=$type
    fi

    echo -e "${C_INFO}正在从 Alice API 获取白名单...${C_RESET}"
    DOMAINS_JSON=$(curl -s "${API_BASE_URL}/api/get_alice_whitelist")

    if [ -z "$DOMAINS_JSON" ] || ! echo "$DOMAINS_JSON" | jq -e '.domains' > /dev/null; then
        echo -e "${C_ERROR}错误: 无法从 API 获取域名列表，或者列表为空。${C_RESET}"
        return 1
    fi
    
    SELECTED_DOMAINS=$(echo "$DOMAINS_JSON" | jq '.domains')
    echo -e "${C_SUCCESS}成功获取 Alice 白名单域名。${C_RESET}"

    echo -e "${C_INFO}正在生成 ${display_type} 配置...${C_RESET}"
    JSON_PAYLOAD=$(jq -n \
        --arg ipv4 "$ipv4_address" \
        --arg ipv6 "$ipv6_address" \
        --argjson domains "$SELECTED_DOMAINS" \
        '{ipv4: $ipv4, ipv6: $ipv6, selected_domains: $domains}')

    response=$(curl -s -X POST "${API_BASE_URL}/api/generate_${type}_config" \
        -H "Content-Type: application/json" \
        -d "${JSON_PAYLOAD}")

    if echo "${response}" | jq -e '.error' > /dev/null; then
        error_message=$(echo "${response}" | jq -r '.error')
        echo -e "${C_ERROR}错误: 生成 ${display_type} 配置失败: ${error_message}${C_RESET}"
        return 1
    fi

    echo "${response}" | jq -r '.config' > "${output_file}"
    echo -e "${C_SUCCESS}成功！${display_type} 配置已保存到 ${output_file}${C_RESET}"
    return 0
}

stop_services_on_port_53() {
    echo -e "${C_INFO}检查端口 53 的占用情况...${C_RESET}"
    PIDS=$(lsof -t -i:53)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            SERVICE_NAME=$(ps -p $PID -o comm=)
            echo -e "${C_WARNING}端口 53 被进程 $SERVICE_NAME (PID: $PID) 占用，正在停止...${C_RESET}"
            systemctl stop "$SERVICE_NAME" &>/dev/null
            systemctl disable "$SERVICE_NAME" &>/dev/null
            kill -9 "$PID" &>/dev/null
        done
        echo -e "${C_SUCCESS}端口 53 已释放。${C_RESET}"
    else
        echo -e "${C_SUCCESS}端口 53 未被占用。${C_RESET}"
    fi
}

set_and_lock_resolv_conf() {
    chattr -i /etc/resolv.conf &>/dev/null
    cp /etc/resolv.conf /etc/resolv.conf.bak."$(date +%s)"
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf
    echo -e "${C_SUCCESS}DNS 已设置为 127.0.0.1 并锁定。${C_RESET}"
}

restore_resolv_conf() {
    chattr -i /etc/resolv.conf &>/dev/null
    LATEST_BACKUP=$(ls -t /etc/resolv.conf.bak.* 2>/dev/null | head -n 1)
    if [ -f "$LATEST_BACKUP" ]; then
        mv "$LATEST_BACKUP" /etc/resolv.conf
        echo -e "${C_SUCCESS}已从最新备份 ($LATEST_BACKUP) 恢复 /etc/resolv.conf。${C_RESET}"
    else
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo -e "${C_WARNING}未找到备份，已将 DNS 设置为 8.8.8.8。${C_RESET}"
    fi
    if systemctl list-units --type=service | grep -q 'systemd-resolved'; then
        systemctl restart systemd-resolved
    fi
}

install_and_configure_dnsmasq() {
    echo -e "${C_INFO}开始安装和配置 Dnsmasq...${C_RESET}"
    apt-get install -y dnsmasq
    if ! command -v dnsmasq &> /dev/null; then
        echo -e "${C_ERROR}Dnsmasq 安装失败。${C_RESET}"
        return 1
    fi
    
    select_unlock_ips || return
    
    generate_config_from_api "dnsmasq" "$CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6" || return
    
    stop_services_on_port_53
    set_and_lock_resolv_conf
    
    systemctl restart dnsmasq && systemctl enable dnsmasq
    echo -e "${C_SUCCESS}Dnsmasq 安装配置完成并已启动。${C_RESET}"
}

uninstall_dnsmasq() {
    if ! dpkg-query -W -f='${Status}' dnsmasq 2>/dev/null | grep -q "ok installed"; then
        echo -e "${C_WARNING}Dnsmasq 未安装，无需卸载。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}开始卸载 Dnsmasq...${C_RESET}"
    systemctl stop dnsmasq && systemctl disable dnsmasq
    apt-get purge -y dnsmasq
    rm -f "$CONFIG_FILE"
    restore_resolv_conf
    echo -e "${C_SUCCESS}Dnsmasq 已卸载。${C_RESET}"
}

update_dnsmasq_config() {
    if ! dpkg-query -W -f='${Status}' dnsmasq 2>/dev/null | grep -q "ok installed"; then
        echo -e "${C_WARNING}Dnsmasq 未安装，请先安装。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}开始更新 Dnsmasq 配置...${C_RESET}"
    select_unlock_ips || return
    generate_config_from_api "dnsmasq" "$CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6" || return
    restart_dnsmasq
}

restart_dnsmasq() {
    if ! dpkg-query -W -f='${Status}' dnsmasq 2>/dev/null | grep -q "ok installed"; then
        echo -e "${C_WARNING}Dnsmasq 未安装，无需重启。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}正在重启 Dnsmasq 服务...${C_RESET}"
    systemctl restart dnsmasq
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${C_SUCCESS}Dnsmasq 服务重启成功。${C_RESET}"
    else
        echo -e "${C_ERROR}Dnsmasq 服务重启失败。${C_RESET}"
    fi
}

install_smartdns_package() {
    if command -v smartdns >/dev/null 2>&1; then
        echo -e "${C_SUCCESS}SmartDNS 已安装。${C_RESET}"
        return 0
    fi
    echo -e "${C_INFO}正在安装 SmartDNS...${C_RESET}"
    DEB_URL="https://github.com/pymumu/smartdns/releases/download/Release46/smartdns.1.2024.06.12-2222.x86_64-debian-all.deb"
    TEMP_DEB="/tmp/smartdns.deb"
    wget "$DEB_URL" -O "$TEMP_DEB" || { echo -e "${C_ERROR}SmartDNS 下载失败。${C_RESET}"; return 1; }
    dpkg -i "$TEMP_DEB"
    apt-get -f install -y
    rm -f "$TEMP_DEB"
    if ! command -v smartdns >/dev/null 2>&1; then
        echo -e "${C_ERROR}SmartDNS 安装失败。${C_RESET}"
        return 1
    fi
    echo -e "${C_SUCCESS}SmartDNS 安装成功。${C_RESET}"
}

install_and_configure_smartdns() {
    echo -e "${C_INFO}开始安装和配置 SmartDNS...${C_RESET}"
    install_smartdns_package || return
    
    select_unlock_ips || return
    
    generate_config_from_api "smartdns" "$SMARTDNS_CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6" || return
    
    stop_services_on_port_53
    set_and_lock_resolv_conf
    
    systemctl restart smartdns && systemctl enable smartdns
    echo -e "${C_SUCCESS}SmartDNS 安装配置完成并已启动。${C_RESET}"
}

uninstall_smartdns() {
    if ! dpkg-query -W -f='${Status}' smartdns 2>/dev/null | grep -q "ok installed"; then
        echo -e "${C_WARNING}SmartDNS 未安装，无需卸载。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}开始卸载 SmartDNS...${C_RESET}"
    systemctl stop smartdns && systemctl disable smartdns
    apt-get purge -y smartdns
    rm -f "$SMARTDNS_CONFIG_FILE"
    restore_resolv_conf
    echo -e "${C_SUCCESS}SmartDNS 已卸载。${C_RESET}"
}

update_smartdns_config() {
    if ! dpkg-query -W -f='${Status}' smartdns 2>/dev/null | grep -q "ok installed"; then
        echo -e "${C_WARNING}SmartDNS 未安装，请先安装。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}开始更新 SmartDNS 配置...${C_RESET}"
    select_unlock_ips || return
    generate_config_from_api "smartdns" "$SMARTDNS_CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6" || return
    restart_smartdns
}

restart_smartdns() {
    if ! dpkg-query -W -f='${Status}' smartdns 2>/dev/null | grep -q "ok installed"; then
        echo -e "${C_WARNING}SmartDNS 未安装，无需重启。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}正在重启 SmartDNS 服务...${C_RESET}"
    systemctl restart smartdns
    if systemctl is-active --quiet smartdns; then
        echo -e "${C_SUCCESS}SmartDNS 服务重启成功。${C_RESET}"
    else
        echo -e "${C_ERROR}SmartDNS 服务重启失败。${C_RESET}"
    fi
}

dnsmasq_menu() {
    while true; do
        echo -e "\n${C_SECONDARY}--- Dnsmasq 分流配置 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}安装并配置 Dnsmasq${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}卸载 Dnsmasq${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}更新 Dnsmasq 配置文件${C_RESET}"
        echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}重启 Dnsmasq 服务${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回主菜单${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) install_and_configure_dnsmasq ;;
            2) uninstall_dnsmasq ;;
            3) update_dnsmasq_config ;;
            4) restart_dnsmasq ;;
            0) break ;;
            *) echo -e "${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

smartdns_menu() {
    while true; do
        echo -e "\n${C_SECONDARY}--- SmartDNS 分流配置 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}安装并配置 SmartDNS${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}卸载 SmartDNS${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}更新 SmartDNS 配置文件${C_RESET}"
        echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}重启 SmartDNS 服务${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回主菜单${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) install_and_configure_smartdns ;;
            2) uninstall_smartdns ;;
            3) update_smartdns_config ;;
            4) restart_smartdns ;;
            0) break ;;
            *) echo -e "${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

dns_check_menu() {
    while true; do
        echo -e "\n${C_SECONDARY}--- 流媒体解锁检测 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}检测 IPv4 解锁${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}检测 IPv6 解锁${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}检测 IPv4&IPv6 解锁${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回主菜单${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/dns-check.sh) -M 4 ;;
            2) bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/dns-check.sh) -M 6 ;;
            3) bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/dns-check.sh) ;;
            0) break ;;
            *) echo -e "${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

update_script() {
    echo -e "${C_INFO}正在检查更新...${C_RESET}"
    REMOTE_VERSION=$(curl -s "https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/${SCRIPT_NAME}" | grep '^VERSION=' | cut -d'"' -f2)
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${C_ERROR}获取远程版本失败。${C_RESET}"
        return
    fi

    if [ "$REMOTE_VERSION" != "$VERSION" ]; then
        echo -e "${C_SUCCESS}发现新版本: $REMOTE_VERSION，正在更新...${C_RESET}"
        curl -o "$SCRIPT_PATH" "https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/${SCRIPT_NAME}"
        chmod +x "$SCRIPT_PATH"
        echo -e "${C_SUCCESS}更新完成，请重新运行脚本！${C_RESET}"
        exit 0
    else
        echo -e "${C_SUCCESS}当前已是最新版本。${C_RESET}"
    fi
}

delete_script() {
    read -p "$(echo -e "${C_WARNING}确定要删除此脚本及其快捷方式吗？(y/n): ${C_RESET}")" confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -f "$SCRIPT_PATH"
        rm -f "$SYMLINK_PATH"
        echo -e "${C_SUCCESS}脚本已成功删除。${C_RESET}"
        exit 0
    else
        echo -e "${C_INFO}操作已取消。${C_RESET}"
    fi
}

get_display_width() {
    local text="$1"
    echo -n "$text" | perl -Mutf8 -CS -ne '
        my $len = 0;
        for my $char (split //) {
            if (ord($char) < 128) {
                $len++;
            } else {
                $len += 2;
            }
        }
        print $len;
    '
}

display_header() {
    local width=40
    print_centered() {
        local text="$1"
        local color_code="$2"
        local len=$(get_display_width "$text")
        local padding=$(((width - len) / 2))
        
        if (( padding < 0 )); then padding=0; fi
        
        printf "%*s" $padding ""
        echo -e "${color_code}${text}${C_RESET}"
    }

    IP_INFO=$(curl -s http://ipinfo.io/json)
    IP_ADDRESS=$(echo "$IP_INFO" | jq -r '.ip // "N/A"')
    REGION=$(echo "$IP_INFO" | jq -r '.country // "N/A"')

    echo -e "${C_BORDER}\n========================================${C_RESET}"
    print_centered "Alice 专用 DNS 解锁脚本" "${C_PRIMARY}"
    print_centered "版本: $VERSION | 作者: $AUTHOR" "${C_HI_WHITE}"
    print_centered "VPS IP: $IP_ADDRESS ($REGION)" "${C_HI_WHITE}"
    echo -e "${C_BORDER}========================================${C_RESET}"
}

check_root
check_dependencies
create_symlink

while true; do
    display_header
    echo -e "${C_TEXT} 请选择操作:${C_RESET}"
    echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}Dnsmasq DNS分流${C_RESET}"
    echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}SmartDNS DNS分流${C_RESET}"
    echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}流媒体解锁检测${C_RESET}"
    echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}更新脚本${C_RESET}"
    echo -e "  ${C_WARNING}5.${C_RESET} ${C_TEXT}删除脚本${C_RESET}"
    echo -e "  ${C_ERROR}0.${C_RESET} ${C_TEXT}退出${C_RESET}"
    read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" main_choice

    case $main_choice in
        1) dnsmasq_menu ;;
        2) smartdns_menu ;;
        3) dns_check_menu ;;
        4) update_script ;;
        5) delete_script ;;
        0) echo -e "${C_ERROR}退出脚本...${C_RESET}"; exit 0 ;;
        *) echo -e "${C_ERROR}无效选项！${C_RESET}" ;;
    esac
done
