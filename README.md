# AppDynamics Agent Management

A collection of scripts to handle agent downloads, installs and upgrades. Will sync controller info, account info, and Analytics agent info.

**Table of Contents**

- [AppDynamics Agent Management](#)
	- [Capabilities](#)
	- [Requirements](#)
- [Getting Started](#)
- [Install/Upgrade Agent Locally](#)
	- [Arguments and Settings](#)
- [Install/Upgrade Agent on Remote Server(s)](#)
	- [Arguments and Settings](#)
		- [Environment Config](#)
	- [Install Python Fabric](#)
- [Download AppDynamics Software](#)

## Capabilities
* Install/upgrade the Java agent
    * Will sync controller-info.xml underneath the conf/ and verNNN/conf/ directories.
    * Will sync custom-activity-correlation.xml, custom-interceptors.xml
* Install/upgrade the Machine agent
    * Will sync controller-info.xml underneath the conf/ directory.
    * Sync extensions
* Install/upgrade the Analytics agent within the Machine agent
    * Sync properties for the Analytics agent (endpoint, account name, access key, proxy info)
* Install/upgrade the DB agent
    * Will sync controller-info.xml underneath the conf/ directory.
* Download any appdynamics software by passing in the download URL

## Requirements
* Supported on Linux/OSX/Unix only. No Windows support
* Python 2.7+ on the central distribution server
* Python Fabric on the central distribution server
* Unzip utility available on the destination servers

# Getting Started
1. Download the latest release from https://github.com/derrekyoung/appd-agent-management/releases/latest
1. Unzip the release and run `chmod u+x *.sh` on the files in the release directory so that your user can execute the scripts.
1. Local agent management
    1. Execute local installs/upgrades by running `local-agent-install.sh`. See below.
    2. Test locally before deploying remotely.
1. Remote agent management
    1. Create your environment config named as `config-NAME_HERE.json`. See below.
    2. Execute remote installs/upgrades by running `./remote-agent-install.sh`. See below.

# Install/Upgrade Agent Locally
Operates on your local system. Install a brand new agent or upgrade a new agent in place. Upgrades will sync existing configurations and settings.

> *NOTE*: The install script will create a symlink that always points to the latest version of the agent. Configure the Java app server startup script to point to this symlink.

Usage: `./local-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -h=./`

## Arguments and Settings
1. Arguments are optional. You will be prompted for values otherwise. Optionally hard code values in the script. Optional params:
    * -a= Agent archive
    * -h= Remote AppDynamics home directory
1. `APPD_AGENT_HOME`: the install directory for the agents. The default is to install it in the same directory where you run the script.
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.


# Install/Upgrade Agent on Remote Server(s)
Operates on remote systems. Requires you to create and define a configuration environment. The environment config must be in a JSON file and named in the format of `config-NAME_HERE.json`.

For example, the Production environment might be defined in config-production.json. You'd then trigger this config in `remote-agent-install.sh` by passing in the `-e=production` argument or entering `production` in the interactive shell. See `config-sample.json` for

You must install Python Fabric on your management system (the system where you launch the script), but **NOT** on the remote systems. Communication to the systems has no external dependencies because all comms happen over SSH and Shell.

Test locally before deploying remotely.

Usage: `./remote-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -h=/opt/AppDynamics/ -e=Production`

## Arguments and Settings
1. Arguments are optional. You will be prompted for values otherwise. Optionally hard code values in the script. Optional params:
    * -e= Deployment environment configuration name
    * -a= Agent archive
    * -h= Remote AppDynamics home directory
1. `REMOTE_APPD_HOME`: where to install the AppDynamics agents. Default is /opt/AppDynamics/.
1. `ENV`: JSON file containing
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.

### Environment Config
You must define your remote servers and credentials in a config file. The file must be of the name `config-NAME_HERE.json`. 

The configuration JSON file contains a few elements. It must be valid JSON so use a JSON validator like, http://jsonlint.com/.

Example:
```
{
   // REQUIRED A list of remote hosts. Can be in the format of plain hostnames or as username@hostname, 
   // where you specify an explicit username to override the default username
    "hosts": [
        "root@server5.internal.mycompany.org"
        ,"appdynamics@server6"
        ,"ubuntu@server7.us"
        ,"jsmith@server8.co"
        ,"server9.example.com"
    ],
    
    // (optional) The default, implicit username for the remote hosts. Useful if all usernames will be 
    // the same. Otherwise, specify the username as part of the hostname using the format username@HOSTNAME
    "user": "user1",
    
    // (optional) A list of SSH keys to access the remote hosts
    "key_filename": [
        "./my-key1.pem"
        ,"./my-key2.pem"
    ]
}
```

* **hosts**: REQUIRED A list of remote hosts. They can be in the format of simple hostnames or as username@hostname where you specify an explicit username to override the default username
* **user**: (optional) The default, implicit username for the remote hosts. Use this if all usernames will be the same. Otherwise, specify the username as part of the hostname using the format username@HOSTNAME. See `config-sample.json` for examples.
* **key_filename**: (optional) A list of SSH keys to access the remote hosts
* **passwords**: You will be prompted for passwords interactively. Do not enter them in your config JSON file.

## Install Python Fabric

http://www.fabfile.org/installing.html

* Ubuntu: sudo apt-get install fabric
* RHEL/CentOS: sudo yum install fabric
* Pip: sudo pip install fabric

# Download AppDynamics Software
This will prompt you for your username, password and the download URL. You can optionally set the values at the top of the script or pass in arguments.

Usage: `./download.sh -e=foo@example.com -p=password123 -u=http://download.appdyanmcsi.com/javaagent-1.2.3.zip`

Arguments are optional. You will be prompted for values otherwise. Optionally hard code values in the script.
Optional params:
* -e= Your AppDynamics username
* -p= Your AppDynamics password
* -u= Specific AppDynamics download URL
