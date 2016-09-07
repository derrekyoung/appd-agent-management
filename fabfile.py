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


################################################################################

# Upload and install the agent
# @parallel(pool_size=10)
# @task(default=True)
@task
def deploy_agent(archive, appd_home_dir):
    # Quick sanity check
    validate_file(archive)

    # Create the dir if appd_home doesn't exist on the target server
    if not exists(appd_home_dir, use_sudo=True):
        create_appd_home_dir(env.user, appd_home_dir)

    print('INFO:  Installing AppDyanmics agent into '+appd_home_dir)

    # Upload the agent install script
    upload_file(agent_install_script_path, appd_home_dir)
    chmod_script( ntpath.basename(agent_install_script_path), appd_home_dir)

    # Upload the archive
    upload_file(archive, appd_home_dir)


    # Install the agent. Upgrade in place, if necessary
    install_agent(ntpath.basename(archive), appd_home_dir, ntpath.basename(agent_install_script_path) )


    # Delete the archive
    delete(ntpath.basename(archive), appd_home_dir)

    # Delete the installer script
    delete(ntpath.basename(agent_install_script_path), appd_home_dir)

    print('INFO:  Agent deployment finished.\n\n')

@parallel(pool_size=100)
def create_appd_home_dir(user, appd_home_dir):
    print('INFO:  creating AppDynamics home directory, '+appd_home_dir)
    sudo('mkdir -p '+appd_home_dir)

    print('INFO:  setting permissions on AppDynamics '+appd_home_dir+' for user='+user)
    sudo('chown -R '+user+':'+user+' '+appd_home_dir)

@parallel(pool_size=100)
def upload_file(file, upload_dir):
    print('INFO:  uploading '+file+' to '+upload_dir)
    upload = put(file, upload_dir)
    upload.succeeded

@parallel(pool_size=100)
def chmod_script(file, dir):
    with cd(dir):
        run('chmod u+x '+file)

@parallel(pool_size=10)
def install_agent(archive, appd_home, script):
    with cd(appd_home):
        run('./'+script+' -a='+archive+' -h='+appd_home)

@parallel(pool_size=100)
def delete(file, dir):
    with cd(dir):
        run('rm '+file)

@parallel(pool_size=100)
def validate_file(file):
    if not file:
        print('INFO:\n  USAGE: fab deploy_agent deploy_agent:archive=test,appd_home_dir=./AppServerAgent-4.2.5.1.zip')
        sys.exit()

    if not os.path.isfile(file):
        print('INFO:\n  ERROR: file to find '+file)
        sys.exit()

@task
def check_host():
    run('echo "Host is valid"')

@task
def set_env(env_str):
    file = 'config-'+str(env_str)+'.json'

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
