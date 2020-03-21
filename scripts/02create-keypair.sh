#!/bin/bash

## 如已有对应区域的密钥对，此步骤可忽略
## 创建密钥对（用于管理机及后续的EKS集群节点）
## 密钥对名称
KEYPAIR_NAME=<EC2-KEY-NAME>

## aws ec2 delete-key-pair --key-name $KEYPAIR_NAME
## 创建密钥对并将密钥文件保存到当前目录下，后缀名以.pem结尾
aws ec2 create-key-pair --key-name $KEYPAIR_NAME | jq -r '.KeyMaterial'> $KEYPAIR_NAME.pem

## 修改密钥对权限
chmod 600 $KEYPAIR_NAME.pem
