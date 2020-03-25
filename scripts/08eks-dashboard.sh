#!/bin/bash

# mkdir -p ~/download
# cd ~/download

##安装jq
sudo apt install jq -y

##部署metrics server
DOWNLOAD_URL=$(curl -Ls "https://api.github.com/repos/kubernetes-sigs/metrics-server/releases/latest" | jq -r .tarball_url)
DOWNLOAD_VERSION=$(grep -o '[^/v]*$' <<< $DOWNLOAD_URL)
curl -Ls $DOWNLOAD_URL -o metrics-server-$DOWNLOAD_VERSION.tar.gz
mkdir metrics-server-$DOWNLOAD_VERSION
tar -xzf metrics-server-$DOWNLOAD_VERSION.tar.gz --directory metrics-server-$DOWNLOAD_VERSION --strip-components 1
##修改 metrics-server-0.3.6/deploy/1.8+ 目录下 metrics-server-deployment.yaml 文件中 metrics-server 的容器为三方源
vi metrics-server-0.3.6/deploy/1.8+/metrics-server-deployment.yaml

## metrics-server 替换三方源
      - name: metrics-server
        # image: k8s.gcr.io/metrics-server-amd64:v0.3.6
        image: 三方源/metrics-server-amd64:v0.3.6
        imagePullPolicy: Always

kubectl apply -f ./metrics-server-$DOWNLOAD_VERSION/deploy/1.8+/

## 查看部署
kubectl get deployment metrics-server -n kube-system

## 下载最新的Dashboard部署文件
## https://github.com/kubernetes/dashboard
## wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc5/aio/deploy/recommended.yaml

## 修改 recommended.yaml 文件
## 在确保访问安全的情况下，可添加参数延长Token的过期时间（单位为分钟，默认为15分钟） *
## 或 在登录界面增加 Skip 按钮*

<<COMMENT
    spec:
      containers:
        - name: kubernetes-dashboard
          image: kubernetesui/dashboard:v2.0.0-rc5
          imagePullPolicy: Always
          ports:
            - containerPort: 8443
              protocol: TCP
          args:
            - --auto-generate-certificates
            - --namespace=kubernetes-dashboard
*           - --token-ttl=43200
*           - --enable-skip-login

COMMENT

## 通过kubectl应用配置
kubectl apply -f ./recommended.yaml

## 创建 eks-admin-service-account.yaml 文件
<<COMMENT
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eks-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: eks-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: eks-admin
  namespace: kube-system
COMMENT

## 通过kubectl应用配置
kubectl apply -f ./eks-admin-service-account.yaml

## 获取登录Token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')

## 启用代理
nohup kubectl proxy &

## 如需要从本地访问控制面板，可启用SSH Tunnel
## ssh -L 8001:localhost:8001 -A ubuntu@EC2公网IP

## 浏览器访问下面的链接，并输入之前获取的Token
## http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login

