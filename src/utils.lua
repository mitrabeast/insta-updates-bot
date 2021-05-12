local utils = {}

function utils.wait(seconds)
    local start = os.time()
    repeat until os.time() > start + seconds
end

return utils