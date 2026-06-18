#!/usr/bin/python

from datetime import datetime

import boto3

MONTHS = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
]

current_m = datetime.now().month - 1
assert 0 <= current_m < len(MONTHS), f"Current month({current_m}) is out of range"

prev_name = MONTHS[current_m - 3]
# prev_idx = "%02d" % (MONTHS.index(prev_name) + 1)
prev_idx = f"{MONTHS.index(prev_name) + 1:02d}"
prev_3month = f"{prev_idx}-{prev_name}"

s3_client = boto3.client("s3")

BUCKET = "duplicity.gautier.org"
PREFIX = f"{prev_3month}/"

response = s3_client.list_objects_v2(Bucket=BUCKET, Prefix=PREFIX)

CONTENTS = "Contents"
if CONTENTS in response:
    print("Backup Cleanup:")
    for object in response[CONTENTS]:
        if object["Key"] != PREFIX:
            print(" - Deleting", object["Key"])
            s3_client.delete_object(Bucket=BUCKET, Key=object["Key"])
