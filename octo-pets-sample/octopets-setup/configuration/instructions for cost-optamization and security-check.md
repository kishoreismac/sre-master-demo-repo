# 🚀 Proactive Cloud Ops with SRE Agent

**Scheduled Checks for Continuous Cloud Optimization**

Cloud operations isn’t just about keeping things running — it’s about running them better.

This repository demonstrates how to build a **proactive cloud optimization system** using:

* 🤖 Primary SRE Agent (orchestrator)
* 🧩 Specialized sub-agents (Security & Cost)
* ⏰ Scheduled triggers
* 📢 Microsoft Teams notifications
* 🐙 GitHub issue automation
* 📊 Azure-native telemetry

Instead of reactive firefighting, this setup enables **continuous cloud hygiene and optimization**.

---

# 📌 Problem Statement

Modern cloud environments are dynamic:

* New features ship weekly
* Traffic patterns shift
* Costs creep quietly
* Security posture drifts
* Teams forget unused resources

> The real question is not **“Is something broken?”**
> It is **“Could this be better?”**

Most teams check occasionally.
**SRE Agent checks continuously.**

---

# 🧱 Four Pillars of Cloud Optimization

| Pillar          | Goal                        | Common Challenge               |
| --------------- | --------------------------- | ------------------------------ |
| 🔐 Security     | Stay compliant, reduce risk | Config drift, expiring secrets |
| 💰 Cost         | Spend efficiently           | Hard to spot waste             |
| ⚡ Performance   | Meet SLOs                   | Scaling too late               |
| 🟢 Availability | Maximize uptime             | Hidden SPOFs                   |

---

# 🏗️ Solution Architecture

## Components

* Primary SRE Agent (orchestrator)
* Security Optimization Sub-Agent
* Cost Optimization Sub-Agent
* Azure Monitor & Resource Graph
* org-practices knowledge base
* GitHub integration
* Teams integration
* Scheduled triggers

## High-Level Flow

1. Primary agent orchestrates checks
2. Sub-agents perform domain analysis
3. Findings compared against org standards
4. GitHub issues created automatically
5. Teams alerts sent
6. Runs on schedule

---

# 📋 Prerequisites

Before starting, ensure:

* Azure subscription access
* SRE Agent enabled
* Reader role at subscription scope
* Microsoft Teams channel
* GitHub repository access
* org-practices.md prepared

---

# ⚙️ Step 1 — Create Primary SRE Agent

**Steps**

1. Go to **SRE Agent Studio**
2. Click **Create Agent**
3. Configure:

   * Scope: **Subscription**
   * Role: **Reader**
4. Do **NOT** restrict to a single resource group
5. Save the agent

✅ This agent acts as the **orchestrator**.

---

# 📚 Step 2 — Upload Organization Practices

Create file:

```bash
org-practices.md
```

Define what “good” looks like for:

* Security rules
* Cost thresholds
* Tagging standards
* Secret rotation policy
* Public exposure rules

**Steps**

1. Open **Knowledge Base**
2. Click **Upload document**
3. Upload `org-practices.md`
4. Confirm indexing completes

> 💡 This is the MOST important step — it gives the agent context.

---

# 🧩 Step 3 — Create Security Sub-Agent (Detailed)

## 3.1 Open Subagent Builder

**Steps**

1. Go to **Subagent builder** tab
2. Click **Create → Subagent**

---

## 3.2 Basic Configuration

Set:

* **Name:** `security-optimization-agent`
* **Type:** `Autonomous`

---

## 3.3 Instructions

Paste:

```text
You are a security optimization specialist.

Responsibilities:
- Scan Azure resources for security violations
- Compare against org-practices.md
- Classify severity (Critical/High/Medium/Low)
- Detect public exposure risks
- Detect expiring or expired secrets
- Validate TLS and identity posture
- Provide remediation guidance

Output requirements:
- Include resource name
- Include business impact
- Include remediation steps
- Be concise and actionable
```

---

## 3.4 Handoff

Set:

```text
Use this agent to perform security posture and compliance checks across Azure resources.
```

---

## 3.5 Select Tools

Select (as available in your environment):

* Azure Resource Graph query
* Azure Monitor / Log Analytics
* App Insights query (optional)
* Knowledge base read
* GitHub issue creation
* Teams notification

---

## 3.6 Create Sub-Agent

Click **Create subagent**

✅ Security sub-agent ready.

---

# 💰 Step 4 — Create Cost Sub-Agent (Detailed)

## 4.1 Open Subagent Builder

**Steps**

1. Go to **Subagent builder**
2. Click **Create → Subagent**

---

## 4.2 Basic Configuration

Set:

* **Name:** `cost-optimization-agent`
* **Type:** `Autonomous`

---

## 4.3 Instructions

Paste:

```text
You are a FinOps and cost optimization specialist.

Responsibilities:
- Identify underutilized compute resources
- Detect unattached disks and idle public IPs
- Find overprovisioned services
- Compare against org-practices.md
- Estimate potential savings
- Provide rightsizing recommendations

Output requirements:
- Include resource name
- Include estimated savings when possible
- Include severity
- Include remediation steps
- Prioritize high-cost waste
```

---

## 4.4 Handoff

Set:

```text
Use this agent to perform cost efficiency and waste detection across Azure resources.
```

---

## 4.5 Select Tools

Recommended:

* Azure Resource Graph
* Azure Monitor metrics
* Cost Management data (if available)
* Knowledge base read
* GitHub issue creation
* Teams notification

---

## 4.6 Create Sub-Agent

Click **Create subagent**

✅ Cost sub-agent ready.

---

# 🔗 Step 5 — Connect Microsoft Teams

**Steps**

1. Go to **Integrations → Teams**
2. Add your channel
3. Configure routing:

| Severity | Action          |
| -------- | --------------- |
| Critical | Immediate alert |
| High     | Immediate alert |
| Medium   | Daily digest    |
| Low      | Weekly digest   |

---

# 🐙 Step 6 — Map Resource Groups to GitHub

Link ownership.

**Example**

| Resource Group       | Repository          |
| -------------------- | ------------------- |
| rg-security-opt-demo | security-demoapp    |
| rg-cost-opt-sreademo | costoptimizationapp |

✅ Enables automatic issue creation.

---

# 🧪 Step 7 — Manual Validation

## Security Test

```text
Invoke security-optimization-agent to scan resource group "rg-security-opt-demo" against org-practices.md. Send Teams message and create GitHub issue.
```

Verify:

* Findings returned
* Teams alert received
* GitHub issue created

---

## Cost Test

```text
Invoke cost-optimization-agent to scan resource group "rg-cost-opt-sreademo" against org-practices.md. Send Teams message and create GitHub issue.
```

---

# ⏰ Step 8 — Create Weekly Security Trigger

## 8.1 Create Trigger

* Go to **Create → Scheduled trigger**
* Name:

```
WeeklySecurityCheck
```

---

## 8.2 Schedule

* Frequency: Weekly
* Day: Wednesday
* Time: 08:00 UTC

---

## 8.3 Instructions

```text
Run security practices checks against org-practices.md for mapped resource groups. Create GitHub issues and send Teams notifications.
```

---

## 8.4 Connect Agent

Select:

```
security-optimization-agent
```

---

## 8.5 Create Trigger

Click **Create**

✅ Security automation enabled.

---

# ⏰ Step 9 — Create Weekly Cost Trigger

## 9.1 Create Trigger

Name:

```
WeeklyCostReview
```

---

## 9.2 Schedule

* Frequency: Weekly
* Day: Monday
* Time: 08:00 UTC

---

## 9.3 Instructions

```text
Run cost optimization checks against org-practices.md for mapped resource groups. Create GitHub issues and send Teams notifications.
```

---

## 9.4 Connect Agent

Select:

```
cost-optimization-agent
```

---

## 9.5 Create Trigger

Click **Create**

✅ Cost automation enabled.

---

# ✅ Validation Checklist

* [ ] Primary agent created
* [ ] org-practices uploaded
* [ ] Security sub-agent working
* [ ] Cost sub-agent working
* [ ] Teams notifications working
* [ ] GitHub issues created
* [ ] Weekly triggers active

---

# 🎯 Outcome

You now have:

* 🤖 Context-aware SRE system
* 🔐 Security specialist agent
* 💰 FinOps specialist agent
* ⏰ Fully automated weekly optimization
* 📢 Teams-native alerts
* 🐙 GitHub-native remediation workflow

**Your cloud is now continuously improving — not just running.**

---

# 🔮 Future Enhancements

* AKS/Kubernetes sub-agent
* Auto-remediation PR agent
* FinOps anomaly detection
* Policy-as-code integration
* Multi-cloud support

---

⭐ If this repo helps you build proactive cloud operations, consider starring it!
