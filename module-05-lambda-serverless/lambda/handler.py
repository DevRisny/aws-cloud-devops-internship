"""
SkillMatch API — AWS Lambda (Python) behind Amazon API Gateway (HTTP API).

POST /match   {"resume": "...", "job": "..."}  -> match score, matched / missing skills, tips
GET  /health                                    -> service status

No external libraries: tokenises both texts, finds known tech skills and
weighted keywords, and explains the score so the result is transparent.
"""
import json
import os
import re
import time
from collections import Counter

VERSION = "1.0.0"

SKILLS = {
    # cloud & devops
    "aws", "amazon web services", "ec2", "s3", "lambda", "iam", "vpc", "rds", "dynamodb", "cloudwatch",
    "api gateway", "cloudformation", "terraform", "docker", "kubernetes", "ci/cd", "github actions",
    "jenkins", "linux", "bash", "azure", "gcp", "google cloud", "serverless", "devops", "git", "github",
    # programming & web
    "python", "java", "javascript", "typescript", "php", "laravel", "c#", "c++", "dart", "flutter",
    "react", "react.js", "node.js", "html", "css", "tailwind", "bootstrap", "rest api", "rest apis",
    "sql", "mysql", "postgresql", "mongodb", "firebase", "django", "flask", "fastapi", "spring boot",
    # data & ai
    "machine learning", "deep learning", "nlp", "natural language processing", "tensorflow", "pytorch",
    "scikit-learn", "pandas", "numpy", "power bi", "tableau", "excel", "data analysis", "computer vision",
    "generative ai", "llm",
    # networks, security, qa, pm
    "networking", "tcp/ip", "dns", "cisco", "firewall", "cybersecurity", "penetration testing",
    "wireshark", "nmap", "selenium", "testing", "qa", "jira", "agile", "scrum", "figma", "ui/ux",
    "communication", "teamwork", "leadership", "problem solving",
}

STOP = set("""a an the and or of to in on for with by from at as is are was were be been being this that these those
it its we you they he she our your their i me my will would can could should may might must have has had do does did
not no yes but if then than so such into over under about across per via etc using use used work working experience
years year strong good ability knowledge skills skill requirements required preferred plus role job candidate team""".split())


def _tokens(text):
    return [t for t in re.findall(r"[a-z][a-z0-9+#./-]*", text.lower()) if t not in STOP and len(t) > 1]


def _skills_in(text):
    low = " " + re.sub(r"\s+", " ", text.lower()) + " "
    found = set()
    for s in SKILLS:
        if re.search(r"(?<![a-z0-9])" + re.escape(s) + r"(?![a-z0-9])", low):
            found.add(s)
    # treat aliases as one skill
    alias = {"react.js": "react", "rest apis": "rest api", "amazon web services": "aws",
             "natural language processing": "nlp", "google cloud": "gcp"}
    return {alias.get(s, s) for s in found}


def match(resume, job):
    job_skills, cv_skills = _skills_in(job), _skills_in(resume)
    matched = sorted(job_skills & cv_skills)
    missing = sorted(job_skills - cv_skills)

    job_kw = Counter(_tokens(job))
    cv_kw = set(_tokens(resume))
    top_job = [w for w, _ in job_kw.most_common(25)]
    kw_hit = [w for w in top_job if w in cv_kw]

    skill_score = len(matched) / len(job_skills) if job_skills else 0.0
    kw_score = len(kw_hit) / len(top_job) if top_job else 0.0
    score = round(100 * (0.7 * skill_score + 0.3 * kw_score))

    if score >= 75:
        verdict = "Strong match"
    elif score >= 50:
        verdict = "Good match — a few gaps"
    elif score >= 30:
        verdict = "Partial match"
    else:
        verdict = "Low match"

    tips = [f"Add evidence of '{s}' (project, course or certificate) if you have it." for s in missing[:5]]
    if not tips:
        tips = ["All required skills found — quantify your impact (numbers, results) to stand out."]

    return {
        "score": score,
        "verdict": verdict,
        "matchedSkills": matched,
        "missingSkills": missing,
        "keywordCoverage": {"matched": kw_hit, "checked": len(top_job)},
        "explanation": {
            "skillWeight": 0.7, "keywordWeight": 0.3,
            "skillScore": round(skill_score, 3), "keywordScore": round(kw_score, 3),
        },
        "tips": tips,
    }


def _resp(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    started = time.time()
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("rawPath", "/")

    if method == "GET" and path.endswith("/health"):
        return _resp(200, {
            "status": "ok", "service": "SkillMatch API", "version": VERSION,
            "region": os.environ.get("AWS_REGION"), "function": os.environ.get("AWS_LAMBDA_FUNCTION_NAME"),
        })

    if method == "POST" and path.endswith("/match"):
        try:
            data = json.loads(event.get("body") or "{}")
        except json.JSONDecodeError:
            return _resp(400, {"error": "Body must be JSON: {\"resume\": \"...\", \"job\": \"...\"}"})
        resume, job = str(data.get("resume", "")).strip(), str(data.get("job", "")).strip()
        if len(resume) < 20 or len(job) < 20:
            return _resp(400, {"error": "Please send both 'resume' and 'job' text (at least 20 characters each)."})
        if len(resume) > 20000 or len(job) > 20000:
            return _resp(413, {"error": "Text too long (max 20,000 characters each)."})
        result = match(resume, job)
        result["meta"] = {"latencyMs": round((time.time() - started) * 1000, 2),
                          "requestId": getattr(context, "aws_request_id", None)}
        print(json.dumps({"event": "match", "score": result["score"], "jobSkills": len(result["matchedSkills"]) + len(result["missingSkills"])}))
        return _resp(200, result)

    return _resp(404, {"error": f"No route for {method} {path}", "routes": ["GET /health", "POST /match"]})
