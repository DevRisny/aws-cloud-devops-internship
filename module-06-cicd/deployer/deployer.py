"""
Keyless deploy hook — the CD half of the Module 06 pipeline.

GitHub Actions (CI) runs the tests, then POSTs {"sha": "<commit>"} to this Lambda Function URL.
No AWS credentials are stored in GitHub. The function trusts nothing it is sent:
  1. it asks the GitHub API for the current head of `main` and refuses any other commit,
  2. downloads exactly that commit from GitHub,
  3. deploys the Module 03 portfolio to S3 and the Module 05 Lambda code,
  4. returns a JSON deployment report (also written to CloudWatch Logs).
"""
import io
import json
import mimetypes
import os
import tarfile
import time
import urllib.request
import zipfile
from datetime import datetime, timezone

import boto3

REPO = os.environ["REPO"]                      # DevRisny/aws-cloud-devops-internship
BUCKET = os.environ["PORTFOLIO_BUCKET"]
FUNCTION = os.environ["APP_FUNCTION"]          # skillmatch-api
REGION = os.environ["AWS_REGION"]
s3 = boto3.client("s3")
lam = boto3.client("lambda")


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "codomax-deploy-hook", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def _reply(code, body):
    print(json.dumps({"status": code, **body}))
    return {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body, indent=2)}


def handler(event, context):
    t0 = time.time()
    try:
        sha = json.loads(event.get("body") or "{}").get("sha", "")
    except json.JSONDecodeError:
        return _reply(400, {"error": "body must be JSON {\"sha\": \"...\"}"})

    head = json.loads(_get(f"https://api.github.com/repos/{REPO}/commits/main"))["sha"]
    if not sha or sha != head:
        return _reply(409, {"error": "only the current head of main can be deployed", "requested": sha, "head": head})

    tar = tarfile.open(fileobj=io.BytesIO(_get(f"https://codeload.github.com/{REPO}/tar.gz/{sha}")), mode="r:gz")
    files = {m.name.split("/", 1)[1]: tar.extractfile(m).read() for m in tar.getmembers() if m.isfile() and "/" in m.name}

    # --- Module 03 portfolio -> S3
    stamp = datetime.now(timezone.utc).strftime("%d %b %Y, %H:%M UTC")
    prefix = "module-03-s3-static-website/site/"
    site = {k[len(prefix):]: v for k, v in files.items() if k.startswith(prefix)}
    site["theme.css"] = files["assets/theme.css"]
    site["index.html"] = (site["index.html"].decode()
                          .replace("{{BUCKET}}", BUCKET)
                          .replace("{{REGION}}", f"{REGION} (Sydney)")
                          .replace("{{DEPLOYED}}", f"{stamp} · CI/CD commit {sha[:7]}")).encode()
    for key, body in site.items():
        ctype = mimetypes.guess_type(key)[0] or "application/octet-stream"
        s3.put_object(Bucket=BUCKET, Key=key, Body=body, ContentType=ctype, CacheControl="max-age=300")

    # --- Module 05 SkillMatch Lambda code
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("handler.py", files["module-05-lambda-serverless/lambda/handler.py"])
    ver = lam.update_function_code(FunctionName=FUNCTION, ZipFile=buf.getvalue(), Publish=True)["Version"]

    return _reply(200, {
        "deployed": sha, "short": sha[:7],
        "portfolio": {"bucket": BUCKET, "files": sorted(site)},
        "lambda": {"function": FUNCTION, "publishedVersion": ver},
        "seconds": round(time.time() - t0, 2),
        "requestId": context.aws_request_id,
    })
