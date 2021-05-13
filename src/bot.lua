local utils = require "src/utils"
local repositories = require "src/repositories"
local services = require "src/services"

local TelegramBot = {
    _token = "no-token",
    _api = nil,
    _user_repo = nil,
    _accounts_repo = nil,
    _photos_repo = nil,
    _stories_repo = nil,
    _instagram_service = nil
}

function TelegramBot:new(token, storage)
    local object = {}
    object._token = token
    object._user_repo = repositories.UserRepository:new(storage)
    object._accounts_repo = repositories.AccountsRepository:new(storage)
    object._photos_repo = repositories.PhotosRepository:new(storage)
    object._stories_repo = repositories.StoriesRepository:new(storage)
    object._instagram_service = services.InstagramService:new()

    setmetatable(object, self)
    self.__index = self
    return object
end

function TelegramBot:start()
    self._api = require("telegram-bot-lua.core").configure(self._token)
    self._api.on_message = function (message) self:_on_message(message) end
    local send_instagram_updates = self:_get_instagram_updates_sender()
    local process_telegram_updates = self:_get_telegram_updates_processor()
    while true do
        send_instagram_updates()
        process_telegram_updates()
    end
end

function TelegramBot:_get_instagram_updates_sender(start_time)
    local last_update_time = tonumber(start_time) ~= nil and start_time or os.time()
    return function ()
        local now = os.time()
        if now - last_update_time >= 60 then
            last_update_time = now
            self._api.send_message("1204323514", 'Instagram Updates')
        end
    end
end

function TelegramBot:_get_telegram_updates_processor(limit, timeout, offset, allowed_updates, use_beta_endpoint)
    limit = tonumber(limit) ~= nil and limit or 1
    timeout = tonumber(timeout) ~= nil and timeout or 0
    offset = tonumber(offset) ~= nil and offset or 0
    return function ()
        local updates = self._api.get_updates(timeout, offset, limit, allowed_updates, use_beta_endpoint)
        if updates and type(updates) == 'table' and updates.result then
            for _, v in pairs(updates.result) do
                self._api.process_update(v)
                offset = v.update_id + 1
            end
        end
    end
end

function TelegramBot:_on_message(message)
    if not message or not message.text then return end
    if utils.starts_with(message.text, "/start") then
        self:_on_start_command(message.chat.id)
    elseif utils.starts_with(message.text, "/stop") then
        self:_on_stop_command(message.chat.id)
    elseif utils.starts_with(message.text, "/list") then
        self:_on_list_command(message.chat.id)
    elseif utils.starts_with(message.text, "/add") then
        self:_on_add_command(message.chat.id)
    elseif utils.starts_with(message.text, "/remove") then
        self:_on_remove_command(message.chat.id)
    elseif utils.starts_with(message.text, "/help") then
        self:_on_help_command(message.chat.id)
    else
        log.info("User "..message.chat.id.." tries to use not existing command "..message.text)
        self._api.send_message(message.chat.id, "Wrong command. Use /help to get list of all commands.")
    end
end

function TelegramBot:_on_start_command(chat_id)
    self._api.send_message(chat_id, chat_id)
end

function TelegramBot:_on_stop_command(chat_id)
    self._api.send_message(chat_id, chat_id)
end

function TelegramBot:_on_list_command(chat_id)
    self._api.send_message(chat_id, chat_id)
end

function TelegramBot:_on_add_command(chat_id)
    self._api.send_message(chat_id, chat_id)
end

function TelegramBot:_on_remove_command(chat_id)
    self._api.send_message(chat_id, chat_id)
end

function TelegramBot:_on_help_command(chat_id)
    self._api.send_message(chat_id, chat_id)
end

return TelegramBot