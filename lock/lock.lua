local action = KEYS[1]

local function lock()
    return 0
end

local function unlock()
    return 0
end

if action == nil
then
    return redis.error_reply("action is missing")
end

if string.lower(action) == "lock"
then
    return lock()
elseif string.lower(action) == "unlock"
then
    return unlock()
end

return redis.error_reply(string.format("invalid action: %s", action))