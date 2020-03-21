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
图片说明：终端显示 EKS 创建过程

eksctl 将通过 AWS Cloudformation 服务完成 EKS 集群创建，也可在控制台 Cloudformation 服务中查看创建过程，以及在出现异常时查看和分析 Cloudformation 中的事件了解详细的错误原因。

![Cloudformation 显示 EKS 创建过程](https://github.com/MMichael-S/ShinyProxyOnEKS-China/blob/master/img/EKS-Create-Console.png)
图片说明：Cloudformation 显示 EKS 创建过程

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


## License

This library is licensed under the MIT-0 License. See the LICENSE file.

