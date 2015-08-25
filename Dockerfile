FROM combro2k/ubuntu-debootstrap:14.04
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>
ADD resources/bin/* /usr/local/bin/
VOLUME ['/data']
RUN chmod +x /usr/local/bin/* && /bin/bash -l -c "/usr/local/bin/setup.sh build"
CMD ['/usr/local/bin/run']
