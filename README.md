# 知识花园

个人学习笔记站点。基于 [Quartz v5](https://quartz.jzhao.xyz/) 构建，纯静态、无后端，push 到 GitHub 后自动发布。

内容只有四个方向：**编程语言 / 音乐 / 美食 / 碎碎念**，外加一个收容所和若干跨领域主题页。

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
# comments: false      # 取消注释 = 关掉这篇的评论区
---
```

3. 用 `[[文件名|显示文字]]` 链接其他笔记，构建时自动生成反向链接和关系图
4. 图片放在**与笔记同名的文件夹**里，用 `![[笔记名/图片名.webp|说明]]` 引用

完整模板见 `content/templates/note.md`（该目录已在 `ignorePatterns` 里，不会发布），
里面还列了 `unlisted` / `draft` / `aliases` 几个可选字段的用法。

## 目录结构

```
content/
├── index.md              首页（四宫格入口）
├── about.md              关于本站
├── inbox/                收容所：还没整理的碎片
├── programming/          编程语言（index.md 是目录页）
├── architecture/         架构
├── guitar/               吉他
├── middleware/           中间件
├── topics/               跨领域主题页
└── templates/            笔记模板（不发布）
```

## 发布到 GitHub Pages

仓库：[zengjixiang-codespace/llm-wiki](https://github.com/zengjixiang-codespace/llm-wiki)
线上地址：**https://zengjixiang-codespace.github.io/llm-wiki/**

发表一篇新笔记，一步：

```bash
git add -A && git commit -m "更新笔记" && git push
```

推送到 `main` 后，`.github/workflows/deploy.yml` 自动构建并发布，约一分钟生效。
在仓库 **Actions** 页能看到每次构建的日志。

### 依赖更新

`.github/dependabot.yml` 每周一检查 `.github/workflows/` 里用到的 actions 版本
（`actions/checkout`、`setup-node` 等），有新版本就提一个 PR。它只提 PR 不自动合并。

npm 依赖**故意不交给 Dependabot**——Quartz 的依赖必须和配套插件一起升，用：

```bash
npx quartz upgrade
```

### 应急方案

`deploy.sh` 保留着：构建后强推 `gh-pages` 分支。如果哪天 Actions 出问题、又急着发布，
可以手动跑一次，再到 Settings → Pages 临时切回 `gh-pages` 分支。

### 凭据过期了怎么办

`git push` 报 `Authentication failed` / `401 Bad credentials`，基本就是 token 过期。

**这只影响本地推送，不影响线上**——Actions 用的是 GitHub 自动注入的 `GITHUB_TOKEN`，
`npx quartz upgrade`、`npx quartz sync` 这类命令则需要本地 token 正常。

续期：

```bash
# 新建 token 时勾 repo + workflow + read:org（缺 read:org 会被 gh 拒绝）
read -rs GH_TOKEN && printf '%s\n' "$GH_TOKEN" | gh auth login --with-token
gh auth status
```

更省事的办法：用 `gh auth login` 走浏览器授权，拿到的 OAuth token 长期有效，不用定期续。

> [!important] 三个跟地址相关的配置，改名或换仓库时一起改
> - `quartz.config.yaml` 的 `baseUrl`：`zengjixiang-codespace.github.io/llm-wiki`
> - `.github/workflows/deploy.yml` 的触发分支：`main`
> - 仓库 **Settings → Pages → Source**：GitHub Actions

## 改外观

| 想改什么 | 去哪儿 |
| --- | --- |
| 站点标题、语言、颜色 | `quartz.config.yaml` 的 `configuration` |
| 字体、卡片样式、背景蒙版 | `quartz/styles/custom.scss` |
| 背景图 | 深色用 `quartz/static/bg.jpg`，浅色用 `quartz/static/bg-light.jpg`，替换同名文件即可 |
| 首页内容 | `content/index.md` |
| 导航栏/搜索/关系图的位置 | `quartz.config.yaml` 的 `layout` |

字体目前**全部用系统字体**（苹方 / 微软雅黑 / Noto），不依赖 Google Fonts，国内打开不会卡在字体上。想换成网络字体，在 `quartz.config.yaml` 里把 `quartz-fonts` 的 `fontOrigin` 改回 `googleFonts` 即可。

## 评论与点赞

用 [Giscus](https://giscus.app/)：评论存进本仓库的 **Discussions → Announcements**，
点赞用讨论上的 GitHub 反应（👍 ❤️ 等），数据都在自己仓库里，没有第三方数据库。

- 配置在 `quartz.config.yaml` 的 `comments` 条目（`repoId` / `categoryId` 等）
- 只显示在笔记和文章页：首页靠 `condition: not-index`，文件夹页和标签页在 `layout.byPageType` 里排除了
- 单篇关闭：在该页 frontmatter 加 `comments: false`（`about.md` 就是这么关的）
- **首次使用要在仓库上安装 giscus App**：<https://github.com/apps/giscus/installations/new>
  不装的话评论区会显示 "giscus is not installed on this repository"

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
