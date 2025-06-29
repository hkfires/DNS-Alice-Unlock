# DNS Alice Unlock - DNS 解锁专用脚本

`DNS Alice Unlock` 是一个功能强大、简单易用的 Shell 脚本，专为想使用 Alice DNS 解锁用户设计，用于一键配置 Dnsmasq 或 SmartDNS，以实现流媒体服务的 DNS 解锁。

本脚本在 [https://github.com/Jimmyzxk/DNS-Alice-Unlock](https://github.com/Jimmyzxk/DNS-Alice-Unlock) 基础上重构而来。

脚本通过与后端 API 联动，自动获取最新的解锁域名白名单，并生成对应的配置文件，让您从繁琐的手动配置中解放出来。

### 📌 版本更新
* **v0.0.6**
  - 增加流媒体检测脚本的选择

* **v0.0.5**
  - 修改DNS选择，限制只能选择一种DNS类型

* **v0.0.4**
  - 集成Alice出口配置脚本

* **v0.0.3**
  - 增加DNS服务提示
  - 优化升级体验

* **v0.0.2**
  - 修复备份恢复BUG，目前会恢复最新版的备份文件

* **v0.0.1**
  - 初始版本发布


## ✨ 主要特性

*   **双引擎支持:** 您可以自由选择使用 `Dnsmasq` 或 `SmartDNS` 作为您的 DNS 分流服务。
*   **自动化配置:** 脚本通过 API 自动获取最新的流媒体域名白名单，并为您生成完整的配置文件。
*   **菜单式交互:** 提供清晰、直观的菜单界面，所有操作（安装、卸载、更新、重启）都可通过简单的数字选择完成。
*   **内置解锁检测:** 集成了流媒体解锁检测功能，无需使用其他工具，即可快速验证当前 VPS 的解锁效果。
*   **智能依赖管理:** 脚本会自动检测并安装所需的依赖包（如 `curl`, `jq`, `lsof`），实现开箱即用。
*   **安全可靠:**
    *   自动处理端口冲突，确保 DNS 服务正常启动。
    *   在卸载服务时，会自动恢复系统原有的 DNS 配置，避免网络中断。
*   **便捷的脚本管理:** 支持一键自我更新到最新版本，也支持一键彻底删除脚本自身。

## 🚀 快速开始

### 系统要求

*   Debian 或 Ubuntu 系统
*   `root` 用户权限，已安装`wget`

### 安装与运行

使用以下命令下载并运行脚本：

```bash
wget https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/main/dns-alice-unlock.sh && chmod +x dns-alice-unlock.sh && bash dns-alice-unlock.sh
```

首次运行后，脚本会自动创建一个快捷命令 `dns`，之后您可以直接在终端输入 `dns` 来再次运行此脚本。

## 📖 功能概览

运行脚本后，您将看到主菜单：

1.  **Dnsmasq DNS分流:** 进入 Dnsmasq 的管理菜单，可以进行安装、卸载、更新配置和重启服务等操作。
2.  **SmartDNS DNS分流:** 进入 SmartDNS 的管理菜单，操作与 Dnsmasq 类似。
3.  **流媒体解锁检测:** 检测当前网络的 IPv4 和/或 IPv6 流媒体解锁情况。
4.  **更新脚本:** 从 GitHub 拉取最新版本的脚本。
5.  **删除脚本:** 从您的系统中彻底移除本脚本和相关的快捷命令。
