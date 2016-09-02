# AppDynamics Agent Management

A collection of scripts to handle agent downloads, installs and upgrades.

## Install/Upgrade Agent Locally
Operates on your local system. Install a brand new agent or upgrade a new agent in place.

Usage: `./local-agent-install.sh AGENT_ARCHIVE`


## Install/Upgrade Agent on Remote Server(s)
Operates on remote systems. Requires you to edit `remote-agent-install.py` and set the appropriates hosts, username and password or SSH key. Also requires you install Python Fabric on your management system (the system where you launch the script), but NOT on the remote systems.

Usage: `./remote-agent-install.sh AGENT_ARCHIVE`

### Install Python Fabric
http://www.fabfile.org/installing.html

## Download Software
This will prompt you for your username, password and the download URL. You can optionally set the values at the top of the script or pass in arguments.

Usage: `./download.sh`

```
-e= Your AppDynamics username
-p= Your AppDynamics password
-u= AppDynamics download URL
```
