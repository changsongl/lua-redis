
-- 打印table
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