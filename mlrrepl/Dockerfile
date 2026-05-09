FROM debian:stable-slim
RUN apt update && apt install -y miller bat vim nano jed jove tmux entr
RUN dpkg-divert --package batcat --add --rename --divert /usr/bin/bat /usr/bin/batcat

# enable nano's syntax highlighting
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc

COPY mlrrepl /bin
RUN chmod a+x /bin/mlrrepl
COPY examples.mlr /root/.repl.mlr
CMD mlrrepl
