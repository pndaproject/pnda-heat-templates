# Change Log
All notable changes to this project will be documented in this file.

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
