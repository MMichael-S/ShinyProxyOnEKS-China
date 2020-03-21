#!/bin/bash

## 如果已设置 AWS_DEFAULT_REGION 环境变量，可以在eksctl中忽略 --region 参数
REGION_EKS=cn-northwest-1
export AWS_DEFAULT_REGION=$REGION_EKS
EKS_CLUSTER_NAME=EKS-ZHY

## 查看节点状态
kubectl get nodes # --watch

## 查看系统pod状态
kubectl -n kube-system get pods # --watch

## 查看集群信息
aws eks describe-cluster --name $EKS_CLUSTER_NAME --region=$REGION_EKS

## 查看NodeGroup 信息
eksctl get nodegroups --cluster $EKS_CLUSTER_NAME --region $REGION_EKS

## Enabled CloudWatch logging for cluster "EKS-HKG" in "ap-east-1"
## 参考链接：https://eksctl.io/usage/cloudwatch-cluster-logging/
## enable types: api, audit, authenticator, controllerManager, scheduler
eksctl utils update-cluster-logging --enable-types all --approve --region=$REGION_EKS --cluster=$EKS_CLUSTER_NAME

