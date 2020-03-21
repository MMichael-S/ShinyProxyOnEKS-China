#!/bin/bash

#mkdir -p ~/download
#cd ~/download

## EKS集群名
EKS_CLUSTER_NAME=EKS-ZHY
## AWS区域
REGION_EKS=cn-northwest-1
## 节点组名称
NODE_GROUP_NAME="NG-UNMANAGED-M5-x"

## 创建NodeGroup
eksctl create nodegroup --config-file=../NG-UNMANAGED-M5-x.yaml

## 在创建异常的情况下，需要删除之前失败的NodeGroup后重新创建
## eksctl delete nodegroup --config-file=./NG-UNMANAGED-M5-x.yaml --approve

## 创建完成后可手工管理NodeGroup的伸缩，如将原节点数量从2调整为3
## 后续将增加自动扩展功能
## eksctl scale nodegroup  --cluster $EKS_CLUSTER_NAME --name $NODE_GROUP_NAME --nodes 3

## 输出显示类似下面信息：
<<COMMENT
/*
[ℹ]  scaling nodegroup stack "eksctl-EKS-HKG-nodegroup-NG-UNMANAGED-M5-x" in cluster eksctl-EKS-HKG-cluster
[ℹ]  scaling nodegroup, desired capacity from "2" to 3
*/
COMMENT
