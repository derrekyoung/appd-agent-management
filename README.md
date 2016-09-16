# AppDynamics Agent Management

A collection of scripts to handle agent downloads, installs and upgrades.

## 5-Minute Getting Started

Prerequisites:

1. **Email** address for your AppDynamics.com account
1. **Password** for your AppDynamics.com account
1. Your AppDynamics Controller **host name**
1. Your AppDynamics Controller **account name**
1. Your AppDynamics Controller **account access key**
1. "**curl**" command needs to be installed on your host



Open a terminal and execute this command. Follow the on-screen prompts.
```BASH
curl -LOk https://github.com/derrekyoung/appd-agent-management/releases/download/latest/appd-agent-management.zip \
&& unzip appd-agent-management.zip -d AppDynamics \
&& cd AppDynamics \
&& chmod u+x *.sh \
&& /bin/bash ./newbies-start-here.sh
```


# Table of Contents

- [AppDynamics Agent Management](#)
- 	  [5- Minute Getting Started](#g5-minute-getting-started)
- [Capabilities](#capabilities)
- [Requirements](#requirements)
- [Download Latest](#download-latest)
- [Install/Upgrade Agent Locally](#installupgrade-agent-locally)
	- [Arguments and Settings](#arguments-and-settings)
	- [Agent Configuration Properties](#agent-configuration-properties)
- [Install/Upgrade Agent on Remote Server(s)](#installupgrade-agent-on-remote-servers)
	- [Arguments and Settings](#arguments-and-settings-1)
	- [Environment Config](#remote-environment-config)
	- [Install Python Fabric](#install-python-fabric)
- [Download AppDynamics Software](#download-appdynamics-software)

# Requirements
* Supported on Linux only. No Windows support
* Python 2.7+ on the central distribution server
* Python Fabric on the central distribution server
* Unzip utility available on the destination servers

# Capabilities
* Install/upgrade the **Java** Agent
* Install/upgrade the **Machine** Agent
    * Sync extensions after upgrade
    * Sync properties for the Analytics agent (endpoint, account name, access key, proxy info) after upgrade
    * Automatically start the Machine Agent after install/upgrade
* Install/upgrade the **Database** Agent
    * Automatically start the Database Agent after install/upgrade
* Common
    * Automatically set connection info: controller hostname, port, ssl enabled, account name, access key
    * Sync **controller-info.xml**, custom-activity-correlation.xml, custom-interceptors.xml for all applicable agents
* **Download** any appdynamics software by passing in the download URL


## Download Latest
Fork/clone this repository or [download a zipped release](https://github.com/derrekyoung/appd-agent-management/releases/latest).

# Install/Upgrade Agent Locally
Operates on your local system. Install a brand new agent or upgrade a new agent in place. Upgrades will sync existing configurations and settings.

> *NOTE*: The install script will create a symlink that always points to the latest version of the agent. Configure the Java app server startup script to point to this symlink.

Usage: `./local-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -h=./agents`

## Arguments and Settings
1. Arguments are optional. You will be prompted for values otherwise. Optionally hard code values in the script. Optional command line arguments:
    * -a|--archive= Agent archive
    * -h|--appdhome= Remote AppDynamics home directory
	* -c|--config= (optional) Agent properties configuration file
1. `APPD_AGENT_HOME`: the install directory for the agents. The default is to install it in the same directory where you run the script.
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.

## Agent Configuration Properties
You can update agent configuration details (controller, access key, analytics endpoint, etc.) by passing in a properties file. A sample file is provided for you to update with your information. (Do not change the key names in the file.) You can create your own configuration files of any name to distinguish between different Controllers or different agent profiles.

Usage: `./local-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -c=agent-config.properties`

Example `controller-info.xml` properties:
```PROPERTIES
controller-host=example.saas.appdynamics.com
controller-port=443
controller-ssl-enabled=true
account-name=my-account-dev
account-access-key=1234-asdf-1234-asdf-1234-asdf
```

Example `analytics-agent.properties` properties:
```PROPERTIES
analytics.agent.enabled=true
http.event.endpoint=https://analytics.api.appdynamics.com:443
http.event.accountName=global_accountName_asdfasdfasdfasdf
http.event.accessKey=1234-asdf-1234-asdf-1234-asdf
```

# Install/Upgrade Agent on Remote Server(s)
Operates on remote systems. Requires you to create and define a configuration environment. The environment config must be in a JSON file and named in the format of `config-NAME_HERE.json`.

For example, the Production environment might be defined in config-production.json. You'd then trigger this config in `remote-agent-install.sh` by passing in the `-e=production` argument or entering `production` in the interactive shell. See `config-sample.json` for

You must install Python Fabric on your management system (the system where you launch the script), but **NOT** on the remote systems. Communication to the systems has no external dependencies because all comms happen over SSH and Shell.

Test locally before deploying remotely.

Usage: `./remote-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -h=/opt/AppDynamics/ -e=Production`

## Arguments and Settings
1. Arguments are optional. You will be prompted for values otherwise. Optionally hard code values in the script. Optional command line arguments:
    * -e|--environment= Deployment environment configuration name
    * -a|--archive= Agent archive
    * -h|--appdhome= Remote AppDynamics home directory
	* -c|--config= (optional) Agent properties configuration file
1. `REMOTE_APPD_HOME`: where to install the AppDynamics agents. Default is /opt/AppDynamics/.
1. `ENV`: JSON file containing remote host names and credentials
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.

## Remote Environment Config
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

Usage: `./download.sh`

Arguments are optional. You will be prompted for values otherwise.
Optional params:
* -e= Your AppDynamics username
* -p= Your AppDynamics password
* -v= Version, default to the latest version"
* -t= Type of software {java, database, machine}"
* -o= JVM type or OS type {sun, ibm, linux, osx}"
* -b= Bitness {32, 64}"
* -f= Format {zip, rpm}"
