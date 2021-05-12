local utils = require "src/utils"

local TelegramBot = {
    _token = "no-token",
    _storage = nil
}

function TelegramBot:new(token, storage)
    local object = {}
    object._token = token
    object._storage = storage

    setmetatable(object, self)
    self.__index = self
    return object
end

function TelegramBot:start()
    log.warn(self._token)
end

return TelegramBot