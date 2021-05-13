local utils = {}

function utils.wait(seconds)
    local start = os.time()
    repeat until os.time() > start + seconds
end

function utils.starts_with(str, start)
    return str:sub(1, #start) == start
end

return utils