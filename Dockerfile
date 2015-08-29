FROM combro2k/ruby-rvm:latest
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>
ENV HOME=/root

VOLUME ["/data"]
ADD resources/bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/* && /bin/bash --login -c '/usr/local/bin/setup.sh build'
ADD resources/etc/ /etc/
CMD ["/usr/bin/supervisord", "-c" "/etc/supervisor/supervisord.conf"]
