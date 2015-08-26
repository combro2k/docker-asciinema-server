#!/bin/bash
set -Ea

/usr/local/bin/setup.sh configure_asciinema

# Start the services
supervisorctl start rsyslog
supervisorctl start asciinema
supervisorctl start sidekiq
