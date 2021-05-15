local pgmoon = require("pgmoon")

local Storage = {
    _username = "user",
    _password = "password",
    _host = "localhost",
    _port = "5342",
    _name = "database",
    _database = nil
}

local function _connect(config)
    local database = pgmoon.new({
        host = config._host,
        port = config._port,
        database = config._name,
        user = config._username,
        password = config._password,
        ssl = true
    })
    log.debug("Connecting to "..config._host..":"..config._port.."/"..config._name.." database...")
    local success, error = database:connect()
    if success then
        log.info("Connected to database "..config._name.." successfuly.")
    else
        log.error("Error connecting to database "..config._name..": "..error)
    end
    return database
end

function Storage:new(config)
    local object = {}
    object._username = config.username or Storage._username
    object._password = config.password or Storage._password
    object._host = config.host or Storage._host
    object._port = config.port or Storage._port
    object._name = config.name or Storage._name
    object._database = _connect(object)

    setmetatable(object, self)
    self.__index = self
    return object
end

function Storage:query(query, params)
    local escaped_params = {}
    for _, value in pairs(params) do
        if type(value) == "string" then
            local escaped_value = self._database:escape_literal(value)
            table.insert(escaped_params, escaped_value)
        else
            table.insert(escaped_params, value)
        end
    end
    local formatted_query = string.format(query, table.unpack(escaped_params))
    log.debug("Executing query: "..formatted_query)
    return self._database:query(formatted_query)
end

function Storage:close()
    if self._database then
        self._database:disconnect()
        log.info("Disconnected from "..self._name.." database.")
    else
        log.error("No database object, or not connected to "..self._name.."!")
    end
end

return Storage