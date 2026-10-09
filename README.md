# AWS ECS Fargate Web App

An nginx website packaged with Docker, stored in Amazon ECR and
deployed on ECS Fargate behind an Application Load Balancer.
Infrastructure is defined using AWS CloudFormation.

## Project files

| File | Purpose |
|---|---|
| vpc.yaml | Creates the VPC, subnets, routing and NAT gateway |
| ecr.yaml | Creates the private ECR repository |
| ecs.yaml | Creates the ECS service, ALB and logging |
| Dockerfile | Builds the nginx image containing the website |
| .dockerignore | Excludes unnecessary files from the build |
| site/index.html | Website content |

## Architecture

Visitors connect to the public ALB on HTTP port 80.
The ALB forwards requests to nginx containers running in a private subnet.

The task security group allows port 80 from the ALB security group only.
Tasks use the NAT gateway for outbound access to pull images and
send logs to CloudWatch.

## Prerequisites

- AWS CLI configured with suitable permissions
- Docker installed and running
- AWS region: eu-north-1

## Deployment

### 1. Create the network and ECR repository

```bash
aws cloudformation deploy \
  --template-file vpc.yaml \
  --stack-name fargate-vpc \
  --region eu-north-1

aws cloudformation deploy \
  --template-file ecr.yaml \
  --stack-name fargate-ecr \
  --region eu-north-1
```

### 2. Build and push the image

Run these commands from the folder containing the Dockerfile:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.eu-north-1.amazonaws.com"
IMAGE_URI="${REGISTRY}/my-app:v1"

aws ecr get-login-password --region eu-north-1 |
  docker login --username AWS --password-stdin "$REGISTRY"

docker build --platform linux/amd64 -t my-app:v1 .
docker tag my-app:v1 "$IMAGE_URI"
docker push "$IMAGE_URI"
```

The repository uses immutable tags. Use a new tag, such as v2,
for subsequent releases and update ecs.yaml accordingly.

### 3. Configure and deploy ECS

Before deployment, update ecs.yaml:
- Replace the account mapping key with your AWS account ID.
- Set the VPC and subnet IDs using the fargate-vpc stack outputs.
- Set the container image to your ECR image URI and tag.

```bash
aws cloudformation deploy \
  --template-file ecs.yaml \
  --stack-name fargate-service \
  --capabilities CAPABILITY_IAM \
  --region eu-north-1
```

### 4. Get the website URL

```bash
aws cloudformation describe-stacks \
  --stack-name fargate-service \
  --region eu-north-1 \
  --query "Stacks[0].Outputs[?OutputKey=='WebsiteUrl'].OutputValue" \
  --output text
```

## Verification

After deployment:
- Check that the ECS service has two running tasks.
- Check that ALB targets become healthy.
- Open the website URL and look for “Hello from ECS Fargate!”
- Inspect container logs in CloudWatch.

## Limitations

- HTTP only; no HTTPS listener or certificate is configured.
- Both tasks run in one private subnet.
- One NAT gateway is used.
- Account-specific mappings must be updated before deployment.
- This repository does not yet include deployment evidence.

## Cleanup

Delete the ECS service stack first:

```bash
aws cloudformation delete-stack \
  --stack-name fargate-service \
  --region eu-north-1

aws cloudformation wait stack-delete-complete \
  --stack-name fargate-service \
  --region eu-north-1
```

Empty the ECR repository before deleting the ECR stack.
Then delete the ECR stack and finally the VPC stack.

Fargate, the ALB, NAT gateway and public IPv4 addresses incur charges
while provisioned. ECR storage and CloudWatch logs may also incur charges.# aws-ecs-fargate-web-app
Containerised nginx website deployed on ECS Fargate with ECR, an Application Load Balancer and CloudFormation
