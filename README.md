# AppDynamics Agent Management

A collection of scripts to handle agent downloads, installs and upgrades.

## Getting Started
Download the latest release from https://github.com/derrekyoung/appd-agent-management/releases. Unzip the release and run `chmod u+x *.sh` on the files in the release directory so that your user can execute the scripts.

# Functionality

## Install/Upgrade Agent Locally
Operates on your local system. Install a brand new agent or upgrade a new agent in place. Upgrades will sync existing configurations and settings.

Usage: `./local-agent-install.sh AGENT_ARCHIVE`


## Install/Upgrade Agent on Remote Server(s)
Operates on remote systems. Requires you to edit `remote-agent-install.py` and set the appropriates hosts, username and password or SSH key. Also requires you install Python Fabric on your management system (the system where you launch the script), but **NOT** on the remote systems.

Usage: `./remote-agent-install.sh AGENT_ARCHIVE`

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
-u= AppDynamics download URL
```
