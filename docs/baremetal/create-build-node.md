# Creating the build Node 

## Overview

The purpose of this node is to host the functions required to conduct both initial orchestration and subsequent updates and maintenance of the PNDA cluster.

The deployment host can be either a virtual machine or a physical machine. It will have two network interfaces. One will be dedicated to provisioning and administration of the bare-metal nodes, the other one will provide direct external connectivity, as suggested below.

![](bm-deployment.png)

The deployment host operating system will preferably be either a Centos 7 or Redhat Enterprise Linux 7.

**TODO** could it be Ubuntu?

Creating the build node involves the following steps

1. [Create Undercloud VM](create-undercloud.md)
2. [Deploy Undercloud](deploy-undercloud.md)
3. [Create SaltMaster](create-saltmaster.md)
4. [Register Nodes](registering-nodes.md)
5. [Create Application Server VM](app-server.md)
