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
    username = username or "no-username"
    return self._instagram_url.."/"..username.."/"
end

function InstagramService:get_account(username)
    local account = self:_api_request(self._profile_picture_type, username)
    if not account or not account.user then
        log.info("User @"..username.." not found, or it's profile is closed.")
        return nil
    end
    local profile_picture
    if account.medias then
        profile_picture = account.medias[1]['downloadUrl']
    end
    return {
        username = account.user.username or username,
        profile_picture = profile_picture
    }
end

function InstagramService:get_photos(username)
    local photos = self:_api_request(self._photos_type, username)
    if not photos or not photos.medias then
        log.info("User photos of @"..username.." not found, or it's profile is closed.")
        return nil
    end
    local photo_urls = {}
    for _, photo in pairs(photos.medias) do
        if photo.node.taken_at_timestamp and not photo.node.is_video then
            -- Add all photo urls if there are some photos in a post.
            if photo.node.edge_sidecar_to_children and photo.node.edge_sidecar_to_children.edges then
                local photo_date = photo.node.taken_at_timestamp
                for _, edge in pairs(photo.node.edge_sidecar_to_children.edges) do
                    if edge.node and edge.node.display_url and not edge.node.is_video then
                        table.insert(photo_urls, {
                            url = edge.node.display_url,
                            photo_date = photo_date
                        })
                        photo_date = photo_date + 1
                    end
                end
            -- Add one photo url if there are no more photos in a post.
            elseif photo.node.display_url then
                table.insert(photo_urls, {
                    url = photo.node.display_url,
                    photo_date = photo.node.taken_at_timestamp
                })
            else
                log.warn("Photo of @"..username.." has no display_url nor edge_sidecar_to_children property.")
            end
        end
    end
    return photo_urls
end

function InstagramService:get_stories(username)
    local stories = self:_api_request(self._stories_type, username)
    if not stories or not stories.medias then
        log.info("User stories of @"..username.." not found, or it's profile is closed.")
        return nil
    end
    local stories_urls = {}
    for _, story in pairs(stories.medias) do
        if story.type and story.downloadUrl then
            -- FIXME: calculate correct story_date
            table.insert(stories_urls, {
                url = story.downloadUrl,
                ["type"] = story.type,
                story_date = os.time()
            })
        end
    end
    return stories_urls
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

function InstagramService:_fetch_credentials(url_type, username)
    local url = self._service_url..url_type.."/"..username
    local success, page, headers = self:_request("GET", url)
    if not success then
        log.error("Error getting page with token by url: "..url)
        return nil
    end
    local cookies = headers["set-cookie"]
    local xsrf_token
    local session
    if cookies then
        xsrf_token = cookies:match("XSRF%-TOKEN=(.-);")
        session = cookies:match("instasaved_session=(.-);")
    end
    local token = page:match('%<input type="hidden" name="token" id="token" value="(.-)%">')
    log.debug(
        "Got token "..tostring(token)..", session "..tostring(session)..
        " and xsrf-token "..tostring(xsrf_token).." for "..username
    )
    return token, xsrf_token, session
end

function InstagramService:_api_request(request_type, username)
    local request_type_url
    if request_type == self._profile_picture_type then
        request_type_url = self._profile_picture_url
    elseif request_type == self._photos_type then
        request_type_url = self._photos_url
    elseif request_type == self._stories_type then
        request_type_url = self._stories_url
    else
        log.error("Wrong request type: "..request_type)
        return nil
    end
    local token, xsrf_token, session = self:_fetch_credentials(request_type_url, username)
    if not token or not xsrf_token or not session then
        log.error("Error fetching credentials for "..username)
        return nil
    end
    local url = self._service_url..self._ajax_url
    local parameters = {
        cursor = "1",
        igtv_ids = "[]",
        token = token,
        ["type"] = request_type,
        username = self:toprofileurl(username),
    }
    local extra_headers = {
        ["Cookie"] = "instasaved_session="..session.."; XSRF-TOKEN="..xsrf_token,
        ["X-XSRF-TOKEN"] = utils.unescape(xsrf_token)
    }
    local success, data = self:_request("POST", url, parameters, extra_headers)
    if not success then
        log.error("Error getting data from ajax request "..self:toprofileurl(username))
        return nil
    end
    local obj, _, err = json.decode(data, 1, nil)
    if err then
        log.error("Error decoding account to JSON object: "..err)
        return nil
    end
    return obj
end

local UpdatesService = {
    _instagram_service = nil,
    _photos_repo = nil,
    _stories_repo = nil,
}

function UpdatesService:new(instagram_service, photos_repo, stories_repo)
    local object = {}
    object._instagram_service = instagram_service
    object._photos_repo = photos_repo
    object._stories_repo = stories_repo

    setmetatable(object, self)
    self.__index = self
    return object
end

function UpdatesService:collect_photo_updates(chat_id, username)
    local photos = {}
    local last_photos = self._instagram_service:get_photos(username)
    for _, last_photo in pairs(last_photos) do
        local existing_photo = self._photos_repo:retrieve({
            chat_id = chat_id,
            username = username,
            photo_date = last_photo.photo_date
        })
        if not existing_photo then
            table.insert(photos, last_photo)
            self._photos_repo:create({
                chat_id = chat_id,
                username = username,
                url = last_photo.url,
                photo_date = last_photo.photo_date
            })
        end
    end
    return photos
end

function UpdatesService:collect_story_updates(chat_id, username)
    local stories = {}
    local last_stories = self._instagram_service:get_stories(username)
    for _, last_story in pairs(last_stories) do
        local existing_story = self._stories_repo:retrieve({
            chat_id = chat_id,
            username = username,
            url = last_story.url
        })
        if not existing_story then
            table.insert(stories, last_story)
            self._stories_repo:create({
                chat_id = chat_id,
                username = username,
                url = last_story.url,
                story_date = last_story.story_date
            })
        end
    end
    return stories
end

_M.InstagramService = InstagramService
_M.UpdatesService = UpdatesService

return _M