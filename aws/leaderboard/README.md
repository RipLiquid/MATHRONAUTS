# AWS leaderboard

The enhanced desktop game optionally uses a public Lambda Function URL backed
by DynamoDB. Ordinary gameplay, Practice and local statistics work offline.
Android and iOS do not yet use this API.

## Manual deployment

The checked-in `lambda_function.py` records the handler prepared for the AWS
console. Changes to this file are not deployed automatically by CI.

| Resource | Setting |
|---|---|
| Region | Canada (Central), `ca-central-1` |
| DynamoDB table | `MathronautsLeaderboard` |
| Partition key | `difficulty` (String) |
| Sort key | `scoreKey` (String) |
| Table capacity | Provisioned: 1 read, 1 write; auto scaling off |
| Encryption | AWS-owned key |
| Lambda | `MathronautsLeaderboardApi` |
| Runtime / handler | Python 3.14 / `lambda_function.lambda_handler` |
| Memory / timeout | 128 MB / 3 seconds |
| Function URL | Auth type `NONE`; CORS disabled for native clients |

The execution role has basic CloudWatch Logs permissions and `dynamodb:Query`
and `dynamodb:PutItem`, restricted to this table's ARN. The public invocation
policy belongs to the function, not to the table. No AWS keys are bundled in
the desktop game or required by CI. The endpoint is in `desktop/leaderboard.py`.

The account's current low concurrency quota prevented reserving concurrency
for this function. It uses the unreserved account pool. Free allowances and
credits depend on account eligibility and usage; this is not a guaranteed
zero-cost service. Existing CloudOps resources remain separate.

## API

`GET /?difficulty=normal` returns up to ten scores in descending order. Valid
difficulties are `easy`, `normal` and `hard`; the default is `normal`.

`POST /` accepts JSON:

```json
{"nickname": "Player1", "difficulty": "normal", "score": 120}
```

The handler checks nickname format (3–16 letters, digits or underscores),
difficulty and integer scores (0–999999990 in multiples of ten). Each accepted
submission gets a UUID and server UTC timestamp. A zero-padded score prefix
in `scoreKey` lets DynamoDB retrieve the highest scores without scanning.
Equal-score order is unspecified. Entries are per submission, not per person.

This is a demo leaderboard with client-submitted scores, not server-verified
gameplay. Nicknames are not unique identities. There is no authentication,
per-player rate limit or automatic data expiry. The desktop permits one
submission attempt per completed Arcade round, without automatic POST retries;
this is a UI safeguard, not enforcement against other clients. A failed or
timed-out attempt may have reached the server.

## Connection check

From the repository root:

```powershell
python -m desktop.check_leaderboard
```

This makes three GET requests, one per difficulty, using the same client as
the game. It verifies connectivity, response fields, the ten-entry limit and
score ordering. It never submits or deletes scores and uses no AWS credentials.
CI runs it as the separate **AWS Leaderboard Connection** job. A network or
AWS outage fails that job; the offline tests and desktop smoke run separately.
Client POST formatting and failure handling are tested locally with simulated responses,
not with writes to the public table. Successful CI does not prove anti-cheat
protection, billing limits, IAM isolation or mobile integration.
