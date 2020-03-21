#!/bin/bash

## 创建EKS集群的Kubernetes 命名空间 —— 名称为 Shiny
kubectl create ns shiny

## Deploy
kubectl apply -f ../sp-service.yaml
kubectl apply -f ../sp-authorization.yaml
kubectl apply -f ../sp-deployment.yaml
kubectl apply -f ../sp-shinyingress.yaml

## Delete
# kubectl delete -f sp-service.yaml
# kubectl delete -f sp-authorization.yaml
# kubectl delete -f sp-deployment.yaml
# kubectl delete -f sp-shinyingress.yaml
