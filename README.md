# Container-Only Lab - Proof of Concept

**Status:** Ready for deployment testing  
**Created:** 2026-05-18  
**Last Updated:** 2026-05-19  
**Purpose:** Test if Showroom can deploy labs using containers instead of KubeVirt VMs

## Verification Status

✅ **AgnosticD code verified** - `zero-touch-base-rhel` handles `virtualmachines: []` safely  
✅ **Networking verified** - Terminal access routes confirmed in showroom-deployer  
✅ **Resource limits configured** - Prevents BestEffort QoS and container eviction  
⏳ **Awaiting deployment** - Ready when sandbox credentials received

## Research Question

Can short, targeted RHEL BU content be deployed in containers to achieve:
- **75-85% faster deployment** (15-45s vs 2-5min)
- **~90% lower memory overhead** (100-200MB vs 1.5-2GB)
- **Higher lab density** (20-40 labs/node vs 5-10 labs/node)

## Key Difference

| Configuration | This PoC | Standard Zerotouch Lab |
|---------------|----------|------------------------|
| `virtualmachines:` | `[]` (empty) | 1-14 VMs |
| `containers:` | 1 UBI9 container | 0-5 support containers (Gitea, Kafka) |
| Terminal access | `/terminal_shell` (in-pod bash) | `/wetty_<vmname>` (SSH) |
| AgnosticD role | `zero-touch-base-rhel` (confirmed) | `zero-touch-base-rhel` |

## Directory Structure

```
poc-containers-only-lab/
├── README.md                  # This file
├── config/
│   ├── instances.yaml         # Container-only (no VMs)
│   ├── firewall.yaml          # Egress for package installs
│   └── networks.yaml          # Empty (not used by containers)
├── ui-config.yml              # Terminal tab configuration
└── content/
    ├── antora.yml
    └── modules/ROOT/
        ├── nav.adoc
        └── pages/
            ├── index.adoc             # Welcome + test instructions
            └── container-basics.adoc  # Container examples
```

## Test Procedure

### Option 1: Direct Deployment (AgnosticD)

**Assumption:** `zero-touch-base-rhel` can handle empty `virtualmachines:` list.

1. Push this repo to GitHub: `https://github.com/rhpds/poc-containers-only-lab.git`

2. Create test catalog item in `zt-rhelbu-agnosticv`:
   ```yaml
   # zt-rhelbu/poc-containers-only/common.yaml
   __meta__:
     deployer:
       type: agnosticd
       scm_type: git
       scm_url: https://github.com/redhat-cop/agnosticd.git
       scm_ref: development
       entry_point: ansible/main.yml
     catalog:
       display_name: "[PoC] Container-Only Lab"
   
   env_type: zero-touch-base-rhel
   cloud_provider: openshift_cnv
   
   ocp4_workload_showroom:
     repo: https://github.com/rhpds/poc-containers-only-lab.git
   ```

3. Deploy to sandbox:
   ```bash
   # Order via catalog.demo.redhat.com or zero.rhdp.net
   # Watch for AgnosticD failures in pre_software.yml (no bastions group)
   ```

4. Monitor deployment:
   ```bash
   oc get pods -n <sandbox-namespace> -w
   oc logs -f <showroom-pod> -c git-cloner
   oc logs -f <showroom-pod> -c antora-builder
   oc logs -f <showroom-pod> -c rhel-shell  # Container with commands
   ```

### Option 2: Manual Helm Deployment (Faster Testing)

**Skip AgnosticD, deploy Showroom chart directly:**

```bash
# Clone showroom-deployer
git clone https://github.com/rhpds/showroom-deployer.git

# Create test namespace
oc new-project poc-containers-test

# Deploy with Helm
helm upgrade --install showroom-poc \
  showroom-deployer/charts/zerotouch/ \
  --set instances[0].repo=https://github.com/rhpds/poc-containers-only-lab.git \
  --set instances[0].name=poc-containers \
  --namespace poc-containers-test
```

**Advantage:** Bypasses AgnosticD entirely, tests chart directly.

### Option 3: Local Helm + Local Repo (Fastest Iteration)

```bash
# Create ConfigMap with instances.yaml
oc create configmap poc-instances \
  --from-file=instances.yaml=config/instances.yaml \
  -n poc-containers-test

# Deploy chart with local config
helm upgrade --install showroom-poc \
  showroom-deployer/charts/zerotouch/ \
  --set instances[0].repo=https://github.com/rhpds/poc-containers-only-lab.git \
  --set instances[0].name=poc-containers \
  --set instances[0].instancesConfigMap=poc-instances \
  --namespace poc-containers-test
```

## Success Criteria

**Phase 1 (Deployment Mechanics):**
- ✅ Showroom pod starts successfully
- ✅ Container `rhel-shell` starts and runs `commands:`
- ✅ Terminal accessible at `/terminal_shell`
- ✅ Antora site builds and loads

**Phase 2 (Functionality):**
- ✅ Learner can execute bash commands
- ✅ RHEL tools available (vim, tmux, git, python3)
- ✅ Container stays running (no CrashLoopBackOff)
- ✅ Resource usage < 500MB memory

**Phase 3 (Performance):**
- ✅ Total deployment time < 1 minute
- ✅ Container start < 30 seconds
- ✅ Memory usage < 200MB idle

## Expected Failures

**AgnosticD `pre_software.yml` failures (if using zero-touch-base-rhel):**
- `bastions` group empty → skips `bastion-base` role
- `all:!centos:!isolated` empty → skips `set-repositories`, package installs
- Satellite registration skipped (no VMs to register)

**Workaround:** These are expected. AgnosticD assumes VMs exist. A new `env_type: zero-touch-base-containers` would skip these steps.

**Chart validation failures:**
- If `showroom-deployer` chart validates that `virtualmachines:` is not empty
- **Check:** `charts/zerotouch/templates/_helpers.tpl` for validation logic

## Measurement Data

Fill in after deployment:

| Metric | VM Baseline | Container (This PoC) | Improvement |
|--------|-------------|----------------------|-------------|
| Infrastructure time | 30-60s | ___s | ___ |
| Boot time | 60-120s | ___s | ___ |
| Setup time | 30-90s | ___s | ___ |
| **Total time** | **2-4.5min** | **___s** | **___%** |
| Memory (idle) | 1.5-2GB | ___MB | ___ |
| CPU (idle) | 0.1-0.2 cores | ___m | ___ |

## Next Steps

1. **If successful:**
   - Identify 5 simple RHEL BU labs as candidates
   - Create `zero-touch-base-containers` AgnosticD env_type
   - Update showroom:create-zerotouch-lab skill

2. **If AgnosticD fails:**
   - Document exact failure points
   - Determine if new env_type is required
   - Prototype minimal config without CNV infrastructure

3. **If chart fails:**
   - Check if `virtualmachines:` can be empty
   - Determine if chart PRs needed
   - Consider hybrid approach (1 minimal VM + containers)

## References

- [Full Research Plan](../cursor-revisit/platform/containers-only-deployment-research-plan.md)
- [AgnosticD Code Verification](../cursor-revisit/platform/agnosticd-containers-only-code-verification.md)
- [Networking Verification](./NETWORKING_VERIFICATION.md) ✅ Terminal access verified
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Quick Start](./QUICK_START.md)
- [Container Guide](../rhdp-skills-marketplace/showroom/skills/create-zerotouch-lab/references/containers-guide.md)
- [Showroom Authoring Reference](../cursor-revisit/platform/showroom-lab-authoring-reference.md)
- [Zero-Touch Playbook Chain](../cursor-revisit/troubleshooting/concepts/rhdp-zt-agnosticd-zero-touch-base-rhel-playbook-chain.md)

---

**Created by:** RHDP Zerotouch Research  
**Status:** Experimental - Phase 1 PoC  
**Last Updated:** 2026-05-18
