# kityminder 接入完整编辑器（修「文字无法编辑」）· 实施计划

> 状态：**A/B 已完成，C 浏览器实证通过，待桌面 GUI 目验**（2026-08-31）。
> 实施结果：完整编辑器整包已打包 `资源/kityminder.ui.zip` 并解压到 `数据/plugins/kityminder/`；
> `KityMinderHost` 新增 `SourcePath` 从插件数据目录加载；`dist/index.html` 注入
> `window.__minder`/`__km` 桥接门面（text/Theme/Layout/import/export/contentchange）；
> 就绪探针改为非致命等待 `__km`。浏览器实证：双击进入文字编辑（receiver 定位+键入+回车提交）、
> 主题/布局/导入/导出往返全部通过；Debug/Release 编译与 dist 发布成功。待用户在 GUI 目验。
> 现象：脑图文字无法编辑，点按钮/双击均无效。
> 根因：当前封装仅用 kityminder **核心库**（`kityminder.core.min.js`），
> 「双击节点进入文字编辑」的能力在编辑器 UI 模块（`kityminder-editor`，
> 依赖 AngularJS 1.x）中，核心库不含；`KityMinderHost` 的「编辑文字」按钮
> 调 `window.__minder.editSelected()`，而当前自写 index.html 未定义该方法 → 空操作。
> 关联规范：`.opencode/rules/rules.md`、`AI_ERRATA.md`（E003 增量编译、E002 编码必读）。

---

## 一、方案选型（用户已确认）

- **方向**：接入完整 kityminder 编辑器（自带双击文字编辑、右键热框、顶栏菜单）。
- **UI 归属**：保留 `MindMapPanel` 顶部「安装/导入/导出/刷新/调试」文件工具栏；
  其余编辑交互（双击编辑、右键热框、自绘编辑操作条去留）交给编辑器自带。
- 把自写 `index.html` 的 `window.__minder` 桥接层适配到完整编辑器的
  `window.editor / window.minder`。

## 二、关键前提（调研实证 2026-08-31）

- kityminder-editor `dist/index.html` 运行期引用：
  - `../bower_components/`（bootstrap、jquery、angular、angular-bootstrap、
    codemirror、angular-ui-codemirror、marked、kity、hotbox、color-picker、
    json-diff）；
  - `../node_modules/kityminder-core/dist/kityminder.core.min.js` + `.css`
    （**仅此一个包引用 node_modules，且只需其 dist 产物**）。
- 因此**无需 bower / grunt / 老 Node 构建**：可手工离线拼包。
  `node_modules/kityminder-core/dist/` 的产物直接复用现有核心 min 文件。
- 完整编辑器内置文本编辑：`src/runtime/input.js`（`this.editText`）+ 双击进入编辑。
- 入口暴露：`dist/index.html` 的 `on-init` 回调把 `editor`、`minder` 挂到全局
  `window.editor = editor; window.minder = minder;`。
- 图片上传默认指向 `../server/imageUpload.php`（WPF 无 PHP 后端）→ 改为本地 base64 处理。
- 上游 `bower.json` 依赖：bootstrap ~3.3.4、angular ~1.3（resolutions ~1.3.8）、
  angular-bootstrap ~0.12.1、angular-ui-codemirror ~0.2.3、codemirror ~4.8.0、
  marked、hotbox ~1.0.2、color-picker ~1.0.2、kity ^2.0.5、json-diff。

## 三、实施步骤

### A. 打底离线编辑器整包（一次性）
1. 获取 `fex-team/kityminder-editor` 的 `dist/`（`kityminder.editor.min.js` / `.css` /
   `favicon.ico` / `index.html`）。
2. 补 `bower_components/`（11 库，按 bower.json 版本从 jsDelivr / npm / gh 精确拉取）
   与 `node_modules/kityminder-core/dist/`（复用现有 core min+css）。
3. 改 `index.html`：`imageUpload` → 本地 base64 handler；去顶栏 `h1` 标题。
4. 打包为离线可运行整包（放 `资源/kityminder.full.zip` 或 `数据/plugins/kityminder/`）。

### B. 接入运行（代码改动）
- `KityMinderHost` 改为从插件数据目录加载完整编辑器 `index.html`（而非 dll 内嵌自写 HTML）。
- 桥接层 `window.__minder.*` 门面适配 `window.editor/window.minder`
  （文本编辑、execCommand、exportJson/importJson、setTheme/setLayout、contentchange 脏标记）。
- 就绪探针/状态适配 `window.editor` / `window.minder`。
- 保留 MindMapPanel 顶部文件工具栏。

### C. 回归
- 编译增量验证（E003）；装卸各一次；导入/导出 JSON 往返；
- 文字编辑（双击）、Ctrl+回车新建节点、右键热框；主题/布局；
- 运行稳定性；`--roundtrip` 自检。

## 四、风险与回退

| 风险 | 应对 |
|---|---|
| 某 bower 依赖拉取失败或版本不兼容 → 编辑器白屏 | 回退到方案 A：只改当前 `index.html`、自实现双击内联文本编辑（不引入外部大包），保证可用 |
| 完整包体积 ~5–15MB | 外置到数据目录，脱离 dll 内嵌紧凑形态（用户既定方向） |
| 内嵌子资源（bootstrap 字体等）缺失 | 按 css 引用补 `dist/fonts/` 等 |
| UI 与本项目自绘工具栏重叠 | 编辑器自带接管编辑交互；仅保留顶部文件工具栏 |

## 五、验收标准
- 打开脑图面板即可在节点上双击进入文字编辑、回车保存、Esc 取消；
- 顶部文件工具栏（安装/导入/导出/刷新/调试）仍可用；
- `window.editor / window.minder` 桥接正常，导入导出往返一致；
- 装卸无损还原。

## 六、接入编辑器样式按 GUI 面板深色对齐（已完成 2026-09-01）
- **目标**：让完整编辑器 chrome（顶部标签/工具面板/下拉/备注/浮层/左侧导航条）
  对齐 MindMapPanel 深色配色；画布背景保留脑图主题驱动，不强压。
- **改动落点**：向 `数据/plugins/kityminder/dist/index.html` 注入独立 `<style>`
  深色覆盖块，并同步写回 `资源/kityminder.ui.zip` 的 `dist/index.html`
  （保证重装/重新部署后样式不丢）。
- **配色映射**（取自 `MindMapPanel.xaml`）：
  - 画布/面板底 `#1B1B1F`、侧栏底 `#101318`、正文 `#AEB6C4`、
    强调 `#7FC2FF`、选中底 `#244B79`、按钮底 `#26262B`、hover `#33333A`、边框 `#383840`。
- **覆盖的关键类**：`html,body`（含 `!important` 压过内联白底）、
  `.top-tab .nav-tabs`（含 `li.active a`）、`.top-tab .tab-content`、
  `.km-btn-item`/`.km-btn-group`、`.btn-default/.btn/.btn-group-vertical .select`、
  `.dropdown-menu`、`.modal-content/.modal-header/.modal-footer`、`.form-control`、
  `.km-note`/`.CodeMirror`、`.nav-bar`（默认珊瑚红 #fc8383 → 深色）、`.hotbox` 浮层。
- **注意（特性不破坏）**：画布 `.km-editor` 背景是 kityminder 主题以内联
  `style="background:…"` 绘制，若 CSS `!important` 强压会废掉 GUI 已上线的
  「自定义主题背景色」。结论（用户确认）：**画布跟随主题，不做强制处理**——
  需要全深可新建/选用深色自定义主题。
- **发布形态**：本改动只涉及外部插件目录与资源 zip，`src/` 嵌入资源未改，
  外部插件优先加载，GUI 下次打开脑图即生效，**无需重编 dist**。

## 七、顶部栏 GUI 化迁移脚手架（进行中 2026-09-01）
- **目标**：把编辑器 WebView 原生工具栏（链接/图片/备注/优先级等）逐个重绘为 GUI
  深色按钮，迁入一条新 GUI 顶部栏；迁移完成后移除原生工具栏。当前阶段只搭栏+样板。
- **落点（WPF，MindMapPanel）**：在面板标题行下方新增一行（Row=1，承载区移到 Row=2）
  深色顶部栏（`#101318` 底/`#383840` 边），位于 WebView 上方；与编辑器原生工具栏
  上下并存，便于逐项对照功能是否齐全。
- **样式**：新增本地 `ToolBarBtn` 样式（底 `#26262B`、hover `#33333A`、按下 `#244B79`、
  描边 `#383840`），对齐 GUI 面板配色。
- **首期样板按钮**：链接 / 图片 / 备注 三个占位，点击仅 `SetStatus` 提示（占位）。
- **后续（未做）**：逐个把原生编辑命令桥接为按钮点击（走 `KityMinderHost`/`window.__minder`
  桥，如 execCommand('hyperlink')/('image')/('note')），迁移一个移除原生对应按钮一个。

## 八、外观功能全部迁入右侧边栏（已完成 2026-09-01）
- **目标（用户需求）**：把 WebView 编辑器原生【外观】页签的整理布局/清除样式/字体/字号/
  加粗/斜体/字体颜色，全部搬到 MindMapPanel 右侧边栏；原生外观页签**暂时保留对照**（与
  顶部栏迁移策略一致），全部稳定后再删。
- **命令映射（经 `kityminder.core.min.js` / `kityminder.editor.min.js` 静态核验）**：
  - 整理布局 `resetlayout`、清除样式 `clearstyle`（无参）
  - 加粗 `bold`、斜体 `italic`（无参 toggle；注意编辑器按钮命令是 `italic`，仅 CSS 类名
    写作 `font-italics`，勿被类名误导用 `italics`）
  - 字体 `fontfamily`（带参，CSS 字体族串，如 `""宋体,SimSun""`）、字号 `fontsize`（带参数字，
    内置档 `10/12/16/18/24/32/48`）、字体颜色 `forecolor`（带参 HEX `#rrggbb`，默认 `#000`）
- **关键改动**：
  1. `数据/plugins/kityminder/dist/index.html` 桥接 `bridge.execCommand` 由单参收窄改为
     `minder.execCommand.apply(minder, arguments)` 放开可变参数，带参命令（forecolor/
     fontfamily/fontsize）才能透传；并同步回 `资源/kityminder.ui.zip` 内的 `dist/index.html`
     （逐字节校验一致），保证重装离线包后仍生效。改外部插件目录后**无需重编 dist** 即生效。
  2. `KityMinderHost` 新增 `ExecCommandWithValueAsync(name, value)`：value 经
     `JsonSerializer.Serialize` 化为合法 JS 字面量（字符串带引号、数字裸值）注入命令。
  3. `MindMapPanel.xaml`：右侧边栏主题项下新增「外观」分组——整理布局/清除样式按钮、
     字体/字号下拉（新增本地深色 `SideComboBox` 样式，硬编码配色，不依赖全局 Neu 资源）、
     B 加粗 / I 斜体 / 字体颜色色块按钮（走 `ColorPicker.Pick` 取色，色块实时回显）。
  4. `MindMapPanel.xaml.cs`：`BuildSidebar` 填充字体目录（与原编辑器目录一致，12 种）
     与字号档；外观事件接线（无参命令走 `ExecCommandAsync`，带参走 `ExecCommandWithValueAsync`）。
- **验证**：`build.ps1` 编译成功产出 `dist\分配项目组.exe`；启动后进程存活无 XamlParseException，
  右侧边栏外观分组渲染，探针确认桥接可执行带参命令。

## 九、思路功能全部迁入新 GUI 顶部栏（已完成 2026-09-01）
- **目标（用户需求）**：把 WebView 编辑器原生【思路】页签的全部功能搬到 MindMapPanel 新 GUI
  顶部栏；原生思路页签**暂时保留对照**（与顶部栏/外观迁移策略一致），全部稳定后再删。
- **功能清单（经运行实例 DOM 枚举核验）**：撤销/重做、插入下级/同级/上级主题、上移/下移、
  编辑节点、删除节点、优先级(0-9)、进度(0-9)、插入/移除链接、插入/移除图片、插入/移除备注。
- **命令映射（关键坑：core 命令键名全小写！经 `minder._commands` 运行探测确认）**：
  - 撤销/重做：**不在内核命令表**，走 `window.editor.history.undo()/redo()`（宿主
    `ExecCommandAsync` 对 `undo`/`redo` 特判）；勿用 `execCommand('undo')`（静默失败）
  - 插入下级 `appendchildnode`、同级 `appendsiblingnode`、上级 `appendparentnode`
  - 上移 `arrangeup`、下移 `arrangedown`、删除 `removenode`（均小写！不是 `ArrangeUp`/`RemoveNode`）
  - 编辑节点：`window.__minder.editSelected()`（宿主新增公开 `EditSelectedAsync`）
  - 优先级 `priority`、进度 `progress`：带参数字 0-9（0=清除，编辑器值域同为 0-9）
  - 链接 `hyperlink`、图片 `image`、备注 `note`：带参；null 即移除（宿主新增
    `SetHyperlinkAsync`/`SetImageAsync`/`SetNoteAsync`，值经 JSON 序列化）
- **关键改动**：
  1. `KityMinderHost`：`ExecCommandAsync` 对 undo/redo 走 `editor.history`；新增
     `EditSelectedAsync`、`SetHyperlinkAsync`、`SetImageAsync`、`SetNoteAsync`。
  2. `MindMapPanel.xaml`：顶部栏由「快捷编辑（迁移中）」样板改为「思路」分组——撤销/重做/
     插入下级/同级/上级/上移/下移/编辑/删除/链接/图片/备注 + 优先级(P1-P9+清除) + 进度(1-9+清除)
     图标按钮排，分隔线分组；外观功能保留在右侧边栏（用户确认：顶部栏仅思路一组）。
  3. `MindMapPanel.xaml.cs`：`OnIdeaClick`（无参命令）、`OnLinkClick`/`OnImageClick`/`OnNoteClick`
     （复用 `PromptDialog` 输入，留空确定=移除）、`OnPriorityClick`/`OnProgressClick`（带参 0-9）。
- **验证（2026-09-01 重跑）**：`build.ps1` 编译成功产出 `dist\分配项目组.exe`（此前 exe 时间戳早于
  源码，验证结论过期，已按 E014 当场重跑）；启动后进程存活无 XamlParseException，顶部栏思路分组渲染。
- **原生思路页签去留**：用户确认**暂时保留对照**（与顶部栏/外观迁移策略一致），全部稳定后再删。

## 十一、视图功能全部迁入新 GUI 顶部栏（已完成 2026-09-01）
- **目标（用户需求）**：把 WebView 编辑器原生【视图】页签的全部功能搬到 MindMapPanel 新 GUI 顶部栏，
  靠右排放；新 GUI 顶部栏改为**上下两排**，上排思路、下排视图，按钮排布参考 webview 排布。
- **功能清单（经 `kityminder.editor.js` 静态核验 topTab.html + 三指令模板）**：
  - 展开级别 `expand-level`：展开全部节点（`ExpandToLevel` 9999）/ 一级到六级（1-6）
  - 选择 `select-all`：全选 `all` / 反选 `revert` / 选择兄弟节点 `siblings` / 选择同级节点 `level` /
    选择路径 `path` / 选择子树 `tree`
  - 搜索 `search-btn`：触发 `minder.fire('searchNode')` 弹出编辑器自带搜索框
- **关键点**：
  1. 选择未走内核命令（无独立命令），需在 JS 桥接层复刻编辑器 selectAll 指令的 6 种选择逻辑
     （`window.__minder.select(mode)`）；`ExpandToLevel` 是 core 命令，宿主 `ExecCommandWithValueAsync`
     直接透传。
  2. `index.html` 桥接层新增 `select(mode)`/`search()`，并同步回 `资源/kityminder.ui.zip`
     （逐字节校验一致），保证重装离线包后不丢。
  3. `KityMinderHost` 新增 `SelectNodesAsync(mode)`、`SearchAsync()`。
  4. `MindMapPanel.xaml`：顶部栏外层 Orientation 改为 Vertical 分上下两排；上排思路不变，
     下排 `DockPanel` 把视图控件组 Dock.Right 靠右（展开级别/选择两个下拉 + 搜索按钮）。
  5. `MindMapPanel.xaml.cs`：`OnExpandLevelChanged`（选中即执行并重置占位）、`OnSelectChanged`（同）、
     `OnSearchClick`。
- **排布调整（2026-09-01 用户确认）**：顶部栏改为**两排网格**（`Grid` 2 行 × 多列）——
  左=思路功能上下成对叠放（撤销/重做、插入上级/下级、上移/下移、编辑/删除；插入同级独立占上排；
  链接/图片/备注竖排跨两行；优先级、进度各自拆成上下两排：P1-P5/1-5 上排、P6-P9+清除/6-9+清除 下排），
  右=视图功能（展开级别/选择/搜索）跨两排靠右。非「思路一排+视图一排」。
  数字按钮改用 `ToolBarNumBtn` 样式（40×32，右距 4）。
- **验证**：`build.ps1` 编译成功产出 `dist\分配项目组.exe`（2026-09-01 05:23）；启动后进程存活无 XamlParseException。
- **原生视图页签去留**：暂保留对照（与思路/外观迁移策略一致），全部稳定后再删。

## 十、布局切换改为图片缩略图网格（已完成 2026-09-01）
- **目标（用户需求）**：GUI 右侧边栏「布局」由 6 个文字选项改为与 webview 外观页签一致的
  6 张图片缩略图直显，鼠标悬浮显示名称，名称与 webview 完全一致。
- **关键改动**：
  1. 从编辑器 `template.png` 雪碧图裁剪 6 张缩略图 → `src/Assets/Layouts/layout-{value}.png`
     （default/right/filetree/structure/fish-bone/tianpan），csproj 声明为 EmbeddedResource。
  2. `KityMinderContract.LayoutMeta` 对齐 webview 模板下拉：default=思维导图 / right=逻辑结构图 /
     filetree=目录组织图 / structure=组织结构图 / fish-bone=鱼骨头图 / tianpan=天盘图
     （注意：webview「逻辑结构图」= right 单向，非旧 GUI 的 mind 双向）。
  3. `index.html` 桥接新增 `setTemplate(t)`（`execCommand('template', t)` 回退 `useTemplate`），
     并同步回 `资源/kityminder.ui.zip`（逐字节校验一致）；`KityMinderHost` 新增 `SetTemplateAsync`。
  4. `MindMapPanel.xaml`：布局区改 `UniformGrid Columns=3` + `LayoutThumbBtn` 样式
     （图片直显、选中 #244B79 底、悬浮 #7FC2FF 描边、ToolTip 显示名称）；
     `MindMapPanel.xaml.cs`：`StyleOption` 增 `Thumb` 属性，`LoadLayoutThumb` 从内嵌资源加载
     冻结位图，`OnLayoutClick` 改走 `SetTemplateAsync`。
- **验证（2026-09-01）**：`build.ps1` 编译成功产出 `dist\分配项目组.exe`；`分配项目组.dll`
  内嵌 6 张布局资源名核验齐全（`FenPeiXiangMuZu.Assets.Layouts.layout-*`）。注意：编译期间
  若 GUI 实例在运行会锁 `KityMinderPlugin.dll` 导致拷贝失败（新 exe+旧 dll 不一致），须先
  关闭实例再编译，或从 `%TEMP%\fpx-kityminder-plugin-build` 补拷 dll。
- **修复（2026-09-01 用户反馈「鱼骨头图没切到」）**：根因是**缩略图资源名不匹配**——文件与
  csproj 声明为 `layout-fishbone.png`（无连字符），而 `LoadLayoutThumb` 按 `layout-{value}.png`
  拼接出 `layout-fish-bone.png`（有连字符），鱼骨头缩略图加载失败显示空白，其余 5 张正常。
  修复：重命名文件为 `layout-fish-bone.png` 并同步 csproj，重建后嵌入资源名与拼接一致。
  另经独立浏览器实测核验切换机制本身无问题：core 注册 `fish-bone` 模板（b[71]）、命令
  `template`（小写）正确、`useTemplate('fish-bone')` 成功切换；webview 模板下拉同样用
  `execCommand('template','fish-bone')`。最小环境 execCommand 报 `clientWidth` 空引用属
  无渲染目标的环境差异，真实编辑器内正常。
- **布局调整（2026-09-01 用户需求「3行2列、图片加宽、两侧透明不拉伸」）**：缩略图由
  3列2行 改为 2列3行（`UniformGrid Columns=2`）；6 张 png 由 50x40 加宽为 100x40
  （内容 50x40 居中、两侧各 25px 透明像素，System.Drawing 处理，注意 `FromFile` 会锁文件
  须先读入 MemoryStream 再保存）；XAML 图片尺寸改 `Width=100 Height=58 Stretch=Uniform`
  （内容不变形居中，上下留按钮背景色）。重建后 dll 内嵌 6 张均为 100x40。

## 十一、脑图自动保存与打开恢复（已完成 2026-09-01）
- **目标（用户需求）**：每次打开脑图都是默认样式/内容 → 每次编辑自动保存，打开时恢复
  上次编辑的内容、主题、布局。
- **关键改动**：
  1. 新增 `src/Services/MindMapStateStore.cs`：`MindMapState{Content,Theme,Layout}` 持久化到
     `数据/mindmap-state.json`（原子写 tmp→move、进程内锁、写路径严格读取，遵循 MindMapThemeStore 模式）。
  2. `KityMinderHost.Reload()` 重置 `_ready/_diagnosed`，使重载完成后再次触发 `ReadyChanged`
     （供调用方恢复状态；刷新按钮/插件目录变化重载均受益）。
  3. `MindMapPanel`：
     - 编辑器就绪（`ReadyChanged`）→ `OnEditorReady` 恢复上次内容/主题/布局（自定义主题先注册再切换），
       恢复期间 `_suppressSave` 抑制保存，延迟 1.2s 解除并补存抑制期间变更（`_dirtyDuringSuppress`）。
     - `ContentChanged` → 600ms 防抖自动保存（`SaveStateNowAsync`：导出 JSON + 主题/布局落盘，
       内容去重 + `_saving` 重入保护）。
     - 切换主题/布局（`OnThemeClick`/`SwitchCustomThemeAsync(persist)`/`OnLayoutClick`）立即落盘。
     - `Show()` 改为「编辑器已就绪且插件目录未变时不再重载」，保留内容/视图状态（避免每次打开重置）；
       目录变化或未就绪才 `Reload()`。
     - 面板不可见（关闭浮层）时立即落盘防抖窗口内的编辑（`IsVisibleChanged`）。
- **验证（2026-09-01）**：`build.ps1` 编译成功产出 `dist\分配项目组.exe`（05:33）；启动后进程
  存活无 XamlParseException、无新增异常日志；WebView2 子进程正常。功能验证由用户手动进行：
  打开脑图 → 编辑/改主题/改布局 → 关闭重开（应保留）→ 重启应用再打开（应恢复）。
