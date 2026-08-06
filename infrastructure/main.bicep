// ==========================================================
// PARAMETERS
// Values provided from outside the template.
// ==========================================================

@description('Azure region used for all resources.')
param location string = resourceGroup().location

@minLength(3)
@maxLength(30)
@description('Globally unique lowercase prefix used to generate resource names.')
param namePrefix string

@allowed([
  'B1'
  'S1'
  'P1v3'
])
@description('App Service Plan SKU. Use B1 for the first lab and S1 later for deployment slots.')
param skuName string = 'B1'

@allowed([
  'development'
  'test'
  'production'
])
@description('Environment represented by this deployment.')
param environmentName string = 'development'


// ==========================================================
// VARIABLES
// Values calculated inside the template.
// ==========================================================

// Convert the prefix to lowercase to avoid invalid resource names.
var normalizedPrefix = toLower(namePrefix)

// Automatically derive the correct pricing tier from the SKU.
// This prevents invalid combinations such as B1 + Standard.
var skuTier = skuName == 'B1'
  ? 'Basic'
  : skuName == 'S1'
    ? 'Standard'
    : 'PremiumV3'

// Resource naming convention.
var planName = '${normalizedPrefix}-asp'
var webAppName = '${normalizedPrefix}-web'
var logAnalyticsName = '${normalizedPrefix}-law'
var applicationInsightsName = '${normalizedPrefix}-appi'

// Tags applied consistently to all supported resources.
var commonTags = {
  project: 'azure-app-service-blue-green-platform'
  environment: environmentName
  managedBy: 'bicep'
  purpose: 'az204-devops-lab'
}


// ==========================================================
// LOG ANALYTICS WORKSPACE
// Central storage and query platform for monitoring data.
// ==========================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags

  properties: {
    // Logs are retained for 30 days while the workspace exists.
    retentionInDays: 30

    features: {
      // Allows access to logs based on permissions to their
      // related Azure resources.
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}


// ==========================================================
// APPLICATION INSIGHTS
// Collects application telemetry such as requests,
// response times, failures, exceptions, and dependencies.
// ==========================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: commonTags

  properties: {
    Application_Type: 'web'

    // Connect Application Insights to Log Analytics.
    // Because this references logAnalytics.id, Bicep creates
    // the workspace before Application Insights.
    WorkspaceResourceId: logAnalytics.id
  }
}


// ==========================================================
// APP SERVICE PLAN
// Provides CPU, memory, Linux workers, and scaling capacity.
// This is the main continuously billed resource.
// ==========================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  tags: commonTags

  sku: {
    name: skuName
    tier: skuTier

    // Start with one App Service worker instance.
    capacity: 1
  }

  properties: {
    // For this resource type, reserved=true identifies
    // the App Service Plan as a Linux plan.
    reserved: true
  }
}


// ==========================================================
// AZURE WEB APP
// Hosts the Python Flask application.
// ==========================================================

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  tags: commonTags

  properties: {
    // Attach the Web App to the App Service Plan.
    // This also creates an implicit dependency on the plan.
    serverFarmId: appServicePlan.id

    // Force clients to use HTTPS.
    httpsOnly: true

    siteConfig: {
      // Use the built-in Python 3.12 Linux runtime.
      linuxFxVersion: 'PYTHON|3.12'

      // Keep the application loaded instead of unloading it
      // after a period of inactivity.
      alwaysOn: true

      // FTP/FTPS deployment is unnecessary because deployment
      // will be performed through GitHub Actions.
      ftpsState: 'Disabled'

      // Reject old TLS versions.
      minTlsVersion: '1.2'

      // Enable HTTP/2 for supported HTTPS clients.
      http20Enabled: true

      // Command Azure App Service runs to start Flask.
      //
      // app.app:app means:
      // app directory -> app.py file -> Flask object named app
      appCommandLine: 'gunicorn --bind=0.0.0.0:8000 --timeout 120 app.app:app'

      // These settings become environment variables inside
      // the Flask application.
      appSettings: [
        {
          name: 'APP_NAME'
          value: 'Azure Service Status Dashboard'
        }
        {
          name: 'APP_VERSION'
          value: '1.0.0'
        }
        {
          name: 'APP_ENVIRONMENT'
          value: environmentName
        }
        {
          // Provides the Application Insights connection
          // information to the Web App.
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          // Instruct App Service to install dependencies from
          // requirements.txt during ZIP deployment.
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}


// ==========================================================
// OUTPUTS
// Values returned after deployment and usable by workflows.
// ==========================================================

output webAppName string = webApp.name

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'

output appServicePlanName string = appServicePlan.name

output applicationInsightsName string = applicationInsights.name

output logAnalyticsWorkspaceName string = logAnalytics.name

output deployedSku string = '${skuName} / ${skuTier}'

output deployedEnvironment string = environmentName
