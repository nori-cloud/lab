# Democratic-CSI Module

This module deploys [democratic-csi](https://github.com/democratic-csi/democratic-csi) drivers for TrueNAS storage provisioning on a Talos Kubernetes cluster.

## Drivers

| Driver | StorageClass | Access Modes | Use Case |
|--------|--------------|--------------|----------|
| `freenas-iscsi` | `freenas-iscsi` | RWO (block/fs) | Databases, single-pod workloads |
| `freenas-nfs` | `freenas-nfs` (default) | RWX, RWO | Shared storage, general workloads |

## TrueNAS Setup

Before deploying, configure TrueNAS:

### 1. Create Datasets

Navigate to **Datasets** and create the following structure:

```
volume-0/talos/
├── iscsi/
│   ├── v/    # iSCSI volumes (zvols created here)
│   └── s/    # iSCSI snapshots
└── nfs/
    ├── v/    # NFS volumes (datasets created here)
    └── s/    # NFS snapshots
```

**Dataset settings:**
- For all datasets, use **Generic** preset (not SMB)
- ACL Type: **POSIX** (default, simpler for NFS/iSCSI)
- Record Size: Leave default or tune for workload

### 2. iSCSI Configuration

1. **Portal**: Create iSCSI portal (default port 3260)
2. **Initiator Group**: Create initiator group allowing cluster nodes
3. Note the Portal Group ID and Initiator Group ID for `setup-secrets.sh`

### 3. NFS Configuration

1. Enable NFS service
2. Ensure cluster nodes can access NFS shares

### 4. API Key

Create an API key in TrueNAS:
1. Click user menu (top-right) → **API Keys**
2. Click **Add** → name it (e.g., "democratic-csi")
3. Copy the key (shown only once)

### 5. SSH User with Sudo Permissions

The `freenas-iscsi` and `freenas-nfs` drivers use SSH to execute ZFS commands. Create a dedicated user with sudo access.

#### Step 1: Create the user

Navigate to **Credentials → Local Users → Add**:

| Field | Value |
|-------|-------|
| Full Name | `Democratic CSI` |
| Username | `democratic-csi` |
| Password | Disable password (uncheck) |
| Primary Group | Create new group (checked) |
| Home Directory | `/mnt/volume-0/democratic-csi` |
| Shell | `bash` or `sh` (**not** `csh` - causes quoting issues) |
| SSH Public Key | Paste your public key |
| SMB User | Disabled |

#### Step 2: Configure sudo permissions (ZFS commands only)

In the same user creation/edit screen, configure restricted sudo access:

1. Leave **Allow all sudo commands** unchecked
2. In **Allowed sudo commands with no password**, add:
   ```
   /usr/sbin/zfs
   /usr/sbin/zpool
   ```

> **Note**: TrueNAS SCALE manages sudoers internally. Do not edit `/etc/sudoers` directly as changes are overwritten on reboot.

#### Step 3: Verify SSH and sudo access

```bash
# Test SSH connection
ssh -i ~/.ssh/democratic-csi democratic-csi@10.0.0.251

# Test allowed commands (should work)
ssh -i ~/.ssh/democratic-csi democratic-csi@10.0.0.251 "sudo zfs list"
ssh -i ~/.ssh/democratic-csi democratic-csi@10.0.0.251 "sudo zpool status"

# Test restricted commands (should fail with "not allowed")
ssh -i ~/.ssh/democratic-csi democratic-csi@10.0.0.251 "sudo ls /"
ssh -i ~/.ssh/democratic-csi democratic-csi@10.0.0.251 "sudo cat /etc/passwd"
```

Expected output for restricted commands:
```
Sorry, user democratic-csi is not allowed to execute '/usr/bin/ls /' as root on truenas.
```

### 6. Dataset Permissions

The `democratic-csi` user needs ownership of parent datasets to create/delete child datasets and zvols.

1. Navigate to **Datasets → volume-0/talos**
2. Click **Edit** on the permissions widget
3. Set:
   - Owner: `democratic-csi`
   - Group: `democratic-csi`
4. Check **Apply permissions recursively**
5. Save

Repeat for both `iscsi` and `nfs` parent datasets.

#### Verify permissions

```bash
# SSH into TrueNAS and verify the user can manage datasets
ssh -i ~/.ssh/democratic-csi democratic-csi@10.0.0.251

# Test dataset creation (NFS)
sudo zfs create volume-0/talos/nfs/v/test-dataset
sudo zfs destroy volume-0/talos/nfs/v/test-dataset

# Test zvol creation (iSCSI)
sudo zfs create -V 1G volume-0/talos/iscsi/v/test-zvol
sudo zfs destroy volume-0/talos/iscsi/v/test-zvol
```

## Deployment

The module uses a `deploy_drivers` variable to control helm chart deployment. This ensures secrets are populated before drivers are installed.

### Step 1: Apply Terraform (creates namespace and empty secrets)

```bash
cd /workspace/lab/home
tofu apply -target=module.democratic_csi
```

With `deploy_drivers = false` (default), this only creates:
- Namespace
- Snapshot CRDs
- Empty secrets

### Step 2: Populate secrets

```bash
cd _democratic-csi

# Both drivers
./setup-secrets.sh --api-key "1-xxxxxxxxxxxx" --ssh-key ~/.ssh/democratic-csi

# Or individually
./setup-secrets.sh --api-key "1-xxxxxxxxxxxx" --ssh-key ~/.ssh/democratic-csi --iscsi-only
./setup-secrets.sh --api-key "1-xxxxxxxxxxxx" --ssh-key ~/.ssh/democratic-csi --nfs-only

# With custom host
./setup-secrets.sh --api-key "1-xxxxxxxxxxxx" --ssh-key ~/.ssh/democratic-csi --host 10.0.0.251
```

### Step 3: Deploy drivers

```bash
cd /workspace/lab/home
tofu apply -target=module.democratic_csi -var="deploy_democratic_csi_drivers=true"
```

## Customization

Edit `setup-secrets.sh` to modify:

| Setting | iSCSI | NFS |
|---------|-------|-----|
| Dataset paths | `zfs.datasetParentName` | `zfs.datasetParentName` |
| Snapshot paths | `zfs.detachedSnapshotsDatasetParentName` | `zfs.detachedSnapshotsDatasetParentName` |
| Portal/Initiator groups | `iscsi.targetGroups` | N/A |
| Share options | N/A | `nfs.shareMaprootUser`, etc. |

## Verification

### Check pods

```bash
kubectl get pods -n democratic-csi
```

Expected output:
```
democratic-csi-iscsi-controller-xxx   Running
democratic-csi-iscsi-node-xxx         Running (one per node)
democratic-csi-nfs-controller-xxx     Running
democratic-csi-nfs-node-xxx           Running (one per node)
```

### Check StorageClasses

```bash
kubectl get storageclasses
```

Expected output:
```
NAME             PROVISIONER                  DEFAULT
freenas-iscsi    org.democratic-csi.iscsi     false
freenas-nfs      org.democratic-csi.nfs       true
```

### Check CSI drivers

```bash
kubectl get csidrivers
```

## Testing

### Test NFS (RWX)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  storageClassName: freenas-nfs
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-nfs-pod
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo 'NFS works!' > /data/test.txt && cat /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: test-nfs-pvc
EOF
```

### Test iSCSI (RWO)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-iscsi-pvc
spec:
  storageClassName: freenas-iscsi
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-iscsi-pod
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo 'iSCSI works!' > /data/test.txt && cat /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: test-iscsi-pvc
EOF
```

### Verify test pods

```bash
# Check PVC status (should be Bound)
kubectl get pvc test-nfs-pvc test-iscsi-pvc

# Check pod logs
kubectl logs test-nfs-pod
kubectl logs test-iscsi-pod

# Verify on TrueNAS
# - Check datasets created under volume-0/talos/nfs/v/ and volume-0/talos/iscsi/v/
# - Check iSCSI targets created
```

### Cleanup test resources

```bash
kubectl delete pod test-nfs-pod test-iscsi-pod
kubectl delete pvc test-nfs-pvc test-iscsi-pvc
```

## Troubleshooting

### Check controller logs

```bash
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi-iscsi -c csi-driver
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi-nfs -c csi-driver
```

### Check node logs

```bash
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi-iscsi -c csi-driver --prefix
```

### Common issues

| Issue | Cause | Solution |
|-------|-------|----------|
| PVC stuck in Pending | Secret not configured | Run `setup-secrets.sh` |
| API authentication failed | Invalid API key | Regenerate API key in TrueNAS |
| SSH connection failed | Wrong key or user | Verify `democratic-csi` user has SSH key |
| iSCSI connection failed | Wrong portal/initiator group | Check TrueNAS iSCSI config |
| NFS mount failed | Permissions or network | Check NFS service and firewall |
| Node pods crashing | Talos config missing | Verify `node.hostPID` and nsenter settings |
| NFS `data.path` / `data.paths` error | TrueNAS SCALE 25.x API change | Use `next` image tag (see above) |
| `mkdir /usr/local/etc/iscsi: read-only` | Wrong iSCSI path for Talos | Update `iscsiDirHostPath` to `/etc/iscsi` |

### View secret configuration

```bash
# iSCSI config
kubectl get secret democratic-csi-iscsi-config -n democratic-csi \
  -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d

# NFS config
kubectl get secret democratic-csi-nfs-config -n democratic-csi \
  -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d
```

## References

- [democratic-csi GitHub](https://github.com/democratic-csi/democratic-csi)
- [democratic-csi Talos setup](https://github.com/democratic-csi/democratic-csi#talos)
- [TrueNAS CSI documentation](https://www.truenas.com/docs/solutions/integrations/containers/)
- [TrueNAS SCALE Managing Users](https://www.truenas.com/docs/scale/scaletutorials/credentials/manageusers/)
- [TrueNAS SCALE Dataset Permissions](https://www.truenas.com/docs/scale/scaletutorials/datasets/permissionsscale/)
- [TrueNAS + Talos + Democratic-CSI Guide](https://wazaari.dev/blog/truenas-talos-democratic-csi)

## TrueNAS SCALE 25.x Compatibility

TrueNAS SCALE 25.x introduced breaking API changes. The NFS driver requires the `next` image tag:

```yaml
# nfs-values.yaml
controller:
  driver:
    image:
      registry: docker.io/democraticcsi/democratic-csi
      tag: next
node:
  driver:
    image:
      registry: docker.io/democraticcsi/democratic-csi
      tag: next
```

See [GitHub Issue #479](https://github.com/democratic-csi/democratic-csi/issues/479) for details.

**Note**: The iSCSI driver works with the default image tag.

## Talos Notes

### Required Extension

Talos requires the `iscsi-tools` system extension for iSCSI support:

```bash
# Check installed extensions
talosctl get extensions -n <node-ip>
```

### iSCSI Path Configuration

The iSCSI config path depends on your iscsi-tools version:

| Extension Version | Config Path |
|-------------------|-------------|
| iscsi-tools v0.2.0 | `/etc/iscsi` |
| older versions | `/usr/local/etc/iscsi` |

Verify the correct path:

```bash
talosctl ls /etc/iscsi -n <node-ip>
talosctl ls /usr/local/etc/iscsi -n <node-ip>
```

Update `iscsiDirHostPath` in `iscsi-values.yaml` if needed.
