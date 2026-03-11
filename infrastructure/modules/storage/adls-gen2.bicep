// ============================================================================
// SecureBank GRC Engineering - ADLS Gen2 (GRC Data Lake)
// ============================================================================
// The GRC Data Lake stores all compliance evidence and control data.
// Uses Azure Data Lake Storage Gen2 (ADLS) - hierarchical namespace enabled.
// Medallion architecture containers:
//   - bronze: raw compliance data (Azure Policy, Defender, Activity Logs)
//   - silver: cleansed, enriched with control mappings
//   - gold: aggregated metrics, control effectiveness scores
//   - evidence: audit-ready artifacts with timestamps
// NIST CSF mapping: ID.AM-1, PR.DS-1, PR.DS-3, DE.CM-1
// ============================================================================

param location string
param projectName string
param tags object
param logAnalyticsWorkspaceId string

// --- Variables ---
// Storage account names must be 3-24 chars, lowercase alphanumeric only
var storageAccountName = 'stsbgrc${substring(uniqueString(resourceGroup().id), 0, 8)}'

// --- ADLS Gen2 Storage Account ---
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    // LRS = Locally Redundant Storage - cheapest, fine for dev
    // Use ZRS or GRS in production for compliance requirements
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // Enable hierarchical namespace = ADLS Gen2
    isHnsEnabled: true
    // Enforce HTTPS only - GRC Control: PR.DS-2
    supportsHttpsTrafficOnly: true
    // Minimum TLS version - GRC Control: PR.DS-2
    minimumTlsVersion: 'TLS1_2'
    // Disable public blob access - GRC Control: PR.AC-3
    allowBlobPublicAccess: false
    // Disable shared key access - use Entra ID instead
    allowSharedKeyAccess: true // keeping true for dev simplicity
    accessTier: 'Hot'
    encryption: {
      // Microsoft-managed keys for dev, customer-managed for prod
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      // Default deny - only allow specific networks
      defaultAction: 'Allow' // Allow for dev, change to Deny for prod
      bypass: 'AzureServices'
    }
  }
}

// --- Blob Service ---
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    // Soft delete for blobs - 7 days recovery window
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    // Versioning for audit trail
    //isVersioningEnabled: true
  }
}

// --- Medallion Architecture Containers ---
resource bronzeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'bronze'
  properties: {
    publicAccess: 'None'
    metadata: {
      layer: 'bronze'
      description: 'Raw compliance data from Azure Policy, Defender, Activity Logs'
    }
  }
}

resource silverContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'silver'
  properties: {
    publicAccess: 'None'
    metadata: {
      layer: 'silver'
      description: 'Cleansed data enriched with NIST CSF control mappings'
    }
  }
}

resource goldContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'gold'
  properties: {
    publicAccess: 'None'
    metadata: {
      layer: 'gold'
      description: 'Aggregated metrics and control effectiveness scores'
    }
  }
}

resource evidenceContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'evidence'
  properties: {
    publicAccess: 'None'
    metadata: {
      layer: 'evidence'
      description: 'Audit-ready artifacts with timestamps for compliance evidence'
    }
  }
}

// --- Diagnostic Settings -> Log Analytics ---
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-storage-to-law'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// --- Outputs ---
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output bronzeContainerId string = bronzeContainer.id
output silverContainerId string = silverContainer.id
output goldContainerId string = goldContainer.id
output evidenceContainerId string = evidenceContainer.id
