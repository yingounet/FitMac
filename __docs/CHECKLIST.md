# FitMac - 功能开发 Checklist

**项目目标**: 开源 Mac 清理工具（GUI + CLI），类似 CleanMyMac / OnyX / Pearcleaner  
**重点**: 安全、透明、可审计  
**最低支持**: macOS 13 Ventura（GUI），CLI 可降至 macOS 11 Big Sur  
**许可证**: MIT

**使用说明**:
- `[ ]` 未开始 / `[~]` 进行中 / `[x]` 已完成
- 优先完成 **MVP** 部分

---

## 阶段 1：MVP（最小可用产品）✅ 已完成

### 1.1 系统/应用缓存清理 ✅

| 功能 | GUI | CLI | 状态 |
|------|-----|-----|------|
| 缓存路径定义 | - | - | [x] |
| 扫描逻辑 | [x] | [x] | [x] |
| 分类显示（系统/应用/浏览器/开发） | [x] | [x] | [x] |
| Dry-run 模式 | [x] | [x] | [x] |
| 二次确认 | [x] | [x] | [x] |
| 取消扫描 | [x] | - | [x] |
| 进度反馈 | [x] | - | [x] |

**已支持路径**:
- [x] `~/Library/Caches/*`
- [x] `~/Library/Logs/*`
- [x] `/Library/Caches/*`
- [x] Safari/Chrome/Firefox/Edge 缓存
- [x] Xcode DerivedData/Archives/DeviceSupport
- [x] npm/yarn/pip/Homebrew/CocoaPods 缓存

**CLI 命令**: `fitmac cache --scan --clean --dry-run --category <type>`

---

### 1.2 应用残留 / 完整卸载 ✅

| 功能 | GUI | CLI | 状态 |
|------|-----|-----|------|
| 搜索已安装应用 | [x] | - | [x] |
| 扫描残留文件 | [x] | [x] | [x] |
| 显示残留大小/路径 | [x] | [x] | [x] |
| 移到废纸篓 | [x] | [x] | [x] |
| 二次确认 | [x] | [x] | [x] |

**已支持残留路径**:
- [x] `~/Library/Preferences/*`
- [x] `~/Library/Application Support/*`
- [x] `~/Library/Caches/*`
- [x] `~/Library/Containers/*`
- [x] `~/Library/Logs/*`
- [x] `~/Library/Saved Application State/*`
- [x] `~/Library/WebKit/*`

**CLI 命令**: `fitmac uninstall "AppName" --clean --dry-run --force`

---

### 1.3 大文件 / 旧文件扫描 ✅

| 功能 | GUI | CLI | 状态 |
|------|-----|-----|------|
| 最小大小过滤 | [x] | [x] | [x] |
| 排序（大小/日期） | [x] | [x] | [x] |
| 结果数量限制 | [x] | [x] | [x] |
| 移到废纸篓 | [x] | [x] | [x] |
| 取消扫描 | [x] | - | [x] |
| 进度反馈 | [x] | - | [x] |

**CLI 命令**: `fitmac large --min 100MB --sort size --limit 50 --delete --force`

---

### 1.4 空间概览 & 状态 ✅

| 功能 | GUI | CLI | 状态 |
|------|-----|-----|------|
| 磁盘容量/使用率 | [x] | [x] | [x] |
| 环形进度条 | [x] | - | [x] |
| 快捷操作卡片 | [x] | - | [x] |
| 卡片导航跳转 | [x] | - | [x] |
| 返回时自动刷新 | [x] | - | [x] |

**CLI 命令**: `fitmac status`

---

### 1.5 清理历史 ✅

| 功能 | GUI | CLI | 状态 |
|------|-----|-----|------|
| 记录清理操作 | [x] | [x] | [x] |
| 查看历史列表 | [x] | [x] | [x] |
| 展开查看详情 | [x] | [x] | [x] |
| 清除历史 | [x] | [x] | [x] |

**CLI 命令**: `fitmac log --list --clear --last 10`

---

### 1.6 通用安全机制 ✅

| 功能 | 状态 |
|------|------|
| Dry-run 默认开启 | [x] |
| 所有删除移到废纸篓 | [x] |
| 操作日志记录 | [x] |
| Full Disk Access 检测 | [x] |
| 权限引导界面 | [x] |
| 统一错误处理 (FitMacError) | [x] |

---

### 1.7 基础设施 ✅

| 功能 | 状态 |
|------|------|
| 项目结构 (Core/App/CLI) | [x] |
| swift-argument-parser | [x] |
| PathUtils 公共工具 | [x] |
| CleanupLogger 独立模块 | [x] |
| 单元测试 (28 tests) | [x] |
| LICENSE (MIT) | [x] |
| .gitignore | [x] |

---

## 阶段 2：1.0 核心版（规划中）

### 2.1 Trash Bins（垃圾桶管理）✅ 已完成

- [x] 扫描用户垃圾桶大小
- [x] 扫描外部磁盘垃圾桶
- [x] 一键清空所有垃圾桶
- [x] 选择性清空特定磁盘
- [x] GUI: TrashView + TrashViewModel
- [x] CLI: `fitmac trash --list --empty`

**优先级**: 高 | **新建**: `TrashScanner.swift`

---

### 2.2 Language Files（语言文件清理）🆕

- [ ] 扫描非当前语言的 `.lproj` 目录
- [ ] 显示可释放空间
- [ ] 保留当前语言选项
- [ ] GUI: LanguageFilesView
- [ ] CLI: `fitmac language --scan --clean`

**路径**: `/Applications/*/Contents/Resources/*.lproj`

**优先级**: 中 | **新建**: `LanguageScanner.swift`

---

### 2.3 System Junk 扩展

#### 2.3.1 Temporary Files & Broken Downloads
- [ ] 扫描 `~/Library/Caches/com.apple.bird`
- [ ] 扫描 `/tmp` 目录
- [ ] 扫描损坏的下载文件 (`.crdownload`, `.tmp`, 损坏的 `.dmg`/`.pkg`)

#### 2.3.2 Document Versions & AutoSave
- [ ] 扫描 `~/Library/Autosave Information`
- [ ] 扫描 `~/Library/Application Support/com.apple.sharedfilelist`
- [ ] 保留最新版，删除旧版本

#### 2.3.3 System Leftovers
- [ ] 扫描 `.DS_Store` 文件
- [ ] 扫描孤立的 plist 文件
- [ ] 扫描 Spotlight 索引残留

**优先级**: 中

---

### 2.4 iTunes Junk（iOS 备份等）🆕

- [ ] 扫描 iOS 设备备份 (`~/Library/Application Support/MobileSync/Backup`)
- [ ] 扫描旧播客下载
- [ ] 显示备份大小和日期
- [ ] GUI: iTunesView + iTunesViewModel
- [ ] CLI: `fitmac itunes --list-backups --clean`

**优先级**: 中 | **新建**: `iTunesScanner.swift`

---

### 2.5 Mail Attachments（邮件附件）🆕

- [ ] 扫描 Mail.app 大附件
- [ ] 按大小/发件人分类
- [ ] 显示附件预览
- [ ] GUI: MailAttachmentsView
- [ ] CLI: `fitmac mail --list --clean`

**优先级**: 低 | **新建**: `MailScanner.swift`

---

### 2.6 系统内置应用安全移除

- [ ] 预定义可安全移除列表 (GarageBand, iMovie, Pages 等)
- [ ] 检查安装位置
- [ ] GUI: 警告弹窗 + 列表
- [ ] CLI: `fitmac system list`、`fitmac system remove "GarageBand"`
- [ ] 使用 `pkgutil --forget`

**优先级**: 中

---

### 2.7 Homebrew 集成

- [ ] 集成 `brew cleanup` 命令
- [ ] 或手动扫描 Homebrew 缓存路径
- [ ] 显示可清理的旧版本

**优先级**: 低

---

### 2.8 浏览器深度清理增强

- [ ] 避免删除书签数据
- [ ] 避免删除密码数据库
- [ ] 避免删除扩展数据
- [ ] 添加安全路径白名单

**优先级**: 中

---

## 阶段 3：未来扩展（社区驱动）

### 3.1 Duplicates（重复文件查找）🆕

- [ ] 基于 hash 检测完全重复文件
- [ ] 支持图片相似度检测
- [ ] 预览重复组
- [ ] 选择保留一份删除其余
- [ ] GUI: DuplicatesView
- [ ] CLI: `fitmac duplicates --scan`

**优先级**: 低 | **计算密集，需后台扫描**

---

### 3.2 菜单栏小组件

- [ ] 常驻菜单栏图标
- [ ] 显示磁盘使用率
- [ ] 快速清理按钮
- [ ] 清理完成通知

---

### 3.3 启动项管理

- [ ] 扫描 Login Items
- [ ] 扫描 LaunchAgents / LaunchDaemons
- [ ] 启用/禁用功能

---

### 3.4 iCloud 优化

- [ ] 扫描旧设备备份
- [ ] 扫描 iCloud Drive 缓存
- [ ] 优化建议

---

### 3.5 自定义清理规则

- [ ] 用户自定义路径
- [ ] 正则表达式匹配
- [ ] 导入/导出规则

---

### 3.6 多语言支持

- [ ] Strings Catalog
- [ ] 中文界面
- [ ] 英文界面

---

### 3.7 自动更新

- [ ] Sparkle 集成
- [ ] 检查更新
- [ ] 后台下载

---

### 3.8 发布渠道

- [ ] GitHub Releases
- [ ] Homebrew cask
- [ ] 公证 (Notarization)

---

## 代码质量 Checklist

### 已完成 ✅

- [x] P1: CacheCleaner 统一使用 moveToTrash
- [x] P2: CLI large --delete 功能实现
- [x] P3: QuickActionCard 导航交互
- [x] P4-P5: PathUtils 公共工具提取
- [x] P6: CleanupLogger 独立文件
- [x] P7: CLI log 命令
- [x] P8-P9: 扫描取消和进度反馈
- [x] P10: FitMacError 统一错误处理
- [x] P13: HomeView 磁盘状态自动刷新

### 待完成

- [ ] Swift 6 严格并发检查
- [ ] 更完善的单元测试覆盖
- [ ] 集成测试
- [ ] 性能测试（大目录扫描）
- [ ] macOS 13/14/15 兼容性测试

---

## 文件结构

```
Sources/
├── FitMacCore/                    # 核心库
│   ├── Cleaners/
│   │   ├── CacheScanner.swift     ✅
│   │   └── TrashScanner.swift     ✅ 新增
│   ├── Models/
│   │   └── CleanupItem.swift      ✅
│   └── Utils/
│       ├── CachePaths.swift       ✅
│       ├── FileUtils.swift        ✅
│       ├── PathUtils.swift        ✅
│       ├── PermissionUtils.swift  ✅
│       ├── FitMacError.swift      ✅
│       └── CleanupLogger.swift    ✅
├── FitMacApp/                     # GUI
│   ├── Views/
│   │   ├── HomeView.swift         ✅
│   │   ├── CacheView.swift        ✅
│   │   ├── TrashView.swift        ✅ 新增
│   │   ├── LargeFilesView.swift   ✅
│   │   ├── UninstallView.swift    ✅
│   │   ├── LogView.swift          ✅
│   │   └── FullDiskAccessView.swift ✅
│   └── ViewModels/
│       ├── DiskStatusViewModel.swift    ✅
│       ├── CacheViewModel.swift         ✅
│       ├── TrashViewModel.swift         ✅ 新增
│       ├── LargeFilesViewModel.swift    ✅
│       ├── UninstallViewModel.swift     ✅
│       └── LogViewModel.swift           ✅
└── FitMacCLI/                     # CLI
    ├── FitMacCLI.swift            ✅
    ├── StatusCommand.swift        ✅
    ├── CacheCommand.swift         ✅
    ├── TrashCommand.swift         ✅ 新增
    ├── LargeCommand.swift         ✅
    ├── UninstallCommand.swift     ✅
    └── LogCommand.swift           ✅
```

---

## 版本里程碑

| 版本 | 目标 | 状态 |
|------|------|------|
| **0.1.0** | MVP 功能完整 | ✅ 完成 |
| **0.2.0** | Trash Bins + Language Files | 🔄 进行中 (Trash Bins ✅) |
| **0.3.0** | iTunes Junk + Mail Attachments | 📋 规划中 |
| **1.0.0** | 核心功能完整 + 多语言 + 自动更新 | 📋 规划中 |

---

## 参考文档

- [PROJECT.md](PROJECT.md) - 项目总览
- [fitmacapp_plan.md](fitmacapp_plan.md) - 功能规划
- [mvp_review.md](mvp_review.md) - MVP 代码审查

---

**最后更新**: 2026-02-27
