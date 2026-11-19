# Module 02 — AWS IAM & EC2

A web server on **Amazon EC2** (Amazon Linux 2023, Sydney `ap-southeast-2`) secured with IAM least privilege. The page shows live facts the instance reads about itself from IMDSv2 at boot.

🌐 **Live website:** _see the link in the module submission_ · 🧹 `cleanup.sh` removes everything

## What `deploy.sh` builds

| Step | Resource | Detail |
|---|---|---|
| IAM | Policy `EC2-Operate-Lab-Only` | `ec2:Describe*` + start/stop/reboot **only** on instances tagged `Project=Codomax` ([policy](iam/ec2-operator-policy.json)) |
| IAM | Group `EC2-Operators` + user `risny-ec2-operator` | Permissions attached to the group, never directly to the user |
| IAM | Role `EC2-WebServer-Role` + instance profile | `AmazonSSMManagedInstanceCore` → admin via Session Manager, no SSH keys |
| Network | Security Group `WebServer-SG` | Inbound **TCP 80 only**; port 22 closed |
| Compute | EC2 free-tier instance | IMDSv2 required, public IP, tags |
| Boot | [`user-data.tpl.sh`](user-data.tpl.sh) | Installs NGINX, unpacks the site, fills in instance ID / AZ / AMI / IP from IMDSv2 |

## Connect to the instance (no SSH)
EC2 console → instance → **Connect** → **Session Manager** → `sudo systemctl status nginx`.
