# FitMac App 页面设计

**文档版本**: 1.0  
**最后更新**: 2026-02  
**关联文档**: [PROJECT.md](PROJECT.md) | [fitmacapp_plan.md](fitmacapp_plan.md)

---

## 一、整体布局

### 1.1 主框架

采用 `NavigationSplitView` 实现主从布局：

```
┌─────────────────────────────────────────────────────────────────┐
│  FitMac                                                         │
├──────────────┬──────────────────────────────────────────────────┤
│  侧边栏       │  主内容区                                         │
│  (min 180px, │                                                  │
│   ideal 200) │  根据选中的侧边栏项显示对应视图                         │
│              │                                                  │
│  - Home      │                                                  │
│  - System... │                                                  │
│  - Trash     │                                                  │
│  - ...       │                                                  │
└──────────────┴──────────────────────────────────────────────────┘
```

### 1.2 侧边栏规范

- **宽度**: `min: 180`, `ideal: 200`
- **导航标题**: "FitMac"
- **分组**: 可选分组（清理 / 文件管理）或扁平列表

### 1.3 推荐导航结构

```
FitMac
├── Home（首页）
├── 清理
│   ├── System Junk（系统垃圾）
│   ├── Trash Bins（垃圾桶）
│   ├── iTunes Junk
│   └── Mail Attachments
├── 文件管理
│   ├── Large & Old Files（大文件 & 旧文件）
│   └── Duplicates（重复文件）
├── Uninstall（应用卸载）
├── History（清理历史）
└── Permissions（权限）
```

### 1.4 备选：扁平化侧边栏

若不使用分组，则保持单一 `List`，所有入口平铺。

---

## 二、各页面设计

### 2.1 Home（首页）

**现有实现**: [HomeView](Sources/FitMacApp/Views/HomeView.swift)

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  [权限警告 Banner]（未开启 Full Disk Access 时显示）          │
├─────────────────────────────────────────────────────────┤
│  headerSection                                           │
│  - 图标 + FitMac 标题 + 副标题                             │
├─────────────────────────────────────────────────────────┤
│  diskStatusSection（GroupBox "Disk Status"）              │
│  - DiskGaugeView 环形进度条                                │
│  - StatusItem: Total / Used / Available                  │
├─────────────────────────────────────────────────────────┤
│  quickActionsSection（GroupBox "Quick Actions"）          │
│  - LazyVGrid 2 列                                        │
│  - QuickActionCard 快捷入口                               │
└─────────────────────────────────────────────────────────┘
```

**快捷操作卡片规划**（需扩展）:

| 卡片 | 图标 | 标题 | 跳转目标 |
|------|------|------|----------|
| Clean Cache | trash.circle.fill | 系统垃圾 | System Junk |
| Find Large Files | doc.fill | 大文件 | Large & Old Files |
| Uninstall Apps | xmark.bin.fill | 应用卸载 | Uninstall |
| View History | clock.arrow.circlepath | 清理历史 | History |
| Empty Trash | trash | 清空垃圾桶 | Trash Bins |
| Find Duplicates | doc.on.doc | 重复文件 | Duplicates |

**交互**:
- 点击卡片 → 切换 `selectedSidebarItem` 到对应页面
- 返回首页时刷新磁盘状态（`onChange(of: selectedSidebarItem)`）

---

### 2.2 System Junk（系统垃圾）

**现有实现**: [CacheView](Sources/FitMacApp/Views/CacheView.swift)（可重命名/扩展）

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  toolbarSection                                          │
│  - Categories Menu（子分类多选）                           │
│  - Select All / Deselect All                             │
│  - Scan 按钮（扫描中显示 Cancel）                           │
│  - Clean 按钮（有选中项时显示）                             │
├─────────────────────────────────────────────────────────┤
│  content                                                 │
│  - 扫描中: ProgressView + 文案 + scannedCount              │
│  - 有结果: List（按子分类 Section 或 DisclosureGroup）      │
│  - 空: emptyStateView                                    │
├─────────────────────────────────────────────────────────┤
│  bottomBar（有选中项时）                                   │
│  - N items selected | Total: XXX                         │
└─────────────────────────────────────────────────────────┘
```

**子分类呈现方式**（方案 A，推荐）:
- 使用 `Section` 或 `DisclosureGroup` 区分子模块
- 子模块: Caches / Logs / Language Files / Temp / Document Versions / Dev / Leftovers / Mail & Photo（系统级）

**列表行**:
- 勾选框 + 图标（文件夹/文件）+ 名称 +  shortenPath + 大小
- 点击整行可勾选/取消勾选

**交互流程**:
1. 选择 Categories → 点击 Scan → 显示扫描进度
2. 扫描完成 → 展示按分类分组的结果列表
3. 勾选要清理的项 → 点击 Clean → 二次确认弹窗 → 执行清理

---

### 2.3 Trash Bins（垃圾桶）

**新建**: `TrashView` + `TrashViewModel`

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  toolbarSection                                          │
│  - Scan 按钮（扫描各垃圾桶大小）                            │
│  - Empty All 按钮（一键清空）                              │
├─────────────────────────────────────────────────────────┤
│  content                                                 │
│  - 按磁盘/来源分组的垃圾桶列表                              │
│  - 每项: 磁盘名/来源 + 大小 + Empty 按钮                    │
│  - 支持选择性清空单个垃圾桶                                 │
└─────────────────────────────────────────────────────────┘
```

**交互**:
- 扫描 → 展示各垃圾桶大小
- 可一键清空全部，或按项单独清空
- 清空前必须二次确认

---

### 2.4 Large & Old Files（大文件 & 旧文件）

**现有实现**: [LargeFilesView](Sources/FitMacApp/Views/LargeFilesView.swift)

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  toolbarSection                                          │
│  - Min Size 输入框                                        │
│  - Sort Picker (Size / Date)                             │
│  - Limit Picker (20/50/100/200)                          │
│  - Scan 按钮                                              │
│  - Move to Trash 按钮（有选中项时）                         │
├─────────────────────────────────────────────────────────┤
│  content                                                 │
│  - List: LargeFileRow（勾选 + 图标 + 名称 + 路径 + 日期 + 大小）│
├─────────────────────────────────────────────────────────┤
│  bottomBar（有选中项时）                                   │
└─────────────────────────────────────────────────────────┘
```

**增强点**:
- 可增加「最后访问时间」过滤
- 可增加路径选择（默认用户目录）
- 支持右键预览（Quick Look）

---

### 2.5 iTunes Junk

**新建**: `iTunesView` + `iTunesViewModel`

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  toolbarSection                                          │
│  - Scan 按钮                                              │
│  - Clean 按钮（有选中项时）                                 │
├─────────────────────────────────────────────────────────┤
│  content                                                 │
│  - Section: iOS 设备备份（列表 + 设备名 + 日期 + 大小）       │
│  - Section: 旧播客下载                                     │
│  - Section: 损坏的媒体文件                                 │
│  - 勾选后 Clean                                           │
└─────────────────────────────────────────────────────────┘
```

---

### 2.6 Mail Attachments

**新建**: `MailAttachmentsView` + `MailAttachmentsViewModel`

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  toolbarSection                                          │
│  - Scan 按钮                                              │
│  - 按大小/发件人排序的 Picker                              │
│  - Clean 按钮（有选中项时）                                 │
├─────────────────────────────────────────────────────────┤
│  content                                                 │
│  - 大附件列表：名称 + 大小 + 发件人 + 日期                   │
│  - 勾选删除                                               │
└─────────────────────────────────────────────────────────┘
```

---

### 2.7 Duplicates（重复文件）

**新建**: `DuplicatesView` + `DuplicatesViewModel`

**布局结构**:

```
┌─────────────────────────────────────────────────────────┐
│  toolbarSection                                          │
│  - Scan 按钮（支持取消）                                   │
│  - 进度条（计算密集，需明显反馈）                            │
├─────────────────────────────────────────────────────────┤
│  content                                                 │
│  - 重复组列表（每组可展开）                                 │
│  - 每组内: 文件列表 + 预览对比 + 选择保留哪一份              │
│  - 其余项可批量删除                                        │
└─────────────────────────────────────────────────────────┘
```

**交互**:
- 扫描可取消
- 每组默认选第一个为保留，用户可切换
- 预览支持图片/文档

---

### 2.8 Uninstall（应用卸载）

**现有实现**: [UninstallView](Sources/FitMacApp/Views/UninstallView.swift)

**布局结构**:
- 左侧: App 列表（支持搜索）
- 右侧: 选中 App 的残留详情 + 扫描/删除
- 支持拖拽 .app 到窗口

---

### 2.9 History（清理历史）

**现有实现**: [LogView](Sources/FitMacApp/Views/LogView.swift)

**布局结构**:
- 工具栏: 条目数、Clear History、Refresh
- 列表: 每次清理记录（时间、类型、释放空间、详情）

---

### 2.10 Permissions（权限）

**现有实现**: [FullDiskAccessView](Sources/FitMacApp/Views/FullDiskAccessView.swift)

**布局**: 权限说明 + 跳转系统设置的链接

---

## 三、通用交互

### 3.1 清理流程

```
扫描 → 结果列表 → 勾选 → 二次确认弹窗 → 执行（moveToTrash）
```

### 3.2 Dry-run

- 设置中可配置「默认 Dry-run」
- 清理弹窗中可切换「模拟/实际执行」

### 3.3 进度与取消

- 扫描时显示 `ProgressView` + 文案
- 长时间扫描（大文件、重复文件）需支持取消按钮

### 3.4 错误处理

- 扫描/清理失败时显示 `errorMessage`
- 使用 `alert` 或内联提示

---

## 四、组件规范

### 4.1 QuickActionCard

```swift
// 参数: icon, title, description, color, action
// 样式: HStack(图标 + 文字 + Spacer + chevron)，背景 gray.opacity(0.1)，圆角 8
```

### 4.2 DiskGaugeView

```swift
// 环形进度条，根据 usedPercentage 着色（绿/橙/红）
```

### 4.3 列表行通用模式

- 勾选框 + 图标 + 主标题 + 副标题（路径）+ 右侧元数据（大小/日期）
- `contentShape(Rectangle())` + `onTapGesture` 支持整行点击勾选

### 4.4 bottomBar

- 固定在底部，`safeAreaInset(edge: .bottom)`
- 背景 `.regularMaterial`
- 内容: 左侧「N items selected」，右侧「Total: XXX」

### 4.5 确认弹窗

- 标题: 操作名称（如 "Clean Cache"）
- 内容: 将操作的数量和总大小
- 按钮: Cancel + 执行（如 "Clean" / "Move to Trash"）
- 执行按钮可用 `role: .destructive`（删除类操作）

### 4.6 路径显示

- 使用 `PathUtils.shorten()` 将 `~/...` 形式缩短显示

---

## 五、图标与 SF Symbols

| 模块 | 图标 |
|------|------|
| Home | externaldrive.fill |
| System Junk | trash.circle.fill |
| Trash Bins | trash |
| Large Files | doc.fill |
| iTunes Junk | music.note |
| Mail Attachments | envelope.fill |
| Duplicates | doc.on.doc |
| Uninstall | xmark.bin.fill |
| History | clock.arrow.circlepath |
| Permissions | lock.shield.fill |

---

## 六、参考

- [fitmacapp_plan.md](fitmacapp_plan.md) - 功能规划
- [Sources/FitMacApp/Views/](Sources/FitMacApp/Views/) - 现有视图实现
