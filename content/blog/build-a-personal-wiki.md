---
title: 从零搭一个个人知识库：Quartz v5 + GitHub Pages 全流程
description: 从选型到上线，把每个节点的目的、作用，以及真实踩过的六个坑讲清楚。
tags:
  - meta
  - type/note
  - status/growing
date: 2026-11-17
---

一句话概括这套方案：**把一堆 Markdown 文件编译成静态 HTML，交给 CDN 托管。** 所有复杂度都集中在「编译」这一步，运行期几乎没有成本——没有数据库、没有后端进程、没有服务器要维护。

下面按「为什么这么选 → 全景 → 每个节点做什么 → 可复现步骤 → 踩过的坑 → 边界」来讲。

## 一、先定模型，再挑工具

个人知识库只有两种基本组织模型，选错模型，后面用什么都别扭。

| 模型 | 代表工具 | 结构从哪来 | 适合什么 |
| --- | --- | --- | --- |
| 树 | MkDocs Material、Docusaurus | 手写的导航配置 | 有先后顺序的教程、文档 |
| 网 | Quartz、Obsidian Publish | 链接自然生长 | 多领域并行、互相引用的笔记 |

判断标准很朴素：**你半年后打开它，是想从头读，还是想搜某一个点？**

我的笔记横跨编程、音乐、美食、碎碎念四个方向，彼此没有共同的阅读顺序，还经常互相引用（「刻意练习」既是练琴的方法，也是写代码的方法）。所以我选了「网」——具体用 Quartz，它原生支持 `[[双链]]`、反向链接和关系图。

> [!note] 一个反直觉的点
> 网状结构不等于没有目录。做法是**每个领域一个 MOC（Map of Content）**：`programming/index.md` 里手写一个目录，链接到该领域的各篇笔记。这样既有了目录感，又不用维护导航配置。

## 二、全景：一次发布到底发生了什么

```text
你的编辑器
  │  写 content/**/*.md
  ▼
content/  ──git push──►  GitHub（main 分支）
  │
  │  npx quartz build（本地或 CI 里跑）
  ▼
┌─────────────┐   ┌──────────────┐   ┌─────────────┐
│  解析 Parse  │──►│ 转换 Transform │──►│  输出 Emit  │
└─────────────┘   └──────────────┘   └─────────────┘
  │
  ▼
public/  纯静态 HTML + CSS + JS + 搜索索引
  │
  ▼
GitHub Pages（CDN）──► https://用户名.github.io/仓库名/
```

关键点：**构建发生在「写完之后」，而不是「访问的时候」。** 访客拿到的是已经渲染好的 HTML，所以首屏快、可被搜索引擎收录、也不需要担心服务器被拖垮。

## 三、每个节点在做什么

### 1. `content/` —— 唯一真源

整个站点只有这里是你需要长期维护的。设计上的三个决定：

- **真源是本地 Markdown，不是数据库。** 网站只是它的一个渲染产物，哪天想换生成器，内容一行都不用改。
- **frontmatter 是元数据的入口。** 标题、描述、标签、日期都写在这里：

  ```yaml
  ---
  title: 一句话判断，不是名词
  description: 会出现在链接预览和搜索结果里
  tags: [programming, type/note, status/seedling]
  date: 2026-11-17
  ---
  ```

  这些字段直接决定了几件事：链接显示什么文字、出现在哪个标签页、反向链接的锚文本、搜索结果的摘要。
- **`templates/` 被排除在构建之外。** 配置里的 `ignorePatterns` 让它只存在于本地，不会出现在线上。

### 2. `quartz.config.yaml` —— 站点行为的开关

一个文件管三件事，分工很清晰：

| 区块 | 管什么 | 典型改动 |
| --- | --- | --- |
| `configuration` | 全局行为 | 站名、语言、颜色、链接解析方式、`baseUrl` |
| `plugins` | 内容处理流水线 | 代码高亮、公式、目录、评论、搜索 |
| `layout` | 组件放在哪 | 侧栏、搜索框、返回顶部、阅读模式 |

> [!warning] `baseUrl` 是最容易忽略的一项
> 它只影响 sitemap、RSS 这类需要绝对地址的地方，但如果它是错的，搜索引擎收录的链接就会指向一个不存在的地址。部署到 `用户名.github.io/仓库名` 时，必须写成 `用户名.github.io/仓库名`，**不带 `https://`，不带结尾斜杠**。

### 3. `quartz/styles/custom.scss` —— 只覆盖，不修改

原则：不动 Quartz 内核，只在自己的文件里覆盖。这样做的好处是升级 Quartz 时不会产生冲突。

字体就是一个例子。默认配置从 Google Fonts 加载字体，国内访问会卡在字体上（页面能出来，但要等几秒才「换脸」）。改成系统字体栈后，零网络请求、瞬间渲染：

```scss
:root:root {
  --bodyFont: "Noto Sans SC", -apple-system, "PingFang SC",
    "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
}
```

用 `:root:root` 而不是 `:root`，是为了靠特异性压过框架自己注入的变量，不依赖 CSS 加载顺序——这种细节在别人的主题上尤其重要。

### 4. 构建：`npx quartz build`

这条命令内部是三段流水线，理解它，出问题时才知道该看哪里。

1. **解析（Parse）**：把每个 `.md` 拆成 frontmatter 和正文，生成 AST。
2. **转换（Transform）**：一串插件依次处理 AST——把 `[[双链]]` 变成带标题的 `<a>`、跑代码高亮、渲染 callout 和数学公式、生成目录、算出每篇的日期。
3. **输出（Emit）**：写出 HTML 页面、标签页、文件夹页、`sitemap.xml`、`contentIndex.json`（搜索和关系图都靠它）。

产物全在 `public/`。**搜索是纯前端的**：浏览器下载 `contentIndex.json`，在本地做匹配，没有后端查询。

### 5. 部署：GitHub Pages 的两种模式

这部分最容易混淆，因为两种模式长得像，机制完全不同。

| 模式 | 构建在哪跑 | 产物怎么到线上 | 特点 |
| --- | --- | --- | --- |
| 从分支发布 | 你的电脑 | 把 `public/` 推到 `gh-pages` 分支 | 简单，但要求本地能构建 |
| GitHub Actions | GitHub 的机器 | 构建产物作为 artifact 直接部署 | 可复现，不依赖本地环境 |

Actions 模式更适合长期维护：换台电脑、甚至只用网页编辑器改一行笔记，也能触发一次完整构建。代价是首次配置要多走一步——把 Pages 的 Source 从「分支」改成「GitHub Actions」。

### 6. `.github/workflows/deploy.yml` —— 自动化

结构就三个 job：`build`（装依赖、构建、上传产物）、`deploy`（部署到 Pages），以及触发条件（push 到 main）。

两个细节值得注意：

- **`permissions` 必须显式声明 `pages: write` 和 `id-token: write`**。这是 OIDC 部署的前提，少了这两行，部署会以权限错误失败。
- **`fetch-depth: 0` 不能省。** Quartz 会把 git 提交时间当作笔记的「最后修改时间」，浅克隆拿不到历史，日期就会全部变成构建时间。

### 7. `.github/dependabot.yml` —— 依赖更新

只配了 `github-actions` 一个生态：每周检查 workflow 里 `uses: actions/xxx@vN` 的版本，有新版本就提 PR。

**npm 依赖故意不交给它。** Quartz 的依赖和配套插件是强耦合的，必须一起升级；让机器人逐个包提 PR，很容易出现「`npm ci` 通过但插件在运行时崩掉」。这类升级应该走 `npx quartz upgrade`。

## 四、可复现的步骤

```bash
# 1. 拿到源码
git clone https://github.com/jackyzha0/quartz.git my-notes
cd my-notes

# 2. 安装依赖、初始化（交互式）
npm install
npx quartz create

# 3. 本地预览：改 content/ 会自动重建
npx quartz build --serve      # http://localhost:8080

# 4. 接上自己的仓库
git remote add origin https://github.com/<用户名>/<仓库名>.git
git push -u origin main

# 5. 仓库 Settings → Pages → Source 选 GitHub Actions

# 6. 之后的日常
git add -A && git commit -m "更新笔记" && git push
```

## 五、踩过的六个坑

这些坑的共同点：**报错信息说的不是真正的原因。** 记录下来，下次遇到能少花半小时。

### 坑 1：`npx` 报 EPERM，说缓存目录有 root 文件

```
npm error Your cache folder contains root-owned files
```

**原因**：以前用 `sudo npm install` 留下的缓存文件，属主是 root。
**解法**：`sudo chown -R $(id -u):$(id -g) ~/.npm`。
**教训**：永远别用 `sudo` 跑 npm。

### 坑 2：推送被拒，`refusing to allow an OAuth App to create or update workflow`

**原因**：workflow 文件能执行任意代码、能读取仓库 secrets，所以 OAuth App 默认不许写它，必须单独授予 `workflow` 权限。
**解法**：`gh auth refresh -s workflow`，或建一个带 `workflow` 的 PAT。
**教训**：这不是配置错误，是安全模型的一部分，别想着绕过。

### 坑 3：浅克隆之后推送失败，`remote unpack failed: index-pack failed`

**原因**：`git clone --depth 1` 只拿到一个截断的历史，推到新仓库时对方要求完整的对象图。
**解法**：`git fetch --unshallow` 补全历史再推。

### 坑 4：Dependabot 每周报红叉，`/action.yml or /.github/workflows/<anything>.yml not found`

**原因**：为了绕过权限限制，把 workflow 挪出了 `.github/workflows/`，结果 `github-actions` 生态扫描时一个文件都找不到。
**解法**：workflow 归位。**教训**：工具的限制往往有连锁反应，移动文件前先想清楚它被谁扫描。

### 坑 5：RSS 里混进一堆 `tags/xxx`，内容为空

**原因**：生成的标签页也进了内容索引，按日期排序后反而排在前面。
**解法**：关掉 RSS，保留 sitemap（搜索引擎主要看后者）。等上游修复再开。

### 坑 6：Google Fonts 在国内拖慢首屏

**原因**：字体阻塞渲染，`font-display: swap` 只能缓解换脸闪烁。
**解法**：换系统字体栈，或者用 `fontOrigin: selfHosted` 在构建时下载字体自托管。

## 六、凭据：token 过期了怎么续

这一节单独讲，因为「token 会不会过期」是最容易被忽略的事。先把三种凭据分清，很多困惑来自把它们混为一谈：

| 凭据 | 谁在用 | 会不会过期 | 过期影响谁 |
| --- | --- | --- | --- |
| `GITHUB_TOKEN` | Actions 运行时自动注入 | 每次运行重新生成 | 无影响 |
| gh OAuth token（`gho_`） | `gh` 命令、`git push` | 长期有效，除非被撤销 | 只有你本机 |
| 个人访问令牌 PAT（`ghp_` / `github_pat_`） | 代替上一种使用 | **有有效期**（默认 30 天） | 只有你本机 |

**关键结论：token 过期只影响你本地推送，线上站点完全不受影响。** Actions 用的是 GitHub 自动注入的 `GITHUB_TOKEN`，和你那把 PAT 没有任何关系——这也是为什么把构建放在 CI 里更省心：凭据的生命周期和你的本地环境解耦了。

### 到期时的症状

```text
remote: Invalid username or password.
fatal: Authentication failed for 'https://github.com/xxx/yyy.git'
```

或者 `gh` 命令直接返回 `401 Bad credentials`。注意 GitHub 会在 classic token 到期前几天发邮件提醒，别把那个邮件当广告删了。

### 续期的三步

```bash
# 1. 新建 token：Settings → Developer settings → Tokens
#    勾选 repo、workflow、read:org（缺 read:org 会导致 gh auth login 直接拒绝）

# 2. 换掉本地凭据（粘贴时不会回显，也不会进 shell 历史）
read -rs GH_TOKEN && printf '%s\n' "$GH_TOKEN" | gh auth login --with-token

# 3. 验证
gh auth status      # 三个 scope 都要在，Token 前缀应为 ghp_ 或 github_pat_
```

### 更省事的做法：别用 PAT

`gh auth login` 走浏览器设备流，拿到的是 `gho_` 开头的 OAuth token，**长期有效**，不用每 30 天换一次。PAT 只在两种情况下才值得用：需要精确控制权限范围，或者机器上开不了浏览器。

### 三条纪律

- token 不进仓库、不进截图、不进聊天记录——一旦泄露就当作已泄露，立刻吊销重建
- token 不进 workflow secrets。Actions 自带 `GITHUB_TOKEN`，把个人 PAT 塞进去只会扩大攻击面
- 定期检查 https://github.com/settings/tokens ，删掉不再使用的

## 七、这套方案的边界

静态站很适合「长期积累、低频更新、需要被检索」的知识库，但有几件事它做不了：

- **协作编辑**：没有实时同步，多人要改同一个文件只能靠 git 分支。
- **动态数据**：评论、点赞、访问统计要么接第三方服务，要么放弃。
- **全文语义检索**：内置搜索是关键词匹配，不是向量检索。真需要「按意思找」，得另外加一层 RAG。

这也解释了为什么「LLM Wiki」和「RAG」在讨论里总和静态站一起出现：前者改变的是**知识在什么时机被整理**（写的时候 vs 查的时候），后者改变的是**检索方式**。它们和「用哪个生成器」是正交的两件事——本站现在只是把「写的时候」这部分交给了自己，辅助整理留到以后。

## 八、小结

回头看，整个方案的复杂度分布很不平均：

- **构建期**：一堆插件、链接解析、索引生成，最复杂，但只需要理解一次。
- **发布期**：一条命令或一次 push，简单到无聊。
- **运行期**：零。没有服务器，没有数据库，没有要盯的进程。

这正是静态站点值钱的地方：**把复杂度一次性锁进构建流程里，之后每次发布都是免费的。**
