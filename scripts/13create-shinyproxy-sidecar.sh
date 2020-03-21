#!/bin/bash

## 需根据情况修改命令中的AWS账号、区域信息

mkdir -p ~/download
cd ~/download

## kube-proxy-sidecar
## The kube-proxy-sidecar container handles the different users login, creating a new pod for every user login.

git clone https://github.com/rohitsrmuniv/Shinyproxy.git
cd Shinyproxy

## 创建容器并推送到AWS ECR服务，容器标签可自定义
docker build -t xxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/kube-proxy-sidecar:0.1.0 kube-proxy-sidecar/

docker push xxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/kube-proxy-sidecar:0.1.0

