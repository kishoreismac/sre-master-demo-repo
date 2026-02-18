# Security Posture Demo for SRE Agent

This demo deploys Azure resources with **intentional security misconfigurations** for SRE Agent to detect.

## What Gets Deployed

| Resource | Intentional Issue | SRE Agent Should Detect |
|----------|-------------------|------------------------|
| NSG | SSH (22) open to 0.0.0.0/0 | ⚠️ Insecure inbound rule |
| NSG | RDP (3389) open to 0.0.0.0/0 | ⚠️ Insecure inbound rule |
| Storage Account | Public blob access enabled | ⚠️ Data exposure risk |
| Key Vault | Secrets expiring in <30 days | ⚠️ Credential expiration |
| Private DNS Zone | Missing VNet link | ⚠️ DNS resolution will fail |

## Deploy

```bash
cd security-posture-demo
azd auth login
azd init
azd up
```

## Test with SRE Agent

After deployment, use this prompt with SRE Agent:

```
Run a security posture check on my subscription. Find:
1. NSG rules allowing inbound 0.0.0.0/0 on ports 22, 3389, or 1433
2. Storage accounts with public blob access enabled
3. Key Vault secrets expiring in the next 30 days
4. Private DNS zones missing VNet links

For each finding, explain the risk and recommend a fix.
```

## Expected Findings

SRE Agent should identify:
- 2 NSG rules with overly permissive source addresses
- 1 storage account with public blob access
- 3 secrets expiring soon (14, 19, 24 days)
- 1 Private DNS Zone without VNet link

## Clean Up

```bash
azd down --purge
```