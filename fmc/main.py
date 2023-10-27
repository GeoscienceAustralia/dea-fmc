import boto3
import json
import fmc.model as model

def read_dataset(message):
    stac_doc = json.loads(message)
    dataset_id = stac_doc['id']
    return dataset_id

def send(queue_url, message_path):
    sqs = boto3.client("sqs")
    print("sending")
    with open(message_path, 'r') as f:
        file_contents = f.read()

    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=file_contents
    )


def handle(queue_url, model_path):
    sqs = boto3.client("sqs")
    response = sqs.receive_message(
        QueueUrl=queue_url
    )
    message = response['Messages'][0]
    receipt_handle = message['ReceiptHandle']

    dataset_id = read_dataset(message['Body'])
    model.process(dataset_id, model_path)

    # process
    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receipt_handle
    )