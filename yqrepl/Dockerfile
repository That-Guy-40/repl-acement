FROM debian:stable-slim
RUN apt update && apt install -y curl bat vim nano jed jove tmux entr

# install yq (Mike Farah's Go implementation)
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
      -o /usr/local/bin/yq && chmod a+x /usr/local/bin/yq

RUN dpkg-divert --package batcat --add --rename --divert /usr/bin/bat /usr/bin/batcat

# enable nano's syntax highlighting
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc

COPY yqrepl /bin
RUN chmod a+x /bin/yqrepl
COPY examples.yq /root/.repl.yq
CMD yqrepl
