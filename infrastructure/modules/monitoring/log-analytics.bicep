// ============================================================================
// SecureBank GRC Engineering - Log Analytics Workspace
// ============================================================================
// Central logging hub for all GRC evidence collection.
// Everything flows here: Azure Policy compliance, Defender alerts,
// Activity logs, resource diagnostics.
// This is the foundation of the GRC Data Platform.
// NIST CSF mapping: DE.CM-1, DE.CM-3, DE.CM-7, RS.AN-1
// ============================================================================

param location string
param projectName string
param tags object

// --- Variables ---
var workspaceName = 'law-${projectName}-central-${location}'

// --- Log Analytics Workspace ---
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      // PerGB2018 = pay per GB ingested, cheapest for dev/learning
      // Estimated cost: ~$2-5/month for light GRC data ingestion
      name: 'PerGB2018'
    }
    // 30 days retention - minimum for dev, increase for prod (90+ days)
    retentionInDays: 30
    features: {
      // Enables searching across workspaces - useful for multi-workspace GRC
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      // Daily cap at 1GB to prevent runaway costs during learning phase
      // Remove this cap in production
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// --- Enable Azure Activity Log collection ---
resource activityLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-activity-to-law'
  scope: logAnalyticsWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// --- Outputs ---
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output workspaceCustomerId string = logAnalyticsWorkspace.properties.customerId
