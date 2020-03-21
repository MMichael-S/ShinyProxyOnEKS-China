## 三、ShinyProxy 部署

ShinyProxy 原生支持三种容器后端平台，单机版本的 Docker、Docker Swarm 集群以及 Kubernetes 集群。在此步骤我们将完成 ShinyProxy 在 EKS Kubernetes 平台上的部署。

### 3.1 Amazon ECR配置

[Amazon Elastic Container Registry](https://docs.aws.amazon.com/zh_cn/AmazonECR/latest/userguide/what-is-ecr.html) (Amazon ECR) 是一项托管 AWS Docker 镜像仓库服务，安全、可扩展且可靠。通过与 AWS IAM服务配合使用，Amazon ECR 可限制仅限特定用户或 Amazon EC2 实例可以访问，您可以使用 Docker CLI 推送、拉取和管理映像。可参考 [通过控制台创建容器镜像的ECR存储库](https://docs.aws.amazon.com/zh_cn/AmazonECR/latest/userguide/getting-started-console.html) 以及 [Amazon ECR CLI参考](https://docs.aws.amazon.com/cli/latest/reference/ecr/index.html)。 
如果相关的容器已经存放在本地或其他三方的镜像仓库中，此步骤可忽略。

```
## 通过AWS CLI方式创建容器镜像的ECR存储库
REGION_EKS=cn-northwest-1
export AWS_DEFAULT_REGION=$REGION_EKS

## 创建三个ECR存储库
aws ecr create-repository \
    --repository-name shiny-application \
    --image-scanning-configuration scanOnPush=true
    
aws ecr create-repository \
    --repository-name kube-proxy-sidecar \
    --image-scanning-configuration scanOnPush=true

aws ecr create-repository \
    --repository-name shinyproxy-application \
    --image-scanning-configuration scanOnPush=true
    

## 登录ECR服务（下面的命令无需修改可执行，注意保留 $符号及括号）
## 执行成功将返回 “Login Succeeded” 信息
$(aws ecr get-login --no-include-email --region cn-northwest-1)

```

### 3.2 Shiny 测试应用

此部分我们将创建用于 ShinyProxy 的一个简单 Shiny 测试应用，为了简化 Shiny 应用的编译过程，我们在本文中直接使用 Rocker 官方的示例 shiny 容器作为测试应用。您也可自行选择用于测试的R应用容器，比如 [Rstudio](https://github.com/rstudio/shiny-examples/blob/master/docker/Dockerfile) 的示例 Shiny 应用，或将目前的 R 应用容器化并通过 Shiny 进行封装后进行实际的测试。如已有就绪的 Shiny 应用容器，此步骤可忽略。


```
## 搜索 Shiny 容器
docker search shiny

## 拉取 Shiny 容器
docker pull rocker/shiny

## 简单测试，如在80端口启动Shiny（EC2上未使用端口均可），需对应开启EC2安全组设置
sudo docker run -it -p 80:3838 rocker/shiny

```

通过浏览器访问 EC2 公网IP地址加对应端口，如Shiny应用正常会显示“Welcome to Shiny Server!”页面。

如使用Dockerfile进行Shiny容器的创建，或使用已有的Shiny容器，应将Dockerfile中末尾启动命令注释，重新进行docker build创建后再推送到Amazon ECR镜像仓库，并将Shiny容器的启动命令对应写入 Shinyproxy 的配置文件中，以供后续Shinyproxy发起正确的调用。

### 3.3 ShinyProxy 配置

在此步骤中，我们将参考 [OpenAnalytics 的示例配置](https://github.com/openanalytics/shinyproxy-config-examples/tree/master/03-containerized-kubernetes) 完成ShinyProxy 及 kube-proxy-sidecar 的部署。


```
## 下载 OpenAnalytics 的示例配置
cd ~/download
git clone https://github.com/openanalytics/shinyproxy-config-examples.git
cd ~/download/shinyproxy-config-examples/03-containerized-kubernetes

vi kube-proxy-sidecar/Dockerfile
## 修改 kube-proxy-sidecar 目录下的Dockerfile 文件内容为：

FROM alpine:3.6
ADD https://share-aws-nx.s3.cn-northwest-1.amazonaws.com.cn/shiny/kubectl1.7.4 /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl
EXPOSE 8001
ENTRYPOINT ["/usr/local/bin/kubectl", "proxy"]

```

修改ShinyProxy 的 Dockerfile 文件，可更新 ShinyProxy 至最新稳定版本或其他下载源，请定期查看[ShinyProxy版本信息](https://www.shinyproxy.io/downloads/)。

```
FROM openjdk:8-jre

RUN mkdir -p /opt/shinyproxy/
RUN wget https://share-aws-nx.s3.cn-northwest-1.amazonaws.com.cn/shiny/shinyproxy-2.3.0.jar -O /opt/shinyproxy/shinyproxy.jar
COPY application.yml /opt/shinyproxy/application.yml

WORKDIR /opt/shinyproxy/
CMD ["java", "-jar", "/opt/shinyproxy/shinyproxy.jar"]

```


在创建 ShinyProxy 容器及推送前，需要对其配置文件 application.yml 进行一些相应的编辑以适应目前的环境。其中涉及的参数含义可参考：[Shinyproxy配置参数说明](https://www.shinyproxy.io/configuration/)。 

**需要注意的事项：**

* 修改配置文件示例中的AWS账号为您的账号信息；
* 目前测试使用Shinyproxy的Simple认证模式，用户名及密码根据实际情况进行修改，后续需进行优化
* ShinyProxy 后端可运行的容器，可来自于ECR镜像仓库，也可来自于其他镜像仓库或互联网的容器
* 注意匹配每个Shiny容器的启动命令路径与原Dockerfile中信息一致
* ShinyProxy 使用了Spring Boot框架，[相关参数设置](https://docs.spring.io/spring-boot/docs/current/reference/html/appendix-application-properties.html)会影响其运行配置。比如在Shiny容器中上传文件的大小限制，默认只有1MB或10MB，可通过设置配置文件中 spring 节来提升限制，同时还需要在Shiny应用中也需要相应设置。

```
cd ~/download/shinyproxy-config-examples/03-containerized-kubernetes/shinyproxy-example

vi application.yml

proxy:
  port: 8080
  authentication: simple
  admin-groups: admins
  users:
  - name: admin
    password: Admin@123
    groups: admins
  - name: guest
    password: Guest@123
    groups: guest
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
  - id: 00_demo_shiny_application
    display-name: Simple Shiny Application Demo
    description: Simple Shiny Application Demo
    container-cmd: ["sh", "/usr/bin/shiny-server.sh"]
    container-image: <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shiny-application:v1
    access-groups: [admins, guest]
  - id: 01_hello_shiny_application
    display-name: Hello Application
    description: Application which demonstrates the basics of a Shiny app
    container-cmd: ["R", "-e", "shinyproxy::run_01_hello()"]
    container-image: openanalytics/shinyproxy-demo
    access-groups: [admins, guest]

spring:
  servlet:
    multipart:
      max-file-size: 100MB
      max-request-size: 100MB

logging:
  file:
    shinyproxy.log

```

### 3.4 容器推送至Amazon ECR

为完成整体部署，我们需要推送三个容器到Amazon ECR镜像仓库，包括：

* ShinyProxy 容器
* kube-proxy-sidecar容器（用于ShinyProxy的代理功能）
* Shiny 测试应用容器

在标记上传容器镜像时，请注意更换其中的 AWS 账号为您的账号信息。
通过ECR中的容器标签，可用于多次发布不同容器的版本控制。可参见：[推送镜像](https://docs.aws.amazon.com/zh_cn/AmazonECR/latest/userguide/docker-push-ecr-image.html)

```
## 标记并推送 Shiny 测试应用容器到 ECR 服务
docker tag rocker/shiny:latest <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shiny-application:v1
docker push <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shiny-application:v1

## 创建、标记并推送 kube-proxy-sidecar 容器
cd ~/download/shinyproxy-config-examples/03-containerized-kubernetes/kube-proxy-sidecar
docker build -t <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/kube-proxy-sidecar:v1 .
docker push <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/kube-proxy-sidecar:v1

## 创建、标记容器并推送到 ECR 服务，标签可自定义
cd ~/download/shinyproxy-config-examples/03-containerized-kubernetes/shinyproxy-example
docker build -t <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shinyproxy-application:v1 .
docker push <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shinyproxy-application:v1

```

### 3.5 ShinyProxy 部署

sp-authorization.yaml 文件无需修改。

编辑 sp-service.yaml 文件，以便部署后 EKS 自动创建负载均衡器便于访问。
修改 type 为 LoadBalancer，其中的 port 参数为后续负载均衡器所使用的端口。

```
cd ~/download/shinyproxy-config-examples/03-containerized-kubernetes

vi sp-service.yaml

kind: Service
apiVersion: v1
metadata:
  name: shinyproxy
spec:
  type: **LoadBalancer**
  selector:
    run: shinyproxy
  ports:
  - protocol: TCP
**    port****:**** ****80**
    targetPort: 8080
    nodePort: 32094
```

编辑 sp-deployment.yaml 文件，修改其中内容以对应在目前环境中已在 Amazon ECR 镜像仓库中发布的容器名称及标签。注意需根据修改其中的AWS账号为您的账号信息。

```
cd ~/download/shinyproxy-config-examples/03-containerized-kubernetes

vi sp-deployment.yaml 

apiVersion: apps/v1
kind: Deployment
metadata:
  name: shinyproxy
  namespace: default
spec:
  selector:
    matchLabels:
      run: shinyproxy
  replicas: 1
  template:
    metadata:
      labels:
        run: shinyproxy
    spec:
      containers:
      - name: shinyproxy
        image: <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/shinyproxy-application:v1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
      - name: kube-proxy-sidecar
        image: <AWS账号ID>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/kube-proxy-sidecar:v1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8001
      imagePullSecrets:

```

```

## 使用 kubectl 完成部署
kubectl apply -f sp-authorization.yaml
kubectl apply -f sp-deployment.yaml
kubectl apply -f sp-service.yaml

## 后续如对 sp-deployment.yaml 文件进行了修改，可重新Apply得以应用新的内容
kubectl apply -f sp-deployment.yaml

## 可使用下面的命令查看ShinyProxy的部署情况，正常情况下会很快显示 Running 状态
kubectl get pod -n shiny --watch

## 部署过程会自动创建AWS的负载均衡器用于访问 ShinyProxy
## 通过下面的命令可在 EXTERNAL-IP 列获取AWS负载均衡器信息的访问地址链接
## 负载均衡器有一个约几分钟的创建和生效过程，可通过AWS控制台确认负载均衡器状态正常后再进行访问
kubectl get svc

```

访问负载均衡器地址及端口，正常可显示 ShinyProxy 的登录界面。输入之前配置的用户名和密码信息，可显示 ShinyProxy 的管理界面，点击其中已有的 Shiny 应用即可启动它们。至此，ShinyProxy 平台已经成功地运行在 Amazon EKS 服务上。

![ShinyProxy 主界面](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/ShinyProxy-GUI.png)
图片说明：ShinyProxy 主界面

![Shiny 应用的运行界面](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/ShinyProxy-Shiny-GUI.png)
图片说明：Shiny 应用的运行界面


