# Module 06 — AWS DevOps & CI/CD

Pipeline: [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) · Deploy hook: [`deployer/deployer.py`](deployer/deployer.py)

```
git push (main)
   │
   ▼  GitHub Actions — CI  ───────────────────────────────────────────────
   │   • pytest: SkillMatch Lambda unit tests
   │   • HTML parse check of every page · bash -n on every script
   ▼  GitHub Actions — CD (environment: production)
   │   • POST {"sha": "<commit>"}  ─────►  Lambda Function URL  "codomax-deploy-hook"
   │                                         1. asks GitHub API: is this the head of main?  (else 409)
   │                                         2. downloads exactly that commit
   │                                         3. S3 PutObject → portfolio bucket (Module 03)
   │                                         4. UpdateFunctionCode + publish → skillmatch-api (Module 05)
   │   • smoke tests: /health + portfolio URL
   ▼   • job summary with the JSON deployment report
 Live on AWS (ap-southeast-2) — footer of the portfolio shows the deployed commit
```

## Why a deploy hook instead of access keys or OIDC?
The usual secure option is **GitHub OIDC → IAM role** ([`setup-oidc.sh`](setup-oidc.sh) is kept for standard accounts).
My Free-plan account's **service control policy denies `iam:CreateOpenIDConnectProvider`**, and storing long-lived access keys in GitHub is bad practice. So CD is **pull-based and keyless**:

- GitHub holds **no AWS credentials** — only the public hook URL (in the workflow `env`, not a secret).
- The hook can deploy **only the current head of `main`** from this public repo, so calling it with anything else does nothing.
- Its IAM role can do exactly two things: `s3:PutObject` on one bucket and `lambda:UpdateFunctionCode/PublishVersion` on one function.
- Every run is logged in CloudWatch Logs and reported back into the GitHub Actions summary.

## Git workflow
Feature branch → pull request (CI only) → merge to `main` (CI + CD). Every deployment is traceable to a commit SHA.

## AWS-native CI/CD (concepts)
| Stage | AWS service | In this project |
|---|---|---|
| Source | CodeCommit / GitHub via CodeConnections | GitHub |
| Build & test | AWS CodeBuild | GitHub Actions runners |
| Deploy | AWS CodeDeploy / CloudFormation / S3 / Lambda | Deploy-hook Lambda → S3 + Lambda |
| Orchestrate | AWS CodePipeline | GitHub Actions workflow |
