FROM combro2k/ubuntu-debootstrap:14.04
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>

ADD resources/bin/* /usr/local/bin/

RUN chmod +x /usr/local/bin/*
RUN /usr/local/bin/install.sh \
    install_custom_repo \
    install_dependencies \
    compile_libtsm

USER app

RUB /usr/local/bin/install.sh \
    install_ruby_rvm \
    install_asciinema \
    configure_asciinema

CMD ['/usr/local/bin/run']
