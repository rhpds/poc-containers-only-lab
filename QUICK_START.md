# PoC Container Lab - Quick Start

**Repo:** https://github.com/rhpds/poc-containers-only-lab  
**Goal:** Prove containers deploy 75-85% faster than VMs

---

## 1. Order Lab (via Developer Experience)

```
Catalog item: "Developer Experience"
Content repo: https://github.com/rhpds/poc-containers-only-lab.git
```

---

## 2. Get Credentials

Wait for email with:
- Sandbox namespace: `sandbox-XXXXX-XXXXX`
- OCP cluster URL
- Login credentials

---

## 3. Quick Validation (30 seconds)

```bash
NAMESPACE=sandbox-XXXXX-XXXXX  # Replace with your namespace

# Check pod is running
oc get pods -n $NAMESPACE

# Check NO VMs created (proof it's container-only)
oc get vm -n $NAMESPACE
# Expected: "No resources found" ✅

# Check QoS is Burstable (has resource limits)
POD=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/name=showroom -o name)
oc get $POD -n $NAMESPACE -o jsonpath='{.status.qosClass}'
# Expected: "Burstable" ✅

# Get Showroom URL
oc get route showroom -n $NAMESPACE -o jsonpath='{.spec.host}'
# Open in browser, click Terminal tab
```

---

## 4. Measure Timing (Critical!)

```bash
POD=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/name=showroom -o name)

# Get created and ready timestamps
oc get $POD -n $NAMESPACE -o json | jq '{
  created: .metadata.creationTimestamp,
  ready: .status.conditions[] | select(.type=="Ready") | .lastTransitionTime
}'

# Calculate total deployment time
# Target: <60 seconds
# VM baseline: 120-270 seconds (2-4.5 minutes)
```

---

## 5. Collect Results

```bash
# Complete data dump
cat > ~/poc-results.txt << EOF
Namespace: $NAMESPACE
Created: $(oc get $POD -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
Ready: $(oc get $POD -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')
QoS: $(oc get $POD -n $NAMESPACE -o jsonpath='{.status.qosClass}')
VMs created: $(oc get vm -n $NAMESPACE 2>&1 | wc -l)
Showroom URL: https://$(oc get route showroom -n $NAMESPACE -o jsonpath='{.spec.host}')
EOF

cat ~/poc-results.txt
```

---

## Success = <1 Minute Deployment

**VM baseline:** 2-4.5 minutes  
**Container target:** 15-45 seconds  
**Savings:** 75-85%

---

## Full Guide

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for:
- Detailed measurement commands
- Troubleshooting steps
- Resource usage validation
- Comparison table

---

**Questions?** Check [README.md](./README.md) or [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
