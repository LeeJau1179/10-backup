'use strict';
/*
 * StoryLine Prefix Sync
 *
 * StoryLine 1.10.81 起，拖动重排只改 frontmatter 的 `sequence`，不再改文件名。
 * 本插件在场景的 act/sequence 变化后（防抖等拖动写完），把文件名前缀
 * `<act>-<sequence> ` 同步成当前值。改名一律走 app.fileManager.renameFile，
 * 与 Obsidian 手动改名 / CLI move 相同，全库链接自动更新。
 *
 * 前缀格式与 StoryLine 源码一致（SceneManager.getSceneFileNameForMetadata +
 * utils/actChapter.formatActChapterPrefix），只改前缀，不动标题部分。
 */
const obsidian = require('obsidian');
const { Plugin, Notice, Modal, PluginSettingTab, Setting, TFile, normalizePath } = obsidian;

// ── 与 StoryLine 一致的前缀算法 ─────────────────────────────────────
const ILLEGAL_PATH_CHARS = /[\\/:*?"<>|]/g;
// StoryLine getTitleFromSceneFileName 用的同一条正则
const PREFIX_RE = /^([^\s/-]+)-(\d+(?:\.\d+)?)\s+/;

function isPureNumeric(v) {
  if (v === undefined || v === null) return false;
  if (typeof v === 'number') return Number.isFinite(v);
  const s = String(v).trim();
  return s !== '' && /^-?\d+(\.\d+)?$/.test(s);
}

function formatActPrefix(v, fallback = '00') {
  if (v === undefined || v === null) return fallback;
  if (isPureNumeric(v)) {
    const n = Number(v);
    const padded = String(Math.trunc(Math.abs(n))).padStart(2, '0');
    const decimals = (String(v).match(/\.\d+$/) || [''])[0];
    return (n < 0 ? '-' : '') + padded + decimals;
  }
  return String(v).replace(ILLEGAL_PATH_CHARS, '-').replace(/\s+/g, ' ').trim().replace(/[\s.]+$/g, '');
}

function formatSeq(seq) {
  return seq !== undefined && seq !== null ? String(seq).padStart(2, '0') : '00';
}

/**
 * 计算单个场景应有的新文件名。返回：
 *  { status: 'ok' }                       已一致
 *  { status: 'rename', newBase }          需要改名
 *  { status: 'skip', reason }             不处理（并说明原因）
 */
function planFor(basename, fm) {
  const m = basename.match(PREFIX_RE);
  if (!m) return { status: 'skip', reason: '文件名没有序号前缀，按你的选择保留' };
  const titlePart = basename.slice(m[0].length).trim();
  const fmTitle = fm.title === undefined || fm.title === null ? '' : String(fm.title).trim();
  // StoryLine 收到外部改名时会用「去前缀后的文件名」覆盖 frontmatter title。
  // 两者不一致时改名会顺带改掉标题，所以跳过并报告。
  if (!fmTitle || titlePart !== fmTitle) {
    return { status: 'skip', reason: `文件名标题「${titlePart}」≠ frontmatter title「${fmTitle}」` };
  }
  if (fm.sequence === undefined || fm.sequence === null || fm.sequence === '') {
    return { status: 'skip', reason: '没有 sequence' };
  }
  const prefix = `${formatActPrefix(fm.act, '00')}-${formatSeq(fm.sequence)}`;
  const newBase = `${prefix} ${titlePart}`;
  return newBase === basename ? { status: 'ok' } : { status: 'rename', newBase };
}

// ── 插件 ───────────────────────────────────────────────────────────
const DEFAULT_SETTINGS = {
  enabled: true,
  root: 'StoryLine',      // 只处理这个文件夹下的场景
  debounceMs: 2000,       // 拖动后等这么久没有新变化再改名
  confirmAbove: 20,       // 一次要改的文件超过这个数，先弹窗确认
};

class PrefixSyncPlugin extends Plugin {
  async onload() {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
    this.running = false;
    this.rerun = false;
    this.timer = null;
    this.lastSeen = new Map(); // path -> "act|sequence"，只在顺序真的变了才触发

    this.addSettingTab(new PrefixSyncSettingTab(this.app, this));

    this.addCommand({
      id: 'check',
      name: '检查场景文件名前缀（只看不改）',
      callback: () => this.run({ dryRun: true, manual: true }),
    });
    this.addCommand({
      id: 'sync-now',
      name: '立即同步场景文件名前缀',
      callback: () => this.run({ dryRun: false, manual: true }),
    });

    this.app.workspace.onLayoutReady(() => {
      // 记录启动时的状态：启动本身不触发改名，只有之后 act/sequence 变了才触发
      for (const f of this.sceneFiles()) this.lastSeen.set(f.path, this.orderKey(f));
      this.registerEvent(this.app.metadataCache.on('changed', (file) => this.onChanged(file)));
      this.registerEvent(this.app.vault.on('rename', (file, oldPath) => {
        const k = this.lastSeen.get(oldPath);
        this.lastSeen.delete(oldPath);
        if (k !== undefined) this.lastSeen.set(file.path, k);
      }));
    });
  }

  onunload() {
    if (this.timer) window.clearTimeout(this.timer);
  }

  async saveSettings() { await this.saveData(this.settings); }

  inScope(file) {
    if (!(file instanceof TFile) || file.extension !== 'md') return false;
    const root = normalizePath(this.settings.root || '');
    if (root && !(file.path === root || file.path.startsWith(root + '/'))) return false;
    const segs = file.path.split('/');
    if (!segs.includes('Scenes')) return false;
    if (segs.some((s) => s === 'Archive' || s === '_snapshots' || s === '.snapshots')) return false;
    const fm = this.app.metadataCache.getFileCache(file)?.frontmatter;
    return !!fm && fm.type === 'scene' && fm.corkboardNote !== true;
  }

  sceneFiles() {
    return this.app.vault.getMarkdownFiles().filter((f) => this.inScope(f));
  }

  orderKey(file) {
    const fm = this.app.metadataCache.getFileCache(file)?.frontmatter || {};
    return `${fm.act ?? ''}|${fm.sequence ?? ''}`;
  }

  onChanged(file) {
    if (!this.settings.enabled || !this.inScope(file)) return;
    const key = this.orderKey(file);
    const prev = this.lastSeen.get(file.path);
    this.lastSeen.set(file.path, key);
    if (prev === key) return; // 只是改正文/其他字段，不触发
    if (this.running) { this.rerun = true; return; }
    this.schedule();
  }

  schedule() {
    if (this.timer) window.clearTimeout(this.timer);
    this.timer = window.setTimeout(() => {
      this.timer = null;
      this.run({ dryRun: false, manual: false });
    }, Math.max(500, Number(this.settings.debounceMs) || 2000));
  }

  buildPlan() {
    const renames = [];
    const skipped = [];
    const taken = new Set(this.app.vault.getFiles().map((f) => f.path.toLowerCase()));
    for (const file of this.sceneFiles()) {
      const fm = this.app.metadataCache.getFileCache(file)?.frontmatter || {};
      const p = planFor(file.basename, fm);
      if (p.status === 'skip') {
        if (PREFIX_RE.test(file.basename)) skipped.push({ path: file.path, reason: p.reason });
        continue;
      }
      if (p.status !== 'rename') continue;
      const folder = file.parent && file.parent.path !== '/' ? file.parent.path : '';
      const newPath = normalizePath(folder ? `${folder}/${p.newBase}.md` : `${p.newBase}.md`);
      renames.push({ file, from: file.path, to: newPath });
    }
    // 只改前缀、标题部分不变，所以目标名只会和「同文件夹同标题」的文件撞名。
    // 撞名时不改，报告出来（不用临时名中转：StoryLine 会把临时名当成新标题写回）。
    const seen = new Set();
    const ok = [];
    for (const r of renames) {
      const t = r.to.toLowerCase();
      if (taken.has(t) || seen.has(t)) {
        skipped.push({ path: r.from, reason: `目标文件名已存在：${r.to}` });
        continue;
      }
      seen.add(t);
      ok.push(r);
    }
    return { renames: ok, skipped };
  }

  async run({ dryRun, manual }) {
    if (this.running) { this.rerun = true; return; }
    if (!dryRun && this.app.vault.getConfig && this.app.vault.getConfig('alwaysUpdateLinks') !== true) {
      new Notice('StoryLine Prefix Sync：请先打开「设置 → 文件与链接 → 始终更新内部链接」，否则改名会断链。已停止。', 10000);
      return;
    }
    const plan = this.buildPlan();

    if (dryRun) {
      new PlanModal(this.app, plan, { title: '场景文件名前缀检查（未改动）', readOnly: true }).open();
      return;
    }
    if (plan.renames.length === 0) {
      if (manual) new PlanModal(this.app, plan, { title: '所有场景文件名前缀都已是最新', readOnly: true }).open();
      return;
    }
    const limit = Number(this.settings.confirmAbove);
    if (manual || (limit >= 0 && plan.renames.length > limit)) {
      new PlanModal(this.app, plan, {
        title: `将改名 ${plan.renames.length} 个场景文件`,
        onConfirm: () => this.apply(plan),
      }).open();
      return;
    }
    await this.apply(plan);
  }

  async apply(plan) {
    this.running = true;
    let done = 0;
    const failed = [];
    try {
      for (const r of plan.renames) {
        const f = this.app.vault.getAbstractFileByPath(r.from);
        if (!(f instanceof TFile)) { failed.push(`${r.from}：文件已不存在`); continue; }
        if (this.app.vault.getAbstractFileByPath(r.to)) { failed.push(`${r.from}：目标已存在 ${r.to}`); continue; }
        try {
          await this.app.fileManager.renameFile(f, r.to);
          done++;
        } catch (e) {
          failed.push(`${r.from} → ${r.to}：${e && e.message ? e.message : e}`);
        }
      }
    } finally {
      for (const f of this.sceneFiles()) this.lastSeen.set(f.path, this.orderKey(f));
      this.running = false;
    }
    let msg = `StoryLine Prefix Sync：已同步 ${done} 个场景文件名`;
    if (plan.skipped.length) msg += `，跳过 ${plan.skipped.length} 个（命令「检查场景文件名前缀」可看原因）`;
    if (failed.length) msg += `，失败 ${failed.length} 个（详见开发者控制台）`;
    new Notice(msg, 8000);
    if (failed.length) console.warn('[storyline-prefix-sync] 改名失败：', failed);
    if (this.rerun) { this.rerun = false; this.schedule(); }
  }
}

class PlanModal extends Modal {
  constructor(app, plan, opts) {
    super(app);
    this.plan = plan;
    this.opts = opts;
  }
  onOpen() {
    const { contentEl } = this;
    const { renames, skipped } = this.plan;
    contentEl.createEl('h3', { text: this.opts.title });
    contentEl.createEl('p', { text: `需要改名：${renames.length}　跳过：${skipped.length}` });
    const box = contentEl.createDiv();
    box.style.maxHeight = '50vh';
    box.style.overflow = 'auto';
    box.style.fontSize = '0.85em';
    const show = (label, rows) => {
      if (!rows.length) return;
      box.createEl('h4', { text: label });
      const ul = box.createEl('ul');
      for (const r of rows.slice(0, 300)) ul.createEl('li', { text: r });
      if (rows.length > 300) ul.createEl('li', { text: `……另有 ${rows.length - 300} 条` });
    };
    const base = (p) => p.split('/').pop().replace(/\.md$/, '');
    show('改名', renames.map((r) => `${base(r.from)}  →  ${base(r.to)}`));
    show('跳过', skipped.map((s) => `${base(s.path)}：${s.reason}`));
    const btns = contentEl.createDiv({ cls: 'modal-button-container' });
    if (!this.opts.readOnly && this.opts.onConfirm && renames.length) {
      const go = btns.createEl('button', { text: `改名 ${renames.length} 个`, cls: 'mod-cta' });
      go.onclick = () => { this.close(); this.opts.onConfirm(); };
    }
    const cancel = btns.createEl('button', { text: this.opts.readOnly ? '关闭' : '取消' });
    cancel.onclick = () => this.close();
  }
  onClose() { this.contentEl.empty(); }
}

class PrefixSyncSettingTab extends PluginSettingTab {
  constructor(app, plugin) { super(app, plugin); this.plugin = plugin; }
  display() {
    const { containerEl } = this;
    containerEl.empty();
    const s = this.plugin.settings;
    new Setting(containerEl).setName('拖动后自动同步').setDesc('act/sequence 变化后自动改文件名前缀。关掉后只能用命令手动同步。')
      .addToggle((t) => t.setValue(s.enabled).onChange(async (v) => { s.enabled = v; await this.plugin.saveSettings(); }));
    new Setting(containerEl).setName('处理范围').setDesc('只处理此文件夹下各 Scenes 目录里的场景（Archive 除外）。')
      .addText((t) => t.setValue(s.root).onChange(async (v) => { s.root = v.trim(); await this.plugin.saveSettings(); }));
    new Setting(containerEl).setName('等待时间（毫秒）').setDesc('拖动后多久没有新变化才开始改名。')
      .addText((t) => t.setValue(String(s.debounceMs)).onChange(async (v) => { s.debounceMs = Number(v) || 2000; await this.plugin.saveSettings(); }));
    new Setting(containerEl).setName('超过多少个先确认').setDesc('一次要改名的文件数超过此值时先弹窗列出清单。设为 -1 表示从不确认。')
      .addText((t) => t.setValue(String(s.confirmAbove)).onChange(async (v) => { const n = Number(v); s.confirmAbove = Number.isFinite(n) ? n : 20; await this.plugin.saveSettings(); }));
  }
}

module.exports = PrefixSyncPlugin;
module.exports.__test = { planFor, formatActPrefix, formatSeq };
