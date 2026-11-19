<div align="center">

# ☁️ AWS Cloud & DevOps Internship — Hands-on Labs

**Junaideen Risny Suha** · AWS Cloud & DevOps Intern at **Codomax Digital Solutions** · Intern ID `CDS/INT/202695753`

Real deployments on AWS (Sydney, `ap-southeast-2` — the Region enabled for my Free-plan account), built with the AWS CLI, CloudFormation and GitHub Actions.

![AWS](https://img.shields.io/badge/AWS-ap--southeast--2-FF9900?logo=amazonwebservices&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![CloudFormation](https://img.shields.io/badge/IaC-CloudFormation-E7157B)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)

</div>

## Modules

| # | Module | What I built | Folder |
|---|---|---|---|
| 01 | AWS & Cloud Fundamentals | Learning notes + highly-available reference architecture diagram | [`module-01-cloud-fundamentals`](module-01-cloud-fundamentals) |
| 02 | AWS IAM & EC2 | IAM user/group/custom policy/role, HTTP-only Security Group, NGINX on EC2 via user data + IMDSv2 | [`module-02-iam-ec2`](module-02-iam-ec2) |
| 03 | Amazon S3 & Cloud Storage | Portfolio website on S3 static hosting with versioning and a least-privilege bucket policy | [`module-03-s3-static-website`](module-03-s3-static-website) |
| 04 | AWS Networking & RDS | VPC / subnets / route tables / RDS notes + 3-tier EC2 + RDS architecture | [`module-04-networking-rds`](module-04-networking-rds) |
| 05 | AWS Lambda & Serverless | **SkillMatch** — résumé ↔ job matching API on Lambda + API Gateway, frontend on S3 | [`module-05-lambda-serverless`](module-05-lambda-serverless) |
| 06 | AWS DevOps & CI/CD | GitHub Actions pipeline: tests → OIDC (no keys) → deploy to S3 + Lambda | [`module-06-cicd`](module-06-cicd) |
| 07 | Final Cloud Project | **InternTrack** — serverless tracker: S3 + API Gateway + Lambda + DynamoDB + CloudWatch + IAM, all in CloudFormation | [`module-07-final-project`](module-07-final-project) |

## 🌐 Live on AWS

| Module | Live link (HTTPS via CloudFront) | Direct AWS endpoint |
|---|---|---|
| 02 · EC2 web server | https://d361b2wm8slqum.cloudfront.net | http://16.178.55.164 (EC2 public IP) |
| 03 · S3 portfolio | https://d7x1ojq6uq6wa.cloudfront.net | http://risnysuha-portfolio-133556562490.s3-website-ap-southeast-2.amazonaws.com |
| 05 · SkillMatch (Lambda) | https://d35w185x7f1hbe.cloudfront.net | API: https://b03b4vxstj.execute-api.ap-southeast-2.amazonaws.com/health |
| 07 · InternTrack | https://d82fcovh5qor2.cloudfront.net | http://interntrack-app-133556562490.s3-website-ap-southeast-2.amazonaws.com |

## Run any module

Every module deploys from **AWS CloudShell** with one command and can be removed with `cleanup.sh`:

```bash
git clone https://github.com/DevRisny/aws-cloud-devops-internship.git
cd aws-cloud-devops-internship
bash module-02-iam-ec2/deploy.sh      # or module-03…, module-05…, module-07…
```

## Principles I followed

- **Least privilege everywhere** — scoped IAM policies, no SSH open to the internet, no long-lived access keys (GitHub → AWS uses OIDC).
- **Infrastructure as code** — CLI scripts and a CloudFormation template, so everything is repeatable.
- **Cost-aware** — free-tier eligible resources, tags `Project=Codomax` on everything, and a cleanup script per module.

---
<sub>© 2026 Junaideen Risny Suha · [LinkedIn](https://www.linkedin.com/in/risny-suha-8a6b66423) · [GitHub](https://github.com/DevRisny)</sub>
