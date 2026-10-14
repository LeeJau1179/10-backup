# Obsidian-S 目录指引

本 vault 是《逆世书》小说创作库。本文件只做**目录导航**，各层具体规则见对应子 AGENTS.md（见文末索引），不在此复述。

## 全库铁律

- **讨论不等于设定，解释不等于约束，否定旧方案不等于新增永久禁令。**
- 改任何文件都直接改成最新内容，不留痕迹：不写来源、修订记录、日期标注、「作者定／作者对话」、「改为／删除／原来」之类的改动说明。改动历史由 git 记录。
- 场景卡 `synopsis` 记事件及核心变化，`conflict` 记矛盾；SceneNotes 记节拍、边界和正文待改。写法见 `StoryLine/逆世书/AGENTS.md`「场景卡与 SceneNotes」。

## 顶层目录

| 路径 | 用途 |
| --- | --- |
| `StoryLine/` | 小说主库（StoryLine 插件 + 《逆世书》） |
| `小剧场.md` | 番外／小剧场对话集 |
| `.obsidian/` | Obsidian 配置与插件（勿手改） |
| `.opencode/` `.claude/` `.agents/` `.claudian/` `copilot/` | AI 工具配置、skills、会话（非小说内容） |
| `.git/` `.gitignore` | 版本控制 |

## 《逆世书》结构（`StoryLine/逆世书/`）

| 路径                          | 用途                                                                                |
| --------------------------- | --------------------------------------------------------------------------------- |
| `Codex/`                    | 跨本共用设定层：Characters / Culture / Items / Locations / Lore / Organizations / Systems |
| `System/`                   | StoryLine 插件数据（`codex-categories.json` 等），**禁止放 `.md`**                           |
| `今生/`                       | 本一（正文主体）                                                                          |
| `今生/Codex/`                 | 本一层设定：Characters / Locations / Items / Culture / Lore / Organizations；Systems 空置  |
| `今生/Scenes/Act 0–5、Act 99/` | 场景卡（成果驱动）                                                                         |
| `今生/SceneNotes/`            | 场景笔记：节拍、边界、正文待改                                                                   |
| `今生/Notes/`                 | 作者私人参考工作区                                                                         |
| `今生/Research/`              | 研究资料                                                                              |
| `今生/Archive/`               | 归档场景卡                                                                             |
| `今生/System/`                | StoryLine 插件数据（board / plotgrid / plotlines / timeline / characters / stats 等）    |
| `初世/`、`前尘/`                 | 其他故事线（当前仅 storyline 主文件 + `System/` 数据）                                           |
| `StoryLine/Codex/`          | 空置目录（仅登记，不删）                                                                      |

## 规范入口索引

| 文件 | 装什么 |
| --- | --- |
| `StoryLine/逆世书/AGENTS.md` | 创作分层（Codex / Scene / 正文）、场景卡三件套、链接铁律、新建 Scene SOP |
| `StoryLine/逆世书/Codex/AGENTS.md` | Codex 命名／目录归位／单一事实源 |
| `StoryLine/逆世书/今生/Notes/AGENTS.md` | Notes 定位与铁律 |
