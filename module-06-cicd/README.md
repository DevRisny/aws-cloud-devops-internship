# Module 06 — AWS DevOps & CI/CD

Pipeline: [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)

```
push to main ─► Test & validate ─────────────► Deploy to AWS (environment: production)
                • pytest (SkillMatch Lambda)     • OIDC → assume GitHubActions-Deploy-Role (no stored keys)
                • HTML parse check                • build + aws s3 sync → portfolio bucket (Module 03)
                • bash -n on all scripts          • zip + lambda update-function-code --publish (Module 05)
                                                  • job summary with live links
```

## Security: OpenID Connect instead of access keys
[`setup-oidc.sh`](setup-oidc.sh) creates the GitHub OIDC identity provider and a role that **only this repository's `main` branch** can assume. Its inline policy allows writing to one bucket and updating one Lambda function — nothing else.

## Git workflow
Feature branch → pull request (runs tests only) → merge to `main` (tests + deploy). Every deployment is traceable to a commit SHA and run number, shown in the website footer.
