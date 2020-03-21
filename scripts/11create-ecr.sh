#!/bin/bash

## 通过AWS CLI方式创建容器镜像的ECR存储库
## 可参考： https://docs.aws.amazon.com/zh_cn/AmazonECR/latest/userguide/getting-started-cli.html

REGION_EKS=cn-northwest-1
export AWS_DEFAULT_REGION=$REGION_EKS

## 创建三个ECR存储库
aws ecr create-repository \
    --repository-name shiny-application \
    --image-scanning-configuration scanOnPush=true
    
aws ecr create-repository \
    --repository-name kube-proxy-sidecar \
    --image-scanning-configuration scanOnPush=true

aws ecr create-repository \
    --repository-name shinyproxy-application \
    --image-scanning-configuration scanOnPush=true
    

## 登录ECR服务
$(aws ecr get-login --no-include-email --region cn-northwest-1)


