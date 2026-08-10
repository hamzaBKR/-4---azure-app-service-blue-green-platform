# Azure App Service Blue/Green Platform

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/f8d2d822-4807-4e1e-9967-ad08120451d0" />


A hands-on Azure DevOps project demonstrating Infrastructure as Code with **Bicep**, passwordless **GitHub Actions OIDC** authentication to Azure, least-privilege **Azure RBAC**, automated application deployment, monitoring foundations, and health validation.

> **Cost note:** this lab creates billable Azure resources. Delete the Resource Group after testing. See [Cleanup and Cost Control](#cleanup-and-cost-control).

## Project Goals

- Build and test a Python/Flask application locally
- Store source code and automation in GitHub
- Use GitHub Actions for CI/CD
- Use OIDC instead of a long-lived Azure client secret
- Apply Azure RBAC at Resource Group scope
- Provision infrastructure with Bicep
- Validate and preview infrastructure before deployment
- Deploy the Flask application automatically
- Verify deployment using `/health`
- Integrate Application Insights and Log Analytics
- Keep the environment disposable

## Architecture

```text
Developer / VS Code
        |
        v
GitHub Repository
        |
        +-------------------------+
        |                         |
        v                         v
       CI                  Infrastructure / App Workflows
                                  |
                                  v
                         GitHub Actions OIDC
                                  |
                                  v
                   Microsoft Entra workload identity
                                  |
                                  v
                             Azure RBAC
                  Contributor on one Resource Group
                                  |
                                  v
                      rg-az204-appservice-dev
                           /      |       \
                          /       |        \
                         v        v         v
                  App Service  App Insights  Log Analytics
                      Plan          |
                        \           /
                         \         /
                           Web App
                             |
                             v
                       Python / Flask
                             |
                             v
                          /health
```

## Technology Stack

- Azure App Service
- Azure App Service Plan
- Application Insights
- Log Analytics Workspace
- Microsoft Entra ID
- Azure RBAC
- Bicep
- GitHub Actions
- OpenID Connect (OIDC)
- Python / Flask
- Gunicorn
- pytest

## Repository Structure

```text
.
├── app/
│   ├── app.py
│   └── templates/
│       └── index.html
├── tests/
│   └── test_app.py
├── infrastructure/
│   └── main.bicep
├── scripts/
│   └── bootstrap-oidc.sh
├── screenshots/
│  
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── test-azure-login.yml
│       ├── deploy-infrastructure.yml
│       └── deploy-app.yml
├── docs/
│   └── screenshots/
├── requirements.txt
├── .gitignore
└── README.md
```

# Secure Azure Authentication

## GitHub Actions OIDC → Microsoft Entra workload identity federation → Azure RBAC

This project does **not** store a reusable Azure password or client secret in GitHub.

```text
GitHub Actions
    |
    | requests a short-lived OIDC token
    v
GitHub OIDC provider
    |
    | token contains repository + environment identity
    v
Microsoft Entra ID
    |
    | federated credential validates issuer, audience and subject
    v
Service Principal
    |
    | Azure checks RBAC
    v
Contributor on rg-az204-appservice-dev only
```

| Component | Purpose |
|---|---|
| Entra application | Defines the application identity |
| Service principal | Represents that application inside the Azure tenant |
| Federated credential | Defines which GitHub repository/environment can use the identity |
| Azure RBAC role assignment | Defines what the identity can do and where |
| GitHub OIDC token | Short-lived token issued for a workflow run |

### Why OIDC

Traditional approach:

```text
GitHub Secret -> long-lived Azure client secret
```

This project:

```text
GitHub workflow -> short-lived OIDC token -> Entra federation -> Azure access token
```

The service principal is granted:

```text
Role:  Contributor
Scope: rg-az204-appservice-dev only
```

This follows a least-privilege approach and avoids subscription-wide Contributor access.

# GitHub Actions Configuration

## Repository Secrets

The repository uses:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Only the secret names are visible below; the values are not exposed.



## Repository Variable

The Resource Group name is normal configuration data, so it is stored as a GitHub Actions variable:

```text
AZURE_RESOURCE_GROUP=rg-az204-appservice-dev
```



> Important lesson: `${{ secrets.NAME }}` and `${{ vars.NAME }}` are different contexts.

# Infrastructure Workflow

The infrastructure workflow is manually triggered and supports two operations:

- `preview`
- `deploy`

# Infrastructure as Code

The Bicep deployment creates:

1. Azure App Service Plan
2. Azure Web App
3. Application Insights
4. Log Analytics Workspace

Resource naming:

```text
hamza204demo-asp
hamza204demo-web
hamza204demo-appi
hamza204demo-law
```

## Deployed Azure Resources

![Azure Resource Group and deployed resources](docs/screenshots/06-azure-resource-group.png)

# Application Deployment

Application deployment is separated from infrastructure deployment.

Typical flow:

```text
Checkout
  -> Python setup
  -> Install dependencies
  -> pytest
  -> Azure OIDC login
  -> Package application
  -> Deploy to existing Web App
  -> Health validation
```

## Successful Application Deployment

![Successful application deployment workflow](docs/screenshots/07-app-deployment-success.png)

# Application Validation

The deployed Flask application shows health, version, environment, deployment timestamp, and the health endpoint.

![Azure Service Status Dashboard](docs/screenshots/08-app-dashboard.png)

## Health Endpoint

The application exposes:

```text
/health
```

Example:

```json
{
  "deployment_time": "2026-08-09T11:04:01Z",
  "environment": "development",
  "name": "Azure Service Status Dashboard",
  "status": "healthy",
  "version": "1.0.0"
}
```

![Health endpoint response](docs/screenshots/09-health-endpoint.png)

# Troubleshooting and Lessons Learned


## 1. Client ID vs Service Principal Object ID

The Entra application has a client/application ID, while the service principal has its own object ID.

For RBAC:

```bash
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "$RESOURCE_GROUP_SCOPE"
```



## 2. OIDC Subject Mismatch

Azure initially returned:

```text
AADSTS700213: No matching federated identity record found
```

The fix was to compare the actual OIDC token values from the GitHub Actions log:

- issuer
- audience
- subject

The federated credential in Microsoft Entra ID must match the actual GitHub token values exactly.

```text
GitHub token subject == Entra federated credential subject
GitHub issuer        == Entra federated credential issuer
GitHub audience      == Entra federated credential audience
```

This repository used GitHub's immutable OIDC subject format, so the Entra federated credential had to use that exact subject.



## 3. Azure Resource Provider Registration

The first deployment failed with:

```text
MissingSubscriptionRegistration
```

Required providers:

```bash
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
```

Verify:

```bash
az provider show --namespace Microsoft.Web --query registrationState -o tsv
az provider show --namespace Microsoft.OperationalInsights --query registrationState -o tsv
az provider show --namespace Microsoft.Insights --query registrationState -o tsv
```

Expected:

```text
Registered
Registered
Registered
```

## 4. Validate Before Deploying

The infrastructure workflow follows:

```text
Bicep build
   ->
Azure validation
   ->
Azure what-if
   ->
Deployment
```

This makes failures easier to isolate.


# Cleanup and Cost Control

The lab infrastructure should **not** be left running after testing because the App Service Plan and monitoring resources can generate Azure charges.

Delete the full Resource Group:

```bash
az group delete \
  --name rg-az204-appservice-dev \
  --yes \
  --no-wait
```

This removes the lab resources inside the Resource Group, including:

```text
App Service Plan
Web App
Application Insights
Log Analytics Workspace
```

Verify that the Resource Group is gone:

```bash
az group exists \
  --name rg-az204-appservice-dev
```

Expected:

```text
false
```

You can also check that the project resources no longer exist:

```bash
az resource list \
  --query "[?contains(name, 'hamza204demo')].{Name:name,Type:type,ResourceGroup:resourceGroup}" \
  --output table
```

Historical usage can still appear in Azure Cost Management after deletion, but the deleted resources are no longer running.

> Deleting the Resource Group also removes the RBAC assignment scoped to that Resource Group. The Entra application, service principal, and federated credential remain in Microsoft Entra ID. If the Resource Group is recreated later, its RBAC assignment must be created again.

# Future Improvements

- Deployment Slots
- Staging-to-Production swap
- Swap with Preview
- Slot-specific App Settings
- Canary traffic routing
- Autoscaling
- Azure Monitor alerts
- OpenTelemetry instrumentation
- Automated destroy workflow
- Terraform version of the architecture
