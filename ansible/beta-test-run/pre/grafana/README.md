# Graylog Ansible Playbook

Build: 13m

This repository contains Ansible playbooks for installing, configuring, and uninstalling Graylog, MongoDB, and related components on both Debian and Windows systems.

## Usage

To install MongoDB, Graylog Data Node, and Graylog Server, run: `ansible-playbook playbook.yaml` 

To configure A Debian-based or Windows client, run: `ansible-playbook -i inventory.yml playbook.yml --extra-vars "install=false"` 

 
## Variables

### Server Installer Variables 
The following variables are defined in `roles/install/vars/main.yml`:


`graylog_install`: Boolean to control the installation of Graylog components.
`graylog_configure`: Boolean to control the configuration of Graylog components.
`graylog_uninstall`: Boolean to control the uninstallation of Graylog components.
`HOST_IP`: IP address of the host.
`GRAYLOG_API_WAIT_TIME`: Wait time for Graylog API readiness.
`GRAYLOG_API_WAIT_RETRIES`: Number of retries for Graylog API readiness.
`mongodb_repo`: URL for the MongoDB repository.
`mongodb_key`: URL for the MongoDB GPG key.
`graylog_repo`: URL for the Graylog repository.
`graylog_password_secret`: Secret for Graylog password.
`graylog_admin_password`: Password for the Graylog admin user.
`graylog_admin_user`: Username for the Graylog admin user.
`vm_max_map_count`: Value for vm.max_map_count.
`HTTP_BIND_ADDRESS`: Bind address for Graylog HTTP.
`HTTP_PUBLISH_URI`: Publish URI for Graylog HTTP.
`HTTP_EXTERNAL_URI`: External URI for Graylog HTTP.
`MESSAGE_JOURNAL_MAX_SIZE`: Maximum size for the message journal.
`MESSAGE_JOURNAL_MAX_AGE`: Maximum age for the message journal.
`CA_ORGANIZATION`: Organization name for the CA.
`RENEWAL_POLICY`: Renewal policy for the CA.

### Client Installer Variables

The following variables are defined in `roles/client_configure/vars/main.yml`: 

SERVER_API_URL: URL for the Graylog API.
SERVER_API_USERNAME: Username for the Graylog API.
SERVER_API_PASSWORD: Password for the Graylog API.
NEW_TOKEN_NAME: Name for the new API token.
