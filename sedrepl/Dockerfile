FROM debian:stable-slim
# sed and bash are Essential packages, already in debian:stable-slim
RUN apt update && apt install -y bat vim nano jed jove tmux entr
RUN dpkg-divert --package batcat --add --rename --divert /usr/bin/bat /usr/bin/batcat

# enable nano's syntax highlighting (a little overboard, I know)
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc

COPY sedrepl /bin
RUN chmod a+x /bin/sedrepl
COPY examples.sed /root/.repl.sed
CMD sedrepl
