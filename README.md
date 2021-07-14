# lua-redis

### 简介
在Redis中使用Lua脚本在业务开发中是比较常见的事情，`使用Lua的优点`有以下几点。

1. 对于与多次redis指令的发送，使用Lua脚本可以`减少网络的开销`。当网络传输慢或者响应要求高的场景中尤为关键。
Lua脚本可以将多个请求通过脚本形式一次进行处理，减少网络的相关时延。Redis还提供了Pipeline来解决这个问题，
   但是在前面指令会影响后面指令逻辑的场景下，Pipeline并不能满足。
   
2. 原子操作。在Lua脚本中会将整个脚本作为一个整体来执行，中间`不会被其他指令而打断`，因此`保证了原子性`。
因此在我们写Lua脚本时，无需考虑竞争而导致的整体数据`状态不一致`的问题，并且无需使用事务。并且因为此特性，
   需确保脚本尽可能不要运行时间过长，要确保脚本执行的粒度最小化。
   
3. 复用和封装。针对于一些`通用能力`的功能，把这些放到redis脚本中去实现。
其他客户端调用相同的脚本代码，从而达到逻辑的`复用`。
   
#### 对比Lua脚本与事务：

Lua脚本本身也可以看作为一种事务，而且使用脚本起来更简单，并且可控制的流程更灵活。

在使用Redis事务的时候会遇到两种`问题`：

* 事务在调用EXEC之前，产生了语法错误（如参数数量，参数名等问题）或者服务器内存等问题。
遇到这一类问题是，会在服务器运行这些指令前发现这些问题（2.6.5之后），并且终止此次的事务。
  
* 事务执行EXEC调用之后的失败，如事务中某个键的类型错误的问题。中间指令的错误并不会终止后面的流程，
  也不会导致前面指令的回滚。然而在Lua脚本中，你可以完全控制这些。

### Lua-Redis指令教程

#### 注入和使用脚本：
1. 运行脚本时把脚本发送到Redis(网络开销较大)
````shell
EVAL script numkeys [key ...] [arg ...]

# 运行脚本
redis> EVAL "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second

# 运行只读脚本，脚本需要不包含任何修改内容的操作。这个指令可以随意被kill掉，
# 而且不会影响到副本的stream。这个指令可以在master和replica上执行。
redis> EVAL_RO "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second
````

2. 上传脚本，之后使用SHA1校验和来调用脚本。（潜在碰撞问题，在使用时一般会忽视）
````shell
SCRIPT LOAD script
EVALSHA sha1 numkeys key [key ...] arg [arg ...]

redis> SCRIPT LOAD "return 'hello moto'"
"232fd51614574cf0867b83d384a5e898cfd24e5a"

# 运行脚本
redis> EVALSHA 232fd51614574cf0867b83d384a5e898cfd24e5a 0
"hello moto"

# 运行只读脚本，脚本需要不包含任何修改内容的操作。这个指令可以随意被kill掉，
# 而且不会影响到副本的stream。这个指令可以在master和replica上执行。
redis> EVALSHA 232fd51614574cf0867b83d384a5e898cfd24e5a 0
````

3. 其他一些指令
* SCRIPT DEBUG 用来调试脚本 [[Document]](https://redis.io/commands/script-debug)
* SCRIPT EXISTS 通过校验值用来检查脚本是否存在 [[Document]](https://redis.io/commands/script-exists)
* SCRIPT FLUSH 清除脚本 [[Document]](https://redis.io/commands/script-flush)
* SCRIPT KILL 停到现在执行中的脚本，默认脚本没有写操作 [[Document]](https://redis.io/commands/script-kill)

4. 注意点
- 运行脚本需要严格按照Keys和Args的要求来进行传参。
  所有操作到的redis key应放到Keys对象中，否则可能会影响到在redis集群中错误表现。
````shell
# Bad
> eval "return redis.call('set','foo','bar')" 0
OK

# Good
> eval "return redis.call('set',KEYS[1],'bar')" 1 foo
OK
````

#### 调用redis指令
在redis lua脚本中最常用的就是调用redis原生的指令。有以下两个指令：
1. redis.call(command, key, arg1, arg2...): 当调用发生错误时，自动终止脚本，强制把相关Lua 错误返回给客户端。
2. redis.pcall(command, key, arg1, arg2...): 当调用发生错误时，会进行错误拦截，并返回相关错误。

当调用redis.call和redis.pcall指令时Redis Reply会转换为Lua类型，当Lua脚本返回时，会将Lua类型转换为Redis Reply。
因此这两种类型的转换是需要知晓的。可以阅读此文档了解Redis协议。[[Link]](http://redisdoc.com/topic/protocol.html)

* Redis integer reply: 如EXISTS...
* Redis bulk reply: 如GET...
* Redis multi bulk reply: 如LRANGE...
* Redis status reply: 如SET...
* Redis error reply: 指令错误...

##### 转换表
* Redis回复类型转Lua类型转换表:
```` 
       Redis integer reply   ->   Lua number

          Redis bulk reply   ->   Lua string

    Redis multi bulk reply   ->   Lua table (may have other Redis data types nested)

        Redis status reply   ->   Lua table with a single ok field containing the status

         Redis error reply   ->   Lua table with a single err field containing the error

      Redis Nil bulk reply   ->   Lua false boolean type

Redis Nil multi bulk reply   ->   Lua false boolean type
````

* Lua类型类型转Redis回复转换表:
````
                Lua number   ->   Redis integer reply (the number is converted into an integer)

                Lua string   ->   Redis bulk reply

         Lua table (array)   ->   Redis multi bulk reply (truncated to the first nil inside the Lua array if any)

         Lua table with      ->   Redis status reply
         a single ok field

         Lua table with      ->   Redis error reply
         a single err field

         Lua boolean false   ->   Redis Nil bulk reply.
````
* 注意事项

1. Lua只有`一个数字类型`，Lua number。没有区分integer和floats，因此将`永远转换Lua numbers为integer回复`。
如果需要floats类型，请return字符串。(ZSCORE指令就是这么实现的)

2. 由于Lua`语义`原因，Lua array不可以有`nils`。当redis reply转换到Lua array时会`终止运行`。

3. 当`Lua Table`包含keys(和其values)，转换成redis reply将`不会包含keys`。

4. 在Redis Lua里面不可以使用`os库`，并且强烈建议大家不要使用`redis.call("time")`去获取时间。
因为os库的操作和redis的time操作返回的数值是不确定的，特别当主从复制的时候，这个值在不同副本中的值可能会不同。


##### RESP3 - Redis 6 协议
如需要了解请查看官方文档 [[Link]](https://redis.io/commands/eval)

### 示例
* lock: 分布式锁
* rate limit: 限流，时间桶实现


### Reference:

* Redis Lua实战 [[Link]](https://www.jianshu.com/p/366d1b4f0d13)
* Redis 官方文档 [[Link]](https://redis.io/commands/eval)