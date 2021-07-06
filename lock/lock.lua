-- 获取命令 lock | unlock
local action = ARGV[1]

-- lock 方法 lock $lockerKey $uuid $expireSeconds
local function lock()
    local lockerKey, value, expireSeconds = KEYS[1], ARGV[2], ARGV[3]
    if #KEYS ~=1 or #ARGV ~= 3 then
        return redis.error_reply("wrong number of args")
    end

    local setRs = redis.call("SET", lockerKey, value, "NX", "EX", expireSeconds)
    if type(setRs) == "table" and setRs["ok"] == "OK" then
        return 1
    else
        return 0
    end
end

-- unlock 方法 unlock $lockerKey $uuid 只有当前是这个uuid锁才会进行unlock
local function unlock()
    if  #KEYS ~=1 or #ARGV ~= 2 then
        return redis.error_reply("wrong number of args")
    end

    local lockerKey, value = KEYS[1], ARGV[2]
    local kValue = redis.call("GET", lockerKey)
    if kValue == value then
        redis.call("DEL", lockerKey)
        return 1
    end
    return 0
end

-- 检查action是否为空
if action == nil then
    return redis.error_reply("action is missing")
end

-- 调用命令
if string.lower(action) == "lock" then
    return lock()
elseif string.lower(action) == "unlock" then
    return unlock()
end

return redis.error_reply(string.format("invalid action: %s", action))