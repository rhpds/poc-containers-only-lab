# zt-using-file-permissions Container Conversion - Ready for Deployment

**Status:** ✅ READY FOR TESTING

**Branch:** `zt-using-file-permissions-conversion`

**Last Updated:** 2026-05-19

---

## What's Changed

### Container Image Built and Pushed

**Image:** `quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions` (519 MB)

**Pre-configured setup:**
- ✅ Group `team` (GID 1002)
- ✅ `/srv/status.sh` (rwxr-x---, root:root)
- ✅ `/srv/tasks.txt` (rwxr-x---, root:root)
- ✅ `/srv/proprietary/` directory (rw-r-----, root:root)
- ✅ 4 contract files (rwxrwxrwx, root:root)
- ✅ Non-root user 1001 with passwordless sudo
- ✅ OpenShift SCC compatible

### Repository Cleaned Up

**Removed:**
- ❌ `setup-automation/` (setup baked into image)
- ❌ `runtime-automation/` (stub scripts with no function)

**Performance gain:** ~110-220 seconds saved by eliminating unnecessary Ansible overhead

**Updated:**
- ✅ `config/instances.yaml` uses container image
- ✅ `ui-config.yml` configured for terminal access
- ✅ `CONTAINER_CONVERSION_NOTES.md` documents approach

**Unchanged:**
- ✅ All 8 content modules (100% compatible with containers)
- ✅ `config/networks.yaml` (default network)
- ✅ `config/firewall.yaml` (TCP 443 egress)

---

## Deployment Configuration

### instances.yaml

```yaml
containers:
  - name: rhel
    image: quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions
    command: ['sleep', 'infinity']
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "1"
        memory: "1Gi"
    terminals:
      - name: shell
        command: oc exec -it rhel -- /bin/bash
```

### ui-config.yml

```yaml
name: Using File Permissions
description: Learn RHEL file permissions, ownership, and chmod/chown commands

antora:
  name: modules
  dir: www
  modules:
    - name: "01-what-are-file-permissions"
      label: "What Are File Permissions"
    # ... (8 modules total)

tabs:
  - name: Terminal
    type: terminal
    url: /shell
    external: false
```

---

## Expected Deployment Metrics

### VM-Based (Baseline)

| Metric | Value |
|--------|-------|
| Total deployment time | 4-6 minutes |
| VM provisioning | 2-3 minutes |
| Setup-automation | 30-60 seconds |
| Runtime-automation overhead | 80-160 seconds (8 pages × 10-20s each) |
| Resource usage | 4 GB memory, 1 vCPU, 40 GB disk |

### Container-Based (Target)

| Metric | Target | Improvement |
|--------|--------|-------------|
| Total deployment time | <90 seconds | **77-79% faster** |
| Pod creation + image pull | 30-60 seconds | N/A |
| Setup-automation | 0 seconds (baked in) | **100% eliminated** |
| Runtime-automation overhead | 0 seconds (removed) | **100% eliminated** |
| Resource usage | 512 MB-1 GB memory, 500m-1 vCPU | **75-87% reduction** |

### Cost Efficiency

| Metric | VM-Based | Container-Based | Improvement |
|--------|----------|-----------------|-------------|
| Memory per lab | 4 GB | 512 MB-1 GB | **75-87% reduction** |
| Labs per 128 GB node | ~32 labs | 128-256 labs | **4-8x capacity** |
| Deployment overhead | 110-220 seconds | 0 seconds | **Eliminated** |

---

## Pre-Deployment Checklist

### Image Preparation

- [x] Image built and tested locally
- [x] Image pushed to quay.io/rhn_support_wharris
- [ ] **TODO:** Set quay.io repository to PUBLIC (no imagePullSecrets configured)
- [x] Image verified (team group, /srv files, permissions)

### Repository Configuration

- [x] instances.yaml uses correct image tag
- [x] ui-config.yml has terminal configuration
- [x] setup-automation removed
- [x] runtime-automation removed
- [x] All commits pushed to branch

### Content Verification

- [x] All 8 content modules unchanged
- [x] All commands container-compatible (verified via research)
- [x] No VM-specific references in content
- [x] Terminal access configured for /shell URL

### Testing Plan

- [ ] Deploy via developer-experience catalog
- [ ] Measure time from namespace creation to pod Ready
- [ ] Verify terminal access works (browser → container shell)
- [ ] Test all 8 lab modules:
  - [ ] 01-what-are-file-permissions
  - [ ] 02-interacting-with-different-users
  - [ ] 03-chmod-command
  - [ ] 04-modifying-permissions
  - [ ] 05-modifying-absolute
  - [ ] 06-changing-ownership
  - [ ] 07-changing-group-ownership
  - [ ] 08-find-audit-permissions
- [ ] Verify commands work: ls -l, chmod, chown, chgrp, find -perm, groupadd
- [ ] Check resource usage (oc adm top pod)
- [ ] Document actual deployment time

---

## Deployment Instructions

### 1. Make Image Public

**CRITICAL:** Before deploying, set quay.io repository to public:

1. Login to quay.io
2. Navigate to `quay.io/rhn_support_wharris/rhel-lab-tools`
3. Settings → Make Public
4. Confirm

**Why:** No imagePullSecrets configured in showroom-deployer for private registries.

### 2. Deploy via Developer-Experience Catalog

**Catalog item:** `zt-rhel-bu-lab-developer-cnv`

**Content repo URL:** Point to this PoC repo branch:
```
https://github.com/rhpds/poc-containers-only-lab.git
ref: zt-using-file-permissions-conversion
```

**Or:** Update the catalog item to point to the converted branch if already configured.

### 3. Monitor Deployment

```bash
# Watch pod creation
oc get pods -n <namespace> -w

# Check events
oc get events -n <namespace> --sort-by='.lastTimestamp'

# Check pod details when ready
oc describe pod showroom-<hash> -n <namespace>

# Check resource usage
oc adm top pod -n <namespace>
```

### 4. Test Terminal Access

1. Open lab UI in browser
2. Click "Terminal" tab
3. Verify landing in container shell as user `rhel`
4. Run: `whoami` (should show: rhel)
5. Run: `sudo whoami` (should show: root)
6. Run: `ls -la /srv` (should show status.sh, tasks.txt, proprietary/)

### 5. Test Lab Content

Work through all 8 modules verifying:
- Content renders correctly
- All commands execute successfully
- File permissions exercises work as expected
- No errors in browser console

---

## Success Criteria

### Deployment Time

- ✅ Pod reaches Running state in <60 seconds
- ✅ Pod reaches Ready state in <90 seconds
- ✅ Total time competitive with or faster than PoC baseline (83s)

### Functionality

- ✅ Terminal access works via browser
- ✅ All 8 lab modules render correctly
- ✅ All file permission commands work
- ✅ Group operations work (team group exists)
- ✅ /srv files accessible with correct permissions

### Resource Efficiency

- ✅ Memory usage: 512 MB-1 GB (vs 4 GB VM)
- ✅ CPU usage: 500m-1 vCPU (vs 1 vCPU VM)
- ✅ No disk allocation needed (ephemeral container)

### User Experience

- ✅ Identical UX to VM-based labs
- ✅ Terminal access transparent (no manual oc exec)
- ✅ Content unchanged from VM version
- ✅ Commands work without modification

---

## Next Steps After Successful Testing

### 1. Production Image Registry

Move image to official RHPDS registry:

```bash
# Pull from personal registry
podman pull quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions

# Tag for RHPDS registry
podman tag quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions \
            quay.io/rhpds/rhel-lab-tools:v1.1.0-file-permissions

# Push to RHPDS (requires credentials)
podman push quay.io/rhpds/rhel-lab-tools:v1.1.0-file-permissions
```

Update instances.yaml to use quay.io/rhpds image.

### 2. Create Production Catalog Item

Create `zt-rhelbu-agnosticv/catalog_items/zt-using-file-permissions/`:

```yaml
# agnosticv.yaml
ocp4_workload_showroom_setup_automation_setup: "false"
ocp4_workload_showroom_runtime_automation_setup: "false"
# ... standard zerotouch config
```

### 3. Document for Lab Authors

Add case study to container-only-labs-authoring-guide.md:

- Conversion process from VM to container
- How to bake setup into image vs use commands field
- When to remove automation directories
- Performance gains achieved

### 4. Update Container Conversion Research

Add zt-using-file-permissions to:
- `/home/wilson/Projects/cursor-revisit/platform/container-conversion-research-summary.md`
- Document as successful pilot conversion
- Update viability statistics (4 researched, 1 converted, 100% success rate for viable labs)

### 5. Plan Additional Conversions

Based on this pilot, convert remaining viable labs:
- zt-unixisms (also uses rhel-lab-tools, very similar)
- zt-managing-user-basics (user/group operations, similar setup)

---

## Rollback Plan

If deployment fails or testing reveals issues:

1. **Image issues:** Use v1.1.0 base image with `commands:` field for setup
2. **Setup issues:** Restore setup-automation directory, re-enable in catalog
3. **Functionality issues:** Document and fix in next image version
4. **Critical failure:** Revert to VM-based deployment while investigating

---

## Contact & Support

**Repository:** https://github.com/rhpds/poc-containers-only-lab  
**Branch:** zt-using-file-permissions-conversion  
**Image:** quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions

**Documentation:**
- CONTAINER_CONVERSION_NOTES.md - Detailed conversion notes
- README.md - Original PoC documentation
- DEPLOYMENT_GUIDE.md - Original deployment instructions
