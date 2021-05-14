local https = require "ssl.https"
local ltn12 = require "ltn12"
local json = require "dkjson"
local utils = require "src/utils"

local _M = {}

local InstagramService = {
    _instagram_url = "https://instagram.com",
    _service_url = "https://instasaved.net",
    _ajax_url = "/ajax-instasaver",
    _profile_picture_url = "/save-profile-picture",
    _photos_url = "/save-profile-posts",
    _stories_url = "/save-stories",
    _profile_picture_type = "profilePic",
    _photos_type = "profile",
    _stories_type = "story"
}

function InstagramService:new()
    local object = {}

    setmetatable(object, self)
    self.__index = self
    return object
end

function InstagramService:toprofileurl(username)
    return self._instagram_url.."/"..username.."/"
end

function InstagramService:get_account(username)
    local token, xsrf_token, session = self:_get_token(self._profile_picture_url, username)
    if not token then
        log.error("Error getting token for "..username)
        return nil
    end
    local url = self._service_url..self._ajax_url
    local parameters = {
        cursor = "1",
        igtv_ids = "[]",
        token = token,
        ["type"] = self._profile_picture_type,
        username = self:toprofileurl(username),
    }
    local extra_headers = {
        ["Cookie"] = "instasaved_session="..session.."; XSRF-TOKEN="..xsrf_token,
        ["X-XSRF-TOKEN"] = utils.unescape(xsrf_token)
    }
    local success, account = self:_request("POST", url, parameters, extra_headers)
    if not success then
        log.error("Error getting account of "..self:toprofileurl(username))
        return nil
    end
    local account_obj, pos, err = json.decode(account, 1, nil)
    if err then
        log.error("Error decoding account to JSON object: "..err)
        return nil
    end
    local user = account_obj.user
    if not user then
        log.info("User @"..username.." not found, or it's profile is closed.")
        return nil
    end
    account = {
        username = user.username or username,
        profile_picture = user["profilePicUrl"]
    }
    return account
end

function InstagramService:get_photos(username)

end

function InstagramService:get_stories(username)

end

function InstagramService:_request(method, url, parameters, extra_headers)
    parameters = parameters or {}
    extra_headers = extra_headers or {}
    local response = {}
    local encoded_parameters = json.encode(parameters)
    local request_settings = {
        ['url'] = url,
        ['method'] = method,
        ['source'] = ltn12.source.string(encoded_parameters),
        ['sink'] = ltn12.sink.table(response)
    }
    if next(parameters) then
        request_settings['headers'] = {
            ['User-Agent'] = "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:87.0) Gecko/20100101 Firefox/87.0",
            ['Accept'] = 'application/json, text/plain, */*',
            ['Content-Type'] = 'application/json;charset=utf-8',
            ['Content-Length'] = #encoded_parameters
        }
    end
    if next(extra_headers) then
        for key, value in pairs(extra_headers) do
            request_settings['headers'][key] = value
        end
    end
    log.debug("Making request: "..method.." "..url.." settings: "..utils.tabletostring(request_settings))
    local _, code, headers, status = https.request(request_settings)
    if code == 200 then
        return true, table.concat(response), headers
    else
        log.error("Wrong status code: "..status.." for url "..url.." "..utils.tabletostring(headers))
        return false
    end
end

function InstagramService:_get_token(url_type, username)
    local url = self._service_url..url_type.."/"..username
    local success, page, headers = self:_request("GET", url)
    if not success then
        log.error("Error getting page with token by url: "..url)
        return nil
    end
    local cookies = headers["set-cookie"]
    local xsrf_token = "no-xsrf-token"
    local session = "no-session"
    if cookies then
        xsrf_token = cookies:match("XSRF%-TOKEN=(.-);") or xsrf_token
        session = cookies:match("instasaved_session=(.-);") or session
    end
    local token = page:match('%<input type="hidden" name="token" id="token" value="(.-)%">')
    log.debug("Got token "..token..", session "..session .." and xsrf-token "..xsrf_token.." for "..username)
    return token, xsrf_token, session
end

_M.InstagramService = InstagramService

return _M