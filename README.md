# 随记 · 鲨鱼辣椒的小世界

个人学习笔记站点。基于 [Quartz v5](https://quartz.jzhao.xyz/) 构建，纯静态、无后端，push 到 GitHub 自动构建发布。

- 线上地址：**https://zengjixiang-codespace.github.io/llm-wiki/**
- 仓库：`zengjixiang-codespace/llm-wiki`

四个方向并行：**编程 / 音乐 / 美食 / 碎碎念**，外加一个收容所和若干跨领域主题页。

---

## 目录结构

```
content/
├── index.md                首页（四宫格入口）
├── about.md                关于
├── inbox/                  收容所：还没整理的碎片
├── programming/            编程（index.md 是目录页）
├── music/                  音乐
│   ├── scale-basics.md     音阶基础
│   ├── practice-plan.md    练习规划
│   ├── seven-groups.md     七组音阶练习
│   ├── practice-log.md     练习日志模板
│   └── <笔记名>/           该笔记的配图
├── food/                   美食
├── feeling/                碎碎念
├── topics/                 跨领域主题页
├── blog/                   长文（建站记录等）
└── templates/              笔记模板（不发布）
```

配图放在**与笔记同名的文件夹**里，删笔记时整个文件夹一起删，不会留下孤儿图片。

## 写一篇笔记

1. 在对应栏目下新建 `.md`（不确定放哪就先扔 `content/inbox/`）
2. 文件头写 frontmatter：

```yaml
---
title: 一句话判断，不是名词
description: 这篇解决什么问题，会出现在链接预览里。
tags:
  - music              # 领域：programming / music / food / feeling
  - type/note          # 类型：note / log / cheatsheet / moc / topic
  - status/seedling    # 状态：seedling / growing / stable
date: 2026-11-19
# comments: false      # 取消注释 = 关掉这篇的评论区
---
```

3. 用 `[[文件名|显示文字]]` 链接其他笔记，构建时自动生成反向链接和关系图
4. 图片放 `content/<栏目>/<笔记名>/`，用 `![[笔记名/图片名.webp|说明]]` 引用

完整模板见 `content/templates/note.md`（该目录在 `ignorePatterns` 里，不发布），
里面还列了 `unlisted` / `draft` / `aliases` 的用法。

## 日常流程

```bash
npx quartz build --serve      # 本地预览 http://localhost:8080
# 写…
git add -A && git commit -m "更新笔记" && git push
```

push 后 Actions 自动构建，约 40 秒上线。

> [!note] 如果 `npx` 报 `EPERM` / `root-owned files`
> 是 `~/.npm` 所有权问题，一次性修好：`sudo chown -R $(id -u):$(id -g) ~/.npm`
> 不想动 sudo 就用本地 CLI：`node quartz/bootstrap-cli.mjs build --serve`

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `npx quartz build --serve` | 本地预览（热更新） |
| `npx quartz build` | 只构建到 `public/` |
| `npx quartz sync` | 提交并推送当前内容 |
| `npx quartz upgrade` | 升级 Quartz 本体 |

## 部署

- **自动**：push 到 `main` → `.github/workflows/deploy.yml` → GitHub Pages
- **应急**：`./deploy.sh` 构建后强推 `gh-pages` 分支，再把 Pages 临时切到该分支
- **缓存**：GitHub Pages 给静态资源 `max-age=600`。**换图时请同时换文件名**（如 `group1-v4.webp`），否则浏览器十分钟内看到的还是旧图

## 评论与点赞

用 [Giscus](https://giscus.app/)，数据存在本仓库 **Discussions → Announcements**：

- 点赞 = 讨论上的 GitHub 反应
- 只在笔记页和文章页显示（`condition: not-index` + `byPageType` 排除文件夹页和标签页）
- 单篇关闭：frontmatter 加 `comments: false`
- 首次部署需安装 App：<https://github.com/apps/giscus/installations/new>

## 改外观

| 想改什么 | 去哪儿 |
| --- | --- |
| 站名、语言、配色 | `quartz.config.yaml` 的 `configuration` |
| 字体、卡片、背景蒙版 | `quartz/styles/custom.scss` |
| 背景图 | 深色 `quartz/static/bg.jpg`，浅色 `bg-light.jpg` |
| 首页四宫格 | `content/index.md` |
| 侧栏/搜索/图谱位置 | `quartz.config.yaml` 的 `layout` |

字体全部走系统字体（苹方 / 微软雅黑 / Noto），不依赖 Google Fonts。
想换网络字体，把 `quartz-fonts` 的 `fontOrigin` 改回 `googleFonts`。

## 维护

**依赖更新**：`.github/dependabot.yml` 每周检查 Actions 版本并提 PR。
npm 依赖不交给 Dependabot（Quartz 的依赖要和插件一起升），用 `npx quartz upgrade`。

**凭据过期**：`git push` 报 `Authentication failed` 就是 token 过期。
新建 token 时勾 `repo` + `workflow` + `read:org`，然后：

```bash
read -rs GH_TOKEN && printf '%s\n' "$GH_TOKEN" | gh auth login --with-token
gh auth status
```

> [!important] 改仓库名或换域名时，三处一起改
> `quartz.config.yaml` 的 `baseUrl`、`deploy.yml` 的触发分支、Pages 的 Source

## 说明

- `public/`、`node_modules/`、`.quartz/` 已在 `.gitignore` 里，不需要提交
- 内容全是 Markdown，随时可以换别的静态站工具，不会被锁死
