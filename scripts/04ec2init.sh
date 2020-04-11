#!/bin/bash

## 登录启动的管理机
# ssh -i "hkg-key.pem" ubuntu@$BASTION_EIP

## 系统更新
sudo yum update -y
#sudo yum upgrade -y

## 如更新后提示需要重新启动完成重新启动
# sudo reboot

## 确认Python版本为3.4以上 
python3 --version

## 安装pip
sudo yum install python3-pip -y

## 安装awscli
pip3 install boto3 awscli --upgrade -i http://pypi.doubanio.com/simple --trusted-host pypi.doubanio.com --user

## 查看awscli版本
aws --version
## aws-cli/1.18.6 Python/3.5.2 Linux/4.4.0-1102-aws botocore/1.15.6

## 测试AWS CLI配置是否正确
## 正常会显示当前账号下存储桶信息或无报错空信息
REGION_EKS=cn-northwest-1
export AWS_DEFAULT_REGION=$REGION_EKS
aws s3 ls

## Docker安装
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine -y

sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

sudo yum-config-manager \
    --add-repo \
https://download.docker.com/linux/centos/docker-ce.repo

## sudo yum-config-manager --enable docker-ce-edge
## sudo yum-config-manager --enable docker-ce-test
## sudo yum-config-manager --disable docker-ce-edge
## sudo yum-config-manager --disable docker-ce-test

## sudo yum search docker-ce
sudo yum install docker-ce -y
sudo chkconfig docker on
sudo systemctl restart docker

## 简单测试
## 正常会显示 “Hello from Docker!” 字样
sudo docker run hello-world

## 授权Ubuntu用户拥有Docker的操作权限
## 需注销并重新登录后权限生效
sudo usermod -aG docker $USER

## 查看Docker信息
## 可关注其中的版本信息，如“Server Version: 19.03.6”
docker info

## 创建当前用户根目录下名为download的目录
## 此目录将用于后续文件下载等目的，也可根据需要更改为其他目录名
mkdir -p ~/download
cd ~/download

## 查看eksctl latest版本：https://github.com/weaveworks/eksctl/releases
## 下载eksctl latest最新稳定版本
## curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
## sudo mv /tmp/eksctl /usr/local/bin/eksctl

## 查看当前版本
## eksctl version
## 0.14.0

## 特殊情况下，也可指定具体eksctl版本下载
## eksctl 0.15.0后版本支持中国区域EKS

curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/0.17.0-rc.0/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/eksctl
eksctl version
## 0.17.0-rc.0

mkdir -p ~/download
cd ~/download

## 下载AWS提供的kubectl文件，这些可执行文件与上游社区版本相同
## AWS所提供的kubectl版本会在将来发生变化，下载前请阅读参考文档获取最新的下载链接
curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl

chmod +x ./kubectl

mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin

echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc

kubectl version --short --client
## Client Version: v1.14.7-eks-1861c5

## EKS集群存在情况下的输出
kubectl version --short
##Client Version: v1.14.7-eks-1861c5
##Server Version: v1.14.9-eks-502bfb


