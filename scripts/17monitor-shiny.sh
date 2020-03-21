#!/bin/bash

## 查看 EKS 集群节点信息
kubectl get node -o wide

## 查看 EKS 集群系统Pod信息
kubectl -n kube-system get pods -o wide

## 查看Shiny相关Pods状态
kubectl -n shiny get pods -o wide

## 查看当前Shinyproxy Pod信息
## 可了解当前使用的容器版本等
kubectl describe -n shiny pods/shinyproxy-xxxxxxxxxxxxxxx-xxxxx

## 查看Shinyproxy日志
kubectl logs -f -n shiny -c shinyproxy shinyproxy-xxxxxxxxx-xxxxxxx

## 如果更新容器及相应的配置文件，需删除后再次提交生效
## kubectl delete -f sp-authorization.yaml
kubectl delete -f sp-service.yaml
kubectl delete -f sp-deployment.yaml

## kubectl create -f sp-authorization.yaml
kubectl create -f sp-service.yaml
kubectl create -f sp-deployment.yaml
