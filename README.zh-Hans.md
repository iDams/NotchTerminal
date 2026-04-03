# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.1-green.svg)]()

[**English**](README.md) | [**Español**](README.es.md) | [**日本語**](README.ja.md) | **简体中文** | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

一款驻留在 macOS 刘海屏中的下拉式终端。快速、随时可用，且不碍事。

---

## 演示

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023

https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## 特性

- **刘海屏集成:** 悬停即可展开。适用于所有 Mac（即使没有物理刘海）以及多显示器环境。
- **菜单栏访问:** 提供菜单栏图标，可快速访问核心功能和设置。
- **会话管理:** SwiftData 持久化会在启动时自动恢复窗口的位置、大小和状态。
- **窗口管理:** 紧凑模式、始终置顶以及支持插入路径的拖放系统。
- **内置工具:**
  - *活动端口:* 查看正在监听的 TCP 端口并直接终止进程。
  - *存储分析器:* 快速扫描并清理 `node_modules`、`DerivedData`、缓存和日志。

### 实验性功能
NotchTerminal 包含一个实验性设置选项卡，提供以下功能：
- **CRT 滤镜:** 使用 Metal 着色器的复古 CRT 终端覆盖层。
- **模拟刘海发光:** 模拟从刘海处散发出的环境光（赛博朋克主题等）。
- **启动光球:** 应用程序启动时的视觉指示器。
- **拖动贴靠 (Drag-to-Dock):** 调整将终端窗口拖到刘海附近时的磁性吸附灵敏度。

### 键盘快捷键

| 快捷键 | 操作 |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | 复制 / 粘贴 / 全选 |
| `⌘K` | 清除缓冲区 |
| `⌘F` | 搜索 |
| `⌘W` | 关闭会话 |
| `⌘+` / `⌘-` | 调整字体大小 |

---

## 屏幕截图

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## 运行要求

- macOS 14 或更高版本
- Xcode 16+（仅用于从源码构建）

---

## 安装

### Homebrew

```bash
brew tap idams/notchterminal
brew install --cask notchterminal
```

### 直接下载

1. 打开 GitHub 上的最新 Release。
2. 下载 `NotchTerminal-<version>.zip`。
3. 解压该文件。
4. 将 `NotchTerminal.app` 移动到 `/Applications`。

Releases：

- https://github.com/iDams/NotchTerminal/releases

---

## 从源码构建

```bash
git clone https://github.com/iDams/NotchTerminal.git
cd NotchTerminal
```
打开 `NotchTerminal.xcodeproj` 并运行 `NotchTerminal` 方案。

**本地代码签名:**
该仓库不包含个人的 Apple `DEVELOPMENT_TEAM`。要进行本地构建：
1. 将 `Config/Signing.local.example.xcconfig` 复制为 `Config/Signing.local.xcconfig`
2. 添加您自己的 Apple 开发者团队 ID。
3. 确保此文件仅在本地使用（它已包含在 `.gitignore` 中）。

---

## 文档与链接

- [文档索引](docs/README.md)
- [测试指南](docs/quality/)
- [本地化说明](docs/localization/LOCALIZATION.md)
- [贡献指南](CONTRIBUTING.md)
- [第三方通知](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md)

---

## 反馈与问题

如果你发现了 bug、想请求新功能，或者遇到了安装问题：

- 提交 issue: https://github.com/iDams/NotchTerminal/issues

---

## 支持

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## 品牌说明

某些截图、图标和文字说明可能会提及 OpenAI、Claude、Copilot 或其他第三方工具与服务，用于展示工作流或互操作性。

这些名称、标志和商标均归其各自所有者所有。它们仅用于在应用、网站、文档或展示材料中进行识别和描述性说明。除非另有明确声明，NotchTerminal 与这些公司不存在任何隶属、背书或赞助关系。

---

## 许可证

[MIT](LICENSE) © 2026 Marco Astorga González
