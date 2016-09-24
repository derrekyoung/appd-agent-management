# AppDynamics Agent Management

A collection of scripts to handle agent downloads, installs and upgrades.

## 5-Minute Getting Started

Download these scripts, download the Java and Machine agents and then install the agents on your localhost.

Prerequisites:

1. **Email** and **Password** for your AppDynamics.com account
1. Your AppDynamics Controller **host name**, **account name**, and **account access key**
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

- [AppDynamics Agent Management](#appdynamics-agent-management)
	- [5-Minute Getting Started](#5-minute-getting-started)
- [About AppDynamics Agent Management](#about-appdynamics-agent-management)
	- [Requirements](#requirements)
	- [Capabilities](#capabilities)
	- [Download Latest](#download-latest)
- [Install/Upgrade Local Agent](#installupgrade-local-agent)
	- [Getting Started - Local Install](#getting-started-local-install)
	- [Local Arguments and Settings](#local-arguments-and-settings)
	- [Agent Configuration Properties](#agent-configuration-properties)
- [Install/Upgrade Agent on Remote Server(s)](#installupgrade-agent-on-remote-servers)
	- [Getting Started - Remote Install](#getting-started-remote-install)
	- [Remote Arguments and Settings](#remote-arguments-and-settings)
	- [Remote Environment Config](#remote-environment-config)
	- [Install Python Fabric](#install-python-fabric)
- [Download AppDynamics Software](#download-appdynamics-software)

# About AppDynamics Agent Management
## Requirements
* Supported on Linux & OS X only. No Windows support
* Python 2.7 on the central distribution server
* Python Fabric on the central distribution server
* Unzip utility available on the destination servers

## Capabilities
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

# Install/Upgrade Local Agent
Install a brand new agent or upgrade a new agent in place. Upgrades will sync existing configurations and settings. Operates on your local system.

> *NOTE*: The install script will create a symlink that always points to the latest version of the agent. Configure the Java app server startup script to point to this symlink.

Usage: `./local-agent-install.sh -a=AppServerAgent-4.2.7.0.zip`

## Getting Started Local Install
1. [Download the latest release](https://github.com/derrekyoung/appd-agent-management/releases/latest) of this toolkit and unzip it to your `APPD_HOME` directory.
1. Download the agent from the [download site](https://download.appdynamics.com) or by using `download.sh`.
1. (Optional) Manually create an agent config file under `HOME/conf/agent-configs/.
1. Run `local-agent-install.sh`.
	* Optionally pass in the archive name using `local-agent-install.sh -a=AppServerAgent-4.2.7.0.zip`. You'll be prompted for the archive otherwise.
1. The agent will be installed in the local directory under `HOME/agents/`
	* For example, installing `AppServerAgent-4.2.7.0.zip` will result in a version directory `APPD_HOME/agents/appserveragent-4.2.7.0/` and a symlink named `APPD_HOME/agents/appserveragent` pointing to the version directory. (This symlink will be updated for the latest agent that you install of a given type.
1. Manually instrument your Java application server and include the javaagent config like so `-javaagent:APPD_HOME/agents/appserveragent/javaagent.jar`

## Local Arguments and Settings
1. Arguments are optional. You will be prompted for values otherwise. Optional command line arguments:
    * -a|--archive= Agent archive
    * -h|--appdhome= Remote AppDynamics home directory
	* -c|--config= (optional) Agent properties configuration file
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.

## Agent Configuration Properties
You can update agent configuration details (controller, access key, analytics endpoint, etc.) by passing in a properties file name. These files are under `APPD_HOME/conf/agent-configs/`.

A sample file is provided for you to update with your information. (Do not change the key names in the file.) You can create your own configuration files of any name to distinguish between different Controllers or different agent profiles.

Usage: `./local-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -c=test-env`

Example `controller-info.xml` properties:
```PROPERTIES
controller-host=example.saas.appdynamics.com
controller-port=443
controller-ssl-enabled=true
account-name=my-account-dev
account-access-key=1234-asdf-1234-asdf-1234-asdf
sim-enabled=true
```

Example `analytics-agent.properties` properties:
```PROPERTIES
analytics.agent.enabled=true
http.event.endpoint=https://analytics.api.appdynamics.com:443
http.event.accountName=global_accountName_asdfasdfasdfasdf
http.event.accessKey=1234-asdf-1234-asdf-1234-asdf
```

# Install/Upgrade Agent on Remote Server(s)
Operates on remote systems. Requires you to create and define a configuration environment. The environment config must be in a JSON file and named in the format of  `APPD_HOME/conf/remote-hosts/NAME_HERE.json`.

For example, the Production environment might be defined in `production.json`. You'd then trigger this config in `remote-agent-install.sh` by passing in the `-e=production` argument or entering `production` in the interactive shell. See `sample.json` for

You must install Python Fabric on your management system (the system where you launch the script), but **NOT** on the remote systems. Communication to the systems has no external dependencies because all comms happen over SSH and Shell.

Test locally before deploying remotely.

Usage: `./remote-agent-install.sh -a=AppServerAgent-4.2.6.0.zip -h=/opt/AppDynamics/ -e=Production`

## Getting Started Remote Install
1. [Download the latest release](https://github.com/derrekyoung/appd-agent-management/releases/latest) of this toolkit and unzip it to your `APPD_HOME` directory.
2. Learn how to do a local install by reading the docs above.
3. Create a remote hosts JSON file underneath `APPD_HOME/conf/remote-hosts/`. Folllow the sample file, but see below for additional details.
4. Create an agent config file as described above. Place this file under `APPD_HOME/conf/agent-configs/`.
5. Execute `./remote-agent-install.sh -a=AppServerAgent-4.2.6.0.zip` and enter the name of your remote hosts and agent config file. (Only enter the names, without the extensions.)
6. If using password authentication, you'll be prompted to enter each unique password. Passwords are NOT saved to disk.

## Remote Arguments and Settings
Arguments are optional. You will be prompted for values otherwise.

1. Optional command line arguments:
    * -e|--environment= Remote hosts environment configuration name
    * -a|--archive= Path to agent archive to install
	* -c|--config= (optional) Agent properties configuration file
1. `DEBUG_LOGS`: set to `true` to turn on verbose logging.

## Remote Environment Config
You must define your remote servers and credentials in a config file. The file must be of the name `HOME/conf/remote-hosts/NAME_HERE.json`.

The configuration JSON file contains a few elements. It must be valid JSON so use a JSON validator like, http://jsonlint.com/.

Example:
```
{
   // REQUIRED A list of remote hosts. Can be in the format of plain hostnames or as username@HOSTNAME,
   // where you specify an explicit username to override the default username
    "hosts": [
        "root@server5.internal.mycompany.org"
        ,"appdynamics@server6"
        ,"ubuntu@server7.us"
        ,"jsmith@server8.co"
        ,"server9.example.com"
    ],

    // (optional) The default, implicit username for the remote hosts. Useful if all/most usernames will be
    // the same. Otherwise, specify the username as part of the hostname using the format username@HOSTNAME
    "user": "user1",

    // (optional) A list of SSH keys to access the remote hosts
    "key_filename": [
        "./my-key1.pem"
        ,"./my-key2.pem"
    ],

	// The remote home directory, where to install agents
	"appd-home": "/opt/AppDynamics"
}
```

* **hosts**: REQUIRED A list of remote hosts. They can be in the format of simple hostnames or as username@hostname where you specify an explicit username to override the default username.
* **user**: (optional) The default, implicit username for the remote hosts. Use this if all usernames will be the same. Otherwise, specify the username as part of the hostname using the format username@HOSTNAME. See `sample.json` for examples.
* **key_filename**: (optional) A list of SSH keys to access the remote hosts.
* **appd-home**: Remote directory to install the agents.
* **passwords**: You will be prompted for passwords interactively. Do not enter them in your config JSON file.

## Install Python Fabric

http://www.fabfile.org/installing.html

* Ubuntu: sudo apt-get install fabric
* RHEL/CentOS: sudo yum install fabric
* Pip: sudo pip install fabric

It's best to install Fabric using one of the methods above. However, sometimes customers don't have access to download software. In that case, you can install Fabric offline.
1. Determine the version of Python on the central, distribution server (2.6 or 2.7).
1. Download Fabric and the dependencies on a machine that you control, with access to the internet. Make sure to have the matching version of Python (2.6 or 2.7). `./offline-pip.sh download fabric` under the `APPD_HOME/utils/` directory.
2. Transfer the resulting archive to the central, distribution server that will push the agents. Place the tar archive under the `APPD_HOME/utils/` directory.
3. Insall Fabric by running `./offline-pip.sh install fabric`

# Download AppDynamics Software
Download AppDynamics software including agents and platform components. Pass in no arguments to be prompted for input.

Usage: `./download.sh`

Optional arguments:

    -e=|--email=  AppDynamics username
    -p=|--password=  AppDynamics password
    -v=|--version=  Version, default to the latest version
    -t=|--type=  Type of software {database, java, machine, php, net, apache, analytics, mobile, cpp, controller, eum, events-service}
    -o=|--os=  JVM type or OS type {sun, ibm, linux, windows, osx, android, ios}
    -b=|--bitness=  Bitness {32, 64}
    -f=|--format=  Format {zip, rpm}
    -h|--help  Print usage
