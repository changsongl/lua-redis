# lua-redis

[toc]

### 简介

#### 优势：
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

> eval "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second
1) "key1"
2) "key2"
3) "first"
4) "second"
````

2. 上传脚本，之后使用SHA1校验和来调用脚本。（潜在碰撞问题，在使用时一般会忽视）
````shell
SCRIPT LOAD script
EVALSHA sha1 numkeys key [key ...] arg [arg ...]

redis> SCRIPT LOAD "return 'hello moto'"
"232fd51614574cf0867b83d384a5e898cfd24e5a"

redis> EVALSHA 232fd51614574cf0867b83d384a5e898cfd24e5a 0
"hello moto"
````

### Reference:

[Redis Lua实战](https://www.jianshu.com/p/366d1b4f0d13)