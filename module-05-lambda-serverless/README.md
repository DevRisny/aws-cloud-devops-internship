# Module 05 — AWS Lambda & Serverless · **SkillMatch API**

Paste a résumé and a job description → a Python **AWS Lambda** function behind **Amazon API Gateway (HTTP API)** finds the required tech skills, scores the match and lists what is missing. Frontend hosted on **Amazon S3**.

| Route | Description |
|---|---|
| `GET /health` | Service status, region and function name |
| `POST /match` | Body `{"resume": "...", "job": "..."}` → `score`, `verdict`, `matchedSkills`, `missingSkills`, `tips`, latency |

```bash
curl -s -X POST "$API/match" -H 'content-type: application/json' \
  -d '{"resume":"Python, AWS EC2, Docker","job":"Need AWS Lambda, EC2, Docker and Kubernetes"}'
```

- Runtime Python 3.13, 128 MB, 5 s timeout, execution role with **CloudWatch Logs only**
- CORS configured on the HTTP API; structured JSON logs per request
- Unit tests: `pytest module-05-lambda-serverless/tests` (run on every push by Module 06)
