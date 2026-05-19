# Container Conversion Notes: zt-using-file-permissions

This lab has been converted from VM-based to container-based deployment.

## Key Changes

### 1. Image with Pre-Baked Setup

**Image:** `quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions`

All setup from `setup-automation/setup-rhel.sh` is now baked into the container image:

- Group `team` created at build time
- `/srv/status.sh` and `/srv/tasks.txt` with correct permissions
- `/srv/proprietary/` directory with 4 contract files
- All ownership and permissions pre-configured

**Result:** No setup-automation init container needed.

### 2. Removed Automation Directories

**Deleted:**
- `setup-automation/` - Setup baked into image
- `runtime-automation/` - Scripts were stubs (only echoed to /tmp/progress.log)

**Why runtime-automation was removed:**
- Playbook tries to SSH into containers (no SSH server exists)
- All scripts were no-op stubs that only logged progress
- Adds Ansible overhead with zero benefit
- Increases deployment time unnecessarily

### 3. Container-Native Configuration

**instances.yaml:**
```yaml
containers:
  - name: rhel
    image: quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions
    command: ['sleep', 'infinity']
    terminals:
      - name: shell
        command: oc exec -it rhel -- /bin/bash
```

**Benefits:**
- No SSH bastion required
- Direct terminal access via `oc exec`
- Faster startup (no init containers running Ansible)
- Simpler architecture

## Deployment Configuration

### For PoC Testing (developer-experience catalog)

The PoC repo is ready to deploy as-is. The showroom-deployer chart will:

1. Skip setup-automation (no directory exists)
2. Skip runtime-automation (no directory exists)
3. Deploy container with pre-configured image
4. Provide terminal access via /shell URL

### For Production Catalog Item

When creating the AgnosticV catalog item, explicitly disable automation:

**catalog_items/zt-using-file-permissions.yaml:**
```yaml
ocp4_workload_showroom_setup_automation_setup: "false"
ocp4_workload_showroom_runtime_automation_setup: "false"
```

**Why disable explicitly:**
- Default is "true" in showroom-deployer chart
- Even with missing directories, the init containers may still run
- Explicit disable prevents unnecessary wait/retry cycles
- Clearer intent in catalog configuration

## Image Maintenance

If lab setup needs to change:

1. Update `/home/wilson/Projects/rhpds-lab-images/rhel-lab-tools-file-permissions/Dockerfile`
2. Rebuild image with new version tag (e.g., v1.1.1-file-permissions)
3. Push to quay.io
4. Update `instances.yaml` image reference
5. Test deployment

**Alternative approach for minor tweaks:**
Use `commands:` field in instances.yaml to run additional setup:

```yaml
containers:
  - name: rhel
    image: quay.io/rhn_support_wharris/rhel-lab-tools:v1.1.0-file-permissions
    commands:
      - sudo bash -c 'echo "new content" > /srv/newfile.txt'
```

This executes via `kubernetes.core.k8s_exec` after container creation.

## Performance Impact

**VM-based deployment:**
- 4-6 minutes total
- Includes: VM provisioning, cloud-init, SSH wait, setup-automation, runtime-automation per page

**Container-based deployment (estimated):**
- <90 seconds total
- Includes: Pod creation, image pull (cached), container start
- No SSH, no bastion, no Ansible overhead

**Savings from removing automation:**
- setup-automation: ~30-60s (Ansible + SSH + script execution)
- runtime-automation per page: ~10-20s × 8 pages = 80-160s
- **Total savings: 110-220 seconds** on top of VM → container conversion

## Testing Checklist

Before deploying:

- [ ] Image pushed to quay.io and set to PUBLIC
- [ ] Image verified (test team group, /srv files, permissions)
- [ ] instances.yaml uses correct image tag
- [ ] ui-config.yml has correct terminal configuration
- [ ] Content files unchanged (all commands work in container)
- [ ] Test deployment measures actual time to Ready state
- [ ] Terminal access works (browser lands in container shell)
- [ ] All 8 lab modules function correctly

## Known Differences from VM Version

1. **Hostname:** Container hostname is pod name (e.g., `rhel`), not `host1.example.com`
2. **Network interfaces:** `eth0` instead of `enp1s0` (doesn't affect this lab)
3. **Systemd:** Not running (doesn't affect this lab - no services needed)
4. **Root access:** User 1001 with passwordless sudo (compatible with all lab commands)
5. **Persistence:** Container filesystem is ephemeral (fine for read-only exercises)

## Future Improvements

**When moving to production:**

1. **Multi-architecture support:** Build for amd64 and arm64
2. **Image signing:** Use cosign for supply chain security
3. **Registry migration:** Move from personal to quay.io/rhpds organization
4. **CI/CD:** GitHub Actions for automated builds on Dockerfile changes
5. **Version tagging:** Semantic versioning with changelog
6. **Size optimization:** Multi-stage builds, layer optimization
7. **Security scanning:** Integrate trivy/clair for vulnerability detection

**For broader lab conversion program:**

1. Create base rhel-lab-tools:v2.0.0 with common patterns
2. Document lab-specific image creation workflow
3. Provide Dockerfile templates for common lab types
4. Build image catalog with usage examples
5. Establish naming conventions (e.g., rhel-lab-tools-{lab-name}:v{version})
