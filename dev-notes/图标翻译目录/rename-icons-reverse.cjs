'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = 'e:\\_tools\\Tools_DIY\\分配项目组迁移';
const DATA = path.join(ROOT, '数据');
const CFG = path.join(DATA, '分配项目组-config.json');
const ICON_DIR = path.join(DATA, 'preseticons');

const MAP = {
  ai: '人工智能', animate: '动画', ar: '增强现实', archive: '归档', art: '美术',
  asset: '资源', audio: '音频', backup: '备份', battery: '电池', book: '书籍',
  bookmark: '书签', browser: '浏览器', camera: '相机', chart: '图表', chip: '芯片',
  client: '客户端', clipboard: '剪贴板', clock: '时钟', cloud: '云', code: '代码',
  color: '颜色', contract: '合同', dashboard: '仪表盘', data: '数据', database: '数据库',
  deploy: '部署', design: '设计', desktop: '桌面', display: '显示器', document: '文档',
  download: '下载', experiment: '实验', export: '导出', favorite: '收藏', film: '影片',
  filter: '筛选', finance: '财务', folder: '文件夹', font: '字体', game: '游戏',
  gear: '齿轮', globe: '地球', headset: '耳机', history: '历史', hr: '人力',
  idea: '创意', image: '图片', import: '导入', invoice: '发票', issue: '问题',
  key: '密钥', knowledge: '知识', layer: '图层', level: '关卡', library: '素材库',
  lock: '锁定', log: '日志', logo: '标志', map: '地图', mic: '麦克风',
  mobile: '移动端', model3d: '3D模型', molecule: '分子', monitor: '显示屏', music: '音乐',
  network: '网络', neural: '神经网络', note: '笔记', pad: '平板', palette: '调色板',
  particle: '粒子', permission: '权限', photo: '照片', plan: '计划', player: '播放器',
  preset: '预设', printer: '打印机', project: '项目', prototype: '原型', reference: '参考',
  release: '发布', report: '报表', research: '研究', robot: '机器人', scanner: '扫描仪',
  science: '科学', script: '脚本', search: '搜索', security: '安全', server: '服务器',
  setting: '设置', sfx: '音效', shader: '着色器', share: '分享', shield: '盾牌',
  storyboard: '分镜', study: '学习', sync: '同步', tag: '标签', team: '团队',
  temp: '临时', template: '模板', terminal: '终端', test: '测试', texture: '贴图',
  tool: '工具', training: '训练', tutorial: '教程', ui: '界面', upload: '上传',
  user: '用户', ux: '用户体验', vector: '矢量', video: '视频', vr: '虚拟现实',
  wrench: '扳手', writing: '写作',
};

const raw = fs.readFileSync(CFG, 'utf8');
const cfg = JSON.parse(raw);

// collect all icons from config
const allIcons = [];
for (const g of cfg.iconGroups) for (const n of g.icons) allIcons.push(n);

// validate: every icon has a mapping, and mapped names are unique
const usedNew = new Set();
for (const n of allIcons) {
  if (!MAP[n]) throw new Error('no translation for icon: ' + n);
  const t = MAP[n];
  if (usedNew.has(t)) throw new Error('duplicate target name: ' + t);
  usedNew.add(t);
}
if (MAP) { /* all config icons covered */ }

// physical rename (new name must not already exist on disk)
const renamed = [];
for (const n of allIcons) {
  const t = MAP[n];
  const src = path.join(ICON_DIR, n + '.ico');
  const dst = path.join(ICON_DIR, t + '.ico');
  if (!fs.existsSync(src)) throw new Error('missing icon file: ' + n);
  if (fs.existsSync(dst)) throw new Error('target already exists: ' + t);
}
for (const n of allIcons) {
  const t = MAP[n];
  fs.renameSync(path.join(ICON_DIR, n + '.ico'), path.join(ICON_DIR, t + '.ico'));
  renamed.push(n + ' -> ' + t);
}

// update config iconGroups in place
for (const g of cfg.iconGroups) {
  g.icons = g.icons.map(n => MAP[n]);
}

// write back preserving System.Text.Json style: 2-space indent + \uXXXX escape non-ASCII, no BOM
function escapeNonAscii(s) {
  return s.replace(/[^\x00-\x7F]/g, ch =>
    '\\u' + ch.charCodeAt(0).toString(16).toUpperCase().padStart(4, '0'));
}
const out = escapeNonAscii(JSON.stringify(cfg, null, 2));
fs.writeFileSync(CFG, out, 'utf8');

console.log('RENAMED ' + renamed.length);
console.log(renamed.join('\n'));