FROM combro2k/ubuntu-debootstrap:14.04
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>

ENV HOME=/root

ADD resources/bin/ /usr/local/bin/

VOLUME ['/data']

RUN chmod +x /usr/local/bin/* && /bin/bash --login -c '/usr/local/bin/setup.sh build'

ADD resources/etc/ /etc/

CMD ['/usr/bin/supervisord', '-c' '/etc/supervisor/supervisord.conf']
