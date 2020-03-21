#!/bin/bash

## 需根据情况修改命令中的AWS账号、区域信息

mkdir -p ~/download/Shinyproxy/shiny-application
cd ~/download/Shinyproxy/shiny-application

## 参考：https://github.com/openanalytics/shinyproxy-template
git clone https://github.com/openanalytics/shinyproxy-template.git

## 基于Dockerfile创建本地容器，整个过程一般需要数分钟时间
sudo docker build -t shiny_eks_demo/shiny-application ./shinyproxy-template/

## 查看Docker Images
docker images

REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
shiny_eks_demo/shiny-application     latest              1e49917ec341        19 minutes ago      919MB
openanalytics/r-base                 latest              09fd463ea5e6        6 days ago          562MB
hello-world                          latest              fce289e99eb9        14 months ago       1.84kB

## 在8888端口启动Shiny（EC2上未使用端口均可）
sudo docker run -it -p 8888:3838 shiny_eks_demo/shiny-application

## 确认端口监听正常
sudo netstat -tunlp |grep 8888
tcp6       0      0 :::8888                 :::*                    LISTEN      6181/docker-proxy

## 开启安全组设置（指定端口或端口范围）
## 需根据情况修改命令中的安全组ID信息。可通过控制台查看 管理机 EC2的安全组ID
aws ec2 authorize-security-group-ingress --group-id sg-07bc79481229eedf0 \
    --protocol tcp --port "8888" --cidr 0.0.0.0/0 \
    --region cn-northwest-1
    
## 通过浏览器访问 EC2 弹性IP地址:8888 端口，测试Shiny应用是否正常

## 记录并注释掉Dockerfile文件中最后的 CMD 行，并重新build容器

vi ~/download/Shinyproxy/shiny-application/shinyproxy-template/Dockerfile

*# CMD ["R", "-e", "shiny::runApp('/root/euler')"]*

## 容器内R应用的启动后续将由ShinyProxy通过接口进行调度
## 重新build容器
sudo docker build -t shiny_eks_demo/shiny-application ./shinyproxy-template/

## 标记上传容器镜像，注意更换AWS账号 xxxxxxxxxx
## ECR中容器标签如“0.1.0”，可用于控制多次发布的不同容器应用版本
docker tag shiny_eks_demo/shiny-application:latest xxxxxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shiny-application:0.1.0

## 查看本地标记后images
docker images
REPOSITORY                                                            TAG                 IMAGE ID            CREATED             SIZE
xxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com/shiny-application        0.1.0              1de990a83277        36 minutes ago      919MB

## 推送Images到ECR中
docker push xxxxxxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shiny-application:0.1.0


