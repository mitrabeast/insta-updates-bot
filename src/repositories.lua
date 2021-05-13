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

function Repository:create()
    error("Abstract method.")
end

function Repository:retrieve()
    error("Abstract method.")
end

function Repository:update()
    error("Abstract method.")
end

function Repository:delete()
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
    local result, err = self._storage:query(
        "select * from tgusers where chat_id=%s",
        {chat_id}
    )
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

local PhotosRepository = Repository:new()

local StoriesRepository = Repository:new()

_M.UserRepository = UserRepository
_M.AccountsRepository = AccountsRepository
_M.PhotosRepository = PhotosRepository
_M.StoriesRepository = StoriesRepository

return _M