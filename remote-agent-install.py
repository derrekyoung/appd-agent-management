#!/usr/bin/python

################################################################################
#
# Helper script to deploy AppDynamics agents onto remote servers via Python Fabric.
#
################################################################################

from fabric.api import *
from fabric.contrib.files import exists
from xml.etree import ElementTree as et
import os, time, sys, re, ntpath


# remote hosts
env.hosts = [
    'server1'
    ,'server2'
]
# remote ssh credentials
env.user = 'ubuntu'
env.password = 'password' #ssh password for user
# or, specify path to server public key here:
# env.key_filename = './my-key.pem'


agent_install_script_path = 'local-agent-install.sh'


################################################################################

# Upload and install the agent
@parallel(pool_size=10)
def deploy_agent(archive, appd_home_dir):
    # Quick sanity check
    validate_file(archive)

    # Create the dir if appd_home doesn't exist on the target server
    if not exists(appd_home_dir, use_sudo=True):
        create_appd_home_dir(env.user, appd_home_dir)

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

    print('INFO: Agent deployment finished.')

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
def install_agent(file, appd_home, script):
    with cd(appd_home):
        run('./'+script+' '+file)

@parallel(pool_size=100)
def delete(file, dir):
    with cd(dir):
        run('rm '+file)

@parallel(pool_size=100)
def validate_file(file):
    if not file:
        print('INFO:  USAGE: fab deploy_agent ./AppServerAgent-4.2.5.1.zip')
        sys.exit()

    if not os.path.isfile(file):
        print('INFO:  ERROR: file to find '+file)
        sys.exit()
