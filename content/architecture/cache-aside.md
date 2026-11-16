---
title: 缓存旁路（Cache-Aside）
description: 应用自己读写缓存和数据库，缓存不参与写路径——最常用也最容易写错的缓存模式。
tags:
  - architecture
  - architecture/patterns
  - type/note
  - status/growing
date: 2026-11-16
---

应用代码负责两件事：读的时候先查缓存，未命中再查数据库并回填；写的时候先写数据库，再让缓存失效。

```text
读：  cache ──miss──> db ──写入──> cache ──> 返回
写：  db ──写入──> cache.delete(key)
```

## 为什么是「删除缓存」而不是「更新缓存」

> [!warning] 更新缓存是最常见的错误
> 并发写时两次更新的落库顺序和写缓存顺序不一致，缓存里就会留下旧值。删除只会导致一次未命中，不会导致脏数据。

## 三个经典问题

| 问题 | 现象 | 常见解法 |
| --- | --- | --- |
| 缓存穿透 | 查不存在的数据，请求全打到库 | 空值缓存 / 布隆过滤器 |
| 缓存击穿 | 热点 key 过期瞬间大量并发回源 | 单飞（singleflight）/ 逻辑过期 |
| 缓存雪崩 | 大批 key 同时过期 | 过期时间加随机抖动 |

## 和实现细节的关系

「删除缓存失败怎么办」「过期是怎么被清掉的」这类问题属于具体中间件行为，记在 [[redis-expiry|Redis 过期与淘汰]]。

## 相关

- [[architecture/index|架构]]
- [[dependency-inversion|依赖倒置原则]]
