local action = KEYS[1]

local function lock()
    local keysNum = #KEYS
    if keysNum ~= 4 then
        return redis.error_reply("wrong number of args")
    end

    local lockerKey, value, expireSeconds = KEYS[2], KEYS[3], tonumber(KEYS[4])
    local setRs = redis.call("SET", lockerKey, value, "NX", "EX", expireSeconds)
    if type(setRs) == "table" and setRs["ok"] == "OK" then
        return 1
    else
        return 0
    end
end

local function unlock()
    local keysNum = #KEYS
    if keysNum ~= 3 then
        return redis.error_reply("wrong number of args")
    end

    local lockerKey, value = KEYS[2], KEYS[3]
    local kValue = redis.call("GET", lockerKey)
    if kValue == value then
        redis.call("DEL", lockerKey)
        return 1
    end
    return 0
end

if action == nil then
    return redis.error_reply("action is missing")
end

if string.lower(action) == "lock" then
    return lock()
elseif string.lower(action) == "unlock" then
    return unlock()
end

return redis.error_reply(string.format("invalid action: %s", action))