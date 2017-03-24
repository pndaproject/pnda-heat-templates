# Provisioning PNDA on "bare metal" servers

The purpose of this guide is to explain the process of provisioning PNDA on 'bare metal' servers.

The subject and content of this guide was originally developed and authored by Fabien Andrieux (fandrieu@cisco.com). 

The intention is to maintain and evolve this guide with the input of all those who have helped to trial and prove the processes described.

# Introduction

The PNDA bare-metal deployment process is similar to the process to deploy OpenStack itself. To deploy PNDA on top of bare-metal nodes, OpenStack platform services are used. The two main services involved in this process are Ironic and Heat.

Bare metal nodes on top of which PNDA is to be deployed will need to implement an IPMI interface for power management and be able to boot using PXE to boot and deploy an operating system. We make use of the pxe_ipmitool ironic driver which is generic enough to manage power management and pxe boot on a vast majority of servers.

The remainder of this guide is structured as follows.

#### Informative

1. [Overview (below)](#overview)

#### Detailed Walkthrough
2. [Create Build Node](create-build-node.md)
3. [Create Undercloud VM](create-undercloud.md)
4. [Deploy Undercloud](deploy-undercloud.md)
5. [Create SaltMaster](create-saltmaster.md)
6. [Register Nodes](registering-nodes.md)
7. [Create Application Server VM](app-server.md)
8. [Create PNDA](create-pnda.md)

#### Additional information
9. [Creating a Virtual Environment](virtual-env.md)

## Overview

![](bm-workflow.png)

The high level deployment steps are -

-   Identify and configure the hardware resources - servers and networks - that will be used
-   Create the Build Node
-   Gather bare-metal nodes specifications (IPMI ip address, IPMI credentials, MAC address)
-   Populate the Ironic database with node specifications
-   Introspect the nodes
-   Tag the nodes with profiles
-   Start the heat stack deployment

### Identify and configure the hardware resources

Firstly, a set of suitable hardware must be commissioned and configured. This includes, for example, making sure that all disks are set up with the desired RAID configuration, network switches and routers are properly configured and so on. 

To facilitate the remainder of the process it's useful at this stage to spend some time to compile an accurate inventory of all machine capabilities including CPUs, memory and storage as well as all interfaces, MAC addresses and so on.

### Build Node

The Build Node hosts a number of components used in the provisioning process.

#### Undercloud

The Undercloud is the infrastructure director node. It is a single-system OpenStack installation that includes components for provisioning and managing the servers that ultimately form the underlying PNDA cluster. 

The principal role of the Undercloud is bare metal system control -  via Ironic it uses the Intelligent Platform Management Interface (IPMI) of each node for power management control and a PXE-based service to discover hardware attributes and install software to each node. This provides a method by which we can provision bare metal systems as if they were regular OpenStack nodes.

Please see [the TripleO documentation](http://tripleo.org/) for more information on the architectural concepts.

At part of the Undercloud build we will also create the necessary images for both discovering and provisioning the bare metal servers and for the PNDA nodes.

#### Salt Master

PNDA uses SaltStack to take care of provisioning, managing configuration and upgrading at the software and services layer above the infrastructure. Please see [this quick overview of SaltStack](https://docs.saltstack.com/en/latest/topics/tutorials/walkthrough.html).

SaltStack servers are either designated Master and Minion. The Master is the server hosts all policies and configuration and pushes those to the minions. The Minions are the infrastructure hosts that are to be managed. All communication is encrypted and Minions are securely authenticated with the Master.

#### Application Package Server

PNDA requires a variety of software to be installed during the provisioning process. This software is built from our GitHub and staged on a simple HTTP server in the orchestration environment. 

At provisioning time, when Minions execute SaltStack states, software from this server is downloaded, installed and configured.

### Registering the bare metal cluster 

Once the Undercloud is in place, a skeleton definition of the bare metal cluster is prepared using the inventory information gathered earlier. This definition is then used as an input to drive the Ironic introspection process that then fills out the precise details of the hardware cluster and its capabilitities and stores this in the Ironic database. 

Next, we decorate the database with details of how OpenStack flavors map to the different classes of node that have been introspected. At this point, we can now use regular Nova tools to create instances with a given flavor. 

We are now ready to provision PNDA.

### Provisioning PNDA

Once the infrastructure is in place, the normal PNDA provisioning process for OpenStack is used to define service roles for the nodes and then to trigger the installation of the platform services and software using SaltStack.

This is achieved using Heat Templates and the Heat engine.

Underneath, Nova will select suitable machines via Ironic based on the earlier flavor tagging and the machines will be PXE booted and images installed on the physical disks. 

You can read more about PNDA provisioning processes on our [GitHub](https://github.com/pndaproject/pnda-guide/tree/develop/provisioning).

### Key differences between PNDA 'standard' and 'bare metal' Heat templates

Essentially the main differences between the templates for a standard cluster and those for a bare metal cluster are the removal of the requirement to create volumes and networks, since these are physically present.

We've included a bare metal PNDA flavor in the pnda-heat-templates repository for reference. Please modify this to match your target hardware cluster. 

#### CLI

- Modify to reference new flavor

#### Bootstrap scripts

- It's not necessary to assign volumes from OpenStack - as these are physically present
- But keep any required preparation steps e.g. mkdir, mkfs

#### Templates

- It's likely you'll have a different number of nodes with different roles
- Volumes and networks are made conditional - as these are physically present

# References

The PNDA project homepage: [http://pnda.io](http://pnda.io/)

The OpenStack project documentation:
[http://docs.openstack.org](http://docs.openstack.org/)

The TripleO project documentation:
[http://tripleo.org](http://tripleo.org/)
