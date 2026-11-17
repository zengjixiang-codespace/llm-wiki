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
---
```

## 正文结构建议

1. **一句话结论**（读者只看这句也能拿走点什么）
2. **展开**：机制、例子、代码
3. **代价 / 反例**：什么情况下不成立
4. **相关**：`[[链接]]` 到相邻笔记
