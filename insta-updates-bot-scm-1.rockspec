package = "insta-updates-bot"
version = "scm-1"
source = {
   url = "git+https://github.com/m1tr4b34st/insta-updates-bot"
}
description = {
   homepage = "https://github.com/m1tr4b34st/insta-updates-bot",
   license = "MIT"
}
dependencies = {
   "telegram-bot-lua",
   "luasocket",
   "pgmoon",
   "luaossl"
}
build = {
   type = "builtin",
   modules = {
      main = "src/main.lua"
   }
}
