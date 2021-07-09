-- 本限流实现采用的是时间桶的概念，可以支持进行，秒，分，小时级别的访问总量限制。
-- Redis一共存储了秒桶（60个槽），分钟桶（60个槽），小时桶（24个槽），当用户去

-- 打印table d
local function PrintTable(table , level)
    local key = ""
    level = level or 1
    local indent = ""
    for i = 1, level do
        indent = indent.."  "
    end

    if key ~= "" then
        print(indent..key.." ".."=".." ".."{")
    else
        print(indent .. "{")
    end

    key = ""
    for k,v in pairs(table) do
        if type(v) == "table" then
            key = k
            PrintTable(v, level + 1)
        else
            local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
            print(content)
        end
    end
    print(indent .. "}")
end

-- 拆分string
local function explode (_str, sep)
    local pos, arr = 0, {}
    for st, sp in function() return string.find( _str, sep, pos, true ) end do
        table.insert(arr, string.sub(_str, pos, st-1 ))
        pos = sp + 1
    end
    table.insert(arr, string.sub( _str, pos))
    return arr
end

-- 设置频率规则
local function setRateRule(configKey, type, time, count)
    local v = string.format("%s-%d-%d", type, time, count)
    return redis.call("SADD", configKey, v)
end

-- 根据当前时间的秒，分钟，和小时
local function getTimeDetails(now)
    local second = math.floor(now % 60)
    local minute = math.floor(now / 60 % 60)
    local hour = math.floor(now / 3600 % 24)

    return second, minute, hour
end

-- 获得当前时间，初始秒数，初始分钟，初始小时
local function getBeginTime(now)
    local beginMinute = math.floor(now - math.floor(now % 60))
    local beginHour = math.floor(now - math.floor(now % 3600))

    return now, beginMinute, beginHour
end

-- 对key的元素进行+1
local function incr(key, timeIndex, beginTime, expireTime)
    -- 查看这一秒是否有数据
    local lastIndex = string.format("%d-last-time", timeIndex)
    local dict = redis.call("HMGET", key, timeIndex, lastIndex)

    -- 这一秒的数据不为空，检查是否开始时间要比第一次更新这个槽的时间要晚，
    -- 如果晚的话，则代表这个槽里原来的统计已经过期了，需要归0。
    if dict ~= false and dict[1] ~= false and dict[2] ~= false then
        local time = math.floor(dict[2])
        if time ~= beginTime then
            redis.call("HSET", key, timeIndex, 0)
        end
    end

    -- 增加这个槽的统计次数
    redis.call("HSET", key, lastIndex, beginTime)
    redis.call("HINCRBY", key, timeIndex, 1)
    redis.call("EXPIRE", key, expireTime)
end

-- 增加访问次数
local function incrVisiting(secondKey, minuteKey, hourKey, now)
    local second, minute, hour = getTimeDetails(now)
    local beginSecond, beginMinute, beginHour = getBeginTime(now)

    incr(secondKey, second, beginSecond, 60)
    incr(minuteKey, minute, beginMinute, 60 * 60)
    incr(hourKey, hour, beginHour, 60 * 60)
end

-- 获取桶里面的所有元素，并返回一个table
local function getBucketDetailsDictionary(key)
    local details = redis.call("HGETALL", key)
    local dict = {}
    for i = 1, #details/2, 1 do
        local keyIndex = (i - 1) * 2 + 1
        local valueIndex = keyIndex + 1
        dict[details[keyIndex]] = details[valueIndex]
    end

    return dict
end

-- 返回频次限制规则
local function getRateLimitRules(configKey)
    return redis.call("SMEMBERS", configKey)
end

local function extractTypeTimeCount(ruleString)
    local dict = explode(ruleString, "-")

    return tonumber(dict[1]), tonumber(dict[2]), tonumber(dict[3])
end

-- TODO: 检查当前统计的数据和规则是否还是合法
local function isRuleValidNow(dict)

end

-- 检查是否超过访问限制规则中的一条，如果已超过则返回0，没超过则返回1
local function checkRule(secondKey, minuteKey, hourKey, configKey, now)
    local secondDict = getBucketDetailsDictionary(secondKey)

    local rules = getRateLimitRules(configKey)
    for i, ruleString in ipairs(rules) do
        local type, time, count = extractTypeTimeCount(ruleString)
        local result = true

        if type == 1 then

        elseif type == 2 then
        elseif type == 3 then
        end
    end

end

-- 访问逻辑
local function visit(secondKey, minuteKey, hourKey, configKey, now)
    incrVisiting(secondKey, minuteKey, hourKey, now)

    return checkRule(secondKey, minuteKey, hourKey, configKey, now)
end

-- command 字典
local rateCommands = {
    ["visit"] = visit,
}

-- 执行命令，并检查参数
local cmd = ARGV[1]
local rateCommand = rateCommands[cmd]

if rateCommand then
    -- 访问指令
    -- 检查参数错误
    if #KEYS ~= 4 or #ARGV ~= 2 then
        local error = "invalid keys or argument number: 4 user-second-key user-minute-key user-hour-key config-key visitcheck"
        return redis.error_reply(error)
    end

    local secondKey, minuteKey, hourKey, configKey, now = KEYS[1], KEYS[2], KEYS[3], KEYS[4], ARGV[2]
    return rateCommand(secondKey, minuteKey, hourKey, configKey, now)
elseif cmd == "rule" then
    -- 设置访问规则指令
    -- 检查参数错误
    if #KEYS ~= 1 or #ARGV ~= 4 then
        local error = "invalid keys or argument number: 1 config-key rule hour|minute|second time count"
        return redis.error_reply(error)
    end

    local configKey, type, time, count = KEYS[1], ARGV[2], ARGV[3], ARGV[4]

    return setRateRule(configKey, type, time, count)
else
    -- 非法指令，返回错误
    return redis.error_reply(string.format("invalid command: %s (rule, visitcheck, visit, check)", cmd))
end