---
title: 第 00 课 · 环境、连通性与观测
description: 用你自己的服务器把服务跑起来：配好连接、写一个自检接口、学会读懂三类连接错误，并会用 INFO/MONITOR/CLIENT LIST 观测。
tags:
  - programming
  - programming/redis
  - type/note
  - status/growing
date: 2026-11-19
---

> 这一课你不需要懂 Redis 命令，只需要让「你的服务 ↔ 你的 Redis」这条路通，
> 并且学会在被骗的时候（看起来启动成功，其实连不上）识破它。

---

## 本课目标

学完你应该能回答：

1. 服务连不上 Redis 时，怎么在 30 秒内区分是**网络**、**认证**还是**配置**问题？
2. `INFO` 里哪 5 个字段足以判断「这个实例现在健康吗」？
3. 为什么 Spring Boot 应用启动成功，不代表 Redis 能连上？

---

## 你会建成什么

```text
redis-practice/
├── pom.xml
└── src/main/
    ├── java/com/example/redispractice/
    │   ├── RedisPracticeApplication.java
    │   └── health/HealthController.java
    └── resources/application.yml
```

一个能启动、能自检、连不上时会把原因说清楚的服务骨架。后面的课都长在这上面。

---

## 0.1 先在服务器上确认 Redis

不要一上来就写代码。先在服务器上把「Redis 本身是好的」这件事钉死。

```bash
# 1. 从服务器本机连
redis-cli -h 127.0.0.1 -p 6379 ping
# 期望：PONG

# 2. 有没有密码
redis-cli -h 127.0.0.1 -p 6379 config get requirepass

# 3. 绑了哪个地址、保护模式开没开
redis-cli -h 127.0.0.1 -p 6379 config get bind
redis-cli -h 127.0.0.1 -p 6379 config get protected-mode
```

三种结果的解读：

| 现象 | 含义 | 下一步 |
| --- | --- | --- |
| `PONG` | 本机通、无密码 | 从你电脑 `telnet host 6379` 试外网可达性 |
| `(error) NOAUTH Authentication required` | 有密码 | 用 `-a 密码` 重试，记下密码给配置文件 |
| `Could not connect` | 服务没起或端口不对 | `ss -lntp \| grep 6379` 看监听 |

再确认几个会影响后面实验的设置：

```bash
redis-cli -h 127.0.0.1 -p 6379 info server   | grep -E "redis_version|redis_mode|uptime_in_days"
redis-cli -h 127.0.0.1 -p 6379 info clients  | grep connected_clients
redis-cli -h 127.0.0.1 -p 6379 info memory   | grep -E "used_memory_human|maxmemory_human"
redis-cli -h 127.0.0.1 -p 6379 dbsize
```

> [!warning] 公网暴露的风险
> 如果 Redis 直接监听 `0.0.0.0:6379` 且没有密码，任何人扫到都能拿走你的数据。
> 本课程推荐两条路：**只绑内网 IP + 安全组放行你的出口 IP**，或者**不开公网，走 SSH 隧道**：
> `ssh -L 6379:127.0.0.1:6379 你的服务器`，然后本机连 `127.0.0.1:6379`。

### 本步证据

把下面这张表填好，后面所有实验都基于它：

| 项 | 值 |
| --- | --- |
| 版本 / 模式 | 例：7.2.4 / standalone |
| 访问方式 | 直连 host:port 还是 SSH 隧道 |
| 是否设密码 | 是/否 |
| maxmemory | 例：512mb，淘汰策略 allkeys-lru |

---

## 0.2 创建工程

用 [start.spring.io](https://start.spring.io) 生成，或直接手写。依赖只选两个：

- **Spring Web**
- **Spring Data Redis (Access+Driver)**

等价的最小 `pom.xml`：

```xml
<parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>3.3.5</version>
</parent>

<properties>
  <java.version>17</java.version>
</properties>

<dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
  </dependency>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
  </dependency>
  <!-- Lettuce 连接池需要它；第 12 课才调参，现在放着不影响 -->
  <dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-pool2</artifactId>
  </dependency>
</dependencies>
```

启动类：

```java
package com.example.redispractice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class RedisPracticeApplication {
    public static void main(String[] args) {
        SpringApplication.run(RedisPracticeApplication.class, args);
    }
}
```

---

## 0.3 配置连接

`src/main/resources/application.yml`：

```yaml
server:
  port: 8080

spring:
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}
      database: ${REDIS_DB:0}
      timeout: 2s            # 命令超时
      connect-timeout: 2s    # 建连超时，和上面是两回事
      lettuce:
        pool:
          max-active: 16
          max-idle: 8
          min-idle: 1
          max-wait: 1s
```

**为什么用环境变量而不是写死**：密码进了 git 历史就再也删不干净了。
本机开发时在启动配置里加环境变量，或者用一个不提交的 `run.local.sh`：

```bash
export REDIS_HOST=你的服务器
export REDIS_PORT=6379
export REDIS_PASSWORD='你的密码'
export REDIS_DB=0
mvn spring-boot:run
```

> [!note] 两个超时别混
> `timeout` 是「一条命令最多等多久」，`connect-timeout` 是「建立 TCP 连接最多等多久」。
> 只配前者时，网络不通的表现是线程卡很久而不是快速失败。

---

## 0.4 写第一个端点：`/health`

这个接口是本课程的「仪表盘」，后面每课开头都用它确认环境。

```java
package com.example.redispractice.health;

import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;

@RestController
public class HealthController {

    private final StringRedisTemplate redis;

    public HealthController(StringRedisTemplate redis) {
        this.redis = redis;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> out = new LinkedHashMap<>();
        long start = System.currentTimeMillis();
        try {
            String pong = redis.execute((RedisCallback<String>) RedisConnection::ping);
            Properties info = redis.execute(
                    (RedisCallback<Properties>) c -> c.serverCommands().info("server"));
            out.put("redis", "UP");
            out.put("ping", pong);
            out.put("version", info == null ? "?" : info.getProperty("redis_version"));
            out.put("mode", info == null ? "?" : info.getProperty("redis_mode"));
        } catch (Exception e) {
            // 关键：连不上不抛 500，把错误类型和消息暴露出来
            out.put("redis", "DOWN");
            out.put("error", e.getClass().getSimpleName() + ": " + e.getMessage());
            out.put("hint", "检查 REDIS_HOST / REDIS_PORT / REDIS_PASSWORD");
        }
        out.put("latencyMs", System.currentTimeMillis() - start);
        return out;
    }
}
```

三个设计决定，你要理解而不是照抄：

1. **用 `try/catch` 包住而不是让异常冒泡**：连不上时你想看到的是「什么原因」，不是 500 页面
2. **返回 `latencyMs`**：本机连本地是 0–1ms，跨公网 20–60ms，超过 100ms 就该警惕
3. **`info("server")` 而不是 `info()`**：全量 INFO 输出几百行，只看需要的段

---

## 0.5 验证：三处都要对得上

```bash
# 1. 接口视角
curl -s localhost:8080/health | python3 -m json.tool
# {"redis":"UP","ping":"PONG","version":"7.2.4","mode":"standalone","latencyMs":3}

# 2. 服务端视角：确实有一条新连接
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD client list | grep -c "cmd=ping"
# 期望 >= 1
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD info clients | grep connected_clients

# 3. 命令视角：用 MONITOR 看你的请求到底发了什么
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD monitor
# 另开终端再 curl 一次，应看到 PING / INFO 命令
```

`MONITOR` 这一步非常重要：从第 1 课起，你写的每一行 Java 都要能在 `MONITOR` 里找到对应的 Redis 命令。
**对不上，就说明你还没真正理解这行代码。**

> [!tip] MONITOR 用完马上 Ctrl+C
> 它会把整台实例的命令都打印出来，生产环境长期开着既慢又泄漏数据。

---

## 0.6 故意制造三个故障，学会读报错

这一步别跳过——线上排障能力就是在这里建立的。

**故障 A：端口写错**

```bash
export REDIS_PORT=6399 && mvn spring-boot:run
```

预期：应用**照常启动**，`/health` 返回 `DOWN`，错误类似
`RedisConnectionFailureException: Unable to connect to Redis`。

要记住的结论：**Spring Boot 启动成功 ≠ Redis 能连上**，Lettuce 是懒连接。

**故障 B：密码写错**

```bash
export REDIS_PASSWORD=wrong-password && mvn spring-boot:run
```

预期：`NOAUTH` / `WRONGPASS` / `invalid password`。
这类错误**不会**在启动时出现，只在第一次真正发命令时出现。

**故障 C：网络不通（安全组/防火墙）**

把 host 改成一个不可达的内网 IP，预期是连接超时：

```text
RedisConnectionFailureException: Unable to connect to Redis
```

对比 A 和 C 的耗时：A 通常毫秒级失败，C 会等满 `connect-timeout`。
**耗时本身就是线索。**

---

## 检查点

- [ ] `/health` 返回 `redis: UP`，含 `version`、`mode`、`latencyMs`
- [ ] `CLIENT LIST` 里能看到你的应用建立的连接
- [ ] `MONITOR` 里能看到 `PING` 与 `INFO`
- [ ] 三个故障各制造一次，能说出三条报错的区别
- [ ] 在自己的笔记里记下：版本、访问方式、是否密码、`maxmemory`

---

## 常见坑

1. **只配了 `timeout` 没配 `connect-timeout`**：网络不通时要等很久才失败，误以为是「卡死」
2. **`protected-mode yes` + `bind` 只写了内网**：从外网看就是「连接被拒绝」，很容易误判成服务没起
3. **密码里有特殊字符**：`-a` 后要加引号，配置文件里也要转义，否则报 `WRONGPASS`
4. **用 `redis-cli -a` 会有明文警告**（`Warning: Using a password with '-a' ...`），生产建议 `--askpass`
5. **把 6379 直接暴露公网**：这是真实事故的高发点，能用隧道就用隧道
6. **以为 `spring.data.redis.database` 是命名空间**：它只是 db 编号，Cluster 下只有 db0
7. **`INFO` 里的 `connected_clients` 包含空闲连接**：连接池 `min-idle` 会让它常年不为 0

---

## Go 对照

同样的自检，用 `go-redis` 是这样的（第 02 课之后会逐步补全 Go 版工程）：

```go
rdb := redis.NewClient(&redis.Options{
    Addr:         host + ":" + port,
    Password:     pass,
    DB:           0,
    DialTimeout:  2 * time.Second,
    ReadTimeout:  2 * time.Second,
    WriteTimeout: 2 * time.Second,
})

ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()
pong, err := rdb.Ping(ctx).Result()
```

差异值得注意：Go 客户端**默认连接池是显式的**（`PoolSize`），而 Lettuce 默认共享单连接 + 可选池。
这也解释了为什么第 0.5 步里 `CLIENT LIST` 只看到一两条连接。

---

## 本课产出

- 一个能自检的服务骨架（`/health`）
- 一份环境证据表（版本、模式、访问方式、maxmemory）
- 三条错误报错的对照记忆

## 下一课

[[ch01-data-structures|第 1 课 · 数据结构与命令]]：把七种结构逐个用在真实场景上，并定下全项目的 key 规范。
