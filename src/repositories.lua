local utils = require "src/utils"

local _M = {}

local Repository = {
    _storage = nil
}

function Repository:new(storage)
    local object = {}
    object._storage = storage

    setmetatable(object, self)
    self.__index = self
    return object
end

function Repository:create(params)
    error("Abstract method.")
end

function Repository:retrieve(params)
    error("Abstract method.")
end

function Repository:delete(params)
    error("Abstract method.")
end

local UserRepository = Repository:new()

function UserRepository:create(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local username = params.username or "Anonymous"
    local result, err = self._storage:query(
        "insert into tgusers (chat_id, username) values (%s, %s)",
        {chat_id, username}
    )
    if result then
        log.debug("Created user "..username.." from chat "..chat_id)
    else
        log.error("Error creating user "..username.." from chat "..chat_id.." : "..err)
    end
end

function UserRepository:retrieve(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local result, err = self._storage:query("select * from tgusers where chat_id=%s", {chat_id})
    if result then
        log.debug("Retrieved user "..utils.tabletostring(result).." by chat id "..chat_id)
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving user by chat id "..chat_id..": "..err)
        return nil
    end
end

function UserRepository:delete(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local result, err = self._storage:query(
        "delete from tgusers where chat_id=%s",
        {chat_id}
    )
    if result then
        log.debug("Deleted user by chat id "..chat_id)
    else
        log.error("Error deleting user by chat id "..chat_id..": "..err)
    end
end

local AccountsRepository = Repository:new()

function AccountsRepository:create(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local username = params.username
    local result, err = self._storage:query(
        "insert into igaccounts (tguser_id, username) values (%s, %s)",
        {chat_id, username}
    )
    if result then
        log.debug("Added Instagram account @"..username.." from chat "..chat_id)
    else
        log.error("Error adding Instagram account @"..username.." from chat "..chat_id.." : "..err)
    end
end

function AccountsRepository:retrieve(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local username = params.username
    local query
    if username then
        query = {"select * from igaccounts where tguser_id=%s and username=%s", {chat_id, username}}
    else
        query = {"select * from igaccounts where tguser_id=%s", {chat_id}}
    end
    local result, err = self._storage:query(table.unpack(query))
    if result then
        log.debug("Retrieved Instagram accounts: "..utils.tabletostring(result).." by chat id "..chat_id)
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving Instagram accounts by chat id "..chat_id..": "..err)
        return nil
    end
end

function AccountsRepository:delete(params)
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = params.chat_id
    local username = params.username
    local result, err = self._storage:query(
        "delete from igaccounts where tguser_id=%s and username=%s",
        {chat_id, username}
    )
    if result then
        log.debug("Removed Instagram account @"..username.." from observable list of chat "..chat_id)
    else
        log.error("Error removing Instagram account @"..username.." of chat"..chat_id..": "..err)
    end
end

local PhotosRepository = Repository:new()

function PhotosRepository:create(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local photo_date = params.photo_date
    local url = params.url
    local result, err = self._storage:query(
        "insert into igphotos (tguser_id, photo_date, url) values (%s, %s, %s)",
        {chat_id, photo_date, url}
    )
    if result then
        log.debug("Added Instagram photo "..url.." for user "..chat_id)
    else
        log.error("Error adding Instagram photo "..url.." for user "..chat_id.." : "..err)
    end
end

function PhotosRepository:retrieve(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local page = params.page or 1
    local page_size = params.page_size or 10
    local result, err = self._storage:query(
        "select * from igphotos where chat_id=%s order by photo_date desc limit %d offset %d",
        {chat_id, page_size, page}
    )
    if result then
        log.debug("Retrieved Instagram photos: "..utils.tabletostring(result).." by chat id "..chat_id)
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving Instagram photos by chat id "..chat_id..": "..err)
        return nil
    end
end

local StoriesRepository = Repository:new()

function StoriesRepository:create(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local story_date = params.story_date
    local url = params.url
    local result, err = self._storage:query(
        "insert into igstories (tguser_id, story_date, url) values (%s, %s, %s)",
        {chat_id, story_date, url}
    )
    if result then
        log.debug("Added Instagram story "..url.." for user "..chat_id)
    else
        log.error("Error adding Instagram story "..url.." for user "..chat_id.." : "..err)
    end
end

function StoriesRepository:retrieve(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = params.chat_id
    local page = params.page or 1
    local page_size = params.page_size or 10
    local result, err = self._storage:query(
        "select * from igstories where chat_id=%s order by story_date desc limit %d offset %d",
        {chat_id, page_size, page}
    )
    if result then
        log.debug("Retrieved Instagram stories: "..utils.tabletostring(result).." by chat id "..chat_id)
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving Instagram stories by chat id "..chat_id..": "..err)
        return nil
    end
end

_M.UserRepository = UserRepository
_M.AccountsRepository = AccountsRepository
_M.PhotosRepository = PhotosRepository
_M.StoriesRepository = StoriesRepository

return _M