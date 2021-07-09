-- redis lua rate limit script for specific user
-- set rate rule
-- visit and check: increase visit times and check rules
-- visit
-- check

-- 检查参数错误
if #KEYS ~= 3 or #ARGV ~= 2 then
    local error = "invalid keys or argument: 3 user-second-key user-minute-key user-hour-key command user-id"
    return redis.error_reply(error)
end

local function setRateRule()

end

local function visitCheck()

end

local function visit()

end

local function check()

end

local commands = {
    ["rule"] = setRateRule,
    ["visitcheck"] = visitCheck,
    ["visit"] = visit,
    ["check"] = check,
}

local cmd, userId, secondKey, minuteKey, hourKey = ARGV[1], ARGV[2], KEYS[1], KEYS[2], KEYS[3]

local commandObj = commands[cmd]
if commandObj then
    return commandObj()
else
    return redis.error_reply(string.format("invalid command: %s (rule, visitcheck, visit, check)", cmd))
end



