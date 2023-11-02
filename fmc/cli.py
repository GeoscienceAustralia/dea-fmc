import click
import fmc
import time

@click.command()
@click.option('--queue-url', required=True, envvar='QUEUE_URL', help='URL for SQS queue - e.g., https://sqs.ap-southeast-2.amazonaws.com/XXXXXXXXXXXX/my-queue-name')
@click.option('--model-path', required=True, envvar='MODEL_PATH', help='Path to the pretrained sklearn model parameters')
@click.option('--s3-prefix', required=True, envvar='S3_PREFIX', help='S3 bucket prefix, including directory, to save to - e.g., s3://dea-public-data-dev/derivative/')
@click.option('--explorer-url', required=True, envvar='EXPLORER_URL', help='URL to Explorer to include in STAC document - e.g., https://explorer.dev.dea.ga.gov.au')
def cli(queue_url, model_path, s3_prefix, explorer_url):
    fmc.handle(queue_url, model_path, s3_prefix, explorer_url)

if __name__ == '__main__':
    cli()
