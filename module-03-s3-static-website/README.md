# Module 03 — Amazon S3 & Cloud Storage

My portfolio website, hosted as an **Amazon S3 static website** in `ap-southeast-2` (Sydney).

| Setting | Value |
|---|---|
| Bucket | `risnysuha-portfolio-<account-id>` (tag `Project=Codomax`) |
| Website hosting | `index.html` + custom `error.html` (404) |
| Access control | Account-level Block Public Access kept for ACLs; bucket policy allows **only** `s3:GetObject` ([policy](bucket-policy.tpl.json)) |
| Data protection | Versioning **enabled** — every upload keeps previous versions |
| Storage class | S3 Standard; `Cache-Control: max-age=300` on objects |
| Deploys | `deploy.sh` (CLI) and automatically by the Module 06 GitHub Actions pipeline |

S3 concepts covered: buckets vs objects, keys/prefixes, storage classes (Standard, Standard-IA, One Zone-IA, Glacier tiers, Intelligent-Tiering), bucket policies vs ACLs, Block Public Access, versioning, static website endpoints.
