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
# or, specify path to server public key here:
# env.key_filename = ['./my-key1.pem','./my-key2.pem'] # List of SSH keys to try


REMOTE_APPD_HOME = '/opt/AppDynamics'
agent_install_script_path = 'local-agent-install.sh'
agent_config_script_path = 'utils/local-agent-config.sh'


################################################################################
@task
def set_env(env_file):
    file = env_file

    with open(file, 'r') as json_data:
        env_data = json.load(json_data)
        json_data.close()

        if env_data.get('appd-home'):
            env.home = env_data.get('appd-home')
        else:
            env.home = REMOTE_APPD_HOME

        if env_data.get('user'):
            env.user = env_data.get('user')

        if env_data.get('password'):
            env.password = env_data.get('password')

        if env_data.get('key_filename'):
            env.key_filename = env_data.get('key_filename')

        if env_data.get('hosts'):
            env.hosts = env_data.get('hosts')
        else:
            print('ERROR: You must define hosts in your JSON config file')
            exit

@task
def check_host():
    run('echo INFO:  Host is valid. AppDynamics home is '+env.home)


@parallel(pool_size=10)
@task
def prep(archive, scripts):
    # Create the dir if appd_home doesn't exist on the target server
    if not exists(env.home, use_sudo=True):
        print('INFO:  creating AppDynamics home directory, '+env.home)
        sudo('mkdir -p '+env.home)

        print('INFO:  setting permissions on AppDynamics '+env.home+' for user='+env.user)
        sudo('chown -R '+env.user+':'+env.user+' '+env.home)

    print('INFO:  Preparing install into '+env.home)

    # Upload the agent archive
    upload_file(archive, env.home)

    # Upload the suite
    upload_file(scripts, env.home)

    # Local paths
    scripts = ntpath.basename(scripts)

    with cd(env.home):
        run('unzip -q -o '+scripts)
        run('chmod u+x local-agent-install.sh')
        # Delete the archive
        run('rm -f '+scripts)

@task
def install(archive, config):
    if os.path.isfile(config):
        upload_file(config, env.home)
        config = ntpath.basename(config)
    else:
        print('ERROR: File not found: '+config)
        config=''

    archive = ntpath.basename(archive)

    with cd(env.home):
        run('./'+agent_install_script_path+' -a='+archive+' -c='+config+' && sleep 0.5', pty=False)

@parallel(pool_size=10)
@task
def cleanup(archive, config):
    archive = ntpath.basename(archive)
    config = ntpath.basename(config)

    with cd(env.home):
        # Delete the archive
        run('rm -f '+archive)
        run('rm -f '+config)


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
