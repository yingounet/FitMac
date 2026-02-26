# FitMac - 功能开发 Checklist

项目目标：开源 Mac 清理工具（GUI + CLI），类似 CleanMyMac / OnyX / Pearcleaner，重点安全、透明、可审计。  
最低支持：macOS 13 Ventura（GUI），CLI 可降至 macOS 11 Big Sur 或 10.15 Catalina。  
许可证：MIT

使用说明：  
- [ ] 未开始 / [x] 进行中 / [x] 已完成  
- 优先完成 **MVP** 部分，快速发布 GitHub 可运行版本。

## 阶段 1：MVP（最小可用产品）

### 1.1 系统/应用缓存清理
- [ ] 定义安全缓存路径列表（至少 15–20 条常见路径）
  - [ ] ~/Library/Caches/*
  - [ ] ~/Library/Logs/*
  - [ ] /Library/Caches/*
  - [ ] ~/Library/Containers/*/Data/Library/Caches/*
  - [ ] Safari/WebKit 缓存
  - [ ] Chrome/Firefox/Edge 缓存路径
  - [ ] Xcode DerivedData (可选模块)
  - [ ] npm/yarn/pip 全局缓存
- [ ] 实现缓存扫描逻辑（FileManager 递归 + 文件大小统计）
- [ ] 支持分类显示（系统缓存 / 应用缓存 / 浏览器 / 开发工具）
- [ ] GUI：列表视图 + 勾选删除 + 预计释放空间显示
- [ ] CLI：`fitmac cache --scan`、`--clean`、`--dry-run`、`--category browser`
- [ ] 实现 Dry-run 模式（默认开启，收集文件列表但不删除）
- [ ] 二次确认对话框（GUI） / 提示（CLI）
- [ ] 清理后显示释放空间统计

**优先级**：高 | **权限**：Full Disk Access | **阶段**：MVP

### 1.2 应用残留 / 完整卸载
- [ ] 支持拖拽 .app 到 GUI 窗口
- [ ] 支持通过 bundle ID / 进程名 / 名称搜索已安装应用
- [ ] 定义常见残留路径模板（可配置）
  - [ ] ~/Library/Preferences/com.xxx.*
  - [ ] ~/Library/Application Support/xxx
  - [ ] ~/Library/Caches/xxx
  - [ ] ~/Library/Containers/xxx
  - [ ] ~/Library/Logs/xxx
  - [ ] ~/Library/Saved Application State/xxx
  - [ ] ~/Library/WebKit/xxx
  - [ ] LaunchAgents / LaunchDaemons 用户级
- [ ] 扫描并列出所有匹配文件/文件夹（带大小、路径）
- [ ] GUI：树状或分组列表 + 勾选 + 预览文件内容（文本/图片）
- [ ] CLI：`fitmac uninstall "App Name"`、`--list`、`--force`、`--dry-run`
- [ ] 删除前显示完整路径列表 + 总大小 + 二次确认
- [ ] 支持批量卸载（多选）

**优先级**：高 | **权限**：Full Disk Access | **阶段**：MVP

### 1.3 大文件 / 旧文件扫描
- [ ] 默认扫描目录：~/Downloads, ~/Documents, ~/Desktop, ~/Movies, ~/Pictures
- [ ] 支持自定义路径输入
- [ ] 支持最小文件大小过滤（默认 100MB，可调）
- [ ] 按大小/修改日期排序
- [ ] GUI：列表 + 柱状图/饼图（可选 Charts 库） + 右键预览/删除
- [ ] CLI：`fitmac large --path ~/ --min 500MB --sort size --delete`
- [ ] 支持移动到 Trash（而非直接 rm）
- [ ] 显示文件类型图标或预览（图片/视频/文档）

**优先级**：高 | **权限**：用户选择路径可不需 Full Disk | **阶段**：MVP

### 1.4 空间概览 & 状态
- [ ] 获取磁盘总容量、已用、可用（URL.volumeResourceValues）
- [ ] 显示清理前后对比（本次释放多少）
- [ ] GUI：首页卡片 / 仪表盘
- [ ] CLI：`fitmac status`（文字输出磁盘信息 + 上次清理记录）

**优先级**：中 | **阶段**：MVP

### 1.5 通用安全机制
- [ ] 全局 Dry-run 旗标（CLI） / 开关（GUI）
- [ ] 操作日志记录到 ~/Library/Logs/FitMac/
- [ ] 所有删除使用 FileManager.trashItem（移到废纸篓）
- [ ] 权限检查 & 引导用户开启 Full Disk Access

**优先级**：高 | **阶段**：MVP

## 阶段 2：1.0 核心版

### 2.1 系统内置应用安全移除
- [ ] 预定义可安全移除列表（GarageBand, iMovie, Pages, Numbers, Keynote, Chess 等）
- [ ] 检查是否安装在 /Applications 或 /System/Applications
- [ ] GUI：警告弹窗 + 列表 + 移除后提示 App Store 可重装
- [ ] CLI：`fitmac system list`、`fitmac system remove "GarageBand"`
- [ ] 使用 `pkgutil --forget`（如果适用）

**优先级**：高 | **阶段**：1.0

### 2.2 开发工具缓存清理
- [ ] Xcode：~/Library/Developer/Xcode/DerivedData, Archives, iOS DeviceSupport
- [ ] CocoaPods：~/.cocoapods
- [ ] Homebrew：`brew cleanup` 集成或手动路径
- [ ] npm/yarn/pip cache
- [ ] GUI：独立模块 Tab

**优先级**：中 | **阶段**：1.0

### 2.3 浏览器深度清理
- [ ] Safari：~/Library/Safari, ~/Library/Caches/com.apple.Safari
- [ ] Chrome：~/Library/Application Support/Google/Chrome/Default/Cache
- [ ] Firefox：~/Library/Caches/org.mozilla.firefox
- [ ] 避免删除书签、密码、扩展数据

**优先级**：中 | **阶段**：1.0

### 2.4 日志 & 历史查看
- [ ] 记录每次清理：时间、类型、删除文件列表、释放大小
- [ ] GUI：日志 Tab，可搜索/导出
- [ ] CLI：`fitmac log --list`、`--clear`

**优先级**：中 | **阶段**：1.0

## 阶段 3：未来扩展（可选 / 社区 PR）

- [ ] 菜单栏常驻小工具（磁盘使用 + 快速清理）
- [ ] 重复文件查找（图片 hash 比对）
- [ ] 启动项 / Login Items 管理
- [ ] iCloud 优化（旧设备备份清理）
- [ ] 自定义规则（用户添加路径/正则）
- [ ] 多语言支持（Strings Catalog）
- [ ] Sparkle 自动更新
- [ ] Homebrew cask 发布支持

## 其他通用 Checklist

- [x] 项目结构搭建（Core / App / CLI targets）
- [x] swift-argument-parser 集成 CLI
- [ ] 中英双语 Strings
- [ ] README.md + 截图 + 安装指南
- [ ] LICENSE (MIT)
- [ ] .gitignore 完善
- [ ] 测试：macOS 13 / 14 / 15（虚拟机或真机）

## SwiftUI GUI Checklist（新增）

- [x] FitMacApp 入口（App.swift）
- [x] ContentView 主界面框架（NavigationSplitView）
- [x] HomeView 磁盘概览（仪表盘 + 快捷操作）
- [x] CacheView 缓存清理（分类扫描 + 勾选删除）
- [x] LargeFilesView 大文件扫描（大小过滤 + 排序）
- [x] UninstallView 应用卸载（应用列表 + 残留扫描）
- [x] ViewModel 层（ObservableObject + @Published）
- [x] DiskGaugeView 组件（环形进度条）
- [ ] Assets.xcassets 资源文件
- [ ] App Icon
- [ ] Full Disk Access 权限引导界面

