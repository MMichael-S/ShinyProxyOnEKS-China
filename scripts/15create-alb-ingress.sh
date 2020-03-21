#!/bin/bash

## 环境变量设置
REGION_EKS=cn-northwest-1
export AWS_DEFAULT_REGION=$REGION_EKS
EKS_CLUSTER_NAME=EKS-ZHY

## 创建 IAM OIDC 提供程序，并将该提供程序与您的集群关联
eksctl utils associate-iam-oidc-provider \
    --region $REGION_EKS \
    --cluster $EKS_CLUSTER_NAME \
    --approve

## 为 ALB 入口控制器 Pod 创建一个名为 ALBIngressControllerIAMPolicy 的 IAM 策略，该策略允许此 Pod 代表您调用 AWS API
aws iam create-policy \
    --policy-name ALBIngressControllerIAMPolicy \
    --policy-document https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/iam-policy.json

## 在 kube-system 命名空间中创建一个名为 alb-ingress-controller 的 Kubernetes 服务账户，并创建集群角色和针对 ALB 入口控制器的集群角色绑定，以便用于以下命令。
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/rbac-role.yaml

## 使用以下命令部署 ALB 入口控制器
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/alb-ingress-controller.yaml

## 使用以下命令打开 ALB 入口控制器部署清单以进行编辑
kubectl edit deployment.apps/alb-ingress-controller -n kube-system

## 在 --ingress-class=alb 行之后，为集群名称添加相应内容
## cluster-name 为当前EKS集群名称
## aws-vpc-id 为当前EKS集群使用的VPC的ID
## aws-region 为当前EKS集群使用的AWS区域
## 添加相应的行后，保存并关闭文件

        - --ingress-class=alb
        - --cluster-name=EKS-ZHY
        - --aws-vpc-id=vpc-02427bd6c6168efc2
        - --aws-region=cn-northwest-1


## 使用以下命令确认 ALB 入口控制器是否正在运行
kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
alb-ingress-controller-xxxxxxxxxx-8hbkx   1/1     Running   0          2d1h


