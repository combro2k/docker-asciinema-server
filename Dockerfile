FROM combro2k/ubuntu-debootstrap:14.04
 
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -qy curl patch gawk g++ gcc make libc6-dev patch libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev sudo git software-properties-common python-software-properties && \
    add-apt-repository ppa:tanguy-patte/phantomjs && \
    apt-get update && apt-get install -yq phantomjs && \
    useradd -ms /bin/bash app && \
    gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && \
    /bin/bash -l -c "curl -L get.rvm.io | bash -s stable --rails" && \
    /bin/basg -l -c "rvm install 2.1" && \
    /bin/bash -l -c "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc" && \
    /bin/bash -l -c "gem install bundler --no-ri --no-rdoc" && \
    git clone clone git://github.com/asciinema/asciinema.org.git /home/app/asciinema && \
    git clone git://people.freedesktop.org/~dvdhrm/libtsm /home/app/libtsm && \
    cd /home/app/libtsm && git checkout libtsm-3 && \
    (test -f ./configure || NOCONFIGURE=1 ./autogen.sh) && \
    ./configure --prefix=/usr/local && make && sudo make install
    
USER app
