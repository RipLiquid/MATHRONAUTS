"""Manually deployed Lambda handler for the optional desktop leaderboard."""
import base64
import json
import logging
import re
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import BotoCoreError, ClientError

table = boto3.resource(
    "dynamodb", region_name="ca-central-1"
).Table("MathronautsLeaderboard")

logger = logging.getLogger(__name__)
DIFFICULTIES = {"easy", "normal", "hard"}


def response(status, data):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store"
        },
        "body": json.dumps(data)
    }


def lambda_handler(event, context):
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", "GET")
    )

    try:
        if method == "GET":
            params = event.get("queryStringParameters") or {}
            difficulty = params.get("difficulty", "normal")

            if difficulty not in DIFFICULTIES:
                return response(400, {"error": "Invalid difficulty."})

            result = table.query(
                KeyConditionExpression=Key("difficulty").eq(difficulty),
                ScanIndexForward=False,
                ConsistentRead=True,
                Limit=10
            )

            entries = [
                {
                    "nickname": item["nickname"],
                    "score": int(item["score"]),
                    "createdAt": item["createdAt"]
                }
                for item in result.get("Items", [])
            ]

            return response(200, {
                "difficulty": difficulty,
                "entries": entries
            })

        if method == "POST":
            raw = event.get("body") or ""

            if not isinstance(raw, str) or len(raw) > 2048:
                return response(400, {"error": "Invalid request size."})

            try:
                if event.get("isBase64Encoded"):
                    raw = base64.b64decode(raw, validate=True).decode("utf-8")
                data = json.loads(raw)
            except (ValueError, UnicodeError):
                return response(400, {"error": "Invalid JSON body."})

            if not isinstance(data, dict):
                return response(400, {"error": "Expected a JSON object."})

            nickname = data.get("nickname")
            difficulty = data.get("difficulty")
            score = data.get("score")

            if (
                not isinstance(nickname, str)
                or not re.fullmatch(r"[A-Za-z0-9_]{3,16}", nickname)
            ):
                return response(400, {
                    "error": "Nickname must be 3–16 letters, numbers or underscores."
                })

            if (
                not isinstance(difficulty, str)
                or difficulty not in DIFFICULTIES
            ):
                return response(400, {"error": "Invalid difficulty."})

            if (
                type(score) is not int
                or not 0 <= score <= 999999990
                or score % 10 != 0
            ):
                return response(400, {
                    "error": "Score must be a whole multiple of 10, from 0 to 999999990."
                })

            submission_id = str(uuid.uuid4())
            created_at = datetime.now(timezone.utc).isoformat()

            table.put_item(Item={
                "difficulty": difficulty,
                "scoreKey": f"{score:010d}#{submission_id}",
                "nickname": nickname,
                "score": score,
                "createdAt": created_at
            })

            return response(201, {
                "message": "Score submitted.",
                "submissionId": submission_id
            })

        return response(405, {"error": "Use GET or POST."})

    except (ClientError, BotoCoreError):
        logger.exception("Leaderboard database request failed")
        return response(503, {
            "error": "Leaderboard temporarily unavailable."
        })
