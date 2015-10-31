#!/bin/bash -e 

export RAILS_ENV=production

load_rvm()
{
	if [ -f "${HOME}/.rvm/scripts/rvm" ]
	then
		source ${HOME}/.rvm/scripts/rvm
	else
		echo "Could not load RVM"
		exit 1
	fi
}

load_rvm

cd ${HOME}/server
rails server
