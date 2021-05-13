local _M = {}

local InstagramService = {
    _website = "https://instasaved.net",
    _photos_url = "/save-profile-posts",
    _stories_url = "/",
    _photos_type = "profile",
    _stories_type = "story"
}

function InstagramService:new()
    local object = {}

    setmetatable(object, self)
    self.__index = self
    return object
end

function InstagramService:_make_request(url)
    return ""
end

function InstagramService:_get_token(url)
    return ""
end

function InstagramService:get_account(username)
    return {}
end

function InstagramService:get_photos(username)
    return {}
end

function InstagramService:get_stories(username)
    return {}
end

_M.InstagramService = InstagramService

return _M