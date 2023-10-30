import boto3
import json
import fmc.model as model
import time
from fmc.save import save

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
    print(queue_url, model_path)
    # sqs = boto3.client("sqs")
    # response = sqs.receive_message(
    #     QueueUrl=queue_url,
    #     WaitTimeSeconds=5
    # )
    # message = response['Messages'][0]
    # receipt_handle = message['ReceiptHandle']

    # stac_doc = json.loads(message['Body'])
    # dataset_id = stac_doc['id']

    # # process
    # output_data = model.process(dataset_id, model_path)
    # print(output_data)

    import pickle
    with open('dataset.xarray.bin', 'rb') as f:
        output_data = pickle.load(f)
    dataset_id = "52dda32c-cb4b-49eb-a31d-bcf70bf62751"

    save(dataset_id, output_data)

    # sqs.delete_message(
    #     QueueUrl=queue_url,
    #     ReceiptHandle=receipt_handle
    # )
