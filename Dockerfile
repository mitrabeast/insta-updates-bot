FROM ubuntu:latest
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update && apt-get install -y lua5.3 liblua5.3-dev luarocks libssl-dev lua-posix git
ADD ./ /opt/app
WORKDIR /opt/app
RUN luarocks install insta-updates-bot-scm-1.rockspec
CMD lua src/main.lua