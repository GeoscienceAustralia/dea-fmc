import click
import fmc
import time

@click.command()
@click.option('--queue-url', required=False, help='URL for SQS queue - e.g., https://sqs.ap-southeast-2.amazonaws.com/XXXXXXXXXXXX/my-queue-name')
@click.option('--model-path', required=False, help='Path to the pretrained sklearn model parameters')
@click.option('--message-path', required=False)
def cli(queue_url, model_path, message_path):
    # if message_path:
    #     print("going to send")
    #     fmc.send(queue_url, message_path)
    #     time.sleep(1)
    fmc.handle(queue_url, model_path)

if __name__ == '__main__':
    cli()