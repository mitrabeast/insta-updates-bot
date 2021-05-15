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
    local chat_id = tostring(params.chat_id)
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
    if type(params) ~= "table" then return nil end
    local query_config = {"select * from tgusers", {}}
    if params.chat_id then
        query_config = {"select * from tgusers where chat_id=%s", {tostring(params.chat_id)}}
    end
    local result, err = self._storage:query(table.unpack(query_config))
    if result then
        log.debug("Retrieved user(s) "..utils.tabletostring(result))
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving user(s): "..err)
        return nil
    end
end

function UserRepository:delete(params)
    if type(params) ~= "table" or not params.chat_id then return nil end
    local chat_id = tostring(params.chat_id)
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
    local chat_id = tostring(params.chat_id)
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
    local chat_id = tostring(params.chat_id)
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
    local chat_id = tostring(params.chat_id)
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
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = tostring(params.chat_id)
    local username = params.username
    local photo_date = tonumber(params.photo_date)
    local url = params.url
    local result, err = self._storage:query(
        "insert into igphotos (tguser_id, photo_date, url, username) "..
        "values (%s, to_timestamp(%d::bigint)::timestamp, %s, %s)",
        {chat_id, photo_date, url, username}
    )
    if result then
        log.debug("Added Instagram photo "..url.." for user "..username)
    else
        log.error("Error adding Instagram photo "..url.." for user "..username.." : "..err)
    end
end

function PhotosRepository:retrieve(params)
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = tostring(params.chat_id)
    local username = params.username
    local photo_date = tonumber(params.photo_date)
    local page = params.page or 1
    local page_size = params.page_size or 10
    local query_config = {
        "select * from igphotos where tguser_id=%s and username=%s order by photo_date desc limit %d offset %d",
        {chat_id, username, page_size, page}
    }
    if photo_date then
        query_config = {
            "select * from igphotos where tguser_id=%s and username=%s "..
            "and photo_date=to_timestamp(%d::bigint)::timestamp",
            {chat_id, username, photo_date}
        }
    end
    local result, err = self._storage:query(table.unpack(query_config))
    if result then
        log.debug("Retrieved Instagram photos: "..utils.tabletostring(result).." for @"..username)
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving Instagram photos by chat id "..username..": "..err)
        return nil
    end
end

function PhotosRepository:delete(params)
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = tostring(params.chat_id)
    local username = params.username
    local result, err = self._storage:query(
        "delete from igphotos where tguser_id=%s and username=%s",
        {chat_id, username}
    )
    if result then
        log.debug("Removed Instagram photos of @"..username.." of chat "..chat_id)
    else
        log.error("Error removing Instagram photos of @"..username.." of chat"..chat_id..": "..err)
    end
end

local StoriesRepository = Repository:new()

function StoriesRepository:create(params)
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = tostring(params.chat_id)
    local username = params.username
    local story_date = tonumber(params.story_date)
    local url = params.url
    local result, err = self._storage:query(
        "insert into igstories (tguser_id, story_date, url, username) "..
        "values (%s, to_timestamp(%d::bigint)::timestamp, %s, %s)",
        {chat_id, story_date, url, username}
    )
    if result then
        log.debug("Added Instagram story "..url.." for user "..username)
    else
        log.error("Error adding Instagram story "..url.." for user "..username.." : "..err)
    end
end

function StoriesRepository:retrieve(params)
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = tostring(params.chat_id)
    local username = params.username
    local url = params.url
    local page = params.page or 1
    local page_size = params.page_size or 10
    local query_config = {
        "select * from igstories where tguser_id=%s and username=%s order by story_date desc limit %d offset %d",
        {chat_id, username, page_size, page}
    }
    if url then
        query_config = {
            "select * from igstories where tguser_id=%s and username=%s and url=%s",
            {chat_id, username, url}
        }
    end
    local result, err = self._storage:query(table.unpack(query_config))
    if result then
        log.debug("Retrieved Instagram stories: "..utils.tabletostring(result).." by chat id "..chat_id)
        if next(result) == nil then return nil else return result end
    else
        log.error("Error retrieving Instagram stories by chat id "..chat_id.." and username "..username..": "..err)
        return nil
    end
end

function StoriesRepository:delete(params)
    if type(params) ~= "table" or not params.chat_id or not params.username then return nil end
    local chat_id = tostring(params.chat_id)
    local username = params.username
    local result, err = self._storage:query(
        "delete from igstories where tguser_id=%s and username=%s",
        {chat_id, username}
    )
    if result then
        log.debug("Removed Instagram stories of @"..username.." of chat "..chat_id)
    else
        log.error("Error removing Instagram stories of @"..username.." of chat"..chat_id..": "..err)
    end
end

_M.UserRepository = UserRepository
_M.AccountsRepository = AccountsRepository
_M.PhotosRepository = PhotosRepository
_M.StoriesRepository = StoriesRepository

return _M