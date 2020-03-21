# 基于 Amazon EKS 高效构建企业级 Shiny 平台


文档版本：v0.3

日期：03/21/2020

适用范围：

* **AWS各区域，本文以AWS 宁夏区域为例**
* 建议在AWS中启用一台Linux服务器用作EKS集群管理服务器
* 将自动创建新的VPC用于EKS集群



## Shiny简介

R 是广泛用于统计分析、绘图的开源语言和操作环境，也是用于统计计算和统计制图的优秀工具。[Shiny](https://shiny.rstudio.com/)是由 [Rstudio](https://rstudio.com/) 推出的一个面向 R 软件的产品，可让用户无需编写繁重的代码，即可轻松从 R 直接构建交互式的Web应用程序，并通过 Web 应用的形式通过互联网提供给人们进行访问，使访问者可以轻松地与数据和分析进行交互。
来自全球各地的行业专家、数据科学家及分析师已基于 Shiny 创建了许多功能强大的 Web 应用，如大家近期最为关注的COVID-19病毒疫情，来自 London School of Hygiene & Tropical Medicine 的 Edward Parker 博士使用 Shiny 构建了可多维度了解和分析 COVID-19 疫情数据的在线看板。

![来源：https://shiny.rstudio.com/gallery/covid19-tracker.html](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/shiny-COVID-19.png)


在 Shiny 的开源版本中未提供诸多重要功能，如身份验证、多 Shiny 进程支持、Shiny 应用性能监控、基于 SSL 的安全连接、资源分配控制等。如何实现企业级的安全认证？如何实现秒级的故障恢复？如何实现海量并发用户的访问支撑？ 这些因素均使得用户在构建面向多用户场景的企业生产环境时遇到了极大的障碍。

## ShinyProxy简介

[Open Analytics](https://www.openanalytics.eu/) 在 Shiny 开源版本的基本功能之上开发了 [ShinyProxy](https://www.shinyproxy.io/)，提供了一系列的扩展的增强特性，如身份验证和授权、 TLS 协议支持、Shiny 应用程序容器化及多并发支持等，同时 ShinyProxy 是基于 Apache 许可的100％开源项目。ShinyProxy 前端使用成熟的企业级 Java 框架 [Spring Boot](https://spring.io/projects/spring-boot) 来完成Web应用程序的用户认证、鉴权及后端Shiny应用的调度和管理，后端基于 Docker 技术灵活运行封装了 R 应用的 Shiny 容器。

![ShinyProxy 架构](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/shinyproxy-arch.png)

虽然 ShinyProxy 提供了面向 Shiny 应用的容错机制和高可用设计，但在实际的企业级环境部署时，用户仍然会面临很多不同层面的风险和隐患，均会导致面向用户的 Shiny 平台无法正常提供服务和访问。

* 如遭遇数据中心的网络异常或大并发用户用户访问时的网络拥堵或延迟；
* 如部署服务器软硬件故障、性能瓶颈或维护工作带来的停机；
* 如服务器容器环境配置异常或遭到未预期的损坏；
* 如ShinyProxy自身的配置异常或运行时异常等


![ShinyProxy 的故障风险](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/shinyproxy-risk.png)

基于以上的因素，我们仍然需要为 ShinyProxy 设计一套高可靠、高性能的技术平台及架构，用于支撑 整个平台的良好运行。**在本文中我们将重点介绍如何结合 Amazon EKS 及 AWS 平台上其他成熟服务，快速构建一个拥有高安全性、高可靠性、高弹性且成本优化的高品质 Shiny 平台。**


## EKS 简介

[Kubernetes](https://kubernetes.io/) 是一个用于实现容器化应用程序部署、扩展和自动化管理的开源系统，而 [Amazon Elastic Kubernetes Service](https://aws.amazon.com/cn/eks/) (Amazon EKS) 是一项完全托管的 [Kubernetes](https://aws.amazon.com/kubernetes/) 服务，可让您在 AWS 上轻松运行 Kubernetes，无需您自行支持或维护 Kubernetes 控制层面，因此您可以更专注于应用程序的代码和功能，同时您也可以充分利用社区中开源工具的所有优势。

**Amazon EKS已于2018年6月在全球多个 AWS 区域提供服务，2020年2月28日也已在由光环新网运营的 AWS 中国（北京）区域和由西云数据运营的 AWS 中国（宁夏）区域上线，并于近期与全球AWS区域一致提供最新的 Kubernetes 1.15版本。**

* EKS 跨多个 AWS 可用区运行 Kubernetes 管理基础设施，自动检测和替换运行状况不佳的控制平面节点，并提供零停机时间的按需升级和修补；
* EKS 自动将最新的安全补丁应用到您的集群控制平面，并通过与社区紧密合作以确保在将新版本和补丁部署到现有集群之前解决关键的安全问题；
* EKS 运行上游 Kubernetes且经认证可与 Kubernetes 兼容，因此 EKS 托管的应用程序与所有标准 Kubernetes 环境托管的应用程序完全兼容。

## 一、平台架构及说明

在这个解决方案中，我们会主要用到以下的服务：

* AWS Identity and Access Management（IAM）：用于AWS平台的身份认证及权限管理
* Amazon Elastic Compute Cloud (EC2)：用于EKS管理服务器及EKS中工作节点（[Node](https://kubernetes.io/docs/concepts/architecture/nodes/)） 
* Amazon Elastic Kubernetes Service（EKS）：用于运行ShinyProxy及Shiny应用的容器调度及管理；
* Amazon Elastic Container Registry（ECR）：用于存放ShinyProxy及Shiny容器的镜像仓库；
* Elastic Load Balancing（弹性负载均衡器）：用于接收访问用户的请求并转发给后端的ShinyProxy组件；
* Amazon CloudWatch：用于Amazon EKS服务及EKS中工作节点的监控及日志管理
* Amazon Elastic File System（EFS）：用于存放 Shiny应用所需的持久化共享数据；


![ShinyProxy On EKS架构](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/ShinyOnEKS-Arch.png)

**整个平台的构建过程将主要分为三个步骤：**

* 创建 Amazon EKS 服务
* 部署 ShinyProxy 
* 围绕 Shiny 应用场景的进一步优化配置

在开始 Amazon EKS 服务的创建和部署前，请先参考 **准备工作** 和 **管理机配置** 完成前期的准备工作。


## 二、Amazon EKS 创建

[Amazon EKS 集群](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/clusters.html)包含两个主要部分：Amazon EKS 控制层面 和 Amazon EKS 工作线程节点。Amazon EKS 控制层面由运行 Kubernetes 软件（如 etcd）的控制层面节点和 Kubernetes API 服务器组成。控制层面由 AWS 管理，为给 AWS 用户提供更高的安全性及更好的使用体验，每个 Amazon EKS 集群控制层面都是单租户而且是唯一的，它在其自己的一组 Amazon EC2 实例上运行。

### 2.1 EKS 控制层面创建

用户可以便捷的通过一条 eksctl 指令即完成EKS集群及工作节点的创建，但为了让用户更好的理解 EKS 工作方式，及更好地在独立步骤中自定义 ShinyProxy 运行所需的配置和资源，本文将分成两个阶段进行分别创建，此部分首先完成 EKS 集群控制层面的创建，可参考 [eksctl：Creating a cluster](https://eksctl.io/usage/creating-and-managing-clusters/)。

```
## 全局环境配置
## AWS区域设置，可将此环境设置加入到操作系统用户环境的Profile中实现登录后自动设置
REGION_EKS=cn-northwest-1
export AWS_DEFAULT_REGION=$REGION_EKS

## EKS集群名
EKS_CLUSTER_NAME=EKS-SHINY

## 可自定义EKS集群的Tag标签信息，用于后续的费用跟踪及其他管理（可选项）
TAG="Environment=Alpha-Test,Application=Shiny"

## 以下命令将创建名为 EKS-SHINY、版本为1.15不带任何工作节点组的EKS集群
## 各参数含义可通过 eksctl create cluster --help 查看

eksctl create cluster \
  --name=$EKS_CLUSTER_NAME \
  --version=1.15 \
  --region=$REGION_EKS \
  --tags $TAG \
  --without-nodegroup \
  --asg-access \
  --full-ecr-access \
  --alb-ingress-access

## 集群配置通常需要10到15分钟，此过程将自动创建所需的 VPC/安全组/ IAM角色/ EKS API 服务等诸多资源

## 集群访问测试,正常会显示集群的 CLUSTER-IP 等信息
kubectl get svc --watch

## 如需删除创建的EKS集群，可使用下面的命令
## eksctl delete cluster --name=$EKS_CLUSTER_NAME --region=$REGION_EKS
```

管理服务器终端将显示创建过程

![终端显示 EKS 创建过程](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/EKS-Create.png)

eksctl 将通过 AWS Cloudformation 服务完成 EKS 集群创建，也可在控制台 Cloudformation 服务中查看创建过程，以及在出现异常时查看和分析 Cloudformation 中的事件了解详细的错误原因。

![Cloudformation 显示 EKS 创建过程](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/EKS-Create-Console.png)

### 2.2 节点组创建

Kubernetes 中的工作线程计算机称为“节点”，Amazon EKS 工作节点通过集群 API 服务器终端节点连接到集群的控制层面。节点组是在 Amazon EC2 自动伸缩组（Auto Scaling Group） 中部署的一个或多个 Amazon EC2 实例，EC2 实例也将是真正运行ShinyProxy及Shiny应用的环境。每个节点组必须使用相同的实例类型，但一个 EKS 集群可以包含多个节点组，所以您可根据应用场景选择创建多个不同的节点组来支持不同的节点类型。

下面我们将通过使用 eksctl 及[参数文件](https://eksctl.io/usage/schema/)的方式创建 EKS 中的节点组，使用参数文件可便于以后修改及多次复用。

如果希望后续可以通过SSH登录到EKS 工作节点，需要配置其中的 ssh 节及参数 publicKeyName ，可以使用跟之前创建的管理机 EC2 相同的密钥对，也可以新建新的密钥对分配给 EKS 节点使用。

```
mkdir -p ~/download
cd ~/download

## 相关参数可参考：https://eksctl.io/usage/schema/
## 以下命令将创建一个名为 EKS-Shiny-NodeGroup 的节点组，包含2个 m5.xlarge 类型EC2的节点，存储空间为30GB
## 部分参数可根据实际需求进行修改，如EC2实例类型、数量、EBS卷大小等
## 可在参数文件中根据需要添加 节点标签（labels）、启动时自动执行的脚本、以及附加的Policy
## 添加Policy时必须包括默认的 AmazonEKSWorkerNodePolicy 及 AmazonEKS_CNI_Policy

## 节点组名称
NODE_GROUP_NAME="EKS-Shiny-NodeGroup"

## 编辑NodeGroup配置文件，文件名可自定义
vi EKS-Shiny-NodeGroup.yaml

apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: EKS-SHINY
  region: cn-northwest-1

nodeGroups:
  - name: EKS-Shiny-NodeGroup
    instanceType: m5.xlarge
    minSize: 1
    maxSize: 10
    desiredCapacity: 2
    volumeSize: 30
    ssh:
      allow: true
      publicKeyName: # EC2密钥对
    labels: {role: worker, NodeSize: m5.xlarge}
    tags:
      {
      "Environment": "Alpha-Test",
      "Application": "ShinyProxy"
      }
    iam:
      attachPolicyARNs:
        - arn:aws-cn:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws-cn:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws-cn:iam::aws:policy/AmazonS3FullAccess
      withAddonPolicies:
        albIngress: true
        autoScaler: true
        cloudWatch: true
        ebs: true
        efs: true


## 创建NodeGroup
eksctl create nodegroup --config-file=./EKS-Shiny-NodeGroup.yaml

## 在某些异常的情况下，如需删除之前失败的NodeGroup可执行下面的命令
## eksctl delete nodegroup --config-file=./EKS-Shiny-NodeGroup.yaml --approve

## 查看目前节点组信息，确认各节点状态显示为“Ready”
kubectl get node --wide --watch

```



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
![Shiny 应用的运行界面](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/ShinyProxy-Shiny-GUI.png)

## 四、特性及优化

### 4.1 灵活控制Shiny应用启动的节点

在实际的应用场景中，常常有这样的需求，希望某些 Shiny 应用能够运行在指定的节点上，比如选择某种指定配置的 EC2 服务。
我们可以通过 ShinyProxy 提供的参数配置及 Kubernetes 所提供的“节点选择”功能实现。


```
## 使用上面介绍的节点组创建的方法，启动不同配置的EC2节点组，如下例中的 NG-UNMANAGED-C5-x 和 NG-UNMANAGED-C5-2x，分别代表节点组使用的EC2类型
## 给不同配置的节点组通过 kubectl label 增加自定义的节点标签，如节点所使用的EC2类型/配置等，启用标签后新启动的节点也会自动增加此标签

kubectl label nodes -l alpha.eksctl.io/nodegroup-name=NG-UNMANAGED-C5-x NodeSize=c5.xlarge
kubectl label nodes -l alpha.eksctl.io/nodegroup-name=NG-UNMANAGED-C5-2x NodeSize=c5.2xlarge

## 也可在创建节点组时，在参数文件中增加相应的label来进行标记，如：
    labels: {role: worker, NodeSize: c5.xlarge}

## 修改ShinyProxy配置文件application.yml中 kubernetes 节的配置
## 增加 node-selector 配置，与上述步骤中所做的标签一致即可（Key=Value形式） 

  kubernetes:
    internal-networking: true
    url: http://localhost:8001
    namespace: shiny
    image-pull-policy: IfNotPresent
    image-pull-secret:
    node-selector: NodeSize=m5.xlarge

```

### 4.2 为 Shiny 应用提供可共享存储

在多用户的 Shiny 应用环境中，经常会遇到多个 Shiny 容器甚至多个节点需要共享使用同一存储的场景，在本地数据中心经常会使用可共享的 NAS 存储基于 NFS 协议来满足需求。在AWS 平台中我们可以使用 [EFS服务](https://aws.amazon.com/cn/efs/) 实现。EFS服务可提供简单、可扩展、完全托管的弹性 NFS 文件系统，并可与 AWS 其他云服务配合使用。
对于[在 EKS 中将 EFS 作为持久存储使用](https://aws.amazon.com/cn/premiumsupport/knowledge-center/eks-persistent-storage/)， EKS 提供了[多种方式](https://github.com/kubernetes-incubator/external-storage/tree/master/aws/efs)，如可在 Pod 及 deployment 中通过Container Storage Interface (CSI) 驱动程序使用。但目前由 ShinyProxy 启动的容器并不支持在Pod或者Deployment使用此方式，我们需要在[ShinyProxy配置](https://www.shinyproxy.io/configuration/)中通过 container-volumes 参数，让Shiny容器在所运行的节点上能够通过mount的方式使用EFS存储。
可通过下面的方式实现，我们将[在EKS的节点启动时完成 EFS 在EKS节点上的挂载](https://github.com/weaveworks/eksctl/blob/master/examples/05-advanced-nodegroups.yaml)，并通过 ShinyProxy的配置来完成后续Shiry容器启动时的路径映射及使用。

首先参照文档在EKS集群所处的AWS区域中[创建EFS存储](https://docs.aws.amazon.com/zh_cn/efs/latest/ug/creating-using.html)，并完成[安全组及挂载点设置](https://docs.aws.amazon.com/zh_cn/efs/latest/ug/mounting-fs.html)，记录下创建成功后的EFS 文件系统 ID。

```
## 为使节点能够挂载 EFS存储，我们将在节点组创建过程的配置文件的“preBootstrapCommands”配置节中添加三条命令，完成EFS在节点启动过程中的自动挂载
## 注意修改第二条指令中的 EFS服务ID
preBootstrapCommands:
      - 'sudo mkdir -p /mnt/data/'
      - 'sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport EFS文件系统ID.efs.cn-northwest-1.amazonaws.com.cn:/ /mnt/data/'
      - 'sudo chmod -R 777 /mnt/data'

```

```
## 在 ShinyProxy 的 application.yml 配置文件中为对应的Shiny容器启用自动挂载
## 注意 container-volumes 中路径的一致性

container-volumes: ["/mnt/data:/root/Shiny_seurat/Users/data"]

```

### 4.3 面向实时负载的自动伸缩功能

在Amazon EKS 集群中提供了多种自动扩展的特性及配置方式，可支持多种类型的 Kubernetes 自动扩展，如节点数量的扩展（Cluster Autoscaler）、Pod数量的横向扩展（Horizontal Pod Autoscaler）及 Pod配置的纵向扩展（Vertical Pod Autoscaler）。
 结合ShinyProxy的特征，我们可以通过在Amazon EKS目前的集群上增加 Cluster Autoscaler 功能，从而实现EKS可根据用户并发访问数量、运行的Shiny应用数量、Shiny应用的资源需求等多种因素实现一个弹性、灵动且高性价比的集群平台。其他自动伸缩功能也可根据需求参考[文档](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/autoscaling.html)自行配置。限于篇幅关系，您可以参考[EKS Cluster Autoscaler](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/cluster-autoscaler.html)进行相应的配置和测试。
另外，在配置完成后，也可根据需要随时通过 eksctl 管理EKS中每个节点组的数量。

```
## 如将原节点数量从2调整为3
eksctl scale nodegroup  --cluster EKS集群名 --name 节点组名 --region=cn-northwest-1 —nodes 3

```

### 4.4 提供更高的认证鉴权特性

在前面的测试部署中，Shinyproxy的配置使用了Simple认证模式，用户名及密码均为明文写入配置文件，有极大的安全隐患，同时也很难在多用户环境中进行维护和扩展。其实ShinyProxy 提供了多种用户认证模式的支持，包括 LDAP、Kerberos、Keycloak、OpenID Connect、Social Authentication、Web Service Based Authentication等多种模式。建议在生产环境中能够根据情况选择更高安全性的用户认证和鉴权方式进行完善。
[AWS Directory Service](https://docs.aws.amazon.com/zh_cn/directoryservice/latest/admin-guide/what_is.html) 也是用户一个很好的企业级选择。AWS Directory Service 提供了多种方式来将 Amazon Cloud Directory 和 Microsoft Active Directory (AD) 与其他 AWS 服务结合使用。也可通过 AWS提供的 [Active Directory Connector](https://docs.aws.amazon.com/zh_cn/directoryservice/latest/admin-guide/directory_ad_connector.html)
将目录请求重定向到本地已有的 Microsoft Active Directory，而无需在云中缓存任何信息。 在AD目录中可以存储ShinyProxy 有关用户、组等信息。在ShinyProxy 配置中使用对应的LDAP配置节即可完成相应的配置。

```
proxy:
  ldap:
    url: ldap://ldap.xxxxx.com:389/dc=example,dc=com
    ...
```

### 4.5 使用AWS 应用负载均衡器提高平台高可用能力

AWS弹性负载均衡器（Elastic Load Balancing） 支持三种类型的负载均衡器：Application Load Balancer、Network Load Balancer及Classic Load Balancer。 在之前的测试部署中，我们使用AWS Classic 负载均衡器进行了部署。AWS Classic 负载均衡器为AWS早期的负载均衡器服务，将逐渐被新的AWS 应用负载均衡器或网络负载均衡器服务替代，新服务提供更好的应用特性及性能。
同时使用应用负载均衡器，可以通过设置使ShinyProxy的Pod支持多副本的高可用部署，进一步提高平台的高可用特性及大幅缩短异常发生时的恢复时间。

您可以参考 [Amazon EKS 上的 ALB 入口控制器](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/alb-ingress.html) 使用AWS 应用负载均衡器进行ShinyProxy的部署。
针对ShinyProxy的配置过程需做下面的修改。

```
## 编辑 sp-service.yaml 文件，修改为以下内容

kind: Service
apiVersion: v1
metadata:
  name: shinyproxy
  namespace: default
spec:
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  type: NodePort
  selector:
    run: shinyproxy
```

```
## 新建 sp-shinyingress.yaml 文件，内容如下：
## 设置ALB健康检查的路径为 /login
## 修改ALB目标组的类型为IP（默认为Instance），
## ALB将直接作用于Pod，设置粘性会话支持后，可支持ShinyProxy Replica >= 2的高可用部署
## ALB的Annotations可用于修改ALB负载均衡器属性，可参考[相关文档](https://docs.aws.amazon.com/zh_cn/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-type) 

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: "shinyproxy-ingress"
  namespace: "default"
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=3600
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=1800
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-path: /login
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '20'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/target-type: ip

  labels:
    run: shinyproxy
spec:
  rules:
    - http:
        paths:
          - path: /*
            backend:
              serviceName: "shinyproxy"
              servicePort: 80
```

### 4.6 使用Spot实例大幅节省成本

AWS 提供了丰富的EC2使用和付费模式，通过在 EKS 中使用 Amazon EC2 Spot 实例，可以让您利用 AWS 云中未使用的 EC2 容量，与按需实例的价格相比，使用 Spot 实例最高可以享受 90% 的折扣，从而大幅的降低平台运营成本。
Spot 实例适合用于各种无状态、容错或者灵活的应用程序，在Shiny平台的测试阶段，或在适当的生产场景中，如果您接受节点因为中断而带来的短暂异常状态，则可通过下面的方式在节点组中启用 EC2 Spot 实例。详情可参见 [文档](https://aws.amazon.com/cn/blogs/compute/run-your-kubernetes-workloads-on-amazon-ec2-spot-instances-with-amazon-eks/) 及 [eksctl的对应配置方式](https://eksctl.io/usage/spot-instances/)。

```
## 在节点组的配置文件中，添加下面的内容。可根据需要自定义EC2类型及相应的数量。
    instancesDistribution:
      maxPrice: 1
      instanceTypes: ["c5.xlarge"]
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 2

```

### 4.7 构建完备的运维和监控体系

Amazon EKS 提供了AWS原生的完备的监控和运维体系，另外也与开源生态中主流的 Kubernetes 管理工具、监控工具等良好集成， 可参考 **常用的运维和监控方式** 进行部署，构建完备的 Amazon EKS 及 Shiny 平台的运维体系。其他如 Kubernetes Metrics Server、Prometheus、Grafana等的部署，可参见：[Prometheus 的控制层面指标](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/prometheus.html)、[安装 Kubernetes Metrics Server](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/metrics-server.html)。

![EKS Dashboard](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/dashboard.png)

<center>图片说明：EKS Dashboard 管理界面</center>

## 方案小结

经过上面的部署，我们验证了 ShinyProxy 及 Shiny 应用在 Amazon EKS 平台良好运行的可行性。同时，我们可以结合 AWS 的其他成熟服务，围绕着安全性、可靠性、灵活性、成本优化等多个方面进行了深度优化，从而可以为您及您的客户提供高品质的 Shiny 平台。 希望您早日在 AWS 上构建属于您自己的 Shiny 平台，如果在部署和使用中遇到问题，也欢迎您及时与我们联系，AWS 架构师团队将非常乐意协助您解决技术问题并提供更多的优化建议。


## 主要参考资料：

### Shiny

https://shiny.rstudio.com/

### ShinyProxy

https://www.shinyproxy.io/

### Amazon Elastic Kubernetes Service

https://aws.amazon.com/cn/eks/

### Amazon Elastic Container Registry

https://aws.amazon.com/cn/ecr/

### eksctl

https://eksctl.io/


