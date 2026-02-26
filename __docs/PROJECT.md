# FitMac

**让你的 Mac 更 Fit、更干净、更高效**  
一个**开源、免费、安全、可审计**的 Mac 清理工具，支持 GUI（SwiftUI） + CLI 双模式。

类似于 CleanMyMac / OnyX 的功能，但完全开源（MIT 许可），无广告、无联网（除可选更新）、用户可审计所有清理路径。

- 项目状态：规划 / 开发中
- 最低支持：macOS 13 Ventura（GUI），CLI 可降级至 macOS 11 Big Sur 或更低
- 语言：Swift 5.9+（纯原生，无 Electron）
- 许可证：MIT
项目名称：FitMac 
名字灵感：让mac保持好身材
包名：net.yingou.FitMac
## 核心目标

- 帮助用户安全释放磁盘空间
- 智能卸载应用残留
- 扫描并管理大文件 / 旧文件
- 提供透明、可控的清理过程（Dry-run + 二次确认 + 文件列表预览）
- 支持 CLI 一键操作，适合脚本 / 自动化
- 中英双语界面 & 文档（优先中文用户友好）

## 功能计划（分阶段）

### 阶段 1：MVP（最小可用产品，快速上线验证）

| 优先级 | 功能名称               | 描述                                                                 | GUI 支持                  | CLI 示例命令                              | 安全机制                          |
|--------|------------------------|----------------------------------------------------------------------|---------------------------|-------------------------------------------|-----------------------------------|
| ★★★★★  | 系统/应用缓存清理     | 扫描并删除常见缓存、日志、临时文件、浏览器缓存等                     | 分类列表 + 选中删除       | `fitmac cache --all --dry-run`            | Dry-run 默认、分类可选            |
| ★★★★★  | 应用残留 / 完整卸载   | 拖入 .app 或输入名称 → 扫描并删除残留文件（Preferences、Containers 等） | 拖拽 + 搜索 + 文件预览    | `fitmac uninstall "WeChat" --force`       | 二次确认 + 显示完整路径列表      |
| ★★★★☆  | 大文件 / 旧文件扫描   | 扫描用户目录大文件，支持最小尺寸过滤、可排序、可预览                 | 树状/列表视图             | `fitmac large --path ~/Downloads --min 500MB` | 只扫描用户目录，支持移到 Trash   |
| ★★★★☆  | 空间使用概览           | 显示磁盘总容量、使用情况、清理前后对比                               | 首页仪表盘 / 卡片         | `fitmac status`                           | 实时统计                          |
| ★★★☆☆  | Dry-run / 模拟模式    | 所有操作先模拟，显示将删除的文件 & 预计释放空间                     | 默认开启，可切换          | `--dry-run`（全局旗标）                   | 核心安全机制                      |

**MVP 目标**：1–2 个月内发布可用的 CLI + 简单 GUI，让用户真正清理出空间。

### 阶段 2：1.0 核心版（对标主流工具）

| 优先级 | 功能名称                     | 描述                                                                 | GUI 支持                        | CLI 示例命令                                   | 安全/注意点                              |
|--------|------------------------------|----------------------------------------------------------------------|---------------------------------|------------------------------------------------|------------------------------------------|
| ★★★★★  | 系统内置应用安全移除         | 列出可安全移除的内置 App（如 GarageBand、iMovie），移 Trash + forget | 警告弹窗 + 列表                 | `fitmac system remove "GarageBand"`            | 只列安全项、强烈警告                     |
| ★★★★☆  | 开发工具缓存清理             | Xcode DerivedData、CocoaPods、npm、Homebrew 等                       | 独立 Tab                        | `fitmac dev --xcode --all`                     | 用户可选模块                             |
| ★★★★☆  | 浏览器深度清理               | Safari/Chrome/Firefox/Edge 缓存、扩展残留等                         | 浏览器分类                      | `fitmac browser --chrome --cache`              | 避免删书签/密码                          |
| ★★★★☆  | 重复文件 / 相似照片查找      | 基于 hash 或相似度查找重复图片/文档                                 | 预览对比视图                    | （暂无，未来支持）                             | 计算密集，可后台                         |
| ★★★☆☆  | 系统维护脚本                 | 运行类似 OnyX 的维护脚本（update locate db 等）                     | 一键执行                        | `fitmac maintain`                              | 只运行无害脚本                           |
| ★★★☆☆  | 清理历史 & 日志查看          | 查看每次清理记录、可选撤销（从 Trash 恢复）                         | 日志 Tab                        | `fitmac log --list`                            | 日志存 ~/Library/Logs/FitMac/            |

### 阶段 3：未来扩展（社区驱动）

- 菜单栏小组件（显示磁盘使用、快速清理）
- iCloud / 云存储优化
- 启动项 / Launch Agents 管理
- 内存释放 / 闲置进程清理
- 自定义清理规则（用户添加路径）
- 多语言（中英起步，后续日韩等）
- 自动更新（Sparkle，可选）
- Homebrew cask 发布

## 设计原则

1. **安全第一**：永不偷偷删除，所有操作 Dry-run + 二次确认 + 路径预览
2. **完全透明**：用户能看到每个文件/文件夹的路径、大小、来源
3. **轻量原生**：纯 Swift + SwiftUI，无额外运行时
4. **开源友好**：MIT 许可，鼓励 PR 贡献新清理路径
5. **权限最小化**：需 Full Disk Access，但只用于用户授权的扫描
6. **用户痛点导向**：空间不足、残留文件多、想手动选删

## 技术栈（初步）

- **语言**：Swift 5.9+
- **GUI**：SwiftUI（macOS 13+）
- **CLI**：swift-argument-parser
- **包管理**：Swift Package Manager (SPM)
- **核心库**：FileManager、Combine / async-await、UserDefaults
- **可选**：Sparkle（自动更新）、Charts（空间图表）

## 项目结构建议
FitMac/
├── FitMacCore/             # 纯逻辑库（App + CLI 共用）
│   ├── Sources/
│   │   ├── Cleaners/       # CacheCleaner.swift, LeftoverCleaner.swift 等
│   │   ├── Models/         # CleanupItem.swift, ScanResult.swift
│   │   └── Utils/          # FileUtils.swift, SizeFormatter.swift
├── FitMacApp/              # SwiftUI 主应用
├── FitMacCLI/              # 命令行工具 target
├── Tests/
└── README.md


## 贡献指南

欢迎 Issue / PR！
- 优先添加新的安全清理路径（PR 到 Core/Cleaners/）
- 翻译（Strings Catalog）
- 测试老 macOS 版本兼容
- 文档 / 示例

## 联系 & 讨论

- GitHub Issues：用于 Bug / 功能请求
- Discussions：想法交流、路径分享

**FitMac — Make Your Mac Fit Again!** 💪🧹

最后更新：2026 年