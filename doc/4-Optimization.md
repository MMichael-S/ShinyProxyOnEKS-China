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
图片说明：EKS Dashboard 管理界面

