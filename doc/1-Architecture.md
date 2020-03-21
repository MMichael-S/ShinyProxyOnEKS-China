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
图片说明：ShinyProxy On EKS 架构

**整个平台的构建过程将主要分为三个步骤：**

* 创建 Amazon EKS 服务
* 部署 ShinyProxy 
* 围绕 Shiny 应用场景的进一步优化配置

在开始 Amazon EKS 服务的创建和部署前，请先参考 **[准备工作](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/doc/I-Preparation.md)** 和 **[管理机配置](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/doc/II-ManagementServer.md)** 完成前期的准备工作。
