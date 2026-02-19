# Octopets Autonomous SRE Agent Ecosystem

## End-to-End Setup & Implementation Guide

------------------------------------------------------------------------

# 1. Overview

This document provides complete step-by-step instructions to set up the
Octopets Autonomous SRE Agent ecosystem in Azure.

It covers:

-   Azure resource preparation
-   Log Analytics & monitoring setup
-   Alert rule creation
-   Incident response configuration
-   GitHub MCP connector setup
-   Outlook connector setup
-   Teams connector setup
-   Creation of each SRE agent
-   Scheduled tasks configuration
-   Full operational flow

------------------------------------------------------------------------

# 2. Prerequisites

Ensure the following are available:

-   Azure Subscription
-   Azure Container Apps deployed (Octopets backend)
-   Log Analytics Workspace
-   Application Insights enabled
-   GitHub repository for Octopets
-   Microsoft Teams workspace
-   Outlook mailbox for notifications
-   Azure SRE Agent enabled (Preview)

------------------------------------------------------------------------

# 3. Azure Monitoring Setup

## 3.1 Enable Log Analytics

1.  Create or use existing Log Analytics Workspace.
2.  Connect Container App diagnostics to Log Analytics.
3.  Enable:
    -   ContainerAppConsoleLogs
    -   AzureDiagnostics
    -   AppRequests (if App Insights enabled)

## 3.2 Enable Application Insights

1.  Create Application Insights resource.
2.  Link it to Container App.
3.  Verify telemetry flow via Logs.

------------------------------------------------------------------------

# 4. Alert Rule Creation (Latency and Failure Alerts)

## 4.1 Create Metric-Based Alert

1.  Navigate to Azure Monitor → Alerts → Create Alert Rule.
2.  Select target resource (Container App).
3.  Condition examples:
    -   HTTP 5xx \> 5% over 5 minutes
    -   P95 Latency \> 2x baseline
4.  Set evaluation frequency (5 min).
5.  Define Action Group.

## 4.2 Create Action Group

1.  Choose action type: Azure SRE Agent Trigger.
2.  Link to:
    -   OctoIncidentDiagnosticsAgent
3.  Name action group: "Latency and Failure Alerts".

------------------------------------------------------------------------

# 5. Incident Response Plan Creation

Incident Flow:

Detect → Diagnose → Report → Remediate → Optimize → Govern

Define:

-   Severity thresholds
-   Escalation paths
-   Notification recipients
-   Auto-remediation guardrails
-   GitHub issue creation standards

------------------------------------------------------------------------

# 6. Connectors Setup

## 6.1 GitHub MCP Server Setup

1.  Install GitHub MCP extension in Azure SRE Agent.
2.  Authenticate using GitHub PAT (with repo access).
3.  Configure repository access:
    -   Enable read/write issues
    -   Enable commit inspection
    -   Enable semantic code search

Used tools: - GithubConnector_issue_write - GithubConnector_issue_read -
GithubConnector_list_commits - GithubConnector_get_commit -
GithubConnector_assign_copilot_to_issue

## 6.2 Outlook Connector Setup

1.  Enable Outlook connector in Azure.
2.  Authenticate using organizational mailbox.
3.  Grant permission to send emails.

Used tool: - SendOutlookEmail

Email formatting standard: - Blue header (#0066CC) - Dark sections
(#2d2d2d) - White readable text - Inline CSS - Mobile responsive layout

## 6.3 Microsoft Teams Connector Setup

1.  Enable Teams connector.
2.  Authenticate to target tenant.
3.  Select target channel (e.g., SRE-DEMO).
4.  Grant message posting permission.

Used tool: - TeamsConnector

------------------------------------------------------------------------

# 7. Agent Creation Guide

Navigate to: Azure SRE Agents → Create → Autonomous Agent

## 7.1 OctoHealthMonitorAgent

Type: Autonomous Trigger: Scheduled (Every 30 minutes)

Purpose: - Monitor 5xx rate - Monitor latency - Monitor CPU/memory -
Trigger alert if anomaly

Tools: - QueryLogAnalyticsByResourceId -
GetMetricTimeSeriesElementsForAzureResource - RunAzCliReadCommands -
GetCurrentUtcTime

## 7.2 OctoIncidentDiagnosticsAgent

Type: Autonomous Trigger: Alert-based

Purpose: - Deep root cause analysis - KQL execution - Metrics
correlation - GitHub code inspection - Create issue - Generate PDF -
Send email & Teams notification

Tools: - QueryLogAnalyticsByResourceId - PlotTimeSeriesData -
ExecutePythonCode - GitHub MCP tools - SendOutlookEmail - TeamsConnector

## 7.3 OctoAutoRemediationAgent

Type: Autonomous Trigger: Handoff

Purpose: - Identify bad revision - Roll back traffic to stable
revision - Validate recovery

Tools: - RunAzCliReadCommands - RunAzCliWriteCommands -
GetMetricTimeSeriesElementsForAzureResource - GetCurrentUtcTime

Guardrails: - No blind restart - Validate metrics post remediation

## 7.4 OctoCloudOptimizationAgent

Type: Autonomous Trigger: Daily scheduled

Purpose: - Identify overprovisioned resources - Suggest scaling
optimization - Provide cost savings estimate

Tools: - QueryLogAnalyticsByResourceId -
GetMetricTimeSeriesElementsForAzureResource - RunAzCliReadCommands -
GetCurrentUtcTime

## 7.5 OctoGovernanceComplianceAgent

Type: Autonomous Trigger: Weekly scheduled

Purpose: - Tag compliance checks - Diagnostic settings validation -
Public ingress detection - IaC drift detection

Tools: - RunAzCliReadCommands - QueryLogAnalyticsByResourceId -
GetCurrentUtcTime

------------------------------------------------------------------------

# 8. Scheduled Task Configuration

Create scheduled triggers:

-   Octopets-API-Health-Check-30min → Every 30 min
-   Octopets-Daily-Optimization-Check → Daily
-   Octopets-Weekly-Governance-Check → Weekly

Attach respective agents.

------------------------------------------------------------------------

# 9. End-to-End Operational Flow

1.  Health agent detects anomaly.
2.  Alert rule fires.
3.  Diagnostics agent performs deep analysis.
4.  GitHub issue created with evidence.
5.  Email + Teams notification sent.
6.  Auto-remediation agent rolls back if needed.
7.  Optimization agent runs daily.
8.  Governance agent runs weekly.

------------------------------------------------------------------------

# 10. Validation Checklist

Before demo:

-   Logs flowing
-   Alerts firing correctly
-   GitHub issue creation working
-   Email sent successfully
-   Teams message posted
-   Rollback validated in test scenario
-   Scheduled agents executing

------------------------------------------------------------------------

# 11. Conclusion

This completes the A--Z setup of the Octopets Autonomous SRE Agent
ecosystem.

The system demonstrates:

-   Proactive monitoring
-   Autonomous diagnostics
-   Safe remediation
-   Cost optimization
-   Governance enforcement
-   Multi-agent orchestration
