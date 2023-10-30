#!/bin/bash

awslocal sqs create-queue --queue-name ${QUEUE_NAME}
awslocal s3api create-bucket --bucket ${BUCKET_NAME}
