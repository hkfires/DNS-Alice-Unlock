#!/bin/bash

VERSION="0.0.7"
LAST_UPDATED=$(date +"%Y-%m-%d")
AUTHOR="hKFirEs"

SCRIPT_NAME="dns-alice-unlock.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
SYMLINK_PATH="/usr/local/bin/dns"
CONFIG_FILE="/etc/dnsmasq.conf"
SMARTDNS_CONFIG_FILE="/etc/smartdns/smartdns.conf"

API_BASE_URL="https://dnsconfig.072899.xyz"
ONEKEY_SCRIPT_NAME="onekey-tun2socks.sh"
ONEKEY_SCRIPT_PATH="/root/$ONEKEY_SCRIPT_NAME"
 
IP_ADDRESS=""
REGION=""
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

has_ipv4() {
    (ip -4 addr show | grep -q "inet.*global") && \
    (curl -4 -s --connect-timeout 2 https://ifconfig.co &>/dev/null)
}

has_ipv6() {
    (ip -6 addr show | grep -q "inet6.*global") && \
    (curl -6 -s --connect-timeout 2 https://ifconfig.co &>/dev/null)
}

select_unlock_ips() {
    unlock_ipv4=""
    unlock_ipv6=""

    while true; do
        echo -e "\n${C_BORDER}┌───────────────────────────────────────┐${C_RESET}"
        echo -e "${C_BORDER}│ ${C_WARNING}   注意: 只能选择一种类型的DNS地址    ${C_BORDER}│${C_RESET}"
        echo -e "${C_BORDER}│ ${C_ERROR}  无${C_WARNING}Alice IPv4/IPv6地址${C_ERROR}勿选${C_WARNING}专用DNS！  ${C_BORDER}│${C_RESET}"
        echo -e "${C_BORDER}│ ${C_WARNING}  使用Alice家宽出口${C_ERROR}勿选${C_WARNING}IPv4专用DNS！  ${C_BORDER}│${C_RESET}"
        echo -e "${C_BORDER}│ ${C_WARNING}       选错DNS将导致无法上网！        ${C_BORDER}│${C_RESET}"
        echo -e "${C_BORDER}└───────────────────────────────────────┘${C_RESET}"
        echo -e "  ${C_B_YELLOW}--- IPv4 DNS 选项 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}专用 DNS (香港)${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}专用 DNS (洛杉矶)${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}专用 DNS (纽约)${C_RESET}"
        echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}自定义 IPv4 地址${C_RESET}"
        echo -e "  ${C_B_YELLOW}--- IPv6 DNS 选项 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}5.${C_RESET} ${C_TEXT}公共 DNS (暂时无法使用)${C_RESET}"
        echo -e "  ${C_PRIMARY}6.${C_RESET} ${C_TEXT}专用 DNS (Alice用户专用)${C_RESET}"
        echo -e "  ${C_PRIMARY}7.${C_RESET} ${C_TEXT}自定义 IPv6 地址${C_RESET}"
        echo -e "  ${C_WARNING}8.${C_RESET} ${C_TEXT}跳过 (不设置任何DNS地址)${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项 [1-8]: ${C_RESET}")" choice

        case $choice in
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
                        echo -e "\n${C_ERROR}无效的 IPv4 地址格式，请重新输入。${C_RESET}"
                    fi
                done
                break
                ;;
            5) unlock_ipv6="2a14:67c0:118::1"; break ;;
            6) unlock_ipv6="2a14:67c0:103:c::a"; break ;;
            7)
                while true; do
                    read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入您的自定义解锁 IPv6 DNS地址: ${C_RESET}")" custom_ipv6
                    if is_valid_ipv6 "$custom_ipv6"; then
                        unlock_ipv6="$custom_ipv6"
                        break
                    else
                        echo -e "\n${C_ERROR}无效的 IPv6 地址格式，请重新输入。${C_RESET}"
                    fi
                done
                break
                ;;
            8) break ;;
            *) echo -e "\n${C_ERROR}无效选项，请输入 1 到 8 之间的数字。${C_RESET}" ;;
        esac
    done

    if [ -z "$unlock_ipv4" ] && [ -z "$unlock_ipv6" ]; then
        echo -e "\n${C_WARNING}未选择任何 IP 地址，操作取消。${C_RESET}"
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
        echo -e "\n${C_ERROR}错误: 无法从 API 获取域名列表，或者列表为空。${C_RESET}"
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
        echo -e "\n${C_ERROR}错误: 生成 ${display_type} 配置失败: ${error_message}${C_RESET}"
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

display_backup_list() {
    local -n backups_ref=$1
    echo -e "\n${C_SECONDARY}--- 可用的 resolv.conf 备份 ---${C_RESET}"
    
    i=1
    for backup in "${backups_ref[@]}"; do
        TIMESTAMP=$(echo "$backup" | grep -o '[0-9]*$')
        BACKUP_DATE=$(date -d "@$TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
        
        echo -e "${C_PRIMARY}${i}.${C_RESET} ${C_TEXT}${backup}${C_RESET} (${C_HI_WHITE}备份于: ${BACKUP_DATE}${C_RESET})"
        echo -e "${C_HI_BLACK}┌─ 文件内容预览 (前5行) ─"
        head -n 5 "$backup" | sed 's/^/│ /'
        echo -e "└──────────────────────────${C_RESET}\n"
        ((i++))
    done
}

restore_resolv_conf() {
    chattr -i /etc/resolv.conf &>/dev/null
    
    mapfile -t SORTED_BACKUPS < <(ls -t /etc/resolv.conf.bak* 2>/dev/null)

    if [ ${#SORTED_BACKUPS[@]} -eq 0 ]; then
        echo -e "\n${C_WARNING}未找到任何 resolv.conf 备份文件。${C_RESET}"
        
        local new_content
        if has_ipv4; then
            new_content="nameserver 1.1.1.1\nnameserver 8.8.8.8"
        elif has_ipv6; then
            new_content="nameserver 2606:4700:4700::1111\nnameserver 2001:4860:4860::8888"
        else
            echo -e "${C_ERROR}未检测到有效的 IPv4 或 IPv6 网络连接，无法设置默认DNS。${C_RESET}"
            return
        fi

        echo -e "\n${C_INFO}当前 /etc/resolv.conf 内容预览 (前5行):${C_RESET}"
        echo -e "${C_HI_BLACK}┌──────────────────────────"
        head -n 5 /etc/resolv.conf | sed 's/^/│ /'
        echo -e "└──────────────────────────${C_RESET}"

        echo -e "\n${C_INFO}将应用以下默认DNS配置:${C_RESET}"
        echo -e "${C_HI_BLACK}┌──────────────────────────"
        echo -e "${new_content}" | sed 's/^/│ /'
        echo -e "└──────────────────────────${C_RESET}"
        
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 是否应用此恢复？ (y/n): ${C_RESET}")" confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo -e "$new_content" > /etc/resolv.conf
            echo -e "${C_SUCCESS}已将 DNS 设置为公共 DNS。${C_RESET}"
        else
            echo -e "\n${C_INFO}操作已取消。${C_RESET}"
        fi
    else
        display_backup_list SORTED_BACKUPS
        
        echo -e "${C_SUCCESS}0.${C_RESET} ${C_TEXT}取消恢复并返回${C_RESET}"
        
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请选择要恢复的备份 [0-$((${#SORTED_BACKUPS[@]}))]: ${C_RESET}")" choice
        
        if [[ "$choice" -gt 0 && "$choice" -le "${#SORTED_BACKUPS[@]}" ]]; then
            SELECTED_BACKUP="${SORTED_BACKUPS[$((choice-1))]}"
            
            echo -e "\n${C_INFO}当前 /etc/resolv.conf 内容预览 (前5行):${C_RESET}"
            echo -e "${C_HI_BLACK}┌──────────────────────────"
            head -n 5 /etc/resolv.conf | sed 's/^/│ /'
            echo -e "└──────────────────────────${C_RESET}"

            echo -e "\n${C_INFO}选定的备份 '${SELECTED_BACKUP}' 内容预览 (前5行):${C_RESET}"
            echo -e "${C_HI_BLACK}┌──────────────────────────"
            head -n 5 "$SELECTED_BACKUP" | sed 's/^/│ /'
            echo -e "└──────────────────────────${C_RESET}"

            read -p "$(echo -e "${C_INPUT_PROMPT} ► 是否恢复此备份？ (y/n): ${C_RESET}")" confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                cp "$SELECTED_BACKUP" /etc/resolv.conf
                echo -e "${C_SUCCESS}已从备份 ($SELECTED_BACKUP) 恢复 /etc/resolv.conf。${C_RESET}"
            else
                echo -e "\n${C_INFO}恢复操作已取消。${C_RESET}"
            fi
        elif [ "$choice" == "0" ]; then
            echo -e "\n${C_INFO}操作已取消。${C_RESET}"
        else
            echo -e "\n${C_ERROR}无效选项！恢复操作已取消。${C_RESET}"
        fi
    fi

    if systemctl list-units --type=service | grep -q 'systemd-resolved'; then
        systemctl restart systemd-resolved
        echo -e "${C_INFO}已重启 systemd-resolved 服务。${C_RESET}"
    fi
}

delete_resolv_backup() {
    mapfile -t SORTED_BACKUPS < <(ls -t /etc/resolv.conf.bak* 2>/dev/null)

    if [ ${#SORTED_BACKUPS[@]} -eq 0 ]; then
        echo -e "\n${C_WARNING}未找到任何 resolv.conf 备份文件。${C_RESET}"
        return
    fi

    display_backup_list SORTED_BACKUPS
    
    echo -e "${C_SUCCESS}0.${C_RESET} ${C_TEXT}取消删除并返回${C_RESET}"
    
    read -p "$(echo -e "${C_INPUT_PROMPT} ► 请选择要删除的备份 [0-$((${#SORTED_BACKUPS[@]}))]: ${C_RESET}")" choice
    
    if [[ "$choice" -gt 0 && "$choice" -le "${#SORTED_BACKUPS[@]}" ]]; then
        SELECTED_BACKUP="${SORTED_BACKUPS[$((choice-1))]}"
        read -p "$(echo -e "${C_WARNING}您确定要删除备份文件 ${SELECTED_BACKUP} 吗？此操作不可逆！ (y/n): ${C_RESET}")" confirm_delete
        if [[ "$confirm_delete" == "y" || "$confirm_delete" == "Y" ]]; then
            rm -f "$SELECTED_BACKUP"
            echo -e "\n${C_SUCCESS}备份文件 ${SELECTED_BACKUP} 已被删除。${C_RESET}"
        else
            echo -e "\n${C_INFO}删除操作已取消。${C_RESET}"
        fi
    elif [ "$choice" == "0" ]; then
        echo -e "\n${C_INFO}操作已取消。${C_RESET}"
    else
        echo -e "\n${C_ERROR}无效选项！删除操作已取消。${C_RESET}"
    fi
}

backup_resolv_conf() {
    local backup_file="/etc/resolv.conf.bak.$(date +%s)"
    cp /etc/resolv.conf "$backup_file"
    if [ $? -eq 0 ]; then
        echo -e "\n${C_SUCCESS}成功创建备份: ${backup_file}${C_RESET}"
    else
        echo -e "\n${C_ERROR}创建备份失败！${C_RESET}"
    fi
}

system_dns_menu() {
    while true; do
        echo -e "\n${C_SECONDARY}--- 系统DNS配置管理 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}备份 resolv.conf 文件${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}恢复 resolv.conf 备份${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}删除 resolv.conf 备份${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回主菜单${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) backup_resolv_conf ;;
            2) restore_resolv_conf ;;
            3) delete_resolv_backup ;;
            0) break ;;
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

install_and_configure_dnsmasq() {
    echo -e "${C_INFO}开始安装和配置 Dnsmasq...${C_RESET}"
    apt-get install -y dnsmasq
    if ! command -v dnsmasq &> /dev/null; then
        echo -e "\n${C_ERROR}Dnsmasq 安装失败。${C_RESET}"
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
        echo -e "\n${C_WARNING}Dnsmasq 未安装，无需卸载。${C_RESET}"
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
        echo -e "\n${C_WARNING}Dnsmasq 未安装，请先安装。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}开始更新 Dnsmasq 配置...${C_RESET}"
    select_unlock_ips || return
    generate_config_from_api "dnsmasq" "$CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6" || return
    restart_dnsmasq
}

restart_dnsmasq() {
    if ! dpkg-query -W -f='${Status}' dnsmasq 2>/dev/null | grep -q "ok installed"; then
        echo -e "\n${C_WARNING}Dnsmasq 未安装，无需重启。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}正在重启 Dnsmasq 服务...${C_RESET}"
    systemctl restart dnsmasq
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${C_SUCCESS}Dnsmasq 服务重启成功。${C_RESET}"
    else
        echo -e "\n${C_ERROR}Dnsmasq 服务重启失败。${C_RESET}"
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
        echo -e "\n${C_ERROR}SmartDNS 安装失败。${C_RESET}"
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
        echo -e "\n${C_WARNING}SmartDNS 未安装，无需卸载。${C_RESET}"
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
        echo -e "\n${C_WARNING}SmartDNS 未安装，请先安装。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}开始更新 SmartDNS 配置...${C_RESET}"
    select_unlock_ips || return
    generate_config_from_api "smartdns" "$SMARTDNS_CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6" || return
    restart_smartdns
}

restart_smartdns() {
    if ! dpkg-query -W -f='${Status}' smartdns 2>/dev/null | grep -q "ok installed"; then
        echo -e "\n${C_WARNING}SmartDNS 未安装，无需重启。${C_RESET}"
        return
    fi
    echo -e "${C_INFO}正在重启 SmartDNS 服务...${C_RESET}"
    systemctl restart smartdns
    if systemctl is-active --quiet smartdns; then
        echo -e "${C_SUCCESS}SmartDNS 服务重启成功。${C_RESET}"
    else
        echo -e "\n${C_ERROR}SmartDNS 服务重启失败。${C_RESET}"
    fi
}

onekey_script_check() {
    if [ ! -f "$ONEKEY_SCRIPT_PATH" ]; then
        echo -e "${C_INFO}检测到出口配置脚本不存在，正在下载...${C_RESET}"
        curl -L https://raw.githubusercontent.com/hkfires/onekey-tun2socks/main/onekey-tun2socks.sh -o "$ONEKEY_SCRIPT_PATH"
        if [ $? -ne 0 ]; then
            echo -e "\n${C_ERROR}脚本下载失败，请检查网络或手动下载。${C_RESET}"
            return 1
        fi
        chmod +x "$ONEKEY_SCRIPT_PATH"
        echo -e "${C_SUCCESS}脚本下载并授权成功！${C_RESET}"
    fi
    return 0
}

install_alice_exit() {
    onekey_script_check || return
    echo -e "\n${C_INFO}--- 正在安装 Alice 出口 ---${C_RESET}"
    sudo "$ONEKEY_SCRIPT_PATH" -i alice
    refresh_ip_info
}

change_alice_exit() {
    onekey_script_check || return
    sudo "$ONEKEY_SCRIPT_PATH" -s
    refresh_ip_info
}

update_alice_exit() {
    onekey_script_check || return
    sudo "$ONEKEY_SCRIPT_PATH" -u
}

uninstall_alice_exit() {
    onekey_script_check || return
    sudo "$ONEKEY_SCRIPT_PATH" -r
    refresh_ip_info
}

alice_socks5_menu() {
    while true; do
        echo -e "\n${C_SECONDARY}--- Alice Socks5 出口 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}安装 Alice 出口${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}变更 Alice 出口${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}更新出口配置脚本${C_RESET}"
        echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}卸载出口配置脚本${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回主菜单${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) install_alice_exit ;;
            2) change_alice_exit ;;
            3) update_alice_exit ;;
            4) uninstall_alice_exit ;;
            0) break ;;
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
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
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
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
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

xykt_media_check() {
    while true; do
        echo -e "\n${C_SECONDARY}--- XYKT流媒体检测脚本 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}检测 IPv4 解锁${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}检测 IPv6 解锁${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}检测 IPv4&IPv6 解锁${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回上一级${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/refs/heads/main/dns-check.sh) -M 4 ;;
            2) bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/refs/heads/main/dns-check.sh) -M 6 ;;
            3) bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/refs/heads/main/dns-check.sh) ;;
            0) break ;;
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

1stream_media_check() {
    while true; do
        echo -e "\n${C_SECONDARY}--- 1-Stream流媒体检测脚本 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}检测 IPv4 解锁${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}检测 IPv6 解锁${C_RESET}"
        echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}检测 IPv4&IPv6 解锁${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回上一级${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) bash <(curl -L -s https://raw.githubusercontent.com/1-stream/RegionRestrictionCheck/refs/heads/main/check.sh) -M 4 ;;
            2) bash <(curl -L -s https://raw.githubusercontent.com/1-stream/RegionRestrictionCheck/refs/heads/main/check.sh) -M 6 ;;
            3) bash <(curl -L -s https://raw.githubusercontent.com/1-stream/RegionRestrictionCheck/refs/heads/main/check.sh) ;;
            0) break ;;
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

dns_check_menu() {
    while true; do
        echo -e "\n${C_SECONDARY}--- 流媒体解锁检测 ---${C_RESET}"
        echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}1-Stream流媒体检测脚本"
        echo -e "  ${C_HI_BLACK}(检测项目和分流域名一一对应，但不能区分DNS和原生解锁)${C_RESET}"
        echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}XYKT流媒体检测脚本"
        echo -e "  ${C_HI_BLACK}(检测项目和分流域名不完全对应，但能够区分DNS和原生解锁)${C_RESET}"
        echo -e "  ${C_SUCCESS}0.${C_RESET} ${C_TEXT}返回主菜单${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" choice
        case $choice in
            1) 1stream_media_check ;;
            2) xykt_media_check ;;
            0) break ;;
            *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
        esac
    done
}

update_script() {
    echo -e "${C_INFO}正在检查更新...${C_RESET}"
    REMOTE_VERSION=$(curl -s "https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/${SCRIPT_NAME}" | grep '^VERSION=' | cut -d'"' -f2)
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "\n${C_ERROR}获取远程版本失败。${C_RESET}"
        return
    fi

    if dpkg --compare-versions "$REMOTE_VERSION" "gt" "$VERSION"; then
        echo -e "${C_SUCCESS}发现新版本！${C_RESET}"
        echo -e "${C_INFO}当前版本: ${C_YELLOW}${VERSION}${C_RESET}"
        echo -e "${C_INFO}最新版本: ${C_GREEN}${REMOTE_VERSION}${C_RESET}"
        read -p "$(echo -e "${C_INPUT_PROMPT} ► 是否要更新到最新版本？(y/n): ${C_RESET}")" confirm_update
        if [[ "$confirm_update" == "y" || "$confirm_update" == "Y" ]]; then
            echo -e "${C_INFO}正在更新...${C_RESET}"
            curl -o "$SCRIPT_PATH" "https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/${SCRIPT_NAME}"
            chmod +x "$SCRIPT_PATH"
            echo -e "${C_SUCCESS}更新完成，请重新运行脚本！${C_RESET}"
            exit 0
        else
            echo -e "\n${C_INFO}更新已取消。${C_RESET}"
        fi
    elif [ "$REMOTE_VERSION" == "$VERSION" ]; then
        echo -e "\n${C_SUCCESS}当前已是最新版本。${C_RESET}"
    else
        echo -e "\n${C_WARNING}本地版本 (${VERSION}) 高于远程版本 (${REMOTE_VERSION})，无需更新。${C_RESET}"
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
        echo -e "\n${C_INFO}操作已取消。${C_RESET}"
    fi
}

refresh_ip_info() {
    echo -e "${C_INFO}正在获取最新的网络信息...${C_RESET}"
    IP_INFO=$(curl -s http://ipinfo.io/json)
    IP_ADDRESS=$(echo "$IP_INFO" | jq -r '.ip // "N/A"')
    REGION=$(echo "$IP_INFO" | jq -r '.country // "N/A"')
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

get_dns_status() {
    if systemctl is-active --quiet dnsmasq; then
        echo "Dnsmasq"
    elif systemctl is-active --quiet smartdns; then
        echo "SmartDNS"
    else
        echo "系统默认"
    fi
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
 
    DNS_STATUS=$(get_dns_status)
 
    echo -e "${C_BORDER}\n========================================${C_RESET}"
    print_centered "Alice 专用 DNS 解锁脚本" "${C_PRIMARY}"
    print_centered "版本: $VERSION | 作者: $AUTHOR" "${C_HI_WHITE}"
    print_centered "VPS IP: $IP_ADDRESS ($REGION)" "${C_HI_WHITE}"
    print_centered "当前DNS服务: $DNS_STATUS" "${C_HI_WHITE}"
    echo -e "${C_BORDER}========================================${C_RESET}"
}

check_root
check_dependencies
create_symlink
refresh_ip_info
 
while true; do
    display_header
    echo -e "${C_TEXT} 请选择操作:${C_RESET}"
    echo -e "  ${C_PRIMARY}1.${C_RESET} ${C_TEXT}Alice Socks5出口${C_RESET}"
    echo -e "  ${C_PRIMARY}2.${C_RESET} ${C_TEXT}Dnsmasq DNS分流${C_RESET}"
    echo -e "  ${C_PRIMARY}3.${C_RESET} ${C_TEXT}SmartDNS DNS分流${C_RESET}"
    echo -e "  ${C_PRIMARY}4.${C_RESET} ${C_TEXT}流媒体解锁检测${C_RESET}"
    echo -e "  ${C_PRIMARY}5.${C_RESET} ${C_TEXT}系统DNS配置管理${C_RESET}"
    echo -e "  ${C_PRIMARY}6.${C_RESET} ${C_TEXT}更新脚本${C_RESET}"
    echo -e "  ${C_WARNING}7.${C_RESET} ${C_TEXT}删除脚本${C_RESET}"
    echo -e "  ${C_ERROR}0.${C_RESET} ${C_TEXT}退出${C_RESET}"
    read -p "$(echo -e "${C_INPUT_PROMPT} ► 请输入选项: ${C_RESET}")" main_choice
 
    case $main_choice in
        1) alice_socks5_menu ;;
        2) dnsmasq_menu ;;
        3) smartdns_menu ;;
        4) dns_check_menu ;;
        5) system_dns_menu ;;
        6) update_script ;;
        7) delete_script ;;
        0) echo -e "\n${C_ERROR}退出脚本...${C_RESET}\n"; exit 0 ;;
        *) echo -e "\n${C_ERROR}无效选项！${C_RESET}" ;;
    esac
done
