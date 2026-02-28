# FitMac

**让你的 Mac 更 Fit、更干净、更高效**

一个**开源、免费、安全、可审计**的 Mac 清理工具，支持 GUI（SwiftUI）+ CLI 双模式。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos)

## 特性

### 核心功能

- **磁盘状态** - 实时显示磁盘容量和使用率
- **缓存清理** - 智能清理系统、应用、浏览器、开发工具缓存
- **垃圾桶管理** - 统一管理所有磁盘的垃圾桶
- **语言文件** - 删除多余的语言包，节省空间
- **系统垃圾** - 清理临时文件、文档版本、系统残留
- **系统应用** - 安全移除内置应用（GarageBand、iMovie 等）
- **iTunes 垃圾** - 清理 iOS 备份和旧播客下载
- **邮件附件** - 管理邮件中的大附件
- **重复文件** - 基于 hash 查找重复文件
- **Homebrew 集成** - 清理 Homebrew 缓存和旧版本
- **启动项管理** - 管理登录项和 LaunchAgents
- **大文件查找** - 按大小/日期扫描大文件
- **应用卸载** - 完整卸载应用及其残留
- **清理历史** - 查看所有清理操作记录

### 安全特性

- **Dry-run 默认开启** - 预览所有更改再执行
- **废纸篓删除** - 所有文件移到废纸篓，可恢复
- **路径透明** - 显示每个文件的完整路径和大小
- **浏览器保护** - 自动保护书签、密码、扩展数据
- **无网络连接** - 除可选更新外，不发送任何数据

## 安装

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/yingounet/FitMac.git
cd FitMac

# 构建 CLI
swift build -c release

# 安装到 /usr/local/bin
sudo cp .build/release/fitmac /usr/local/bin/
```

### 构建 GUI 应用

```bash
# 使用 Xcode 打开
open Package.swift

# 或使用命令行构建
swift build -c release --product FitMacApp
```

## 快速开始

### CLI 使用

```bash
# 查看磁盘状态
fitmac status

# 扫描所有缓存
fitmac cache --scan

# 清理缓存（默认 dry-run）
fitmac cache --clean

# 实际执行清理
fitmac cache --clean --no-dry-run

# 查找大文件
fitmac large --min 500MB

# 卸载应用
fitmac uninstall "AppName" --clean

# 查看清理历史
fitmac log --list
```

### GUI 使用

运行 FitMacApp 后，左侧导航栏提供所有功能入口：

1. **Home** - 磁盘状态概览和快捷操作
2. **清理类** - Cache, System Junk, Trash, Language, iTunes, Mail, Homebrew
3. **文件管理** - Large Files, Duplicates
4. **系统管理** - System Apps, Login Items, Uninstall
5. **其他** - History（清理历史）, Permissions（权限设置）

## 项目结构

```
FitMac/
├── Sources/
│   ├── FitMacCore/           # 核心库 (CLI + GUI 共用)
│   │   ├── Cleaners/         # 扫描器和清理器
│   │   ├── Models/           # 数据模型
│   │   └── Utils/            # 工具类
│   ├── FitMacCLI/            # 命令行工具
│   │   ├── FitMacCLI.swift   # 入口
│   │   └── *Command.swift    # 各命令实现
│   └── FitMacApp/            # SwiftUI 应用
│       ├── Views/            # 视图层
│       ├── ViewModels/       # 视图模型
│       └── Utils/            # App 工具
├── Tests/
│   └── FitMacCoreTests/      # 单元测试
├── __docs/                   # 文档
└── Package.swift
```

## 系统要求

- **GUI**: macOS 13 Ventura 或更高版本
- **CLI**: macOS 12 Monterey 或更高版本
- **构建**: Xcode 15+ / Swift 5.9+

## 文档

完整文档请查看 [`__docs/`](__docs/README.md) 目录：

- [CLI 使用指南](__docs/cli/README.md)
- [功能模块文档](__docs/modules/README.md)
- [架构设计](__docs/architecture/overview.md)
- [贡献指南](__docs/development/contributing.md)

## 贡献

欢迎 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 致谢

灵感来源于 CleanMyMac、OnyX、Pearcleaner 等优秀的 Mac 清理工具。

---

**FitMac — Make Your Mac Fit Again!**
