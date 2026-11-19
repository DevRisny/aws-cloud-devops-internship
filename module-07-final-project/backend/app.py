"""
InternTrack API — serverless internship application tracker.
AWS Lambda (Python) + Amazon API Gateway (HTTP API) + Amazon DynamoDB.

Routes
  GET    /applications           list all applications (newest first)
  POST   /applications           create   {company, role, status?, location?, link?, notes?, appliedOn?}
  PATCH  /applications/{id}      update any of the fields above
  DELETE /applications/{id}      delete
  GET    /stats                  counts per status + interview / offer rates
  GET    /health                 service status
"""
import json
import os
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3

TABLE = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
STATUSES = ["Wishlist", "Applied", "Assessment", "Interview", "Offer", "Rejected"]
FIELDS = {"company": 80, "role": 100, "status": 20, "location": 60, "link": 300, "notes": 600, "appliedOn": 10}
MAX_ITEMS = 300


def _json(o):
    if isinstance(o, Decimal):
        return int(o) if o % 1 == 0 else float(o)
    raise TypeError


def resp(code, body):
    return {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body, default=_json)}


def clean(data, partial=False):
    out = {}
    for k, limit in FIELDS.items():
        if k in data and data[k] is not None:
            v = str(data[k]).strip()
            if len(v) > limit:
                raise ValueError(f"'{k}' is longer than {limit} characters")
            out[k] = v
    if not partial:
        for req in ("company", "role"):
            if not out.get(req):
                raise ValueError(f"'{req}' is required")
        out.setdefault("status", "Applied")
        out.setdefault("appliedOn", datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    if "status" in out and out["status"] not in STATUSES:
        raise ValueError(f"status must be one of {STATUSES}")
    if out.get("appliedOn") and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", out["appliedOn"]):
        raise ValueError("appliedOn must be YYYY-MM-DD")
    if out.get("link") and not out["link"].startswith(("http://", "https://")):
        raise ValueError("link must start with http:// or https://")
    return out


def all_items():
    items, kw = [], {}
    while True:
        page = TABLE.scan(**kw)
        items += page.get("Items", [])
        if "LastEvaluatedKey" not in page:
            return items
        kw["ExclusiveStartKey"] = page["LastEvaluatedKey"]


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("rawPath", "/")
    params = event.get("pathParameters") or {}
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return resp(400, {"error": "Body must be valid JSON"})

    try:
        if path.endswith("/health"):
            return resp(200, {"status": "ok", "service": "InternTrack API", "table": TABLE.name,
                              "region": os.environ.get("AWS_REGION")})

        if path.endswith("/stats") and method == "GET":
            items = all_items()
            counts = {s: 0 for s in STATUSES}
            for it in items:
                counts[it.get("status", "Applied")] = counts.get(it.get("status", "Applied"), 0) + 1
            sent = sum(counts[s] for s in STATUSES if s != "Wishlist")
            reached_interview = counts["Interview"] + counts["Offer"]
            return resp(200, {"total": len(items), "byStatus": counts,
                              "interviewRate": round(100 * reached_interview / sent) if sent else 0,
                              "offerRate": round(100 * counts["Offer"] / sent) if sent else 0})

        if path.rstrip("/").endswith("/applications"):
            if method == "GET":
                items = sorted(all_items(), key=lambda i: (i.get("appliedOn", ""), i.get("createdAt", "")), reverse=True)
                return resp(200, {"items": items, "count": len(items)})
            if method == "POST":
                if TABLE.scan(Select="COUNT").get("Count", 0) >= MAX_ITEMS:
                    return resp(429, {"error": "Demo limit reached"})
                item = clean(body)
                now = datetime.now(timezone.utc).isoformat(timespec="seconds")
                item.update({"id": uuid.uuid4().hex[:12], "createdAt": now, "updatedAt": now})
                TABLE.put_item(Item=item)
                print(json.dumps({"event": "created", "id": item["id"], "status": item["status"]}))
                return resp(201, item)

        if "id" in params:
            key = {"id": params["id"]}
            if method == "PATCH":
                upd = clean(body, partial=True)
                if not upd:
                    return resp(400, {"error": "Nothing to update"})
                upd["updatedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
                names = {f"#{k}": k for k in upd}
                values = {f":{k}": v for k, v in upd.items()}
                r = TABLE.update_item(Key=key, UpdateExpression="SET " + ", ".join(f"#{k} = :{k}" for k in upd),
                                      ExpressionAttributeNames=names, ExpressionAttributeValues=values,
                                      ConditionExpression="attribute_exists(id)", ReturnValues="ALL_NEW")
                return resp(200, r["Attributes"])
            if method == "DELETE":
                TABLE.delete_item(Key=key, ConditionExpression="attribute_exists(id)")
                return resp(204, {})

        return resp(404, {"error": f"No route for {method} {path}"})

    except ValueError as e:
        return resp(400, {"error": str(e)})
    except TABLE.meta.client.exceptions.ConditionalCheckFailedException:
        return resp(404, {"error": "Application not found"})
