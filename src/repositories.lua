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

function UserRepository:create()
    print()
end

function UserRepository:retrieve()
    error("Abstract method.")
end

function UserRepository:delete()
    error("Abstract method.")
end

local AccountsRepository = Repository:new()

local PhotosRepository = Repository:new()

local StoriesRepository = Repository:new()

_M.UserRepository = UserRepository
_M.AccountsRepository = AccountsRepository
_M.PhotosRepository = PhotosRepository
_M.StoriesRepository = StoriesRepository

return _M