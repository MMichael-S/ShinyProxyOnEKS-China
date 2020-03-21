#!/bin/bash

## EKS集群名
EKS_CLUSTER_NAME=EKS-ZHY
## AWS区域
REGION_EKS=cn-northwest-1
## 可自定义Tag标签信息，用于后续的费用跟踪及其他管理（可选项）
TAG="Environment=Alpha-Test,Application=Shiny"
## 配置文件方式，可参考：
## https://github.com/weaveworks/eksctl/blob/master/examples/02-custom-vpc-cidr-no-nodes.yaml

eksctl create cluster \
  --name=$EKS_CLUSTER_NAME \
  --version=1.15 \
  --region=$REGION_EKS \
  --tags $TAG \
  --without-nodegroup \
  --asg-access \
  --full-ecr-access \
  --appmesh-access \
  --alb-ingress-access

## 附加选项的说明，增加下列选项在EKS集群创建中将自动创建相关的IAM策略
<<COMMENT
Cluster and nodegroup add-ons flags:
      --asg-access            enable IAM policy for cluster-autoscaler
      --external-dns-access   enable IAM policy for external-dns
      --full-ecr-access       enable full access to ECR
      --appmesh-access        enable full access to AppMesh
      --alb-ingress-access    enable full access for alb-ingress-controller
COMMENT

## 如需删除创建的EKS集群，可使用下面的命令
## eksctl delete cluster --name=$EKS_CLUSTER_NAME --region=$REGION_EKS

## 集群配置通常需要 10 到 15 分钟
## 集群将自动创建所需的VPC/安全组/IAM 角色/EKS API服务等资源

## 集群访问测试
## watch -n 2 kubectl get svc
kubectl get svc

## NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
## kubernetes   ClusterIP   10.100.0.1   <none>        443/TCP   11m


