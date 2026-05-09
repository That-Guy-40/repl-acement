FROM debian:stable-slim
RUN apt update && apt install -y perl bat vim nano jed jove tmux entr
RUN dpkg-divert --package batcat --add --rename --divert /usr/bin/bat /usr/bin/batcat

# enable nano's syntax highlighting
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc

COPY perlrepl /bin
RUN chmod a+x /bin/perlrepl
COPY examples.pl /root/.repl.pl
CMD perlrepl
