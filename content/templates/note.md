---
title: 笔记模板
description: 新笔记直接复制这个头部。
tags:
  - templates
---

> [!note] 这个文件不会发布
> `templates` 在 `quartz.config.yaml` 的 `ignorePatterns` 里，这里的内容只在本地可见。

复制下面的 frontmatter：

```yaml
---
title: 一句话判断，不是名词
description: 一句话说明这篇解决什么问题，会出现在链接预览里。
tags:
  - programming        # 领域：programming / music / food / feeling
  - type/note          # 类型：note / log / cheatsheet / moc / topic
  - status/seedling    # 状态：seedling / growing / stable
date: 2026-11-16
# comments: false      # 取消注释 = 关掉这篇的评论区
---
```

## 可选字段

| 字段 | 作用 | 默认 |
| --- | --- | --- |
| `comments: false` | 关掉这一页的评论区 | 笔记页开；首页、文件夹页、标签页本来就是关的 |
| `unlisted: true` | 页面照常发布、能直接访问，但不出现在侧栏树、搜索、关系图和反向链接里 | 否 |
| `draft: true` | 完全不发布，构建时直接丢弃 | 否 |
| `aliases` | 旧地址重定向，改文件名或改 URL 后旧链接不失效 | 无 |

> [!tip] 什么时候用什么
> 写了一半不想让人看 → `draft: true`；
> 写完了但只想留个链接给自己 → `unlisted: true`；
> 只是不想被评论打扰 → `comments: false`。

## 图片放哪儿

图片放在**与笔记同名的文件夹**里，和笔记并排：

```text
music/
├── practice-plan.md
└── practice-plan/
    ├── practice-flow.webp
    └── another-image.png
```

正文里这样引用：

```md
![[practice-plan/practice-flow.webp|图片说明文字]]
```

好处很实际：删掉笔记时，整个同名文件夹一起删，不会在附件目录里留下一堆孤儿图片；以后回头找某张图的出处，看目录名就知道它属于哪篇。

> [!tip] 命名建议
> 图片文件名别用 `1.png`、`截图.png` 这种，用「这篇笔记里它是什么」来命名，比如 `practice-flow.webp`、`fretboard-scales.webp`。半年后搜文件名能直接找到。

## 正文结构建议

1. **一句话结论**（读者只看这句也能拿走点什么）
2. **展开**：机制、例子、代码
3. **代价 / 反例**：什么情况下不成立
4. **相关**：`[[链接]]` 到相邻笔记
