#!/bin/bash

trap '{ echo -e "error ${?}\nthe command executing at the time of the error was\n${BASH_COMMAND}\non line ${BASH_LINENO[0]}" && tail -n 10 ${INSTALL_LOG} && exit $? }' ERR

DEBIAN_FRONTEND="noninteractive"
INSTALL_LOG="/var/log/build.log"

APP_USER="asciinema"
APP_HOME="/home/${APP_USER}"
ASCIINEMA_SERVER="/${APP_HOME}/server"
RAILS_ENV="production"

CUR_USER="$(id -un)"
CUR_UID="$(id -u)"

PACKAGES=(
    'build-essential'
    'g++'
    'flex'
    'bison'
    'gperf'
    'perl'
    'libsqlite3-dev'
    'libfontconfig1-dev'
    'libicu-dev'
    'libfreetype6'
    'libssl-dev'
    'libpng-dev'
    'libjpeg-dev'
    'python'
    'libx11-dev'
    'libxext-dev'
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
    'postgresql'
    'rsyslog'
    'sqlite3'
    'sudo'
    'supervisor'
    'zlib1g-dev'
    'build-essential'
    'chrpath'
    'libssl-dev'
    'libxft-dev'
    'libfreetype6'
    'libfreetype6-dev'
    'libfontconfig1'
    'libfontconfig1-dev'
)

# install all dependencies
pre_install() {
	if [ "${CUR_UID}" -ne 0 ]
	then
		echo "Need to be root to run ${FUNCNAME[0]} (running as ${CUR_USER})"
		return 1
	fi

	apt-get update 
	apt-get install -yq ${PACKAGES[@]}

	if [ ! -f "/usr/local/lib/libtsm.a" ]
	then
		echo "Compiling libtsm-3"

		mkdir -p "/tmp/libtsm"
		pushd "/tmp/libtsm"
		curl --silent -L http://freedesktop.org/software/kmscon/releases/libtsm-3.tar.xz | tar Jx --strip-components=1
		[ ! -f "./configure" ] && NOCONFIGURE=1 ./autogen.sh
		./configure --prefix=/usr/local && make && make install
		popd

		rm -fr "/tmp/libtsm"
	fi

	if [ ! -d "/opt/phantomjs" ]
	then
        echo "Compiling phantomjs"

        git clone git://github.com/ariya/phantomjs.git /opt/phantomjs
        pushd "/opt/phantomjs"
        git checkout 2.0
        ./build.sh --confirm
        ln -s /opt/phantomjs/bin/phantomjs /usr/bin/phantomjs
        popd
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

	if [ -d "${ASCIINEMA_SERVER}" ]
	then
		pushd "${ASCIINEMA_SERVER}"
		bundle install
		#createdb -E unicode --template=template0
		#bundle exec rake --silent --no-deprecation-warnings db:setup
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
		${task} | tee -a "${INSTALL_LOG}" > /dev/null 2>&1 || exit 1
	done

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
