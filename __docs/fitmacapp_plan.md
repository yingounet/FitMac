# FitMac App 功能规划

**文档版本**: 1.1  
**最后更新**: 2026-02-27  
**关联文档**: [PROJECT.md](PROJECT.md) | [CHECKLIST.md](CHECKLIST.md) | [mvp_review.md](mvp_review.md)

---

## 一、功能总览

### 1.1 核心模块

| 模块 | 描述 | 可清理内容 | 用户操作 |
|------|------|------------|----------|
| **System Junk** | 系统垃圾，通常占用最大空间 | 缓存、日志、语言文件、临时文件、文档版本、邮件附件缓存、开发工具垃圾、系统残留 | 分类勾选 → 扫描 → 预览 → 清理 |
| **Trash Bins** | 所有隐藏/已删项目 | 系统垃圾桶、外部磁盘垃圾桶、Photos 已删、Time Machine 快照中的已删文件 | 一键清空或按磁盘选择性清空 |
| **Large & Old Files** | 用户个人大文件 | 按大小/最后访问时间扫描的整个磁盘 | 浏览列表 → 手动选择删除 |
| **iTunes Junk** | iTunes / Apple Music / Podcasts 垃圾 | 旧播客下载、iOS 设备备份、损坏的媒体文件 | 删除旧备份、未使用的下载 |
| **Mail Attachments** | 邮件大附件 | Mail.app 下载但未删除的附件 | 按大小/发件人浏览 → 删除不需要的 |
| **Duplicates** | 重复文件 & 相似文件 | 文档、音乐、照片等重复项 | 预览重复组 → 选择保留一份、删除其余 |
| **Uninstall** | 应用完整卸载 | 应用残留（Preferences、Containers 等） | 拖入 .app 或搜索 → 扫描 → 删除残留 |
| **History** | 清理历史 | 每次清理记录 | 查看、搜索、导出 |

### 1.2 与现有代码的映射

| 新规划模块 | 现有实现 | 说明 |
|------------|----------|------|
| System Junk | `CacheView` + `CacheScanner` + `CachePaths` | 需扩展子分类与路径 |
| Trash Bins | 无 | 需新建 `TrashScanner`、`TrashView` |
| Large & Old Files | `LargeFilesView` + `LargeFilesViewModel` | 沿用，可增强排序/过滤 |
| iTunes Junk | 无 | 需新建 `iTunesScanner`、`iTunesView` |
| Mail Attachments | 无 | 需新建 `MailScanner`、`MailAttachmentsView` |
| Duplicates | 无 | 需新建 `DuplicateScanner`、`DuplicatesView` |
| Uninstall | `UninstallView` + `UninstallViewModel` | 沿用 |
| History | `LogView` + `LogViewModel` | 沿用 |

---

## 二、System Junk 子模块详解

### 2.1 Caches（缓存文件）

- **路径来源**: `CachePaths.systemCachePaths`、`appCachePaths`、`browserCachePaths`
- **新增路径**:
  - 字体缓存: `~/Library/Caches/com.apple.ats`、`/Library/Caches/com.apple.ats`
  - 内核扩展缓存: `/System/Library/Caches/com.apple.kernelcaches`
- **Dry-run**: 默认开启
- **二次确认**: 显示将删除的路径列表与预计释放空间
- **安全说明**: 应用下次使用会自动重建，不会丢失数据

### 2.2 Logs（日志文件）

- **路径来源**: `~/Library/Logs`、`/Library/Logs`
- **细分**: 系统日志、应用崩溃日志、诊断报告（`.crash`、`.ips`、`DiagnosticReports`）
- **Dry-run**: 默认开启
- **安全说明**: 旧日志可安全删除，不影响应用运行

### 2.3 Language Files（多余语言文件）

- **路径**: `/Applications/*/Contents/Resources/*.lproj`（非当前系统语言）、`/System/Applications/*/Contents/Resources/*.lproj`
- **逻辑**: 保留当前语言（如 zh-Hans、en），删除其余 `*.lproj`
- **Dry-run**: 默认开启
- **安全说明**: 最安全，可节省几百 MB 到数 GB

### 2.4 Temporary Files & Broken Downloads

- **路径**: `~/Library/Caches/com.apple.bird`、`/tmp`、`~/Downloads/*.crdownload`、`~/Downloads/*.tmp`、损坏的 `.pkg`、`.dmg`
- **Dry-run**: 默认开启
- **安全说明**: 全部安全

### 2.5 Document Versions & AutoSave

- **路径**: `~/Library/Autosave Information`、`~/Library/Application Support/com.apple.sharedfilelist`、iCloud 文档版本历史
- **逻辑**: 保留最新版，删除旧版本
- **Dry-run**: 默认开启
- **安全说明**: 保留最新版，删除旧版安全

### 2.6 Mail Attachments & Photo Junk（系统级）

- **路径**: `~/Library/Mail/V*/MailData/Envelope Index` 相关附件缓存、`~/Library/Caches/com.apple.photoanalysis`、`~/Library/Caches/com.apple.iPhoto`、iTunes 缩略图缓存
- **说明**: 与独立「Mail Attachments」模块区分——此为系统级缓存，Mail Attachments 为用户级大附件列表
- **Dry-run**: 默认开启
- **安全说明**: 需单独确认，避免误删用户需要的附件

### 2.7 Development & Xcode Junk

- **路径**: `CachePaths.devCachePaths` 已覆盖
  - `~/Library/Developer/Xcode/DerivedData`
  - `~/Library/Developer/Xcode/Archives`
  - `~/Library/Developer/Xcode/iOS DeviceSupport`
  - `~/.cocoapods`、`~/.npm`、`~/.yarn/cache`、`~/.cache/pip`、`~/.gradle/caches`、`~/.m2/repository`、`~/Library/Caches/Homebrew`
- **Dry-run**: 默认开启
- **安全说明**: 可选/选择性，不影响当前项目

### 2.8 System Leftovers（系统残留）

- **路径**: `**/.DS_Store`、Spotlight 索引残留、`~/Library/Preferences` 中的孤立 plist
- **Dry-run**: 默认开启
- **安全说明**: 全部安全

---

## 三、Trash Bins 详解

- **扫描目标**: 用户主垃圾桶、外部磁盘垃圾桶、`~/.Trash`、Photos 已删项目、Time Machine 快照中的已删文件
- **用户操作**: 一键清空所有垃圾桶，或选择性清空特定磁盘
- **Dry-run**: 可选，清空前显示各垃圾桶大小
- **二次确认**: 必须，清空垃圾桶不可恢复（除非从 Time Machine 恢复）

---

## 四、Large & Old Files 详解

- **扫描范围**: 用户选择的目录（默认 `~/Downloads`、`~/Documents`、`~/Desktop`、`~/Movies`、`~/Pictures`）
- **过滤**: 最小文件大小（默认 100MB）、最后访问时间
- **排序**: 按大小、按修改日期
- **用户操作**: 浏览列表 → 手动选择 → 移至废纸篓
- **安全说明**: 完全是用户文件，用户需自己判断，工具不自动选中

---

## 五、iTunes Junk 详解

- **可清理**:
  - 旧播客下载
  - iOS 设备备份（`~/Library/Application Support/MobileSync/Backup`）
  - 损坏的媒体文件
- **用户操作**: 删除旧备份、未使用的下载
- **Dry-run**: 默认开启
- **与 System Junk 区分**: iTunes 通用缓存归 System Junk；旧备份、播客下载归本模块

---

## 六、Mail Attachments 详解

- **可清理**: Mail.app 下载但未从邮件中删除的附件（大文件）
- **用户操作**: 按大小/发件人浏览 → 删除不需要的
- **Dry-run**: 默认开启
- **与 System Junk 区分**: 本模块展示用户级大附件列表，System Junk 仅清理系统级附件缓存

---

## 七、Duplicates & Similar Files 详解

- **检测方式**: 基于 hash（完全重复）或相似度（图片）
- **范围**: 文档、音乐、照片等
- **用户操作**: 预览重复组 → 选择保留一份、删除其余
- **实现注意**: 计算密集，需后台扫描、进度条、可取消
- **Dry-run**: 默认开启

---

## 八、优先级与阶段

### MVP ✅ 已完成

| 模块 | 子项 | 状态 |
|------|------|------|
| System Junk | Caches、Logs、Temporary | ✅ 已完成 |
| Trash Bins | 全部 | 📋 待开发 |
| Large & Old Files | 全部 | ✅ 已完成 |
| Uninstall | 全部 | ✅ 已完成 |
| History | 全部 | ✅ 已完成 |

**新增功能**（2026-02-27）:
- ✅ CLI `fitmac log --list/--clear` 命令
- ✅ 扫描取消功能
- ✅ 扫描进度反馈
- ✅ QuickActionCard 导航
- ✅ PathUtils 公共工具
- ✅ FitMacError 统一错误处理
- ✅ HomeView 自动刷新

### 1.0 核心版

| 模块 | 子项 | 说明 |
|------|------|------|
| System Junk | Language Files、Document Versions、Development | 扩展路径与分类 |
| iTunes Junk | 全部 | 新建 |
| Mail Attachments | 全部 | 新建 |
| Duplicates | 全部 | 新建 |

### 未来扩展

| 模块 | 说明 |
|------|------|
| System Junk | System Leftovers、Mail Attachments & Photo Junk（系统级） |
| 其他 | 重复文件相似度检测、自定义清理规则 |

---

## 九、与 Core / CLI 的对应

### 9.1 现有扩展点

- **CacheScanner** (`Sources/FitMacCore/Cleaners/CacheScanner.swift`): 支持按 `CacheCategory` 扫描，可扩展 `CacheCategory` 枚举与 `CachePaths`
- **CachePaths** (`Sources/FitMacCore/Utils/CachePaths.swift`): 新增路径数组即可

### 9.2 需新增 Scanner（FitMacCore）

| Scanner | 职责 | 输出模型 |
|---------|------|----------|
| `TrashScanner` | 扫描各垃圾桶大小与路径 | `TrashScanResult` |
| `LanguageScanner` | 扫描非当前语言的 `.lproj` | `ScanResult`（复用或新建） |
| `iTunesScanner` | 扫描 iTunes 备份、播客下载 | `iTunesScanResult` |
| `MailScanner` | 扫描 Mail 大附件 | `MailScanResult` |
| `DuplicateScanner` | 基于 hash 查找重复文件 | `DuplicateScanResult` |

### 9.3 CLI 命令对应

| 功能 | 现有 | 状态 |
|------|------|------|
| 缓存 | `fitmac cache --scan` / `--clean` | ✅ 完成 |
| 日志 | `fitmac log --list` / `--clear` / `--last` | ✅ 完成 |
| 大文件 | `fitmac large --delete` | ✅ 完成 |
| 卸载 | `fitmac uninstall` | ✅ 完成 |
| 垃圾桶 | `fitmac trash --list` / `--empty` | 📋 待开发 |
| iTunes | `fitmac itunes --list-backups` / `--clean` | 📋 待开发 |
| Mail | `fitmac mail --list-attachments` / `--clean` | 📋 待开发 |
| 重复文件 | `fitmac duplicates` | 📋 未来 |

---

## 十、安全机制（与 mvp_review 衔接）✅ 已完成

以下问题已全部修复：

| 优先级 | 问题 | 状态 |
|--------|------|------|
| P1 | CacheCleaner 目录删除不一致 | ✅ 已修复 - 统一使用 `moveToTrash` |
| P2 | CLI LargeCommand `--delete` 未实现 | ✅ 已实现 |
| P3 | QuickActionCard 无导航交互 | ✅ 已实现 |
| P4-P5 | `shortenPath`、`parseSize` 重复 | ✅ 已提取到 `PathUtils` |
| P6 | CleanupLogger 职责混乱 | ✅ 已独立为单独文件 |
| P7 | CLI log 命令缺失 | ✅ 已实现 `fitmac log --list/--clear` |
| P8-P9 | 扫描无法取消/无进度 | ✅ 已添加取消按钮和进度反馈 |
| P10 | 错误处理不统一 | ✅ 已创建 `FitMacError` |
| P13 | HomeView 磁盘状态不刷新 | ✅ 已添加 onChange 刷新 |

所有清理操作遵循：
- ✅ Dry-run 默认开启
- ✅ 二次确认 + 文件列表预览
- ✅ 统一使用 `FileUtils.moveToTrash`，不直接删除

---

## 十一、参考

- [PROJECT.md](PROJECT.md) - 项目总览
- [CHECKLIST.md](CHECKLIST.md) - 功能开发清单（已更新）
- [mvp_review.md](mvp_review.md) - MVP 代码审查（问题已修复）
