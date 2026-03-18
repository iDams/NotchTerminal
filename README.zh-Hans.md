# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.0-green.svg)]()

[**English**](README.md) | [**Español**](README.es.md) | [**日本語**](README.ja.md) | **简体中文** | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

**NotchTerminal** 是一款围绕“刘海屏”（notch）构建的 macOS 终端应用程序。保持终端访问快速、可见并贴近您的当前工作，而不会让桌面堆满多余的窗口。

---

## 演示

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023


https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## 目录

- [屏幕截图](#屏幕截图)
- [特性](#特性)
- [运行要求](#运行要求)
- [安装](#安装)
- [从源码构建](#从源码构建)
- [项目结构](#项目结构)
- [设置](#设置)
- [文档](#文档)
- [贡献](#贡献)
- [致谢](#致谢)
- [支持](#支持)
- [许可证](#许可证)

---

## 屏幕截图

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## 特性

### 刘海覆盖层
- 悬停展开
- 支持多显示器工作
- 兼容带物理刘海或不带物理刘海的 Mac
- 显示最小化的终端标签
- 快速操作：`新建`、`重组`、`批量处理`、`设置`

### 终端窗口
- 打开/关闭/最小化/最大化
- 紧凑模式
- 窗口置顶切换
- 拖动至刘海附近自动贴靠刘海
- 拖放文件/文件夹（插入转义路径）

### 会话
- 基于 SwiftData 的持久化
- 启动时自动恢复：位置、大小、贴靠状态、紧凑模式、始终置顶、最大化状态

### 开发者工具
- **活动端口**: 列出监听中的 TCP 端口，支持过滤和按 PID 终止进程
- **存储分析**: 扫描 `node_modules`、`DerivedData`、`Pods`、缓存、日志、废纸篓等

### 视觉效果
- 极光背景样式
- CRT 滤镜
- 模拟刘海发光效果

### 菜单栏
- 快速访问：新建终端、显示所有窗口、设置、隐藏、退出

### 键盘快捷键
| 快捷键 | 操作 |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | 复制 / 粘贴 / 全选 |
| `⌘K` | 清除缓冲区 |
| `⌘F` | 搜索 |
| `⌘W` | 关闭会话 |
| `⌘+` / `⌘-` | 调整字体大小 |

---

## 运行要求

- macOS 14 或更高版本
- Xcode 16+（仅用于开发）

> 默认的 shell 是 `/bin/zsh`，可在任何纯净的 macOS 安装系统中使用。

---

## 安装

> 敬请期待

---

## 从源码构建

1. 克隆仓库:
   ```bash
   git clone https://github.com/marcoastorj/NotchTerminal.git
   cd NotchTerminal
   ```

2. 打开 `NotchTerminal.xcodeproj`

3. 选择 `NotchTerminal` 方案

4. 构建并运行

### 贡献者的本地代码签名

该仓库不包含个人的 Apple `DEVELOPMENT_TEAM`：

1. 将 `Config/Signing.local.example.xcconfig` 复制为 `Config/Signing.local.xcconfig`
2. 用您自己的 Apple 开发者团队 ID 替换 `YOURTEAMID`
3. 确保 `Config/Signing.local.xcconfig` 仅在本地使用（已加入 `.gitignore`）

### 调试工作流

调试构建会自动安装到 `/Applications/NotchTerminal.app`，以便在 Xcode 外部进行测试。

---

## 项目结构

```
NotchTerminal/
├── App/                    # 应用程序生命周期
├── Features/
│   ├── Notch/              # 覆盖层 UI 与交互
│   ├── Storage/            # 存储分析
│   ├── Windows/            # 窗口管理器与终端
│   └── Persistence/        # SwiftData 模型
├── Rendering/Metal/        # 着色器与渲染器
├── Settings/               # 设置屏幕
├── Services/               # 助手和共享服务
└── Assets.xcassets/        # 图标和图片
```

---

## 设置

| 部分 | 主要选项 |
|---------|--------------|
| **通用** | 语言、触觉反馈、程序坞图标、菜单栏图标、悬停行为 |
| **刘海** | 按显示器启用/禁用、X/Y 偏移、宽度、自定义极光 |
| **外观** | 边距、悬停关闭标签、悬停预览、极光主题 |
| **关于** | 显示实验选项卡 |
| **实验功能** | 贴靠刘海的拖动灵敏度、启动光球、模拟刘海发光、CRT 滤镜 |

支持语言：English, Español, Français, 日本語, 简体中文

---

## 文档

- 文档索引：[`docs/README.md`](docs/README.md)
- 测试指南：[`docs/quality/`](docs/quality/)
- 本地化说明：[`docs/localization/LOCALIZATION.md`](docs/localization/LOCALIZATION.md)

---

## 贡献

查看 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

---

## 致谢

查看 [`NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md)。

主要致谢：
- **SwiftTerm** – 终端模拟 (MIT)
- **Port-Killer** – 端口工作流灵感 (MIT)

UI 中使用的品牌标志/徽标属于其各自的所有者。

---

## 支持

如果您想支持开发：

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## 许可证

[MIT](LICENSE) © 2026 Marco Astorga González

---

<p align="center">
  Made with ❤️ by Marco Astorga González
</p>