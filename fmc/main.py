import boto3
import json
import fmc.model as model
import time
from fmc.save import save

def read_dataset(message):
    stac_doc = json.loads(message)
    dataset_id = stac_doc['id']
    return dataset_id

def handle(queue_url, model_path):
    sqs = boto3.client("sqs")
    response = sqs.receive_message(
        QueueUrl=queue_url,
        WaitTimeSeconds=5
    )

    if "Messages" not in response:
        print("No messages to process")
        return

    message = response['Messages'][0]
    receipt_handle = message['ReceiptHandle']

    stac_doc = json.loads(message['Body'])
    dataset_id = stac_doc['id']

    # process
    output_data = model.process(dataset_id, model_path)

    save(dataset_id, output_data)

    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receipt_handle
    )
