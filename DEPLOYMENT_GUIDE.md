# PoC Container-Only Lab - Deployment Guide

**GitHub Repo:** https://github.com/rhpds/poc-containers-only-lab  
**Purpose:** Test container-only deployment (no VMs) for 75-85% faster boot times

---

## Quick Deployment (Developer Experience Pattern)

Since you're testing via developer experience catalog item (points at GitHub repo directly), no catalog item creation needed.

### Step 1: Order Developer Experience Lab

1. Go to catalog.demo.redhat.com or zero.rhdp.net
2. Order "Developer Experience" catalog item
3. **Set content repo parameter:**
   ```
   https://github.com/rhpds/poc-containers-only-lab.git
   ```

### Step 2: Get Sandbox Credentials

Once provisioned, you'll receive:
- Sandbox namespace: `sandbox-<guid>`
- OCP cluster URL
- Access credentials

### Step 3: Monitor Deployment

```bash
# Set your namespace
NAMESPACE=sandbox-<your-guid>

# Watch pod creation
oc get pods -n $NAMESPACE -w

# Expected sequence:
# 1. showroom-<hash> pod created
# 2. Init containers run: git-cloner, antora-builder
# 3. Main containers start: content, nginx, wetty, etc.
# 4. rhel-shell container starts (our test container)
```

---

## Deployment Timing Measurements

**Track these timestamps:**

### Phase 1: Infrastructure (should be ~0s - no VMs!)

```bash
# Watch for Showroom pod creation
oc get pods -n $NAMESPACE -o json | \
  jq '.items[] | select(.metadata.name | startswith("showroom")) | .metadata.creationTimestamp'
```

**Expected:** Pod created immediately (no DataVolume cloning)

### Phase 2: Init Containers

```bash
# Watch init container sequence
oc get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.initContainerStatuses[*]}{"\t"}{.name}{": "}{.state}{"\n"}{end}{end}'

# Time git-cloner
oc logs -n $NAMESPACE <showroom-pod> -c git-cloner

# Time antora-builder
oc logs -n $NAMESPACE <showroom-pod> -c antora-builder
```

**Expected:** 
- git-cloner: 5-10s
- antora-builder: 10-15s

### Phase 3: Container Start (rhel-shell)

```bash
# Watch rhel-shell container (our test container)
oc logs -n $NAMESPACE <showroom-pod> -c rhel-shell -f

# Check container start time
oc get pod <showroom-pod> -n $NAMESPACE -o json | \
  jq '.status.containerStatuses[] | select(.name=="rhel-shell") | .state.running.startedAt'
```

**Expected:**
- Image pull: 5-15s (first time), <1s (cached)
- Commands execution: 10-20s (dnf install vim tmux git python3)
- Total: 15-35s

### Phase 4: Total Ready Time

```bash
# Check pod Ready condition
oc get pod <showroom-pod> -n $NAMESPACE -o json | \
  jq '.status.conditions[] | select(.type=="Ready")'

# Calculate total time
CREATED=$(oc get pod <showroom-pod> -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
READY=$(oc get pod <showroom-pod> -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')

echo "Created: $CREATED"
echo "Ready: $READY"
# Calculate difference manually or with date commands
```

**Target:** <1 minute total (vs 3-5 min for VMs)

---

## Validation Checklist

### Container Health

```bash
# Check all containers running
oc get pod <showroom-pod> -n $NAMESPACE -o jsonpath='{range .status.containerStatuses[*]}{.name}{": "}{.state}{"\n"}{end}'

# Expected: All containers in "running" state
# Key containers:
# - content (nginx serving Antora site)
# - nginx (reverse proxy)
# - wetty (terminal proxy)
# - rhel-shell (our test container) ← IMPORTANT
```

### Resource Usage

```bash
# Check resource requests/limits applied
oc get pod <showroom-pod> -n $NAMESPACE -o json | \
  jq '.spec.containers[] | select(.name=="rhel-shell") | {name, resources}'

# Expected:
# resources:
#   limits:
#     cpu: 1000m
#     memory: 2Gi
#   requests:
#     cpu: 500m
#     memory: 1Gi

# Check actual usage
oc adm top pod <showroom-pod> -n $NAMESPACE --containers

# Expected memory for rhel-shell: 100-300MB (not 2GB - that's the limit)
```

### QoS Class

```bash
# Verify QoS class (should be Burstable, NOT BestEffort)
oc get pod <showroom-pod> -n $NAMESPACE -o jsonpath='{.status.qosClass}'

# Expected: Burstable
# BestEffort = BAD (no limits, evicted first)
# Burstable = GOOD (has limits, protected)
# Guaranteed = BEST (requests == limits)
```

### Terminal Access

```bash
# Get Showroom URL
SHOWROOM_URL=$(oc get route showroom -n $NAMESPACE -o jsonpath='{.spec.host}')
echo "Showroom UI: https://$SHOWROOM_URL"

# Terminal should be accessible at:
# https://<showroom-url>/terminal_shell
# NOT /wetty_shell (that's for VMs via SSH)
```

**Manual test in browser:**
1. Open Showroom URL
2. Click "Terminal" tab
3. Should see bash prompt
4. Run: `cat /etc/redhat-release`
5. Run: `python3 --version`
6. Run: `rpm -qa | wc -l` (check installed packages)

### No VMs Created (Critical!)

```bash
# Verify NO VirtualMachines created
oc get vm -n $NAMESPACE

# Expected: No resources found (success!)

# Verify NO DataVolumes created
oc get datavolume,dv -n $NAMESPACE

# Expected: No resources found (success!)

# This confirms we bypassed CNV infrastructure entirely
```

---

## Expected vs Actual Results Table

Fill this out during testing:

| Metric | Target | Actual | Pass/Fail |
|--------|--------|--------|-----------|
| **Infrastructure time** | 0s (no VMs) | ___s | ☐ |
| **Init containers** | 15-25s | ___s | ☐ |
| **Container start** | 15-35s | ___s | ☐ |
| **Total ready time** | <60s | ___s | ☐ |
| **Memory (idle)** | <300MB | ___MB | ☐ |
| **CPU (idle)** | <50m | ___m | ☐ |
| **QoS Class** | Burstable | ___ | ☐ |
| **Terminal accessible** | Yes | ___ | ☐ |
| **VMs created** | 0 | ___ | ☐ |
| **DataVolumes created** | 0 | ___ | ☐ |

---

## Comparison with VM Baseline

For context, typical VM-based lab timings:

| Phase | VM Baseline | Container Target | Expected Savings |
|-------|-------------|------------------|------------------|
| Infrastructure | 30-60s (DataVolume clone) | 0s | 30-60s |
| Boot | 60-120s (cloud-init) | 5-15s | 45-105s |
| Setup | 30-90s (SSH + commands) | 10-30s | 20-60s |
| **Total** | **2-4.5 min** | **15-45s** | **75-85%** |

---

## Troubleshooting

### Container CrashLoopBackOff

```bash
# Check container logs
oc logs <showroom-pod> -n $NAMESPACE -c rhel-shell

# Common causes:
# - dnf install failed (network issue)
# - useradd failed (permission issue)
# - commands: exited non-zero

# Fix: Check firewall.yaml allows port 443 egress
oc get networkpolicy -n $NAMESPACE -o yaml
```

### Terminal Not Accessible

```bash
# Check nginx routing
oc logs <showroom-pod> -n $NAMESPACE -c nginx | grep terminal_shell

# Check wetty proxy
oc logs <showroom-pod> -n $NAMESPACE -c wetty

# Verify route exists
oc get route showroom -n $NAMESPACE
```

### Image Pull Errors

```bash
# Check image pull status
oc describe pod <showroom-pod> -n $NAMESPACE | grep -A 10 Events

# If ubi9 image fails:
# - Check registry.redhat.io connectivity
# - Verify no proxy issues
# - Check ImagePullBackOff events
```

### Resource Limits Not Applied

```bash
# If QoS is BestEffort instead of Burstable:
oc get pod <showroom-pod> -n $NAMESPACE -o yaml | grep -A 10 resources:

# Verify instances.yaml was parsed correctly
# Check showroom-deployer chart applied limits
```

---

## Success Criteria

**Deployment succeeds if:**
- ✅ Total deployment time < 1 minute
- ✅ Memory usage < 300MB idle
- ✅ QoS class: Burstable (has limits)
- ✅ Terminal accessible via `/terminal_shell`
- ✅ No VMs or DataVolumes created
- ✅ Container stays running (no crashes)

**Deployment FAILS if:**
- ❌ Takes > 2 minutes (slower than VM!)
- ❌ Memory > 1GB (approaching limit)
- ❌ QoS class: BestEffort (no limits)
- ❌ Terminal not accessible
- ❌ VMs created (instances.yaml parsed wrong)
- ❌ Container CrashLoopBackOff

---

## Data Collection Commands (Copy-Paste Ready)

```bash
# Set your namespace
NAMESPACE=sandbox-XXXXX-XXXXX

# Get pod name
POD=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/name=showroom -o name | head -1)

# Complete status dump
cat > /tmp/poc-container-results.txt << EOF
=== PoC Container-Only Lab Results ===
Date: $(date)
Namespace: $NAMESPACE
Pod: $POD

=== Timing ===
Created: $(oc get $POD -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
Ready: $(oc get $POD -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')

=== Resources ===
$(oc adm top $POD -n $NAMESPACE --containers 2>/dev/null || echo "Metrics not available")

=== QoS ===
QoS Class: $(oc get $POD -n $NAMESPACE -o jsonpath='{.status.qosClass}')

=== Container Status ===
$(oc get $POD -n $NAMESPACE -o jsonpath='{range .status.containerStatuses[*]}{.name}{": "}{.state}{"\n"}{end}')

=== VM Check (should be empty) ===
$(oc get vm -n $NAMESPACE 2>&1)

=== Route ===
Showroom URL: https://$(oc get route showroom -n $NAMESPACE -o jsonpath='{.spec.host}')

=== Resource Limits (rhel-shell container) ===
$(oc get $POD -n $NAMESPACE -o json | jq '.spec.containers[] | select(.name=="rhel-shell") | {name, resources}')
EOF

cat /tmp/poc-container-results.txt
```

---

## Next Steps After Deployment

1. **If successful (<1 min deployment):**
   - Document actual timings
   - Take screenshots of terminal
   - Note any issues encountered
   - Proceed to Phase 3: AgnosticD integration

2. **If issues found:**
   - Capture full pod logs
   - Document failure mode
   - Check if chart validation or AgnosticD issue
   - Adjust PoC and retry

3. **Comparison test:**
   - Deploy equivalent VM-based lab (e.g., zt-podman-basics)
   - Measure timing difference
   - Calculate actual % improvement

---

**Repository:** https://github.com/rhpds/poc-containers-only-lab  
**Status:** Ready for deployment testing  
**Questions:** Check README.md or deployment logs
