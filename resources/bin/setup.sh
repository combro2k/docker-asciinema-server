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

# basic functions
access() {
    if [[ "${CUR_USER}" == "${1}" ]] || [[ "${CUR_UID}" == "${1}" ]]
    then
        return 0
    else
        echo "Need to be ${1} to run ${FUNCNAME[1]} (running as ${CUR_USER})"

        return 1
    fi
}

# install all dependencies
install_dependencies() {
    if [ "${CUR_UID}" -ne 0 ]
    then
        echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})"
        exit 1
    fi

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
        echo "Compiling libtsm-3"
        mkdir -p "${TMP_DIR}"
        curl -sSL http://freedesktop.org/software/kmscon/releases/libtsm-3.tar.xz | tar Jx --strip-components=1 -C ${TMP_DIR}
        pushd "${TMP_DIR}"
        [ ! -f "./configure" ] && NOCONFIGURE=1 ./autogen.sh
        ./configure --prefix=/usr/local && make && make install
        popd

        rm -fr "${TMP_DIR}"
    fi

    if [ ! -d "/usr/local/rvm" ]
    then
        echo "Installing RVM ruby..."
        gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
        curl -sSL https://get.rvm.io | bash

        if [ -f "/etc/profile.d/rvm.sh" ]
        then
            source /etc/profile.d/rvm.sh # load rvm if file exist
        fi

        rvm install 2.2.2 && rvm use 2.2.2
        echo 'gem: --no-document' | tee /root/.gemrc ${APP_HOME}/.gemrc > /dev/null 2>&1
        gem install bundler && gem update --system
    fi

    id -u "${APP_USER}"
    if [ $? -ne 0 ]
    then
        echo "Creating user ${APP_USER}..."
        useradd -d "${APP_HOME}" -m -s "/bin/bash" "${APP_USER}"
        echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${APP_USER}
    fi

    return 0
}

chown_asciinema() {
    if [ "${CUR_UID}" -ne 0 ]
    then
        echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})"
        exit 1
    fi

    echo "Setting the correct user rights on ${ASCIICEMA_SERVER}..."
    chown -R "${APP_USER}:${APP_USER}" "${ASCIICEMA_SERVER}"

    return 0
}

# asciinema specific user functions
install_asciinema() {
    if [[ "${CUR_USER}" != "${APP_USER}" ]]
    then
        echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})"
        exit 1
    fi

    if [ ! -d "${ASCIICEMA_SERVER}" ]
    then
        echo "Checking out asciinema.org..."
        curl -sSL https://github.com/asciinema/asciinema.org/archive/master.tar.gz | tar zx -C "${ASCIICEMA_SERVER}" --strip-components=1
    fi

    configure_asciinema

    return 0
}

configure_asciinema() {
    if [[ "${CUR_USER}" != "${APP_USER}" ]]
    then
        echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})"
        exit 1
    fi

    if [ ! -e "/data/config/database.yml" ]
    then
        echo "Copying base skeleton" && cp "${ASCIICEMA_SERVER}/config/database.yml.example" "/data/config/database.yml"
    fi

    if [ ! -L "${ASCIICEMA_SERVER}/config/database.yml" ]
    then
        ln -fs "/data/config/database.yml" "${ASCIICEMA_SERVER}/config/database.yml"
    fi

    if [ "$(ls -A "${ASCIICEMA_SERVER}/log/*")" ]
    then
        rm -f "${ASCIICEMA_SERVER}/log/*"
    fi

    if [ -f "/etc/profile.d/rvm.sh" ]
    then
        source /etc/profile.d/rvm.sh # load rvm if file exist
    fi

    if [ -d "${ASCIICEMA_SERVER}" ]
    then
        pushd "${ASCIICEMA_SERVER}"
        bundle install
        bundle exec rake db:setup
        mkdir -p "./tmp"
        touch "./tmp/restart.txt"
        popd
    fi

    return 0
}

build() {
    install_dependencies
    sudo -H -u "${APP_USER}" ${0} install_asciinema configure_asciinema
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
