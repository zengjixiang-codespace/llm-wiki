---
title: 关于
description: 关于这个站，以及它是怎么搭起来的。
aliases:
  - about-site
comments: false
---

这是我的个人知识库，用来记录长期学习中的笔记、调试记录和阶段性结论。

## 写作原则

- **一篇只讲一件事**：标题尽量写成一句判断，而不是一个名词。
- **先记理由，再记结论**：半年后你只记得结论，会不记得为什么。
- **不确定就标注不确定**：用 `status/seedling` 标明「还没想清楚」，比伪装成定论好。
- **能链接就链接**：孤立的笔记三个月后就会变成垃圾。

## 技术栈

| 部分 | 用什么 |
| --- | --- |
| 内容 | Markdown + YAML frontmatter |
| 站点生成 | [Quartz](https://quartz.jzhao.xyz/) |
| 部署 | GitHub Pages（push 自动构建） |
| 搜索 | 内置全文搜索，纯静态、无后端 |

站点是纯静态的，没有数据库也没有后台。所有内容都在仓库的 `content/` 目录里，改完 push 就会重新发布。

搭建的完整过程——包括每个节点的作用、以及踩过的坑——写在 [[build-a-personal-wiki|从零搭一个个人知识库]] 里。

## 标签约定

- 领域：`programming` / `music` / `food` / `feeling`
- 类型：`type/note`、`type/log`、`type/cheatsheet`、`type/moc`
- 状态：`status/seedling`（幼苗）→ `status/growing`（生长中）→ `status/stable`（稳定）

每篇笔记顶部都会显示它的标签，点任意一个就能看到同类笔记的集合。

## 联系

有问题或建议，可以在 [GitHub](https://github.com/zengjixiang-codespace) 上找我。
