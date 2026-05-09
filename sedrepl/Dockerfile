FROM debian:stable-slim
RUN apt update && apt install -y sed vim nano jed jove tmux entr bash

# enable nano's syntax highlighting (a little overboard, I know)
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc

COPY sedrepl /bin
RUN chmod a+x /bin/sedrepl
COPY examples.sed /root/.repl.sed
CMD sedrepl
