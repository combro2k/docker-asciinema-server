#!/bin/bash
set -e

e () {
    errcode=$? # save the exit code as the first thing done in the trap function
    echo "error $errorcode"
    echo "the command executing at the time of the error was"
    echo "$BASH_COMMAND"
    echo "on line ${BASH_LINENO[0]}"
    #tail -n 25 ${INSTALL_LOG}
    exit 1  # or use some other value or do return instead
}

trap e ERR

ASCIICEMA_SERVER="${APP_HOME}/asciinema.org"
DEBIAN_FRONTEND=noninteractive
TMP_DIR="$(mktemp -u -d -t tsmXXXXXX)"
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

create_user(){
    id "${APP_USER}" > /dev/null 2>&1 && return 0
    [[ "${UID}" -ne 0 ]] && echo "Need to be root to run this command!" && return 1;

    echo "Creating user ${APP_USER}..."
    useradd -d "${APP_HOME}" -m -s "/bin/bash" "${APP_USER}"
    echo "${APP_USER} = NOPASSWD: ALL" > "/etc/sudoers.d/{APP_USER}"
}

compile_libtsm() {
    [ -e "/usr/local/lib/libtsm.a" ] && return 0
    [[ "${UID}" -ne 0 ]] && echo "Need to be root to run this command!" && return 1;

    echo "Compiling libtsm-3"
    git clone -q git://people.freedesktop.org/~dvdhrm/libtsm "${TMP_DIR}"
    pushd "${TMP_DIR}"

    git checkout libtsm-3
    test -f ./configure || NOCONFIGURE=1 ./autogen.sh
    ./configure --prefix=/usr/local
    make
    make install
    popd

    rm -fr "${TMP_DIR}"

    return 0
}

install_custom_repo()
{
    [[ "${UID}" -ne 0 ]] && echo "Need to be root to run this command!" && return 1;

    [ ! -f "/usr/bin/add-apt-repository" ] && apt-get update && apt-get install -yq python-software-properties software-properties-common

    add-apt-repository -y ppa:tanguy-patte/phantomjs
    apt-get update

    return 0
}

install_dependencies() {
    [[ "${UID}" -ne 0 ]] && echo "Need to be root to run this command!" && return 1;

    apt-get install -yq ${PACKAGES[@]}

    return 0
}

install_ruby_rvm() {
    [ -d "${APP_HOME}/.rvm/" ] && return 1
    [[ "${UID}" -ne 0 ]] && echo "Need to be root to run this command!" && return 1;

    echo "Installing RVM ruby..."
    gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
    curl -L get.rvm.io | bash -s stable --rails
    rvm install 2.1
    echo 'gem: --no-ri --no-rdoc' > ${APP_HOME}/.gemrc
    gem install bundler rake --no-ri --no-rdoc

    return 0
}

install_asciinema() {
    [ -d "${ASCIICEMA_SERVER}" ] && return 1
    [[ "${USER}" != "${APP_USER}" ]] && echo "Need to be ${APP_USER} to run this command" && return 1;

    echo "Checking out asciinema.org..."
    git -q clone git://github.com/asciinema/asciinema.org.git "${ASCIICEMA_SERVER}"

    return 0
}

chown_asciinema() {
    [[ "${UID}" -ne 0 ]] && echo "Need to be root to run this command!" && return 1;

    echo "Setting the correct user rights on ${ASCIICEMA_SERVER}..."
    chown -R "${APP_USER}:${APP_USER}" "${ASCIICEMA_SERVER}"

    return 0
}

configure_asciinema() {
    [[ "${USER}" != "${APP_USER}" ]] && echo "Need to be ${APP_USER} to run this command" && return 1;
    [ ! -d "${ASCIICEMA_SERVER}" ] && install_asciinema
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

if [ -z "${@}" ]
then
    echo "No parameters given!"
    echo "Available functions:"
    echo

    compgen -A function

    exit 1
else
    for a in ${@}
    do
        ${a} || exit 1
    done
fi

exit 0
