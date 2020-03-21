#!/bin/bash

## 通过 kubectl 应用配置
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"

## 修改对应信息
kubectl -n kube-system edit deployment.apps/cluster-autoscaler

## 编辑 51行，将 <YOUR CLUSTER NAME> 替换为 当前创建的EKS集群名，如 EKS-ZHY
## 如无法访问gcr.io的镜像，可自行替换为其他三方源
## 在此行下添加下列内容
      containers:
        #- image: k8s.gcr.io/cluster-autoscaler:v1.14.7
        - image: 三方源/cluster-autoscaler:v1.14.7
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false

## 通过 kubectl 应用配置
kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=gcr.azk8s.cn/google_containers/cluster-autoscaler:v1.14.7
## kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=k8s.gcr.io/cluster-autoscaler:v1.14.7

## 查看Cluster Autoscaler日志
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler

## 部署完成后Cluster Autoscaler即开始工作
## 如没有Pod运行，会将目前NodeGroup中节点数逐渐关停到 NodeGroup 扩展组设置的最小值，如当前设置的2

