# kityminder 插件化封装 · 方案定稿 v1

> 状态：**方案待审**（批准后可编码）。
> 目标：把百度 fex-team 的开源思维导图编辑器 **kityminder** 封装成本工具的一个
> **可随时安装 / 卸载**的插件，安装后在界面出现「思维导图」入口，卸载后消失。
> 前置调研已确认（详见文末「关键前提」）：kityminder 是 Web 编辑器，只能靠
> WebView2 承载；且不能只拷 `dist` 离线运行，需整套 `dist + bower_components + node_modules`。
> 关联规范：`.opencode/rules/rules.md`、`AI_ERRATA.md`（E003 增量编译、E002 编码必读）。

---

## 一、需求定义

1. **承载方式**：WebView2（Chromium 内核）加载 kityminder 本地 HTML 页面。
2. **界面形态**：侧边栏新增一个「思维导图」按钮，安装后出现、卸载后移除；
   点击呼出一个独立面板层承载 WebView2。
3. **装卸语义（双轨）**：
   - **内置离线条带**：kityminder 构建产物打包成一个插件 zip，随工具放在数据分区
     （不进 exe 内），**首次安装**时解压到插件目录。离线可用。
   - **联网下载缓存**：选配。为将来从远程同步/更新插件包留接口；
     因上游无现成一体分发包，本版以"本地离线包"为主，"联网下载"为辅。
   - **卸载**：移除插件目录 + 界面入口 + config 注册；**离线包 zip 保留在回收**，
     可随时一键重装。

---

## 二、关键前提（调研实证）

- kityminder 由 `kityminder-core`（可视化/编辑核心，依赖 kity 矢量库）与
  `kityminder-editor`（UI，依赖 AngularJS 1.x）组成。
- **`dist/index.html` 用相对路径引用 `../bower_components/*` 和 `../node_modules/*`**——
  因此可运行目录 = `dist + bower_components + node_modules` 三者一体的整包，
  单拷 `dist` 必失败。
- 一次构建：`npm run init`（装 less/bower/依赖）→ `grunt build`，产物落 `dist`。
- 图片上传指向 `../server/imageUpload.php`——**WPF 无 PHP 后端**，需禁用或移除该配置。
- 宿主 ↔ 编辑器数据通信有现成公开 API：`editor.minder.exportJson() / importJson()`，
  以及 `exportData(protocol, data)`（支持 json/text/markdown/svg/png）。

---

## 三、架构与目录

### 1. 插件包与运行期目录

```
项目根/
├── 资源/                     ← 新增：内置离线插件包（随工具分发，不进 exe）
│   └── kityminder.ui.zip     ← 构建产物整包（见第六节）
└── 数据/
    ├── 分配项目组-config.json ← plugins 注册段（见第四节）
    └── plugins/              ← 运行期插件目录
        ├── _offline/         ← 卸载后回收的离线包（可随时重装）
        └── kityminder/       ← 已安装插件：index.html + dist + bower_components + node_modules
```

- 运行期目录按 `App.ResolveDataPaths()` 的现有探测逻辑定位（dataDir 已有来源）。

### 2. 代码结构（src/ 下）

```
src/
├── Services/
│   └── PluginService.cs        ← 装卸/回收/查询插件（zip→解压→注册→删除→回收）
├── Plugins/
│   ├── PluginHost.cs           ← WebView2 通用承载 + 与页面桥接的封装
│   └── KityMinderPlugin.cs     ← kityminder 专属：入口定位 + exportJson/importJson 桥接
└── Views/
    └── MindMapPanel.xaml(.cs)  ← 侧边栏呼出的思维导图面板（WebView2 + 工具栏）
```

### 3. WebView2 依赖

- csproj 新增 `Microsoft.Web.WebView2` NuGet 包。
- 运行时依赖系统 **WebView2 Runtime**（Win11 自带；Win10 大概率有）。
  `PluginService` 启动探测，缺失时向日志区提示"检测到插件依赖缺失"，不崩溃。

---

## 四、插件注册模型（config 新增，旧格式完全兼容）

```json
"plugins": {
  "kityminder": {
    "id": "kityminder",
    "name": "思维导图",
    "version": "1.0.67",
    "entryRelative": "index.html",
    "installed": true,
    "offlineZip": "资源/kityminder.ui.zip"
  }
}
```

- 单一插件本期 `installed=true/false` 即可；结构上预留 `id` 键便于将来扩展第二个插件。
- 卸载 = `installed=false` + 删除运行期目录 + 目录移回 `_offline/`；
  重装 = 从 `_offline/` 或离线包 zip 还原 + `installed=true`。

---

## 五、界面集成

### 主窗口侧栏

- 在侧边栏（`MainWindow.xaml` 侧栏区，参考现有 `ACL 锁定` 按钮模式）新增
  「思维导图」按钮，`Visibility` 绑定 `MainViewModel.IsMindMapInstalled`。
  - 已安装 → 显示，Click 打开面板；
  - 未安装 → 隐藏。
- 快捷键：可加 Ctrl+M 或留给用户设置，暂不占默认快捷键。

### MindMapPanel（独立面板，仿 TIPS/MCP 浮层的承载方式）

- 顶部薄工具条：安装/卸载按钮、导入/导出、刷新。
- 主体为 WebView2 控件，`Source` 指向插件目录 `index.html`。
- WebView2 属原生 UI 之外的 HWND 宿主，本工具已有 WindowsForms 引用，
  `WebView2` 控件可用，注意其与现有网格分层共存时置顶一次（用
  `ZIndex` / 独立面板层承载）。

### 桥接（导出/导入）

- 面板「导出」按钮 → `ExecuteScriptAsync` 调 `editor.minder.exportJson()` →
  结果经 `PostWebMessageAsString` / 回调取回 C#，写文件。
- 面板「导入」按钮 → 读 .json → `ExecuteScriptAsync("...importJson(...)")`。
- 图片上传功能：在注入脚本中清除 `imageUpload` 配置或置无效，绕开 PHP 后端。

---

## 六、插件包的构建与准备（一次性，构建入工具）

开发期用 WebView2/web 一次性构建 kityminder 并打成 zip，作为内置离线包随工具分发。

1. `git clone https://github.com/fex-team/kityminder-editor.git`
2. `npm run init`（需 Node + npm）
3. `grunt build` → 得到 `dist`
4. 把 `dist + bower_components + node_modules` 打包为 `kityminder.ui.zip`
   （目录保持与 `index.html` 相对路径一致）
5. 将 zip 放入项目 `资源/kityminder.ui.zip`

> 若本机构建受制于老依赖（bower 停维护），回退方案另述（见第七节风险）。

---

## 七、风险与边界

| 风险 | 应对 |
|---|---|
| kityminder 依赖 AngularJS 1.x / bower，构建可能踩老依赖坑 | 构建一次固化产物，成功后不重复构建；重装不重建仅解压 |
| 离线条带不进 exe，搬家时需连同 `资源/` 一起搬 | README 明确「插件包随目录整体移动」，PluginService 按相对路径定位 |
| WebView2 Runtime 缺失 | 启动探测 + 日志提示，不崩溃；文档化安装指引 |
| 图片上传无后端 | 注入脚本禁用 imageUpload |
| 插件目录体积较大（约 5–20MB） | 仅首次安装解压，卸载回收；展示在日志区 |
| 旧数据兼容 | config 新增 `plugins` 段，仅追加不改既有字段 |

---

## 八、实施顺序（开发阶段执行，每步编译一次 ← E003）

1. csproj 加 `Microsoft.Web.WebView2` 包 → `dotnet build` 通过。
2. 构建 kityminder 整包 → 产出 `资源/kityminder.ui.zip`。 ← **前置依赖，先做此步**
3. `Services/PluginService.cs`：探测/解压/注册/卸载/回收 + 自测。
4. `Plugins/KityMinderPlugin.cs` + `Plugins/PluginHost.cs`：WebView2 承载 + 桥接。
5. `Views/MindMapPanel.xaml(.cs)`：面板 + 工具栏。
6. 主窗侧栏按钮 + `MainViewModel.IsMindMapInstalled` 接线。
7. `build.ps1` 编译 + `--roundtrip` 回归 + 运行 5 秒不崩 + 手动装卸各一次验证。
8. README「已实现功能清单」与 TIPS 使用手册同步更新。

---

## 九、验收标准

- 安装插件前：侧栏无「思维导图」入口。
- 点击安装：入口出现 → 面板打开 → kityminder 正常加载、可新建节点编辑。
- 导出/导入 JSON 往返一致。
- 卸载：入口消失、插件目录移除、离线包回收；再次安装可无损还原。