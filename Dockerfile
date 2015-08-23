FROM combro2k/debian-debootstrap:8
 
RUN apt-get update

RUN apt-get install -qy curl patch gawk g++ gcc make libc6-dev patch libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev
RUN useradd -ms /bin/bash app

RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && \
    /bin/bash -l -c "curl -L get.rvm.io | bash -s stable --rails" && \
    /bin/bash -l -c "rvm install 2.1" && \
    /bin/bash -l -c "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc" && \
    /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

USER app
