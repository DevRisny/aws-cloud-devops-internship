import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda"))
import handler  # noqa: E402


class Ctx:
    aws_request_id = "test-request"


def call(method, path, body=None):
    ev = {"requestContext": {"http": {"method": method}}, "rawPath": path}
    if body is not None:
        ev["body"] = json.dumps(body)
    r = handler.lambda_handler(ev, Ctx())
    return r["statusCode"], json.loads(r["body"])


def test_health():
    code, body = call("GET", "/health")
    assert code == 200 and body["status"] == "ok"


def test_match_finds_skills_and_gaps():
    code, body = call("POST", "/match", {
        "resume": "Python developer with AWS EC2 and Docker experience, good communication.",
        "job": "Need AWS, EC2, Lambda, Docker and Kubernetes skills plus communication.",
    })
    assert code == 200
    assert {"aws", "ec2", "docker"} <= set(body["matchedSkills"])
    assert {"lambda", "kubernetes"} <= set(body["missingSkills"])
    assert 0 <= body["score"] <= 100


def test_validation_errors():
    assert call("POST", "/match", {"resume": "short", "job": "short"})[0] == 400
    assert call("DELETE", "/match")[0] == 404


def test_preflight():
    ev = {"requestContext": {"http": {"method": "OPTIONS"}}, "rawPath": "/match"}
    assert handler.lambda_handler(ev, Ctx())["statusCode"] == 204
