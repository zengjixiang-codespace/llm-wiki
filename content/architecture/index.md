---
title: 架构
description: 设计原则、模式与取舍。
tags:
  - architecture
  - type/moc
---

记录原则和模式，但更重要的是**记下当时为什么这么选**。

## 原则

- [[dependency-inversion|依赖倒置原则]]

## 模式

- [[cache-aside|缓存旁路（Cache-Aside）]]

## 想清楚但还没写

- [ ] 什么时候不该拆微服务
- [ ] 「高内聚低耦合」这句话到底在说什么
- [ ] 防腐层与 DTO 的边界

## 跨领域

- 缓存相关的实现细节在 [[redis-expiry|中间件]]
- 接口设计的语言层表现见 [[go-interface|Go 的接口是隐式实现]]
