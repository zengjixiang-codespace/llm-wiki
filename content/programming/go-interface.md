---
title: Go 的接口是隐式实现
description: Go 不需要 implements 关键字，这既是解耦的利器，也是"这个类型实现了哪些接口"变得难以回答的原因。
tags:
  - programming
  - programming/go
  - type/note
  - status/seedling
date: 2026-11-16
---

Go 的接口只描述「方法集合」，不要求实现者声明。任何类型只要方法签名对得上，就自动满足该接口——没有 `implements`，没有注册，也没有继承树。

```go
type Reader interface {
	Read(p []byte) (n int, err error)
}

// *bytes.Buffer 从未提到 Reader，但它就是 Reader
var r io.Reader = bytes.NewBufferString("hello")
```

## 好在哪

- **使用者定义接口，实现者毫不知情**。`net/http` 定义了 `http.Handler`，你的业务代码不需要 import 任何框架包就能被调用。这是依赖倒置在语言层面的直接体现。
- **接口可以小到只有一两个方法**。`io.Reader` / `io.Writer` 能拼出整个标准库的 I/O 抽象，因为小接口的组合空间大。
- **测试替身成本极低**。不需要 mock 框架，写个结构体实现两个方法就行。

## 代价是什么

> [!warning] 隐式实现的三个坑
> 1. **看类型定义看不出它实现了什么接口**，只能靠 `gopls` 的 "implementations" 或 `go doc`。
> 2. **方法名撞车**：两个无关接口都有 `Close() error`，一个类型同时满足两者，可能不是你想要的语义。
> 3. **接口污染**：为了「将来可能扩展」提前抽接口，反而让调用链变长。

## 一个判断标准

接口应该定义在**使用方**，而不是实现方。如果你在实现包里定义接口再导出，那多半是照 Java 的习惯写的。

## 相关

- [[programming/index|编程语言]]
