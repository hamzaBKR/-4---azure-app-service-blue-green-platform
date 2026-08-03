# Azure App Service Blue/Green Platform

Starter for Phases 1 and 2.

## Included

- Flask status dashboard
- `/health` and `/api/info`
- Unit tests
- Bicep infrastructure
- GitHub Actions CI
- OIDC authentication
- Automated App Service deployment
- Smoke test

## Local run

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest -q
gunicorn --bind=0.0.0.0:8000 app.app:app
```

## One-time OIDC bootstrap

```bash
az login
./scripts/bootstrap-oidc.sh   <subscription-id>   <github-owner>   <github-repository>   main
```

Create repository secrets from the printed values:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Deploy

1. Run `Deploy Azure Infrastructure`.
2. Copy the returned Web App name.
3. Run `Deploy Application`.
4. Open the returned URL and `/health`.

## Next phase

Add staging slot, sticky settings, swap, rollback, and canary routing.
