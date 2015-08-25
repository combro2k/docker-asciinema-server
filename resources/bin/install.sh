#!/bin/bash
set -e

e () {
    errcode=$? # save the exit code as the first thing done in the trap function
    echo "error $errorcode"
    echo "the command executing at the time of the error was"
    echo "$BASH_COMMAND"
    echo "on line ${BASH_LINENO[0]}" # && tail -n 25 ${INSTALL_LOG}
    exit 1  # or use some other value or do return instead
}

trap e ERR

export  \
    CUR_USER="$(id -un)"
    CUR_UID="$(id -u)"
    DEBIAN_FRONTEND="noninteractive" \
    APP_USER="asciinema" \
    APP_HOME="/home/${APP_USER}" \
    ASCIICEMA_SERVER="${APP_HOME}/asciinema-server" \
    TMP_DIR="$(mktemp -u -d -t tsmXXXXXX)" \
    PACKAGES=(
        'autoconf'
        'automake'
        'bison'
        'curl'
        'g++'
        'gawk'
        'gcc'
        'git'
        'libc6-dev'
        'libffi-dev'
        'libgdbm-dev'
        'libncurses5-dev'
        'libreadline6-dev'
        'libsqlite3-dev'
        'libssl-dev'
        'libtool'
        'libyaml-dev'
        'make'
        'patch'
        'phantomjs'
        'pkg-config'
        'sqlite3'
        'sudo'
        'zlib1g-dev'
    )

# root user functions
create_user(){
    [ "${CUR_UID}" -ne 0 ] && echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    if ! id -u "${APP_USER}" >/dev/null 2>&1
    then
        echo "Creating user ${APP_USER}..."
        useradd -d "${APP_HOME}" -m -s "/bin/bash" "${APP_USER}"
        echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${APP_USER}
    fi
}

compile_libtsm() {
    [ "${CUR_UID}" -ne 0 ] && echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    if [ ! -f "/usr/local/lib/libtsm.a" ]
    then
        echo "Compiling libtsm-3"

        mkdir -p "${TMP_DIR}"
        pushd "${TMP_DIR}"

        git clone -q git://people.freedesktop.org/~dvdhrm/libtsm .
        git checkout libtsm-3

        if [ ! -f "./configure" ]
        then
            NOCONFIGURE=1 ./autogen.sh
        fi

        ./configure --prefix=/usr/local
        make
        make install

        popd
        rm -fr "${TMP_DIR}"
    fi

    return 0
}

install_dependencies() {
    [ "${CUR_UID}" -ne 0 ] && echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    if [ ! -f "/usr/bin/add-apt-repository" ]
    then
        apt-get update
        apt-get install -yq python-software-properties software-properties-common
    fi

    add-apt-repository -y ppa:tanguy-patte/phantomjs
    apt-get update

    apt-get install -yq ${PACKAGES[@]}

    if [ ! -f "/usr/local/lib/libtsm.a" ]
    then
        compile_libtsm
    fi

    return 0
}

chown_asciinema() {
    [ "${CUR_UID}" -ne 0 ] && echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    echo "Setting the correct user rights on ${ASCIICEMA_SERVER}..."
    chown -R "${APP_USER}:${APP_USER}" "${ASCIICEMA_SERVER}"

    return 0
}


# asciinema specific user functions
install_asciinema() {
    [[ "${CUR_USER}" != "${APP_USER}" ]] && echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    if [ ! -d "${APP_HOME}/.rvm/" ]
    then
        install_ruby_rvm
    fi

    if [ ! -d "${ASCIICEMA_SERVER}" ]
    then
        echo "Checking out asciinema.org..."
        curl -sL https://github.com/asciinema/asciinema.org/archive/master.tar.gz | tar zx -C "${ASCIICEMA_SERVER}" --strip-components=1
    fi

    configure_asciinema

    return 0
}

install_ruby_rvm() {
    [[ "${CUR_USER}" != "${APP_USER}" ]] && echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    if [ ! -d "${APP_HOME}/.rvm/" ]
    then
        echo "Installing RVM ruby..."
        gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
        curl -L get.rvm.io | bash -s stable --rails
        rvm install 2.1
        echo 'gem: --no-ri --no-rdoc' > ${APP_HOME}/.gemrc
        gem install bundler rake --no-ri --no-rdoc
    fi

    return 0
}

configure_asciinema() {
    [[ "${CUR_USER}" != "${APP_USER}" ]] && echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})" && exit 1

    source "${APP_HOME}/.rvm/scripts/rvm"

    [ ! -e "/data/config/database.yml" ] && echo "Copying base skeleton" && cp "${ASCIICEMA_SERVER}/config/database.yml.example" "/data/config/database.yml"
    [ ! -L "${ASCIICEMA_SERVER}/config/database.yml" ] && ln -fs "/data/config/database.yml" "${ASCIICEMA_SERVER}/config/database.yml"
    [ "$(ls -A "${ASCIICEMA_SERVER}/log/*")" ] && rm -f "${ASCIICEMA_SERVER}/log/*"

    pushd "${ASCIICEMA_SERVER}"
    bundle install
    bundle exec rake db:setup
    popd

    mkdir -p "${ASCIICEMA_SERVER}/tmp"
    touch "${ASCIICEMA_SERVER}/tmp/restart.txt"

    return 0
}

build() {
    install_dependencies
    create_user

    sudo -H -u "${APP_USER}" ${0} install_asciinema
}

if [ $# -eq 0 ]
then
    echo "No parameters given! (${@})"
    echo "Available functions:"
    echo

    compgen -A function

    exit 1
else
    for a in ${@}
    do
        ${a}
    done
fi

exit 0
