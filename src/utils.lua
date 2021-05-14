local utils = {}

function utils.wait(seconds)
    local start = os.time()
    repeat until os.time() > start + seconds
end

function utils.starts_with(str, start)
    return str:sub(1, #start) == start
end

function utils.val_to_str(v)
    if "string" == type( v ) then
       v = string.gsub(v, "\n", "\\n")
       if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
          return "'"..v.."'"
       end
       return '"'..string.gsub(v,'"', '\\"')..'"'
    end
    return "table" == type(v) and utils.tabletostring(v) or tostring(v)
end

function utils.key_to_str (k)
    if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
       return k
    end
    return "["..utils.val_to_str(k).."]"
end

function utils.tabletostring(tbl)
   local result, done = {}, {}
   for k, v in ipairs(tbl) do
      table.insert(result, utils.val_to_str(v))
      done[k] = true
   end
   for k, v in pairs(tbl) do
      if not done[k] then
         table.insert(result, utils.key_to_str( k ).."="..utils.val_to_str(v))
      end
   end
   return "{"..table.concat(result, ",").."}"
end

function utils.split(str)
   local splitted = {}
   for i in str:gmatch("([^,%s]+)") do
      splitted[#splitted + 1] = i
   end
   return splitted
end

function utils.hextochar(x)
   return string.char(tonumber(x, 16))
end

function utils.unescape(url)
   return url:gsub("%%(%x%x)", utils.hextochar)
end

return utils