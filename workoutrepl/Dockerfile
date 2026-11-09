FROM debian:stable-slim
# the REPL's own needs (bash, tmux, entr, an editor) and every external tool a drill's
# checker uses: awk comm find flock grep gzip join rsync sed sha256sum shellcheck
# systemd-analyze tar timeout xargs (coreutils, findutils and util-linux carry most of them)
RUN apt update && apt install -y bash tmux entr vim nano gawk sed grep coreutils findutils \
      util-linux gzip tar rsync shellcheck systemd procps

COPY workoutrepl walk.sh verify.sh vimrc /opt/workoutrepl/
COPY steps /opt/workoutrepl/steps
COPY workout /opt/workoutrepl/workout
# the REPL resolves its own path with readlink -f and looks for workout/ beside it, so the
# symlinks below are fine
RUN chmod a+x /opt/workoutrepl/workoutrepl /opt/workoutrepl/walk.sh /opt/workoutrepl/verify.sh \
      /opt/workoutrepl/workout/bin/workout /opt/workoutrepl/workout/demo.sh \
 && ln -s /opt/workoutrepl/workoutrepl /bin/workoutrepl \
 && ln -s /opt/workoutrepl/workout/bin/workout /bin/workout \
 && ln -s /opt/workoutrepl/walk.sh /bin/workout-walk

# The drills are graded as an ordinary user, never root: day 27 makes a source file
# unreadable and expects rsync to fail on it, which root never does (measured: as root,
# demo.sh reports "FAIL: 1 of 60 checks failed" on exactly that day).
RUN useradd -m -s /bin/bash learner
USER learner
WORKDIR /home/learner
# enable nano's syntax highlighting
RUN find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; >> ~/.nanorc
CMD workoutrepl
