# AppDynamics Agent Management

A collection of scripts to handle agent downloads, installs and upgrades.

Supports:
* Java agent
* Machine agent
* DB agent

Will sync controller info, account info, and Analytics agent connection details underneath the Machine Agent.

## Getting Started
Download the latest release from https://github.com/derrekyoung/appd-agent-management/releases. Unzip the release and run `chmod u+x *.sh` on the files in the release directory so that your user can execute the scripts.

# Functionality

## Install/Upgrade Agent Locally
Operates on your local system. Install a brand new agent or upgrade a new agent in place. Upgrades will sync existing configurations and settings.

Usage: `./local-agent-install.sh ./AppServerAgent-4.2.6.0.zip`

### Settings:
1. `APPD_AGENT_HOME`: the install directory for the agents. The default is to install it in the same directory where you run the script.
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.


## Install/Upgrade Agent on Remote Server(s)
Operates on remote systems. Requires you to edit `remote-agent-install.py` and set the appropriates hosts, username and password or SSH key.

You must install Python Fabric on your management system (the system where you launch the script), but **NOT** on the remote systems. Communication to the systems has no external dependencies because all comms happen over SSH and Shell.

Usage: `./remote-agent-install.sh ./AppServerAgent-4.2.6.0.zip`

### Settings:
1. **REQUIRED** `REMOTE_HOSTS`: a string array of hosts in for format of username@HOSTNAME. This variable is **required** and you must set this to begin remote installations.
1. **REQUIRED** credentials:
    1. One of the following authentication mechanisms is required:
    1. `REMOTE_PASSWORD_PROMPT`: Will prompt you for the SSH password of the users defined in your list of `REMOTE_HOSTS`
    1. `REMOTE_SSH_KEY`: The location of the SSH key to access the servers
1. `REMOTE_APPD_HOME`: where to install the AppDynamics agents. Default is /opt/AppDynamics.
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.

### Install Python Fabric

http://www.fabfile.org/installing.html

* Ubuntu: sudo apt-get install fabric
* RHEL/CentOS: sudo yum install fabric
* Pip: sudo pip install fabric

## Download AppDynamics Software
This will prompt you for your username, password and the download URL. You can optionally set the values at the top of the script or pass in arguments.

Usage: `./download.sh`

```
-e= Your AppDynamics username
-p= Your AppDynamics password
-u= Specific AppDynamics download URL
```
