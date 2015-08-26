FROM combro2k/ubuntu-debootstrap:14.04

MAINTAINER Martijn van Maurik <docker@vmaurik.nl>

ENV HOME=/root \
    APP_USER=asciinema \
    INSTALL_LOG=/var/log/build.log \
    APP_HOME=/home/asciinema \
    ASCIINEMA_SERVER=/home/asciinema/server

ADD resources/bin/* /usr/local/bin/

VOLUME ['/data']

RUN chmod +x /usr/local/bin/* && /bin/bash --login -c '/usr/local/bin/setup.sh build'

CMD ['/usr/local/bin/run']
