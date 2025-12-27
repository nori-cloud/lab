# Cluster Setup Guide

Step-by-step guide to bootstrap a single-node Talos Linux cluster with Democratic-CSI storage connected to TrueNAS, all running on Proxmox.

---

## Step 1: Prepare Proxmox Environment

Create two VMs on your Proxmox host:

**TrueNAS VM:**
- Purpose: Provides iSCSI storage for the cluster
- Allocate sufficient CPU, RAM, and disk for ZFS

**Talos VM:**
- Purpose: Runs the Kubernetes cluster
- 4 CPUs, 32GB RAM, 256GB storage
- Network: Static IP (e.g., 10.0.0.110)

---

## Step 2: Configure TrueNAS for iSCSI

1. Install TrueNAS and configure networking (e.g., 10.0.0.251)

2. Create ZFS datasets:
   - `volume-0/talos/iscsi/v` for persistent volumes
   - `volume-0/talos/iscsi/s` for snapshots

3. Enable services:
   - **iSCSI sharing service** - for block storage
   - **SSH service** - for CSI driver communication

4. Configure iSCSI:
   - Create a portal on port 3260
   - Create a portal group (e.g., group 8)
   - Create an initiator group (e.g., group 14)
   - Allow the Talos node to connect

5. Create an API user:
   - Username: `democratic-csi`
   - Grant permissions for ZFS and iSCSI operations

---

## Step 3: Create Talos ISO

1. Go to [Talos Image Factory](https://factory.talos.dev/)

2. Select extensions:
   - `iscsi-tools` (required for iSCSI storage)

3. Download the ISO with your schematic ID

4. Upload the ISO to Proxmox

---

## Step 4: Install Talos Linux

1. Boot the Talos VM from the ISO

2. Install `talosctl` on your workstation

3. Generate cluster configuration:
   ```bash
   talosctl gen config nori-cloud https://10.0.0.110:6443 --install-disk /dev/sda
   ```

4. Edit `controlplane.yaml` to configure:
   - Pod Security: set `enforce: privileged` for CSI drivers
   - Allow scheduling on control plane: `allowSchedulingOnControlPlanes: true`

5. Apply configuration to the node:
   ```bash
   talosctl apply-config --insecure --nodes 10.0.0.110 --file controlplane.yaml
   ```

6. Set the talosctl endpoint:
   ```bash
   talosctl --talosconfig=./talosconfig config endpoints 10.0.0.110
   ```

7. Bootstrap etcd:
   ```bash
   talosctl bootstrap --nodes 10.0.0.110 --talosconfig=./talosconfig
   ```

8. Get kubeconfig:
   ```bash
   talosctl kubeconfig --nodes 10.0.0.110 --talosconfig=./talosconfig
   ```

9. Verify the cluster:
   ```bash
   kubectl get nodes
   ```

---

## Step 5: Deploy Democratic-CSI

1. Create the credentials secret (see [Authentication](#authentication)):
   ```bash
   ./setup-democratic-csi-secret.sh --username democratic-csi --password YOUR_PASSWORD
   ```

2. Deploy snapshot CRDs and Democratic-CSI via Terraform:
   ```bash
   cd /home/cluster
   tofu apply
   ```
   This deploys:
   - Snapshot CRDs (`snapshot-crds.tf`)
   - Democratic-CSI Helm release (`democratic-csi.tf`)

3. Verify the storage class:
   ```bash
   kubectl get storageclasses
   ```

---

## Step 6: Test Storage

Create a test PVC:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: iscsi
  resources:
    requests:
      storage: 1Gi
```

Verify:
```bash
kubectl get pvc
kubectl get pv
```

---

## Reference

### Cluster Configuration

| Setting | Value |
|---------|-------|
| Cluster name | `nori-cloud` |
| Control plane IP | 10.0.0.110 |
| API endpoint | https://10.0.0.110:6443 |
| Pod CIDR | 10.244.0.0/16 |
| Service CIDR | 10.96.0.0/12 |
| Kubernetes version | v1.35.0 |

### Storage Configuration

| Setting | Value |
|---------|-------|
| TrueNAS IP | 10.0.0.251 |
| iSCSI portal | 10.0.0.251:3260 |
| Storage class | `iscsi` |
| Volume dataset | `volume-0/talos/iscsi/v` |
| Snapshot dataset | `volume-0/talos/iscsi/s` |
| Portal group | 8 |
| Initiator group | 14 |

### Authentication

Democratic-CSI requires credentials to communicate with TrueNAS via two channels:

**HTTP API (port 80):** Used for TrueNAS API calls to manage ZFS datasets, iSCSI targets, and extents.

**SSH (port 22):** Used for ZFS operations that require shell access.

**How Credentials Are Stored:**

Credentials are stored in a Kubernetes secret (`democratic-csi-driver-config`) that is created **before** deploying the Helm chart. The Helm values file references this secret via `existingConfigSecret`.

Use the provided script to create the secret:
```bash
./setup-democratic-csi-secret.sh --username democratic-csi --password YOUR_PASSWORD
```

This creates a secret containing the full driver configuration with your credentials. The secret is created using `kubectl` and is separate from the Helm release, keeping credentials out of version control.

**Verify the secret:**
```bash
kubectl get secret democratic-csi-driver-config -n democratic-csi
```

**TrueNAS User Permissions:**

The `democratic-csi` user needs:
- Read/write access to datasets under `volume-0/talos`
- Permission to create/delete iSCSI targets and extents
- SSH access for ZFS operations

### Architecture

This is a **single-node cluster** running both control plane and worker:
- **Control plane**: etcd, kube-apiserver, kube-controller-manager, kube-scheduler
- **Worker**: kubelet, kube-proxy, application pods

Trade-offs:
- No high availability (single point of failure)
- Simpler to manage and lower resource usage
- Suitable for homelab and development workloads
