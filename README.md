# 基于 Amazon EKS 高效构建企业级 Shiny 平台


文档版本：v0.3

日期：03/21/2020

适用范围：

* **AWS各区域，本文以AWS 宁夏区域为例**
* 建议在AWS中启用一台Linux服务器用作EKS集群管理服务器
* 将自动创建新的VPC用于EKS集群
* Amazon EKS 1.15 / eksctl 0.15.0 / kubectl v1.15.10-eks-bac369 / AWS CLI aws-cli/1.18.21



## Shiny简介

R 是广泛用于统计分析、绘图的开源语言和操作环境，也是用于统计计算和统计制图的优秀工具。[Shiny](https://shiny.rstudio.com/)是由 [Rstudio](https://rstudio.com/) 推出的一个面向 R 软件的产品，可让用户无需编写繁重的代码，即可轻松从 R 直接构建交互式的Web应用程序，并通过 Web 应用的形式通过互联网提供给人们进行访问，使访问者可以轻松地与数据和分析进行交互。
来自全球各地的行业专家、数据科学家及分析师已基于 Shiny 创建了许多功能强大的 Web 应用，如大家近期最为关注的COVID-19病毒疫情，来自 London School of Hygiene & Tropical Medicine 的 Edward Parker 博士使用 Shiny 构建了可多维度了解和分析 COVID-19 疫情数据的在线看板。

![来源：https://shiny.rstudio.com/gallery/covid19-tracker.html](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/shiny-COVID-19.png)
来源：https://shiny.rstudio.com/gallery/covid19-tracker.html

在 Shiny 的开源版本中未提供诸多重要功能，如身份验证、多 Shiny 进程支持、Shiny 应用性能监控、基于 SSL 的安全连接、资源分配控制等。如何实现企业级的安全认证？如何实现秒级的故障恢复？如何实现海量并发用户的访问支撑？ 这些因素均使得用户在构建面向多用户场景的企业生产环境时遇到了极大的障碍。

## ShinyProxy简介

[Open Analytics](https://www.openanalytics.eu/) 在 Shiny 开源版本的基本功能之上开发了 [ShinyProxy](https://www.shinyproxy.io/)，提供了一系列的扩展的增强特性，如身份验证和授权、 TLS 协议支持、Shiny 应用程序容器化及多并发支持等，同时 ShinyProxy 是基于 Apache 许可的100％开源项目。ShinyProxy 前端使用成熟的企业级 Java 框架 [Spring Boot](https://spring.io/projects/spring-boot) 来完成Web应用程序的用户认证、鉴权及后端Shiny应用的调度和管理，后端基于 Docker 技术灵活运行封装了 R 应用的 Shiny 容器。

![ShinyProxy 架构](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/shinyproxy-arch.png)
图片说明：ShinyProxy 架构

虽然 ShinyProxy 提供了面向 Shiny 应用的容错机制和高可用设计，但在实际的企业级环境部署时，用户仍然会面临很多不同层面的风险和隐患，均会导致面向用户的 Shiny 平台无法正常提供服务和访问。

* 如遭遇数据中心的网络异常或大并发用户用户访问时的网络拥堵或延迟；
* 如部署服务器软硬件故障、性能瓶颈或维护工作带来的停机；
* 如服务器容器环境配置异常或遭到未预期的损坏；
* 如ShinyProxy自身的配置异常或运行时异常等


![ShinyProxy 的故障风险](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/shinyproxy-risk.png)
图片说明：ShinyProxy 的故障风险

基于以上的因素，我们仍然需要为 ShinyProxy 设计一套高可靠、高性能的技术平台及架构，用于支撑 整个平台的良好运行。**在本文中我们将重点介绍如何结合 Amazon EKS 及 AWS 平台上其他成熟服务，快速构建一个拥有高安全性、高可靠性、高弹性且成本优化的高品质 Shiny 平台。**


## EKS 简介

[Kubernetes](https://kubernetes.io/) 是一个用于实现容器化应用程序部署、扩展和自动化管理的开源系统，而 [Amazon Elastic Kubernetes Service](https://aws.amazon.com/cn/eks/) (Amazon EKS) 是一项完全托管的 [Kubernetes](https://aws.amazon.com/kubernetes/) 服务，可让您在 AWS 上轻松运行 Kubernetes，无需您自行支持或维护 Kubernetes 控制层面，因此您可以更专注于应用程序的代码和功能，同时您也可以充分利用社区中开源工具的所有优势。

**Amazon EKS已于2018年6月在全球多个 AWS 区域提供服务，2020年2月28日也已在由光环新网运营的 AWS 中国（北京）区域和由西云数据运营的 AWS 中国（宁夏）区域上线，并于近期与全球AWS区域一致提供最新的 Kubernetes 1.15版本。**

* EKS 跨多个 AWS 可用区运行 Kubernetes 管理基础设施，自动检测和替换运行状况不佳的控制平面节点，并提供零停机时间的按需升级和修补；
* EKS 自动将最新的安全补丁应用到您的集群控制平面，并通过与社区紧密合作以确保在将新版本和补丁部署到现有集群之前解决关键的安全问题；
* EKS 运行上游 Kubernetes且经认证可与 Kubernetes 兼容，因此 EKS 托管的应用程序与所有标准 Kubernetes 环境托管的应用程序完全兼容。

## [一、平台架构及说明](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/doc/1-Architecture.md)



## [二、Amazon EKS 创建](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/doc/2-EKS-Create.md)



## [三、ShinyProxy 部署](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/doc/3-ShinyProxy-Deploy.md)



## [四、特性及优化](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/doc/4-Optimization.md)


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


## License

This library is licensed under the MIT-0 License. See the LICENSE file.

