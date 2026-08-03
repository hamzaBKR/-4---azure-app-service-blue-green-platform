@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Globally unique lowercase prefix, for example hamza204.')
param namePrefix string

@description('App Service Plan SKU.')
param skuName string = 'B1'

@allowed([
  'Basic'
  'Standard'
  'PremiumV3'
])
param skuTier string = 'Basic'

var planName = '${namePrefix}-asp'
var webAppName = '${namePrefix}-web'
var lawName = '${namePrefix}-law'
var appiName = '${namePrefix}-appi'

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: appiName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: skuName
    tier: skuTier
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource web 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      alwaysOn: skuName != 'B1'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appCommandLine: 'gunicorn --bind=0.0.0.0:8000 --timeout 600 app.app:app'
      appSettings: [
        { name: 'APP_NAME'; value: 'Azure Service Status Dashboard' }
        { name: 'APP_VERSION'; value: '1.0.0' }
        { name: 'APP_ENVIRONMENT'; value: 'Production' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'; value: appi.properties.ConnectionString }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'; value: 'true' }
      ]
    }
  }
}

output webAppName string = web.name
output webAppUrl string = 'https://${web.properties.defaultHostName}'
output appServicePlanName string = plan.name
output applicationInsightsName string = appi.name
