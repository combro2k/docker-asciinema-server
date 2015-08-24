FROM combro2k/ubuntu-debootstrap:14.04
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>

ENV SCRIPT="/usr/local/bin/install.sh" \
    APP_HOME="/home/asciinema" \
    APP_USER="asciinema"

ADD resources/bin/* /usr/local/bin/

RUN chmod +x /usr/local/bin/* \
    bash ${SCRIPT} \
    install_custom_repo \
    install_dependencies \
    compile_libtsm

USER ${APP_USER}

RUN bash ${SCRIPT} \
    install_ruby_rvm \
    install_asciinema \
    configure_asciinema

CMD ['/usr/local/bin/run']
