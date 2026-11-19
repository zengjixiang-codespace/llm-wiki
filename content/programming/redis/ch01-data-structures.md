---
title: 第 01 课 · 数据结构与命令
description: 把七种结构逐个落到真实需求上：短链计数、商铺对象、待处理队列、关注关系、热门榜、签到与 UV，并定下全项目的 key 规范。
tags:
  - programming
  - programming/redis
  - type/note
  - status/growing
date: 2026-11-19
---

> 这一课的核心不是背命令，而是建立一条判断链：
> **业务需求 → 能不能用 Redis 建模 → 选哪种结构 → 代价是什么。**
> 每写完一段代码，都要能在 `MONITOR` 里看到对应的命令、在 `redis-cli` 里看到对应的数据。

---

## 本课目标

1. 对任意一个 `lab:*` key，能说出它的**类型、编码、TTL**
2. 能回答「同一个对象，什么时候用 String 存 JSON，什么时候必须用 Hash」
3. 能解释为什么排行榜必须是 ZSet、签到为什么适合 Bitmap、UV 为什么能用 HLL
4. 完成全项目的 key 命名规范（`Keys` 类），后面每一课都复用它

**前置**：[[ch00-setup|第 0 课]] 的 `/health` 已经是 `UP`。

---

## 你会建成什么

```text
redis-practice/src/main/java/com/example/redispractice/
├── common/Keys.java              全项目唯一 key 入口
└── lesson01/
    ├── ShortlinkDemoController   ① String：映射 + 计数
    ├── ShopDemoController        ② Hash：对象
    ├── QueueDemoController       ③ List：队列
    ├── FollowDemoController      ④ Set：关系
    ├── RankDemoController        ⑤ ZSet：榜
    └── SignUvDemoController      ⑥ Bitmap/HLL：签到与 UV
```

六个 Controller 都用 `StringRedisTemplate`，**先不碰序列化**（第 02 课专门讲为什么）。

---

## 1.0 先定 key 规范

命名不是风格问题，是运维问题：你要能用一个前缀扫出、删掉、统计自己的全部数据。

规则三条：

1. **一律 `lab:` 开头**（实验专用；换成生产也能一眼看出这是谁的数据）
2. **冒号分层**：`lab:{业务}:{对象}:{标识}`，标识放最后，方便 `SCAN lab:shop:*`
3. **不在业务代码里手拼字符串**，全部走一个 `Keys` 类

```java
package com.example.redispractice.common;

import java.time.LocalDate;
import java.time.YearMonth;

public final class Keys {

    private static final String NS = "lab";

    private Keys() {
    }

    // 短链
    public static String shortlink(String code) {
        return NS + ":shortlink:code:" + code;
    }

    public static String shortlinkVisits(String code) {
        return NS + ":shortlink:visits:" + code;
    }

    public static String shortlinkHot() {
        return NS + ":shortlink:hot";
    }

    // 商铺对象
    public static String shop(long shopId) {
        return NS + ":shop:" + shopId;
    }

    // 待处理队列
    public static String orderQueue() {
        return NS + ":queue:order";
    }

    // 关注关系（双向）
    public static String following(long userId) {
        return NS + ":follow:following:" + userId;
    }

    public static String followers(long userId) {
        return NS + ":follow:followers:" + userId;
    }

    // 签到 bitmap：按用户 + 年月
    public static String sign(long userId, YearMonth month) {
        return NS + ":sign:" + userId + ":" + month;
    }

    // UV 统计
    public static String uv(String scene, LocalDate date) {
        return NS + ":uv:" + scene + ":" + date;
    }

    // 本课临时实验用
    public static String demo(String name) {
        return NS + ":demo:" + name;
    }
}
```

> [!note] 为什么 `sign` 要带年月
> 一个 bitmap 最多放 31 天。跨月如果不换 key，31 号之后要重新算 offset，迟早算错。

---

## 1.1 通用命令：先学会看，再学会写

任何 key 拿过来，先问三件事：**是什么类型、还剩多久、底层怎么存**。

```text
TYPE    lab:shop:1            → hash
TTL     lab:shop:1            → -1（永不过期）/ -2（不存在）/ 剩余秒数
OBJECT ENCODING lab:shop:1    → listpack 或 hashtable
MEMORY USAGE lab:shop:1       → 估算占用字节
```

然后是遍历。**永远不要用 `KEYS`**，它会把整台实例卡住；用 `SCAN`：

```text
SCAN 0 MATCH lab:shop:* COUNT 200
# 返回：下一个游标 + 一批 key，游标回到 0 才算遍历完
```

写一个查询接口，把「看」这件事变成你的工具：

```java
@GetMapping("/lesson01/keys")
public Map<String, Object> keys(@RequestParam(defaultValue = "lab:*") String pattern) {
    Set<String> found = new LinkedHashSet<>();
    ScanOptions options = ScanOptions.scanOptions().match(pattern).count(200).build();
    try (Cursor<String> cursor = redis.scan(options)) {
        while (cursor.hasNext()) {
            found.add(cursor.next());
        }
    }
    List<Map<String, Object>> rows = found.stream().map(k -> Map.of(
            "key", k,
            "type", redis.type(k),
            "ttl", redis.getExpire(k, TimeUnit.SECONDS)
    )).toList();
    return Map.of("pattern", pattern, "count", rows.size(), "keys", rows);
}
```

### 检查点 1

- 随便造几个 key 后调这个接口，能同时看到 `type` 和 `ttl`
- 能解释 `TTL = -1` 和 `TTL = -2` 在业务上分别意味着什么

---

## 1.2 String：短链的映射与计数

**业务需求**：把一个长 URL 变成一个短码，访问短链时跳转，并统计每个短链被访问了多少次、哪些最热。

**为什么选 String**：一个短码 → 一个 URL，是典型的 `key → value` 一对一；计数用 `INCR` 是 Redis 里最便宜的原子操作。

```text
SET  lab:shortlink:code:abc123  https://example.com/some/very/long/path EX 2592000
GET  lab:shortlink:code:abc123
INCR lab:shortlink:visits:abc123
```

```java
@PostMapping("/lesson01/shortlink")
public Map<String, Object> create(@RequestParam String code, @RequestParam String url) {
    redis.opsForValue().set(Keys.shortlink(code), url, Duration.ofDays(30));
    return Map.of("code", code, "url", url, "ttl", redis.getExpire(Keys.shortlink(code), TimeUnit.SECONDS));
}

@GetMapping("/lesson01/shortlink/{code}")
public Map<String, Object> visit(@PathVariable String code) {
    String url = redis.opsForValue().get(Keys.shortlink(code));
    if (url == null) {
        return Map.of("code", code, "found", false);
    }
    long visits = redis.opsForValue().increment(Keys.shortlinkVisits(code));
    return Map.of("code", code, "url", url, "visits", visits);
}
```

**还要会两种情况**：

```text
# 只允许创建一次（防覆盖）
SET lab:shortlink:code:abc123 https://... NX EX 2592000

# 验证码 / 临时凭证：写的同时带过期，两个动作原子完成
SET lab:otp:13800000000 483920 EX 60
```

### 检查点 2

- `MONITOR` 里能看到 `SET`、`GET`、`INCR`
- `TTL` 随访问次数增长**不变**（INCR 不影响 TTL，这点很重要）
- 用 `SET ... NX` 重复创建同一个 code，第二次返回什么？（`nil`）

---

## 1.3 Hash：商铺对象

**业务需求**：商铺有 id、名称、城市、评分、营业时间…… 缓存时希望**只改评分不重写整个对象**。

**为什么选 Hash**：字段级更新（`HSET` / `HINCRBY`）不需要读出整个对象再写回。

```text
HSET     lab:shop:1 name 蜜雪冰城 city 杭州 score 4.6 hours 09:00-22:00
HGET     lab:shop:1 name
HGETALL  lab:shop:1
HINCRBY  lab:shop:1 score 1
HDEL     lab:shop:1 hours
HLEN     lab:shop:1
```

```java
@PostMapping("/lesson01/shop")
public Map<String, Object> saveShop(@RequestParam long id,
                                    @RequestParam String name,
                                    @RequestParam String city,
                                    @RequestParam(defaultValue = "4.5") String score) {
    Map<String, String> fields = Map.of("name", name, "city", city, "score", score);
    redis.opsForHash().putAll(Keys.shop(id), fields);
    return Map.of("key", Keys.shop(id), "fields", redis.opsForHash().entries(Keys.shop(id)));
}

@PostMapping("/lesson01/shop/{id}/score")
public Map<String, Object> addScore(@PathVariable long id, @RequestParam double delta) {
    Double newScore = redis.opsForHash().increment(Keys.shop(id), "score", delta);
    return Map.of("id", id, "score", newScore);
}
```

### 对比实验（务必做一次）

同一个商铺，两种存法的真实差别：

| 存法 | 改一个字段 | 读全量 | 可读性 |
| --- | --- | --- | --- |
| `String` 存 JSON | 读 → 反序列化 → 改 → 序列化 → 整个写回 | `GET` 一次 | 差（一坨 JSON） |
| `Hash` 存字段 | `HSET` 一次 | `HGETALL` | 好（字段可见） |

```text
HSET lab:demo:shop-json v '{"name":"蜜雪冰城","city":"杭州","score":"4.6"}'
MEMORY USAGE lab:demo:shop-json
MEMORY USAGE lab:shop:1
```

**结论会让你意外**：字段少的时候 Hash 反而更省（`listpack` 编码），字段多了才会转为 `hashtable`。

### 检查点 3

- `OBJECT ENCODING lab:shop:1` 返回 `listpack`（字段数少于 128 且值不超过 64 字节）
- `HINCRBY` 能把 `score` 改成 5.6，且不碰其他字段

---

## 1.4 List：待处理队列

**业务需求**：下单请求先进队列，后台慢慢处理（第 06 课秒杀会真的用上）。

**为什么选 List**：`LPUSH` + `RPOP` 就是 FIFO 队列，两端操作都是 O(1)。

```text
LPUSH lab:queue:order order-1 order-2 order-3   # 左边进
LRANGE lab:queue:order 0 -1                    # 看全量（小队列才这么干）
RPOP  lab:queue:order                          # 右边出 → order-1
LLEN  lab:queue:order
LTRIM lab:queue:order 0 99                     # 只保留最近 100 条
```

```java
@PostMapping("/lesson01/queue")
public Map<String, Object> push(@RequestParam String orderId) {
    Long size = redis.opsForList().leftPush(Keys.orderQueue(), orderId);
    return Map.of("pushed", orderId, "size", size);
}

@GetMapping("/lesson01/queue/pop")
public Map<String, Object> pop() {
    String orderId = redis.opsForList().rightPop(Keys.orderQueue());
    return Map.of("popped", orderId);
}
```

### 检查点 4

- 依次 push `order-1/2/3`，第一次 pop 出来的是 `order-1`（FIFO）
- 能把「`LPUSH` + `LPOP`」改成后进先出（栈），并说清区别
- 能回答：`RPOP` 之后进程崩了，这条消息去哪了？（→ 第 08 课）

---

## 1.5 Set：关注关系

**业务需求**：A 关注 B、C，B 关注 C，求 A 和 B 的共同关注。

**为什么选 Set**：去重 + 交并差，天然适合关系。

```text
SADD    lab:follow:following:1  2 3
SADD    lab:follow:followers:2  1
SADD    lab:follow:following:2  3
SINTER  lab:follow:following:1 lab:follow:following:2   # → 3
SISMEMBER lab:follow:following:1 2                       # → 1
SCARD   lab:follow:following:1                           # → 2
```

```java
@PostMapping("/lesson01/follow")
public Map<String, Object> follow(@RequestParam long from, @RequestParam long to) {
    redis.opsForSet().add(Keys.following(from), String.valueOf(to));
    redis.opsForSet().add(Keys.followers(to), String.valueOf(from));
    return Map.of("following", redis.opsForSet().members(Keys.following(from)));
}

@GetMapping("/lesson01/follow/common")
public Map<String, Object> common(@RequestParam long a, @RequestParam long b) {
    Set<String> same = redis.opsForSet().intersect(Keys.following(a), Keys.following(b));
    return Map.of("common", same == null ? Set.of() : same);
}
```

**为什么要存双向**：查「我关注了谁」和查「谁关注了我」是两个高频查询，只存一边就要全表扫。

### 检查点 5

- 共同关注返回正确
- 重复关注同一个人，`SCARD` 不变（去重）
- 能估算：两个 100 万粉的大 V 求共同粉丝，`SINTER` 的代价在哪

---

## 1.6 ZSet：热门榜

**业务需求**：短链访问量排行榜、商铺热度榜、游戏积分榜——**能按分数排序、能取某个成员的名次**。

**为什么选 ZSet**：`member` 唯一 + `score` 排序，插入和查询都是 O(log N)；List 无法随时插入到正确位置。

```text
ZADD     lab:shortlink:hot 1 abc123
ZINCRBY  lab:shortlink:hot 1 abc123
ZREVRANGE lab:shortlink:hot 0 9 WITHSCORES     # 前 10 名，带分数
ZREVRANK  lab:shortlink:hot abc123             # 从高到低的名次（0 起）
ZSCORE    lab:shortlink:hot abc123
```

```java
@GetMapping("/lesson01/rank/top")
public Map<String, Object> top(@RequestParam(defaultValue = "10") int n) {
    Set<ZSetOperations.TypedTuple<String>> tuples =
            redis.opsForZSet().reverseRangeWithScores(Keys.shortlinkHot(), 0, n - 1L);
    List<Map<String, Object>> rows = new ArrayList<>();
    if (tuples != null) {
        int rank = 0;
        for (ZSetOperations.TypedTuple<String> t : tuples) {
            rows.add(Map.of("rank", ++rank, "code", t.getValue(),
                    "score", t.getScore() == null ? 0d : t.getScore()));
        }
    }
    return Map.of("top", rows);
}

@GetMapping("/lesson01/rank/{code}")
public Map<String, Object> rank(@PathVariable String code) {
    Long rank = redis.opsForZSet().reverseRank(Keys.shortlinkHot(), code);
    return Map.of("code", code, "rank", rank == null ? -1 : rank, "score",
            redis.opsForZSet().score(Keys.shortlinkHot(), code));
}
```

### 检查点 6

- 同一个 code `ZINCRBY` 三次，`ZSCORE` 为 3
- `ZREVRANK` 的名次从 0 开始，和展示用的「第几名」差 1
- 能解释：为什么 score 不能直接放雪花 ID（double 精度只到 2^53）

---

## 1.7 Bitmap 与 HLL：签到、UV

### Bitmap：每天一个 bit

**业务需求**：用户签到，能查「这个月签了几天」「连续签了几天」。

```text
SETBIT   lab:sign:1:2026-11 0 1        # 1 号签（offset = 日期 - 1）
SETBIT   lab:sign:1:2026-11 2 1        # 3 号签
BITCOUNT lab:sign:1:2026-11            # → 2
GETBIT   lab:sign:1:2026-11 1          # → 0（2 号没签）
BITFIELD lab:sign:1:2026-11 GET u31 0  # 一次取 31 个 bit，比 31 次 GETBIT 快
```

```java
@PostMapping("/lesson01/sign")
public Map<String, Object> sign(@RequestParam long userId,
                                @RequestParam int day,
                                @RequestParam(defaultValue = "2026-11") String month) {
    if (day < 1 || day > 31) {
        throw new IllegalArgumentException("day 必须在 1..31");
    }
    String key = Keys.sign(userId, YearMonth.parse(month));
    Boolean already = redis.opsForValue().setBit(key, day - 1L, true);
    long total = redis.execute((RedisCallback<Long>) c ->
            c.stringCommands().bitCount(key.getBytes(StandardCharsets.UTF_8)));
    return Map.of("key", key, "day", day, "alreadySigned", Boolean.TRUE.equals(already), "total", total);
}
```

**内存账**：31 天 ≈ 4 字节/人；100 万用户一个月约 4MB。
如果改成「每人每天一个 key」，key 本身的开销就上百 MB。

### HyperLogLog：只要数量，不要明细

**业务需求**：今天有多少个独立访客（UV），允许 1% 以内误差。

```text
PFADD   lab:uv:home:2026-11-19 u1 u2 u3
PFCOUNT lab:uv:home:2026-11-19        # → 3（近似值）
PFADD   lab:uv:home:2026-11-19 u1     # → 0，表示已存在
PFMERGE lab:uv:home:week lab:uv:home:2026-11-18 lab:uv:home:2026-11-19
```

`PFCOUNT` 的标准误差约 **0.81%**，固定内存约 **12KB**（能撑到 2^64 个元素）。
所以：UV 能接受误差就用 HLL；需要「到底谁来过」就必须用 Set。

### 检查点 7

- 签到 1 号和 3 号，`BITCOUNT` 为 2，`GETBIT 1` 为 0
- 同一个用户 `PFADD` 两次，`PFCOUNT` 还是 1
- 能说出 Bitmap 与 HLL 各自「牺牲了什么」

---

## 1.8 看一眼编码，理解「小数据量」的红利

同一个类型，数据量不同，底层结构不同，内存能差一个数量级。

```text
OBJECT ENCODING lab:shop:1        → listpack     （字段少）
OBJECT ENCODING lab:sign:1:2026-11 → raw         （string 存 bitmap）
OBJECT ENCODING lab:follow:following:1 → intset  （全是整数）
```

动手做一次阈值实验（第 13 课会深挖原理，这里先建立体感）：

```bash
# 造 127 个字段 → listpack
for i in $(seq 1 127); do redis-cli hset lab:demo:hash f$i v; done
redis-cli OBJECT ENCODING lab:demo:hash
redis-cli MEMORY USAGE lab:demo:hash

# 再加一个，共 128 → 超过 hash-max-listpack-entries(128) 会转 hashtable
redis-cli hset lab:demo:hash f128 v
redis-cli OBJECT ENCODING lab:demo:hash
redis-cli MEMORY USAGE lab:demo:hash
```

记录这两次的内存差，写进你的笔记——这就是「配置参数直接影响成本」的第一个例子。

---

## 本课作业

用上面的积木拼三个真实功能，**先自己写，再看答案**：

1. **短链全链路**：创建（`SET NX EX`）→ 访问（`GET` + `INCR` + `ZINCRBY`）→ 查热门榜
2. **签到 + 连续签到**：给定用户和月份，算出连续签到天数（提示：用 `BITFIELD` 取整月，再对二进制找连续 1）
3. **关注 + 共同关注 + 粉丝数**：跳转页面上同时展示「我关注了几个」「谁关注了我」

---

## 验收清单

- [ ] `/lesson01/keys` 能扫出本课所有 key，类型和 TTL 正确
- [ ] 短链：创建、访问、计数、排行榜串起来能跑
- [ ] 商铺：Hash 字段级更新不覆盖其他字段
- [ ] 队列：FIFO 顺序正确
- [ ] 关注：共同关注正确，重复关注去重
- [ ] 排行榜：名次与分数正确
- [ ] 签到：`BITCOUNT` 与实际天数一致
- [ ] UV：重复用户不重复计数
- [ ] 完成一次 127 → 128 字段的编码切换实验，并记下内存差

---

## 常见坑

1. **`SET` 会清掉原有 TTL**：对带过期的 key 重新 `SET`，它就永不过期了
2. **`SETNX` 不管过期时间**：`SETNX` + `EXPIRE` 是两条命令，中间崩溃就死锁（第 07 课的重点）
3. **`INCR` 遇到非数字直接报错**，而且原值不变
4. **`TTL` 的 `-1/-2`** 含义完全不同：一个是「永不过期」，一个是「key 不存在」
5. **Bitmap 的 offset 从 0 开始**：1 号对应 offset 0，写错就永远差一位
6. **ZSet 的 score 是 double**：超过 2^53 精度丢失，别放雪花 ID
7. **Hash 字段没有 TTL**：想「每个字段单独过期」得拆 key 或用 ZSet 存过期时间
8. **`LRANGE key 0 -1` 在大 list 上会阻塞**：只用于小数据
9. **`KEYS` 是阻塞命令**：线上永远用 `SCAN`
10. **`SINTER` 在大集合上很贵**：50 万 × 50 万的交集要几百毫秒

---

## Go 对照

用 `go-redis v9` 写同样的三件事，注意 API 形态的差异（Java 是 `opsForXxx()`，Go 是链式命令）：

```go
// 短链：写 + 计数
rdb.Set(ctx, "lab:shortlink:code:abc123", url, 30*24*time.Hour)
visits, _ := rdb.Incr(ctx, "lab:shortlink:visits:abc123").Result()

// 商铺对象
rdb.HSet(ctx, "lab:shop:1", map[string]any{"name": "蜜雪冰城", "city": "杭州", "score": "4.6"})
fields, _ := rdb.HGetAll(ctx, "lab:shop:1").Result()

// 排行榜
rdb.ZIncrBy(ctx, "lab:shortlink:hot", 1, "abc123")
top, _ := rdb.ZRevRangeWithScores(ctx, "lab:shortlink:hot", 0, 9).Result()
```

一个值得记住的差异：**Go 客户端每个命令都是一个独立方法，没有 `opsForHash` 这种分组**，
所以你会更直接地看到「我到底发了哪条命令」；Java 的模板方法则容易让人忘记背后是 Redis 命令。

---

## 下一课

第 02 课：Java 客户端与序列化——先让你亲眼看见 `\xac\xed` 乱码，再定下全项目的序列化约定。
