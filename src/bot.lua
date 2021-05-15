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
    _instagram_service = nil,
    _updates_service = nil
}

function TelegramBot:new(token, storage)
    local object = {}
    object._token = token
    object._user_repo = repositories.UserRepository:new(storage)
    object._accounts_repo = repositories.AccountsRepository:new(storage)
    object._photos_repo = repositories.PhotosRepository:new(storage)
    object._stories_repo = repositories.StoriesRepository:new(storage)
    object._instagram_service = services.InstagramService:new()
    object._updates_service = services.UpdatesService:new(
        object._instagram_service,
        object._photos_repo,
        object._stories_repo
    )

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
        -- FIXME: Add coroutines to respond faster to user's commands
        -- send_instagram_updates()
        process_telegram_updates()
    end
end

function TelegramBot:_get_instagram_updates_sender(start_time)
    local last_update_time = tonumber(start_time) ~= nil and start_time or os.time()
    return function ()
        local now = os.time()
        if now - last_update_time >= 60 then
            last_update_time = now
            local chat_id = "1204323514"
            local username = "olyashaasaxon"
            -- TODO: implement
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
        local username = message.from.first_name.." "..message.from.last_name
        self:_on_start_command(message.chat.id, username)
    elseif utils.starts_with(message.text, "/stop") then
        self:_on_stop_command(message.chat.id)
    elseif utils.starts_with(message.text, "/list") then
        self:_on_list_command(message.chat.id)
    elseif utils.starts_with(message.text, "/add") then
        local username = utils.split(message.text)[2]
        self:_on_add_command(message.chat.id, username)
    elseif utils.starts_with(message.text, "/remove") then
        local username = utils.split(message.text)[2]
        self:_on_remove_command(message.chat.id, username)
    elseif utils.starts_with(message.text, "/update") then
        local username = utils.split(message.text)[2]
        self:_on_update_command(message.chat.id, username)
    elseif utils.starts_with(message.text, "/stories") then
        local username = utils.split(message.text)[2]
        self:_on_stories_command(message.chat.id, username)
    elseif utils.starts_with(message.text, "/photos") then
        local username = utils.split(message.text)[2]
        self:_on_photos_command(message.chat.id, username)
    elseif utils.starts_with(message.text, "/help") then
        self:_on_help_command(message.chat.id)
    else
        log.info("User "..message.chat.id.." tries to use not existing command "..message.text)
        self._api.send_message(message.chat.id, "Wrong command. Use /help to get list of all commands.")
    end
end

function TelegramBot:_on_start_command(chat_id, username)
    log.debug("Command /start from "..chat_id)
    local user = self._user_repo:retrieve({chat_id = chat_id})
    if user then
        self._api.send_message(chat_id, "You have been already registered!")
    else
        log.info("Registering user "..username)
        self._user_repo:create({chat_id = chat_id, username = username})
        self._api.send_message(
            chat_id,
            "Hello, "..username.."! Send me /add igusername to observe igusername's Instagram updates."
        )
    end
end

function TelegramBot:_on_stop_command(chat_id)
    log.debug("Command /stop from "..chat_id)
    local user = self._user_repo:retrieve({chat_id = chat_id})
    if user then
        log.info("Deleting user by chat id "..chat_id)
        self._user_repo:delete({chat_id = chat_id})
    else
        log.warn("Trying to delete user data from chat"..chat_id..", but no user data exists.")
    end
end

function TelegramBot:_on_list_command(chat_id)
    log.debug("Command /list from "..chat_id)
    local accounts = self._accounts_repo:retrieve({chat_id = chat_id})
    if accounts then
        local account_links = {}
        for _, account in pairs(accounts) do
            table.insert(account_links, self._instagram_service:toprofileurl(account.username))
        end
        log.info("List of observable Instagram accounts: "..utils.tabletostring(account_links))
        self._api.send_message(chat_id, "Observing:\n"..table.concat(account_links, "\n"))
    else
        self._api.send_message(
            chat_id,
            "You are not subscribed to any Instagram account. "..
            "Provide one using /add igusername command."
        )
    end
end

function TelegramBot:_on_add_command(chat_id, username)
    log.debug("Command /add "..username.." from "..chat_id)
    if not username then
        self._api.send_message(chat_id, "No username parameter provided. Use /add igusername format.")
        return
    end
    local account = self._accounts_repo:retrieve({chat_id = chat_id, username = username})
    if account then
        log.warn("Trying to add already observable account @"..username.." for chat "..chat_id)
        self._api.send_message(chat_id, "This account is already observable for this chat.")
        return
    end
    local profile_url = self._instagram_service:toprofileurl(username)
    account = self._instagram_service:get_account(username)
    if account then
        log.info("Adding @"..username.." to observable accounts list for chat "..chat_id)
        self._accounts_repo:create({chat_id = chat_id, username = username})
        self._api.send_message(chat_id, "Account "..profile_url.." added.")
        self._api.send_photo(chat_id, account.profile_picture, profile_url.." profile picture")
    else
        log.warn("Trying to add wrong username @"..username.." or account is closed.")
        self._api.send_message(
            chat_id,
            "Not found "..profile_url.." or account is closed."
        )
    end
end

function TelegramBot:_on_remove_command(chat_id, username)
    log.debug("Command /remove "..username.." from "..chat_id)
    if not username then
        self._api.send_message(chat_id, "No username parameter provided. Use /remove igusername format.")
        return
    end
    local account = self._accounts_repo:retrieve({chat_id = chat_id, username = username})
    if account then
        log.info("Removing @"..username.." from observable accounts list for chat "..chat_id)
        self._accounts_repo:delete({chat_id = chat_id, username = username})
        self._api.send_message(
            chat_id,
            "Removed "..self._instagram_service:toprofileurl(username).." from observable list."
        )
    else
        log.warn("Trying to remove not observable account @"..username.." for chat "..chat_id)
        self._api.send_message(chat_id, "This account is not observable for this chat.")
    end
end

function TelegramBot:_on_update_command(chat_id, username)
    log.debug("Command /update "..username.." from "..chat_id)
    if not username then
        self._api.send_message(chat_id, "No username parameter provided. Use /update igusername format.")
        return
    end
    local account = self._user_repo:retrieve({chat_id = chat_id, username = username})
    if not account then
        log.warn("Trying to update data of @"..username.." without subscription from chat "..chat_id)
        self._api.send_message(chat_id, "You are not subscribed to this account. Use /add "..username.." command.")
    end
    local stories = self._updates_service:collect_story_updates(chat_id, username)
    if next(stories) then
        self:_send_stories(chat_id, username, stories)
    else
        self._api.send_message(chat_id, "No new stories.")
    end
    local photos = self._updates_service:collect_photo_updates(chat_id, username)
    if next(photos) then
        self:_send_photos(chat_id, username, photos)
    else
        self._api.send_message(chat_id, "No new photos.")
    end
end

function TelegramBot:_on_stories_command(chat_id, username)
    log.debug("Command /stories "..username.." from "..chat_id)
    if not username then
        self._api.send_message(chat_id, "No username parameter provided. Use /stories igusername format.")
        return
    end
    local stories = self._instagram_service:get_stories(username)
    self:_send_stories(chat_id, username, stories)
end

function TelegramBot:_on_photos_command(chat_id, username)
    log.debug("Command /photos "..username.." from "..chat_id)
    if not username then
        self._api.send_message(chat_id, "No username parameter provided. Use /photos igusername format.")
        return
    end
    local photos = self._instagram_service:get_photos(username)
    self:_send_photos(chat_id, username, photos)
end

function TelegramBot:_on_help_command(chat_id)
    log.debug("Command /help from "..chat_id)
    self._api.send_message(
        chat_id,
        "Use one of the specified commands:\n"..
        "/start - Register in Instagram updates observer bot.\n"..
        "/stop - Delete all user data and stop the bot.\n"..
        "/list - Show all observable Instagram accounts.\n"..
        "/add igusername - Begin observing igusername's Instagram account.\n"..
        "/remove igusername - Stop observing igusername's Instagram account.\n"..
        "/update igusername - Force collect & send igusername's Instagram updates.\n"..
        "/stories igusername - Get stories of igusername without observing!\n"..
        "/photos igusername - Get photos of igusername without observing!\n"..
        "/help - Show this message."
    )
end

function TelegramBot:_collect_updates(chat_id, username)
    local photos = self._updates_service:collect_photo_updates(chat_id, username)
    local stories = self._updates_service:collect_story_updates(chat_id, username)
    return {photos = photos, stories = stories}
end

function TelegramBot:_send_updates(chat_id, username, updates)
    if not updates or not next(updates) then
        log.warn("No to send updates provided!")
        return
    end
    for update_type, update in pairs(updates) do
        if update_type == "photos" then
            self:_send_photos(chat_id, username, update.data)
        elseif update_type == "stories" then
            self:_send_stories(chat_id, username, update.data)
        else
            log.warn("Wrong update type: "..update.type)
        end
    end
end

function TelegramBot:_send_photos(chat_id, username, photos)
    local profile_url = self._instagram_service:toprofileurl(username)
    if not photos or not next(photos) then
        self._api.send_message(chat_id, "No photos for "..profile_url)
    end
    for _, photo in pairs(photos) do
        self._api.send_photo(chat_id, photo.url, profile_url.." photo")
    end
end

function TelegramBot:_send_stories(chat_id, username, stories)
    local profile_url = self._instagram_service:toprofileurl(username)
    if not stories or not next(stories) then
        self._api.send_message(chat_id, "No stories for "..profile_url)
        return
    end
    for _, story in pairs(stories) do
        if story.type == "image" then
            self._api.send_photo(chat_id, story.url, profile_url.." story")
        elseif story.type == "video" then
            self._api.send_video(chat_id, story.url, profile_url.." story")
        else
            log.warn("Wrong story type: "..story.type.." of the @"..username)
        end
    end
end

return TelegramBot