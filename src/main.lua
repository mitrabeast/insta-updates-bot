log = require "src/log"
local signal = require "posix.signal"
local Storage = require "src/storage"
local TelegramBot = require "src/bot"

log.level = "debug"

local database_config = {
    username = os.getenv("DB_USER"),
    password = os.getenv("DB_PASSWORD"),
    host = os.getenv("DB_HOST"),
    port = os.getenv("DB_PORT"),
    name = os.getenv("DB_NAME")
}
local telegram_bot_token = os.getenv("TELEGRAM_BOT_TOKEN")

local storage = Storage:new(database_config)
local insta_updates_bot = TelegramBot:new(telegram_bot_token, storage)

signal.signal(signal.SIGINT, function(signum)
    log.info("SIGINT received, stopping.")
    storage:close()
    os.exit(128 + signum)
end)

insta_updates_bot:start()