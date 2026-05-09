FROM debian:stable-slim
RUN apt update && apt install -y jq bat vim nano jed jove tmux entr
RUN dpkg-divert --package batcat --add --rename --divert /usr/bin/bat /usr/bin/batcat

# enable nano's syntax highlighting (a little overboard, I know)
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc

COPY jqrepl /bin
RUN chmod a+x /bin/jqrepl
COPY examples.jq /root/.repl.jq
CMD jqrepl
