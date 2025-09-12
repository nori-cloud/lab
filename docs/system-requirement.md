# System Requirements

Whole bunch of system requirements to run stuffs

- [opnsense](#opnsense)
- [TrueNAS](#truenas)
  - [Hybrid Storage Solution](#hybrid-storage-solution)
  - [Tips](#tips)
- [Proxmox VE](#proxmox-ve)
- [pi-hole](#pi-hole)
- [k3s](#k3s)

## [opnsense](https://docs.opnsense.org/manual/hardware.html)

[back to top](#system-requirements)

Minimum

The minimum specification to run all OPNsense standard features that do not need disk writes, means you can run all standard features, except for the ones that require disk writes, e.g. a caching proxy (cache) or intrusion detection and prevention (alert database).

|                       | Minimum                                                                                                                                                                                                                                                                   | Reasonable                                                                                                                                                | Recommended                                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Processor             | 1 GHz dual core cpu                                                                                                                                                                                                                                                       | 1 GHz dual core cpu                                                                                                                                       | 1.5 GHz multi core cpu                                                                                                          |
| RAM                   | 2 GB                                                                                                                                                                                                                                                                      | 4 GB                                                                                                                                                      | 8 GB                                                                                                                            |
| Install Target        | SD or CF card with a minimum of 4 GB, use nano images for installation.                                                                                                                                                                                                   | 40 GB SSD, a minimum of 2 GB memory is needed for the installer to run.                                                                                   | 120 GB SSD                                                                                                                      |
| Throughput            | 11-150                                                                                                                                                                                                                                                                    | 151-350                                                                                                                                                   | 350-750+                                                                                                                        |
| Users/Networks (Mbps) | 10-30                                                                                                                                                                                                                                                                     | 30-50                                                                                                                                                     | 50-150+                                                                                                                         |
| Feature Set           | reduced                                                                                                                                                                                                                                                                   | all                                                                                                                                                       | all                                                                                                                             |
| Description           | The minimum specification to run all OPNsense standard features that do not need disk writes, means you can run all standard features, except for the ones that require disk writes, e.g. a caching proxy (cache) or intrusion detection and prevention (alert database). | The reasonable specification to run all OPNsense standard features, means every feature is functional, but perhaps not with a lot of users or high loads. | The recommended specification to run all OPNsense standard features, means every feature is functional and fits most use cases. |

## [TrueNAS](https://www.truenas.com/docs/scale/gettingstarted/scalehardwareguide/)

[back to top](#system-requirements)

|         | Minimum                                     |
| ------- | ------------------------------------------- |
| CPU     | 2-Core Intel 64-Bit or AMD x86_64 processor |
| RAM     | 8GB - 8 drives, +1GB/drive                  |
| Storage | 16GB for OS                                 |

About Memory Sizing: https://www.truenas.com/docs/scale/gettingstarted/scalehardwareguide/#memory-sizing

### [Hybrid Storage Solution](https://www.truenas.com/docs/scale/gettingstarted/scalehardwareguide/#expand-8)

[back to top](#system-requirements)

With TrueNAS and OpenZFS, you can merge flash and disk to create hybrid storage that makes the most of both types. Hybrid setups use high-capacity spinning disks to store data, while DRAM and flash perform hyper-fast read and write caching. The technologies work together with a flash-based separate write log (SLOG)

### Tips

- 8 x 4TB is better than 2 x 16TB, better write
- [Best not to virtualize TrueNAS](https://www.truenas.com/docs/scale/gettingstarted/scalehardwareguide/#virtualized-truenas)

## [Proxmox VE](https://www.proxmox.com/en/products/proxmox-virtual-environment/requirements)

[back to top](#system-requirements)

For production servers, high quality server equipment is needed. Proxmox VE supports clustering, this means that multiple Proxmox VE installations can be centrally managed thanks to the integrated cluster functionality. Proxmox VE can use local storage like (DAS), SAN, NAS, as well as shared, and distributed storage (Ceph).

## [pi-hole](https://docs.pi-hole.net/main/prerequisites/)

[back to top](#system-requirements)

|         |                               |
| ------- | ----------------------------- |
| CPU     | 'not much processing power"   |
| RAM     | 512 MB                        |
| Storage | 2GB min, 4Gb recommended      |
| Network | static IP or DHCP reservation |

## [k3s](https://docs.k3s.io/installation/requirements)

[back to top](#system-requirements)

K3s is available for the following architectures: `x86_64, armhf, arm64/aarch64`

|         | Server                                       | Agent  |
| ------- | -------------------------------------------- | ------ |
| CPU     | 2 cores                                      | 1 core |
| RAM     | 2GB                                          | 512 MB |
| Storage | SSD, no SD Cards, eMMC, etcd write intensive |
| DB      | best external                                |

## etcd hardware requirements

|         | "Typical Cluster"                                                                                                                             | Heavy Load    |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| CPU     | 2 - 4 cores                                                                                                                                   | 8 - 16 cores  |
| RAM     | 8GB                                                                                                                                           | 16 - 64GB     |
| Network | 1Gbe                                                                                                                                          | 10Gbe - Heavy |
| Disk    | - 50 sequential IOPS (7200RPM disk)<br>- 500 sequential IOPS (SSD or HiPerf virtualized block device)<br>- diskbench, fio - benchmarking tool |
