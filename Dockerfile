FROM combro2k/ubuntu-debootstrap:14.04
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>

ADD resources/bin/* /usr/local/bin/

RUN chmod +x /usr/local/bin/* && /bin/bash -l -c "/usr/local/bin/setup.sh build"

USER asciinema

CMD ['/usr/local/bin/run']
