#!/bin/bash

## 编辑生成测试文件，为快速查看扩展效果可修改nginx容器的资源配置

cat <<EoF> ./ca-test-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-to-scaleout
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        service: nginx
        app: nginx
    spec:
      containers:
      - image: nginx
        name: nginx-to-scaleout
        resources:
          limits:
            cpu: 500m
            memory: 2048Mi
          requests:
            cpu: 500m
            memory: 2048Mi
EoF

## 通过kubectl 应用配置
kubectl apply -f ./ca-test-nginx.yaml

## 将测试Nginx容器扩展到20个
## 是否触发自动扩展与当前运行的节点数量、节点配置有关
kubectl scale --replicas=20 deployment/nginx-to-scaleout

## 可通过下面的命令监控Nginx容器的部署状态
watch -n 2 kubectl get deployment/nginx-to-scaleout

## 可通过下面的命令监控节点的增加情况
## 也可通过 Cluster Autoscaler 日志观察到节点的扩展信息
kubectl get node -o wide

## 测试完成后删除测试过程的部署
kubectl delete -f ./ca-test-nginx.yaml

