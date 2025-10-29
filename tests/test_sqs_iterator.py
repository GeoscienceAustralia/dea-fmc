import json
import boto3
from moto import mock_aws

from dea_fmc.__main__ import get_uuid_iterator_from_sqs

UUID = "44220f30-1ece-4b16-b3e1-b117ac61184f"

@mock_aws
def test_iterator_yields_valid_uuid_and_receipt_handle():
    # Create mock SQS and queue
    sqs = boto3.client("sqs", region_name="ap-southeast-2")
    q = sqs.create_queue(QueueName="dea-fmc-test")
    queue_url = q["QueueUrl"]

    # 1) Valid bare UUID
    sqs.send_message(QueueUrl=queue_url, MessageBody=UUID)

    # 2) Valid STAC JSON
    stac = json.dumps({"type": "Feature", "id": UUID})
    sqs.send_message(QueueUrl=queue_url, MessageBody=stac)

    # 3) Invalid payload (should be skipped)
    sqs.send_message(QueueUrl=queue_url, MessageBody="not-a-uuid")

    # Collect yields
    it = get_uuid_iterator_from_sqs(queue_url, max_empty_polls=1)
    results = []
    for _ in range(2):  # we expect two valid yields
        uuid_str, receipt = next(it)
        results.append((uuid_str, bool(receipt)))

    # Assertions
    assert all(u == UUID for u, _ in results)
    assert all(has_receipt for _, has_receipt in results)

