#!/bin/bash

cd ~/download/Shinyproxy/shinyproxy-application/

## 修改Dockerfile 文件，更新为ShinyProxy 稳定最新版本
## 可通过 https://www.shinyproxy.io/downloads/ 查看ShinyProxy版本信息

vi Dockerfile

FROM openjdk:8-jre

RUN mkdir -p /opt/shinyproxy/
RUN wget https://www.shinyproxy.io/downloads/shinyproxy-2.3.0.jar -O /opt/shinyproxy/shinyproxy.jar
COPY application.yml /opt/shinyproxy/application.yml

WORKDIR /opt/shinyproxy/
CMD ["java", "-jar", "/opt/shinyproxy/shinyproxy.jar"]


## 修改 application.yml 文件
## 需根据情况修改配置中的AWS账号
## 目前测试使用Shinyproxy的Simple认证模式，后期需进行优化
## 用户名及密码根据实际情况进行修改
## ShinyProxy 配置文件中共配置四个测试应用
## 第一个为本文前期创建的自定义Shiny应用，其他为来自于网络的三方可公开访问容器
## 注意匹配每个Shiny容器的启动命令路径

## Spring相关的参数设置会决定Shiny容器中上传文件的大小限制
## 默认只有1MB/10MB
## 可参考：https://docs.spring.io/spring-boot/docs/current/reference/html/appendix-application-properties.html
## spring.servlet.multipart.max-file-size 和 spring.servlet.multipart.max-request-size参数
## 另外在Shiny应用中也需要相应设置，如下面设置为10MB
## options(shiny.maxRequestSize = 10*1024^2)
## 缺省情况下允许上传的文件大小为5MB

proxy:
  port: 8080
  authentication: simple
  admin-groups: admins
  users:
  - name: admin
    password: Admin@123
    groups: admins
  - name: Guest
    password: Guest@123
  container-backend: kubernetes
  container-wait-time: 300000
  heartbeat-rate: 10000
  heartbeat-timeout: 300000
  kubernetes:
    internal-networking: true
    url: http://localhost:8001
    namespace: shiny
    image-pull-policy: IfNotPresent
    image-pull-secret:
  specs:
  - id: 00_demo_shiny
    display-name: Simple Shiny Application Demo
    description: https://github.com/openanalytics/shinyproxy-template
    container-cmd: ["R", "-e", "shiny::runApp('/root/euler')"]
    container-image: xxxxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shiny-application:0.1.0
  - id: 01_hello
    display-name: Hello Application
    description: Application which demonstrates the basics of a Shiny app
    container-cmd: ["R", "-e", "shinyproxy::run_01_hello()"]
    container-image: openanalytics/shinyproxy-demo
    access-groups: [admins, scientists, mathematicians]
  - id: 06_tabsets
    display-name: Openanalytics shinyproxy-demo tabsets
    description: Application which demonstrates a Shiny app
    container-cmd: ["R", "-e", "shinyproxy::run_06_tabsets()"]
    container-image: openanalytics/shinyproxy-demo
    access-groups: admins
  - id: dash-demo
    display-name: Dash Demo Application
    description: https://github.com/openanalytics/shinyproxy-dash-demo
    port: 8050
    container-cmd: ["python", "app.py"]
    container-image: openanalytics/shinyproxy-dash-demo
    access-groups: admins

spring:
  servlet:
    multipart:
      max-file-size: 2000MB
      max-request-size: 2000MB
      
logging:
  file:
    shinyproxy.log
    
    
## 创建容器并推送到ECR服务，标签可自定义
docker build -t xxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shinyproxy-application:2.3.0 .

docker push xxxxxxxxxx.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shinyproxy-application:2.3.0

