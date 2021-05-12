local repositories = {}

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

function Repository:create(obj)
    return obj
end

function Repository:retrieve()
    return {}
end

function Repository:update(obj)
    print(obj)
end

function Repository:delete()
    print(1)
end

local UserRepository = Repository:new()

function UserRepository:create()
    print()
end



return repositories