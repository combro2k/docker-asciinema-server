#!/bin/bash

set -TEa

trap '{ echo -e "error ${?}\nthe command executing at the time of the error was\n${BASH_COMMAND}\non line ${BASH_LINENO[0]}" && tail -n 10 ${INSTALL_LOG} && exit $? }' ERR

DEBIAN_FRONTEND="noninteractive"
INSTALL_LOG="/var/log/build.log"

APP_USER="asciinema"
APP_HOME="/home/${APP_USER}"
ASCIINEMA_SERVER="/${APP_HOME}/server"
RAILS_ENV="production"

CUR_USER="$(id -un)"
CUR_UID="$(id -u)"

TMP_DIR="$(mktemp -u -d -t tsmXXXXXX) "
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
	'libgmp-dev'
	'libpq-dev'
	'libjson-c-dev'
	'libxml2-dev'
	'libxslt-dev'
	'libyaml-dev'
	'make'
	'nodejs'
	'patch'
	'phantomjs'
	'postgresql'
	'rsyslog'
	'sqlite3'
	'sudo'
	'supervisor'
	'zlib1g-dev'
)

# install all dependencies
pre_install() {
	if [ "${CUR_UID}" -ne 0 ]
	then
		echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})"
		return 1
	fi

	if [ ! -f "/usr/bin/add-apt-repository" ]
	then
		apt-get update
		apt-get install -yq python-software-properties software-properties-common
	fi

	add-apt-repository -y ppa:tanguy-patte/phantomjs
	apt-get update -yq
	apt-get install -yq ${PACKAGES[@]}

	if [ ! -f "/usr/local/lib/libtsm.a" ]
	then
		echo "Compiling libtsm-3"
		mkdir -p "${TMP_DIR}"
		curl --silent -L http://freedesktop.org/software/kmscon/releases/libtsm-3.tar.xz | tar Jx --strip-components=1 -C ${TMP_DIR}
		pushd "${TMP_DIR}"
		[ ! -f "./configure" ] && NOCONFIGURE=1 ./autogen.sh
		./configure --prefix=/usr/local && make && make install
		popd

		rm -fr "${TMP_DIR}"
	fi

        service postgresql start
	if [ ! -d "${APP_USER}" ]
	then
		echo "Creating user ${APP_USER}..."
		useradd -d "${APP_HOME}" -m -s "/bin/bash" "${APP_USER}"
		echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${APP_USER}

		echo "Creating ${APP_USER} as superuser for postgresql"
		sudo -u postgres -H createuser asciinema -s
	fi
        service postgresql stop

	if [ ! -d "/usr/local/rvm" ]
	then
		echo "Installing RVM ruby..."
		gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 2>&1 > /dev/null
		curl --silent -L https://get.rvm.io | bash

		if [ -f "/usr/local/rvm/scripts/rvm" ]
		then
			source /usr/local/rvm/scripts/rvm
		fi

		rvm install 2.1.7 && rvm --default use 2.1.7 && rvm alias create default 2.1.7
		echo 'gem: --no-document' | tee ${APP_HOME}/.gemrc
		gem install bundler
	fi

	return 0
}

chown_asciinema() {
	if [ "${CUR_UID}" -ne 0 ]
	then
		echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})"
		return 1
	fi

	echo "Setting the correct user rights on ${ASCIICEMA_SERVER}..."
	chown -R "${APP_USER}:${APP_USER}" "${ASCIICEMA_SERVER}" /data

	return 0
}

# asciinema specific user functions
install_asciinema() {
	if [[ "${CUR_USER}" != "${APP_USER}" ]]
	then
		if [ "${CUR_UID}" -eq 0 ]
		then
			sudo -E -H -u "${APP_USER}" ${0} ${FUNCNAME[0]}
			return $?
		else
			echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})"
			return 1
		fi
	fi

	if [ ! -d "${ASCIINEMA_SERVER}" ]
	then
		echo "Clone asciinema.org..."
		git clone https://github.com/asciinema/asciinema.org.git "${ASCIINEMA_SERVER}"
    else
        pushd "${ASCIINEMA_SERVER}"
        git stash
        git pull
        git stash apply
        popd
	fi

	configure_asciinema

	return 0
}

configure_asciinema() {
	if [[ "${CUR_USER}" != "${APP_USER}" ]]
	then
		if [ "${CUR_UID}" -eq 0 ]
		then
			sudo -E -H -u "${APP_USER}" ${0} ${FUNCNAME[0]}
			return $?
		else
			echo "Need to be ${APP_USER} to run ${FUNCNAME[0]} (running as ${CUR_USER})"
			return 1
		fi
	fi


	if [ ! -d "/data" ] || [ ! -d "/data/config" ]
	then
		sudo mkdir -p /data/config
		sudo chown -R "${APP_USER}:${APP_USER}" /data
	fi

	if [ ! -e "/data/config/database.yml" ]
	then
		echo "Creating base skeleton"

		echo -e "production:" | tee /data/config/database.yml
		echo -e " tadapter: postgresql" | tee -a /data/config/database.yml
		echo -e " encoding: unicode" | tee -a /data/config/database.yml
		echo -e " database: asciinema" | tee -a /data/config/database.yml
		echo -e " pool: 25" | tee -a /data/config/database.yml
		echo -e " min_messages: WARNING" | tee -a /data/config/database.yml
	fi

	if [ ! -L "${ASCIINEMA_SERVER}/config/database.yml" ]
	then
		ln -fs "/data/config/database.yml" "${ASCIINEMA_SERVER}/config/database.yml"
	fi

	if [ "$(ls -A "${ASCIINEMA_SERVER}/log/*")" ]
	then
		rm -f "${ASCIINEMA_SERVER}/log/*"
	fi

	if [ -f "/usr/local/rvm/scripts/rvm" ]
	then
		source /usr/local/rvm/scripts/rvm
	fi

	if [ -d "${ASCIINEMA_SERVER}" ]
	then
		pushd "${ASCIINEMA_SERVER}"
		bundle install
		createdb -E unicode --template=template0
		bundle exec rake --silent --no-deprecation-warnings db:setup
		mkdir -p "./tmp"
		touch "./tmp/restart.txt"
		popd
	fi

	return 0
}

build() {
	if [ ! -f "${INSTALL_LOG}" ]
	then
		touch "${INSTALL_LOG}"
	fi

	tasks=(
		'pre_install'
		'install_asciinema'
	)

	for task in ${tasks[@]}
	do
		echo "Running build task ${task}..."
		${task} | tee -a "${INSTALL_LOG}" 2>&1 > /dev/null || exit 1
	done

	service postgresql stop

	return 0
}

if [ $# -eq 0 ]
then
	echo "No parameters given! (${@})"
	echo "Available functions:"
	echo

	compgen -A function

	exit 1
else
	for task in ${@}
	do
		${task} || exit 1
	done
fi

exit 0
