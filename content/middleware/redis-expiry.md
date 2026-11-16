---
title: Redis 过期与淘汰
description: 过期删除是惰性 + 定期采样，淘汰是内存压力下的另一套机制——两者经常被混为一谈。
tags:
  - middleware
  - middleware/redis
  - type/note
  - status/growing
date: 2026-11-16
---

有两套完全不同的机制，名字很像，作用却不一样：

| 机制 | 触发条件 | 作用 |
| --- | --- | --- |
| 过期删除 | key 的 TTL 到了 | 清掉逻辑上已经过期的 key |
| 内存淘汰 | `used_memory` 超过 `maxmemory` | 腾出内存给新写入 |

## 过期删除：惰性 + 定期

Redis 不会为每个 key 起一个定时器。

1. **惰性删除**：访问 key 时才检查是否过期，过期就删掉并返回空。
2. **定期删除**：每秒若干次，随机抽一批设置了 TTL 的 key，删掉其中过期的。

> [!warning] 过期不等于立刻消失
> 如果一个 key 过期后再也没人访问，它可能长期占着内存，直到被定期删除扫到，或者触发内存淘汰。所以 `dbsize` 和实际内存占用对不上是正常现象。

## 内存淘汰：八种策略

`maxmemory-policy` 决定超限时删谁，粗略分三组：

- **不淘汰**：`noeviction`，写入直接报错（默认值，很多线上事故的源头）
- **全体 key 里挑**：`allkeys-lru` / `allkeys-lfu` / `allkeys-random`
- **只在设了 TTL 的 key 里挑**：`volatile-lru` / `volatile-lfu` / `volatile-random` / `volatile-ttl`

选 `volatile-*` 时要注意：如果没有 key 设 TTL，行为会退化成 `noeviction`。

## 和缓存模式的关系

在 [[cache-aside|缓存旁路]] 里，「写后删除缓存」这个动作依赖 Redis 的删除是可靠的。但网络超时、主从延迟都会让删除失败或滞后——所以缓存侧通常还要配 TTL 兜底，不能假设删除一定成功。

## 相关

- [[middleware/index|中间件]]
- [[cache-aside|缓存旁路]]
