#!/usr/bin/env python

import argparse
from argparse import RawTextHelpFormatter
import subprocess
import sys
import re
import os
import json
import uuid
import shutil
import yaml
import glob
import jinja2
import time

name_regex = "^[\.a-zA-Z0-9-]+$"

CREATE_INFO = """
Please wait while your PNDA cluster is being created.

This process can last for 1 or 2 hours.
"""

RUNFILE = None
def init_runfile(cluster):
    global RUNFILE
    RUNFILE = 'logs/%s.%s.run' % (cluster, int(time.time()))

def to_runfile(pairs):
    '''
    Append arbitrary pairs to a JSON dict on disk from anywhere in the code
    '''
    mode = 'w' if not os.path.isfile(RUNFILE) else 'r'
    with open(RUNFILE, mode) as rf:
        jrf = json.load(rf) if mode == 'r' else {}
        jrf.update(pairs)
        json.dump(jrf, rf)

def name_string(v):
    try:
        return re.match(name_regex, v).group(0)
    except:
        raise argparse.ArgumentTypeError("String '%s' may contain only  a-z 0-9 and '-'"%v)

def banner():
    print r"    ____  _   ______  ___ "
    print r"   / __ \/ | / / __ \/   |"
    print r"  / /_/ /  |/ / / / / /| |"
    print r" / ____/ /|  / /_/ / ___ |"
    print r"/_/   /_/ |_/_____/_/  |_|"
    print r""

def os_cmd(cmdline, print_output=False, verbose=False):
    if verbose:
        print(cmdline)

    try:
        if print_output:
            ret = subprocess.check_call(cmdline, shell=True)
        else:
            ret = subprocess.check_output(cmdline, shell=True)
        return ret
    except subprocess.CalledProcessError as e:
        print >>sys.stderr, "Command '{}' failed".format(cmdline)
        sys.exit(1)

def get_args():
    epilog = """examples:
  - create cluster
    $ ./heat_cli.py create -e squirrel-land -f standard -n 5 -o 1 -k 2 -z 3 -s pnda

  - destroy existing cluster:
    $ ./heat_cli.py destroy -e squirrel-land

  - view clusters statuses
    $ ./heat_cli.py status

  - view logs output of a deployed PNDA cluster
    $ ./heat_cli.py logs -e squirrel-land"""

    parser = argparse.ArgumentParser(formatter_class=RawTextHelpFormatter, description='PNDA CLI', epilog=epilog)
    banner()

    parser.add_argument('command', help='Mode of operation', choices=['create', 'resize', 'destroy', 'status', 'logs'])
    parser.add_argument('-e','--pnda-cluster', type=name_string, help='Namespaced environment for machines in this cluster')
    parser.add_argument('-n','--datanodes', type=int, help='How many datanodes for the hadoop cluster')
    parser.add_argument('-o','--opentsdb-nodes', type=int, help='How many Open TSDB nodes for the hadoop cluster')
    parser.add_argument('-k','--kafka-nodes', type=int, help='How many kafka nodes for the databus cluster')
    parser.add_argument('-z','--zk-nodes', type=int, help='How many zookeeper nodes for the databus cluster')
    parser.add_argument('-f','--flavor', help='PNDA flavor: e.g. "standard"', choices=['pico', 'standard'])
    parser.add_argument('-b','--branch', help='Git branch to use (defaults to master)')
    parser.add_argument('-s','--keypair', help='keypair name for ssh to the bastion server')
    parser.add_argument('-v','--verbose', help='Be more verbose')
    parser.add_argument('-bare', '--bare', help='Assume baremetal environment')
    parser.add_argument('-fstype', '--fstype', help='FS type for package repository')

    args = parser.parse_args()
    return args

def merge_dicts(base, mergein):
    for element in mergein:
        if element not in base:
            base[element] = mergein[element]
        else:
            for child in mergein[element]:
                base[element][child] = mergein[element][child]

def process_templates_from_dir(flavor, cname, from_dir, to_dir, vars):

    templateVars = vars
    templateEnv = jinja2.Environment( loader=jinja2.FileSystemLoader( searchpath='/' ) )

    print from_dir
    print to_dir
    print vars

    for j2_file in glob.glob('%s/*.j2' % from_dir):
        print 'processing template file: %s' % j2_file
        template = templateEnv.get_template( j2_file )
        yaml_file_content = yaml.load( template.render( templateVars ) )
        #print yaml_file_content
        yaml_file = '{}/{}'.format( to_dir, os.path.basename( j2_file[:-3] ) )
        with open(yaml_file, 'w') as outfile:
            yaml.dump(yaml_file_content, outfile, default_flow_style=False)

    with open('%s/pnda.yaml' % to_dir, 'r') as infile:
        pnda_flavor = yaml.load(infile)
    template = templateEnv.get_template( os.path.abspath( '../../templates/pnda.yaml' ) )
    pnda_common = yaml.load( template.render( templateVars ) )
    merge_dicts(pnda_common, pnda_flavor)
    with open('%s/pnda.yaml' % to_dir, 'w') as outfile:
        yaml.dump(pnda_common, outfile, default_flow_style=False)

def setup_flavor_templates(flavor, cname, is_bare, fs_type, zknodes, kafkanodes, datanodes):

    resources_dir = '_resources_{}-{}'.format(flavor, cname)
    dest_dir = '{}/{}'.format(os.getcwd(), resources_dir)
    if os.path.isdir(resources_dir):
        shutil.rmtree(resources_dir)
    os.makedirs(resources_dir)
    os.chdir(resources_dir)

    templateVars = {}
    if is_bare == 'true':
        templateVars['create_network'] = 0
        templateVars['create_volumes'] = 0
        templateVars['create_bastion'] = 0
    else:
        templateVars['create_network'] = 1
        templateVars['create_volumes'] = 1
        templateVars['create_bastion'] = 1
     
    hypervisor_count = get_hypervisor_count()
    templateVars['create_zknodes_group'] = 1 if (zknodes > 1 and hypervisor_count >= zknodes) else 0
    templateVars['create_kafkanodes_group'] = 1 if (kafkanodes > 1 and hypervisor_count >= kafkanodes) else 0
    templateVars['create_datanodes_group'] = 1 if (datanodes > 1 and hypervisor_count >= datanodes) else 0

    templateVars['package_repository_fs_type'] = fs_type

    for yaml_file in glob.glob('../../templates/%s/*.yaml' % flavor):
        shutil.copy(yaml_file, './')

    process_templates_from_dir( flavor, cname,
                                os.path.abspath( '../../templates/%s' % flavor ),
                                os.path.abspath( dest_dir ),
                                templateVars)

    templateEnv = jinja2.Environment( loader=jinja2.FileSystemLoader( searchpath='/' ) )
    if is_bare == 'true':
        templateVars = { }
    else:
        templateVars = { "create_network": "1" }

    with open('../../pnda_env.yaml', 'r') as infile:
        pnda_env = yaml.load(infile)
    with open('../../templates/%s/resource_registry.yaml' % flavor, 'r') as infile:
        resource_registry = yaml.load(infile)
    with open('../../templates/%s/instance_flavors.yaml' % flavor, 'r') as infile:
        instance_flavors = yaml.load(infile)
    merge_dicts(pnda_env, resource_registry)
    merge_dicts(pnda_env, instance_flavors)
    with open('pnda_env.yaml', 'w') as outfile:
        yaml.dump(pnda_env, outfile, default_flow_style=False)
    shutil.copytree('../../scripts', './scripts')
    shutil.copy('../../deploy', './')
    if os.path.isfile('../../pr_key'):
        shutil.copy('../../pr_key', './')

def create_cluster(args):

    # TODO add bastion/saltmaster endpoints to runfile
    init_runfile(args.pnda_cluster)

    to_runfile({'cmdline':sys.argv})

    pnda_cluster = args.pnda_cluster
    datanodes = args.datanodes
    tsdbnodes = args.opentsdb_nodes
    kafkanodes = args.kafka_nodes
    zknodes = args.zk_nodes
    branch = args.branch
    flavor = args.flavor
    keypair = args.keypair
    command = args.command
    is_bare = args.bare

    if not args.fstype:
        fs_type = 'swift'
    else:
        fs_type = args.fstype

    if flavor == 'standard':
        if datanodes == None:
            datanodes = 3
        if tsdbnodes == None:
            tsdbnodes = 1
        if kafkanodes == None:
            kafkanodes = 2
        if zknodes == None:
            zknodes = 3
    elif flavor == 'pico':
        if datanodes == None:
            datanodes = 1
        if tsdbnodes == None:
            tsdbnodes = 0
        if kafkanodes == None:
            kafkanodes = 1
        if zknodes == None:
            zknodes = 0

    if not os.path.isfile('../deploy'):
        with open('../deploy', 'w') as git_key_file:
            git_key_file.write('If authenticated access to the platform-salt git repository is required then' +
                               ' replace this file with a key that grants access to the git server.\n')

    stack_params = []

    stack_params.append('--parameter ZookeeperNodes={}'.format(zknodes))
    stack_params.append('--parameter KafkaNodes={}'.format(kafkanodes))
    stack_params.append('--parameter DataNodes={}'.format(datanodes))
    stack_params.append('--parameter OpentsdbNodes={}'.format(tsdbnodes))
    stack_params.append('--parameter PndaFlavor={}'.format(flavor))
    stack_params.append('--parameter KeyName={}'.format(keypair))
   
    if branch:
        stack_params.append('--parameter GitBranch={}'.format(branch))
    if command == 'resize':
        an_id = uuid.uuid4()
        stack_params.append('--parameter DeploymentID={}'.format(an_id))

    stack_params.append(pnda_cluster)
    stack_params_string = ' '.join(stack_params)

    if command == 'create':
        print CREATE_INFO
        setup_flavor_templates(flavor, pnda_cluster, is_bare, fs_type, zknodes, kafkanodes, datanodes)
        cmdline = 'openstack stack create --timeout 120 --wait --template {} --environment {} {}'.format('pnda.yaml',
                                                                                    'pnda_env.yaml',
                                                                                    stack_params_string)
    elif command == 'resize':
        os.chdir('_resources_{}-{}'.format(flavor, pnda_cluster))
        stack_params_string = ' '.join(stack_params)
        cmdline = 'openstack stack update --timeout 120 --wait --template {} --environment {} {}'.format('pnda.yaml',
                                                                                    'pnda_env.yaml',
                                                                                    stack_params_string)
    print cmdline
    os_cmd(cmdline, print_output=True)
    console_info = subprocess.check_output(['nova','list', '--name', "%s-cdh-edge" % pnda_cluster, '--fields', 'networks'])
    console_ip = re.search('([0-9]*\\.[0-9]*\\.[0-9]*\\.[0-9]*)', console_info)
    if console_ip:
        print 'Use the PNDA console to get started: http://%s' % console_ip.group(1)
    else:
        print 'Could not find IP address for PNDA console'

def destroy_cluster(args):
    pnda_cluster = args.pnda_cluster

    os_cmd('openstack stack delete --yes --wait {}'.format(pnda_cluster), print_output=True)

def get_pnda_cluster_info(cluster_name):
    hosts = os_cmd('openstack server list --format json --name "{}"'.format(cluster_name))
    hosts = json.loads(hosts)
    try:
        # bastion informations
        bastion = next(h for h in hosts if h['Name'] == '{}-bastion'.format(cluster_name))
        bastion_ip = bastion['Networks'].split(',')[-1]

        # edge node informations
        edge = next(h for h in hosts if h['Name'] == '{}-cdh-edge'.format(cluster_name))
        edge_ip = edge['Networks'].split(',')[0].split('=')[-1]

        return { 'bastion' : {'public-ip': bastion_ip},
            'edge'    : {'private-ip': edge_ip} }
    except:
        return {}

def get_salt_highstate_output(stack):
    return os_cmd('openstack stack output show {} salt_highstate --format value --column output_value'.format(stack))

def get_salt_orchestrate_output(stack):
    return os_cmd('openstack stack output show {} salt_orchestrate --format value --column output_value'.format(stack))

def get_hypervisor_count():
    return int(os_cmd("nova hypervisor-list | awk -F '|' '{print $4}' | grep -c 'up'").strip('\n'))

def print_pnda_cluster_status(stack, verbose=False):
    stack_name = stack['Stack Name']
    stack_status = stack['Stack Status']

    if stack_status in ['CREATE_COMPLETE', 'UPDATE_COMPLETE']:
        info = get_pnda_cluster_info(stack_name)
        if 'bastion' in info and 'edge' in info:
            print '[P] {} - {}'.format(stack_name, stack_status)
            print "    |- Bastion public IP: {}".format(info['bastion']['public-ip'])
            print "    |- Edge node private IP: {}".format(info['edge']['private-ip'])
        else:
            print '[?] {} - {}'.format(stack_name, stack_status)
            print "    |- No Bastion/Edge (May not be a PNDA cluster)."
    else: 
       print '[?] {} - {}'.format(stack_name, stack_status)

def clusters_status(args):
    stacks = os_cmd('openstack stack list --format json', print_output=False)
    stacks = json.loads(stacks)

    for stack in stacks:
        print_pnda_cluster_status(stack, verbose=args.verbose)

def print_pnda_cluster_logs(args):
    stack_name = args.pnda_cluster

    print get_salt_highstate_output(stack_name)
    print get_salt_orchestrate_output(stack_name)

def main():
    args = get_args()

    if args.command in ['create', 'resize']:
        create_cluster(args)
    elif args.command == 'destroy':
        destroy_cluster(args)
    elif args.command == 'status':
        clusters_status(args)
    elif args.command == 'logs':
        print_pnda_cluster_logs(args)

if __name__ == "__main__":
    main()
