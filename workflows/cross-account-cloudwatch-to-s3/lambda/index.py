"""
Firehose transformation Lambda.

Decodes CloudWatch Logs subscription data (base64 + gzip),
flattens each log event into a single JSON line, and returns
the records to Firehose for S3 delivery.
"""

import base64
import gzip
import json


def handler(event, context):
    output = []

    for record in event["records"]:
        payload = base64.b64decode(record["data"])
        payload = gzip.decompress(payload)
        data = json.loads(payload)

        # Skip CloudWatch control messages
        if data.get("messageType") == "CONTROL_MESSAGE":
            output.append({"recordId": record["recordId"], "result": "Dropped"})
            continue

        log_group = data.get("logGroup", "")
        log_stream = data.get("logStream", "")
        account_id = data.get("owner", "unknown")

        lines = []
        for log_event in data.get("logEvents", []):
            line = {
                "timestamp": log_event.get("timestamp"),
                "message": log_event.get("message", ""),
                "logGroup": log_group,
                "logStream": log_stream,
                "accountId": account_id,
            }
            lines.append(json.dumps(line, separators=(",", ":")))

        joined = "\n".join(lines) + "\n"
        encoded = base64.b64encode(joined.encode("utf-8")).decode("utf-8")

        output.append({
            "recordId": record["recordId"],
            "result": "Ok",
            "data": encoded,
        })

    return {"records": output}
