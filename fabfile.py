#!/usr/bin/python

################################################################################
#
# Utility script to deploy AppDynamics agents onto remote servers via Python Fabric.
#
# Requirements:
#   - Install Python Fabric on the machine that will run this script. *Not* required the remote servers.
#       http://www.fabfile.org/installing.html
#       Ubuntu: sudo apt-get install fabric
#       RHEL/CentOS: sudo yum install fabric
#       Pip: sudo pip install fabric
#   - Access to local-agent-install.sh in this same directory
#
# Version: _VERSION_
# Author(s): _AUTHORS_
#
################################################################################

from fabric.api import *
from fabric.contrib.files import exists
from xml.etree import ElementTree as et
import os, time, sys, re, ntpath, json


# Docs on how to sconfigure Fabric for custom deployments
# http://docs.fabfile.org/en/1.12/usage/execution.html
# http://docs.fabfile.org/en/1.12/usage/env.html
# http://docs.fabfile.org/en/1.12/usage/execution.html#password-management

# remote hosts
# env.hosts = [
#     'root@server1'
#     ,'appdynamics@server2'
#     ,'ubuntu@server3'
#     ,'jsmith@server4'
# ]
# remote ssh credentials
env.user = 'appd' # Default, implicit user
# Must provide password or SSH key but not both at the same time
# env.password = 'password' # Default ssh password for user
# env.passwords = ['pass1','pass2'] # List of passwords to try
# or, specify path to server public key here:
# env.key_filename = ['./my-key1.pem','./my-key2.pem'] # List of SSH keys to try


agent_install_script_path = 'local-agent-install.sh'
agent_config_script_path = 'local-agent-config.sh'


################################################################################

# Upload and install the agent
# @parallel(pool_size=10)
# @task(default=True)
@task
def deploy_agent(archive, appd_home_dir, agent_config_file):
    # Quick sanity check
    validate_file(archive)

    # Create the dir if appd_home doesn't exist on the target server
    if not exists(appd_home_dir, use_sudo=True):
        create_appd_home_dir(env.user, appd_home_dir)

    print('INFO:  Installing AppDyanmics agent into '+appd_home_dir)

    # Upload install stuff
    upload_install_artifacts(appd_home_dir,
        ntpath.basename(agent_install_script_path),
        archive)
    # Upload config stuff
    upload_config_artifacts(appd_home_dir,
        ntpath.basename(agent_config_script_path),
        agent_config_file)


    # Install the agent. Upgrade in place, if necessary
    install_agent(ntpath.basename(archive),
        appd_home_dir,
        ntpath.basename(agent_install_script_path),
        ntpath.basename(agent_config_script_path),
        ntpath.basename(agent_config_file) )

    # Clean up installation
    clean_install_artifacts(appd_home_dir,
        ntpath.basename(agent_install_script_path),
        ntpath.basename(archive) )
    # Clean up configs
    clean_config_artifacts(appd_home_dir,
        ntpath.basename(agent_config_script_path),
        ntpath.basename(agent_config_file) )

    print('INFO:  Agent deployment finished.\n\n')

def create_appd_home_dir(user, appd_home_dir):
    print('INFO:  creating AppDynamics home directory, '+appd_home_dir)
    sudo('mkdir -p '+appd_home_dir)

    print('INFO:  setting permissions on AppDynamics '+appd_home_dir+' for user='+user)
    sudo('chown -R '+user+':'+user+' '+appd_home_dir)


################################################################################
# Installation tasks
def upload_install_artifacts(directory, script, archive):
    # Upload the agent install script
    upload_file(script, directory)
    chmod_script(script, directory)

    # Upload the archive
    upload_file(archive, directory)

def install_agent(archive, appd_home, install_script, config_script, agent_config_file):
    with cd(appd_home):
        run('./'+install_script+' -a='+archive+' -h='+appd_home+' -c='+agent_config_file+' && sleep 0.5', pty=False)

def clean_install_artifacts(directory, script, archive):
    with cd(directory):
        # Delete the archive
        run('rm -f '+archive)
        # Delete the installer script
        run('rm -f '+script)


################################################################################
# Configuration tasks
def upload_config_artifacts(directory, config_script, config_file):
    if os.path.isfile(config_file):
        upload_file(config_script, directory)
        chmod_script(config_script, directory)

        upload_file(config_file, directory)

def clean_config_artifacts(directory, config_script, config_file):
    with cd(directory):
        # Delete the config script
        run('rm -f '+config_script)
        # Delete the config file
        run('rm -f '+config_file)

################################################################################
# Preperation tasks
@task
def check_host():
    run('echo "Host is valid"')

@task
def set_env(env_str):
    file = './conf/remote-hosts/'+str(env_str)+'.json'

    with open(file, 'r') as json_data:
        env_data = json.load(json_data)
        json_data.close()

        if env_data.get('user'):
            env.user = env_data.get('user')

        if env_data.get('key_filename'):
            env.key_filename = env_data.get('key_filename')

        if env_data.get('hosts'):
            env.hosts = env_data.get('hosts')
        else:
            print('ERROR: You must define hosts in your JSON config file')
            exit

################################################################################
# Service tasks
def install_service(archive, appd_home_dir):
    # Upload the install and service scripts

    # Chmod scripts

    # Install service

    # Start service
    sudo('service '+serviceName+' start')



################################################################################
# Utility tasks
def upload_file(file, upload_dir):
    print('INFO:  uploading '+file+' to '+upload_dir)
    upload = put(file, upload_dir)
    upload.succeeded

def chmod_script(file, dir):
    with cd(dir):
        run('chmod u+x '+file)

def delete(file, dir):
    with cd(dir):
        run('rm -f '+file)

def validate_file(file):
    if not file:
        print('INFO:\n  USAGE: fab deploy_agent deploy_agent:archive=test,appd_home_dir=./AppServerAgent-4.2.5.1.zip')
        sys.exit()

    if not os.path.isfile(file):
        print('INFO:\n  ERROR: file to find '+file)
        sys.exit()
