# 知识花园

个人学习笔记站点。基于 [Quartz v5](https://quartz.jzhao.xyz/) 构建，纯静态、无后端，push 到 GitHub 后自动发布。

内容只有四个方向：**编程语言 / 架构 / 吉他 / 中间件**，外加一个收件箱和若干跨领域主题页。

---

## 本地预览

```bash
npm install          # 首次
npx quartz build --serve
```

打开 http://localhost:8080 。改 `content/` 里的文件会自动重建。

> [!note] 如果 `npx` 报 `EPERM` / `Your cache folder contains root-owned files`
> 是 `~/.npm` 的所有权问题，一次性修好：
>
> ```bash
> sudo chown -R $(id -u):$(id -g) ~/.npm
> ```
>
> 不想动 `sudo` 的话，可以直接用本地的 CLI：
>
> ```bash
> node quartz/bootstrap-cli.mjs build --serve
> ```

## 写一篇笔记

1. 在对应领域目录下新建 `.md` 文件（不确定放哪就先放 `content/inbox/`）
2. 文件头写 frontmatter：

```yaml
---
title: 一句话判断，不是名词
description: 这篇解决什么问题，会出现在链接预览里。
tags:
  - programming        # 领域
  - type/note          # 类型：note / log / cheatsheet / moc / topic
  - status/seedling    # 状态：seedling / growing / stable
date: 2026-11-16
---
```

3. 用 `[[文件名|显示文字]]` 链接其他笔记，构建时自动生成反向链接和关系图

完整模板见 `content/templates/note.md`（该目录已在 `ignorePatterns` 里，不会发布）。

## 目录结构

```
content/
├── index.md              首页（四宫格入口）
├── about.md              关于本站
├── inbox/                收件箱：还没整理的碎片
├── programming/          编程语言（index.md 是目录页）
├── architecture/         架构
├── guitar/               吉他
├── middleware/           中间件
├── topics/               跨领域主题页
└── templates/            笔记模板（不发布）
```

## 发布到 GitHub Pages

仓库已经建好并接上了 `origin`（`zengjixiang-codespace/llm-wiki`），Pages 也已开启。日常只需要：

```bash
git add -A && git commit -m "更新笔记" && git push
```

`.github/workflows/deploy.yml` 会自动构建并发布到
**https://zengjixiang-codespace.github.io/llm-wiki/**，大约一分钟。

> [!important] 三个跟地址相关的配置，改名或换仓库时一起改
> - `quartz.config.yaml` 的 `baseUrl`：`zengjixiang-codespace.github.io/llm-wiki`
> - `.github/workflows/deploy.yml` 的触发分支：`main`
> - 仓库 **Settings → Pages → Source**：GitHub Actions

## 改外观

| 想改什么 | 去哪儿 |
| --- | --- |
| 站点标题、语言、颜色 | `quartz.config.yaml` 的 `configuration` |
| 字体、卡片样式 | `quartz/styles/custom.scss` |
| 首页内容 | `content/index.md` |
| 导航栏/搜索/关系图的位置 | `quartz.config.yaml` 的 `layout` |

字体目前**全部用系统字体**（苹方 / 微软雅黑 / Noto），不依赖 Google Fonts，国内打开不会卡在字体上。想换成网络字体，在 `quartz.config.yaml` 里把 `quartz-fonts` 的 `fontOrigin` 改回 `googleFonts` 即可。

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `npx quartz build --serve` | 本地预览（含热更新） |
| `npx quartz build` | 只构建到 `public/` |
| `npx quartz sync` | 提交并推送当前内容 |
| `npx quartz upgrade` | 升级 Quartz 本体 |

## 说明

- `docs/` 是 Quartz 自带的离线文档，和你的站无关，可以整个删掉
- 站点构建后才有的 `public/`、`node_modules/`、`.quartz/` 已在 `.gitignore` 里
- 内容用 Markdown 写，随时可以换别的静态站工具，不会被锁死
