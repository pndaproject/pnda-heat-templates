# Change Log
All notable changes to this project will be documented in this file.

## [Unreleased]
### Changed
- PNDA-3583: hadoop distro is now part of grains
- Issue-143: Added pnda_internal_network and pnda_ingest_network as grains.

## [1.4.0] 2017-11-24
### Added:
- PNDA-2969: Allow hadoop distro to be set in `pnda_env.yaml`. Supported values are `HDP` and `CDH`.
- PNDA-2389: PNDA automatically reboots instances that need rebooting following kernel updates

### Changed
- PNDA-3444: Disallow uppercase letters in the cluster names.
- PNDA-2965: Rename `cloudera_*` role grains to `hadoop_*`
- PNDA-3180: When expanding a cluster limit the operations to strictly required steps on specific nodes
- PNDA-3249: put mine configuration in pillar
- Issue-123: Fixed Jenkins GPG Key Added in package-install.sh file

### Fixed
- PNDA-3499: Cleanup CHANGELOG with missing release info.
- PNDA-3524: remove beacons logic

## [1.3.0] 2017-08-01
### Added
- PNDA-3043: Added [mandatory] os_user parameter to pnda_env.yaml - the target platform specific operating system user/sudoer used to configure the cluster instances
- PNDA-2375: Isolate PNDA from breaking dependency changes
- PNDA-2456: Initial work to support for Redhat 7. Salt highstate and orchestrate run on a Redhat7 HEAT cluster with no errors but requires further testing and work
- PNDA-2680 adding extra index url in pip configuration
- PNDA-2708: Add pip index URL in order to enable offline installation
- PNDA-2709: Allow offline installation of ubuntu and redhat packages
- PNDA-2801: Add support for bare-metal deployment using the bmstandard flavor. Add support for distribution flavor providing kafka only cluser. Add documentation for baremetal deployment.
- PNDA-2801: Add offline support for distribution flavor
- PNDA-2878 Isolate PNDA from breaking dependency
- Add an hypervisor_count setting in the pnda_env file to enable Anti-Affinity feature in PNDA.
- Add ability to define a software config that applies a pre config script to all instances but bastion.
- A 'specific_config' parameter to 'pnda_env.yaml' in order to pass parameters to bootstrap scripts and salt pillar, in a generic way
- Example instackenv.json for bare metal
- Add code to make Salt-master listen on a specific VLAN interface
- Add functionality to simulate offline deployment and support pico flavor
- Add online fallback for yum

### Changed
- PNDA-2446: Place PNDA packages in root of PNDA_MIRROR
- PNDA-2688: review pnda_env default values
- PNDA-2691: Use GPG key for nodejs repo
- PNDA-2696: Use PNDA_MIRROR for misc files
- PNDA-2717: Rename mirror paths
- PNDA-2819: fix issue on volume reference once create network is 0
- PNDA-2882: Only create package repo volume in standard flavour if the repo type is set to local
- PNDA-2883: Allow `keystone_auth_version` to be set in `pnda.yaml`
- PNDA-3167: change flavor to m4 in order to be align with the PNDA guide and AWS templates
- fix issue on preconfig error as keystone auth version not needed
- Use 'requests' instead of 'tornado' to download files in salt
- Make saltmaster listen on eth0 by default
- Prioritize local mirror over original repo

### Fixed
- PNDA-2804: Remove unused cloudera role on kafka instance
- PNDA-2916: Make number of kafka nodes variable for pico flavour
- PNDA-2833: pylint fixes

## [1.2.0] 2017-01-20
### Changed
- PNDA-2493: Align openstack and AWS flavors

### Fixed
- PNDA-2475: Fix the way to handle package repository configuration
- Bad data type the 'name_servers' parameter to 'comma_delimited_list'

## [1.1.0] 2016-12-12
### Added
- PNDA-2159: Create a runfile containing structured info about run
- Added numerous comments to bootstrap scripts and templates as in-code documentation
- Added Anti Affinity hints to the nova scheduler

### Changed
- PNDA-2262: If deploy key not found create one with a helpful message
- PNDA-2386: Updates to volume sizes
- PNDA-2387: Run a minion on the saltmaster instance
- PNDA-2428: Mount disks using openstack IDs
- PNDA-2430: Log volume consistency changes
- Specify Anaconda mirror in PNDA YAML and make example mirror URIs consistent

### Fixed
- Move pnda_restart role to correct grain PNDA-2250
- Update doc to match new Cloudera version 5.9.0
- PNDA-2474: Execute PR volume logic conditionally

## [1.0.0] 2016-10-21
### Changed
- PNDA-2272: move to Salt 2015.8.11 in order to get the fix on orchestrate #33467
- PNDA-1211: Add the ability to manage swift / s3 / volume / sshfs or local for package repository backend storage
- PNDA-2248: Refactor heat template provisioning to enable flavors to be deployable on bare metal - firstly 'pico'
- The optional 'NtpServers' option can be set in the pnda_env.yaml configuration file if the default servers are not reacheable

## [0.2.0] 2016-09-07
### Changed
- Display Heat stack events while resizing a cluster
- Add the capability to configure an alternate Anaconda Parcels mirror

## [0.1.0] 2016-07-01
### First version
- Create PNDA from Heat templates
