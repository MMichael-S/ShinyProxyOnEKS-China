hinyProxy on AWS EKS部署指南


文档版本：v0.3
日期：02/29/2020
适用范围：

* **AWS海外区域，本文以AWS香港区域为例**
* 本地设备以Mac笔记本或运行Linux操作系统的设备为例
* 创建新的VPC用于EKS集群

## 组件简介：

### Shiny:

Shiny is an R package that makes it easy to build interactive web applications (apps) straight from R. 
https://shiny.rstudio.com/

### Shinyproxy

ShinyProxy is your favourite way to **deploy Shiny apps in an enterprise context**. It has built-in functionality for LDAP authentication and authorization, makes securing Shiny traffic (over TLS) a breeze and has no limits on concurrent usage of a Shiny app.
https://www.shinyproxy.io/
https://github.com/openanalytics/shinyproxy

### AWS EKS

Amazon Elastic Kubernetes Service (Amazon EKS) 是一项完全托管的 [Kubernetes](https://aws.amazon.com/kubernetes/) 服务。可让您在 AWS 上轻松运行 Kubernetes，而无需支持或维护您自己的 Kubernetes 控制层面。Kubernetes 是一个用于实现容器化应用程序的部署、扩展和管理的自动化的开源系统。 
https://aws.amazon.com/cn/eks/


## 一、管理机创建

*** 如果已经在AWS海外区域有启动的EC2，此步骤可忽略***
*** 在已启动的EC2完成环境设置及软件部署 ***

通过AWS图形Console启动一台普通EC2实例作为管理机
可参考
**https://aws.amazon.com/cn/getting-started/tutorials/launch-a-virtual-machine/?trk=gs_card&e=gs&p=gsrc**

如希望通过快速启动模版进行堡垒机部署
可参考《AWS 云上的 Linux 防御主机：快速入门参考部署》
https://docs.aws.amazon.com/zh_cn/quickstart/latest/linux-bastion/welcome.html

如希望启动AWS Cloud9实例来进行后续部署
可参考《在 AWS Cloud9 中创建环境》
https://docs.aws.amazon.com/zh_cn/cloud9/latest/user-guide/create-environment-main.html

**下面过程将使用 AWS CLI命令行工具完成管理机的启动**

### 1.1 创建IAM User

可参考：
创建您的第一个 IAM 管理员用户和组
https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/getting-started_create-admin-group.html

### 1.2 获取IAM User的访问密钥

可参考：
管理访问密钥（控制台）
https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey

*** 注意：请妥善保存好访问密钥信息 ***

### 1.3 AWSCLI 安装（本地）

可参考：
AWS CLI安装
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/install-linux.html

### 1.4 AWSCLI 设置（本地）

可参考：
AWS CLI 基础使用指南：
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/cli-services-ec2-instances.html


```
## 在本地安装AWSCLI，并配置香港区域Profile
## 使用的IAM User应具有管理员策略 ———— AdministratorAccess

aws configure --profile hkg

AWS Access Key ID [None]: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ## AccessKey
AWS Secret Access Key [None]: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ## SecretKey
Default region name [None]: ap-east-1 ## 香港区域代码
Default output format [None]: json  ## 输出显示格式

## 测试配置是否正确
## 正常会显示当前账号下存储桶信息或无报错的空信息
aws s3 ls --region ap-east-1 --profile hkg

```

```
## 全局环境配置
## 也可将下述设置加入到本地用户环境的Profile中实现自动设置

REGION_EKS=ap-east-1

export AWS_DEFAULT_REGION=$REGION_EKS
export AWS_DEFAULT_OUTPUT=json
export AWS_DEFAULT_PROFILE=hkg
```



### 1.5 创建EC2 密钥对

可参考：
https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/ec2-key-pairs.html

```
## 如已有对应区域的密钥对，此步骤可忽略
## 创建密钥对（用于管理机及后续的EKS集群节点）
## 密钥对名称
KEYPAIR_NAME=hkg-key

## aws ec2 delete-key-pair --key-name $KEYPAIR_NAME
## 创建密钥对并将密钥文件保存到当前目录下，后缀名以.pem结尾
aws ec2 create-key-pair --key-name $KEYPAIR_NAME | jq -r '.KeyMaterial'> $KEYPAIR_NAME.pem

## 修改密钥对权限
chmod 600 $KEYPAIR_NAME.pem
```




### 1.6 启动EC2管理机

本文以Ubuntu 16.04镜像作为管理机操作系统操作系统
镜像将使用Ubuntu 16.04 AMI， AMI ID为ami-9f793dee。可通过AWS控制台查看此AMI的详细信息。
[Image: image.png]使用AWS命令行方式启动管理机的步骤如下：

```
`## 通过Console查看当前可用的VPC ID，及VPC中公有子网 Subnet ID`
`## 以上信息将用于确定管理机启动所依赖的VPC和子网`
## 设置相应的环境变量

`REGION_EKS``=``ap``-``east``-``1`
`export`` AWS_DEFAULT_REGION``=``$REGION_EKS`
`VPC_ID``=``vpc``-``e948a880`
`PUBLIC_SUBNET_ID``=``subnet``-``747f9f1d`

## 创建管理机安全组，安全组名称为sg_eks_bastion
EKS_BASTION_SG=sg_eks_bastion
`EKS_BASTION_SG_ID``=``$``(``aws ec2 create``-``security``-``group`` ``--``vpc``-``id $VPC_ID ``--``group``-``name $EKS_BASTION_SG ``--``description ``"Bastion for EKS"``|``jq ``-``r ``'.GroupId'``)`
`echo $EKS_BASTION_SG_ID`

## 创建安全组中针对SSH访问的22端口访问许可
`aws ec2 authorize``-``security``-``group``-``ingress ``--``group``-``id $EKS_BASTION_SG_ID ``--``protocol tcp ``--``port ``22`` ``--``cidr ``0.0``.``0.0``/``0`` 
`
## 如有其他端口开放要求，可参照以下例子添加
## 为了EC2安全，只开放确定需要开放的端口，切记开放所有端口
`## aws ec2 authorize-security-group-ingress --group-id $EKS_BASTION_SG_ID --protocol tcp --port "8000-9999" --cidr 0.0.0.0/0`

## `管理机配置`
##    AMI：`Ubuntu 16.04 AMI：ami-9f793dee`
##    `EC2实例类型：c5.large (2vCPU/4GB)`
`##    根卷 20GB
##    子网：公有子网`

`BASTION_INSTANCE_ID``=``$``(``aws ec2 run``-``instances ``--``image``-``id ami``-``9f793dee`` \`
`    ``--``security``-``group``-``ids $EKS_BASTION_SG_ID \`
`    ``--``key``-``name $KEYPAIR_NAME \`
`    ``--``block``-``device``-``mappings ``"[{\"DeviceName\": \"/dev/sda1\",\"Ebs\":{\"VolumeSize\":20,\"VolumeType\":\"gp2\"}}]"`` \`
`    ``--``instance``-``type c5``.``large \`
`    ``--``count ``1`` \`
`    ``--``subnet``-``id $PUBLIC_SUBNET_ID \`
`    ``--``associate``-``public``-``ip``-``address \`
`    ``--``tag``-``specifications ``"ResourceType="``instance``",Tags=[{Key="``Name``",Value="``EKS_BASTION``"}]"`` \`
`    ``--``region $REGION_EKS \`
`    ``|`` jq ``-``r ``'.Instances[0].InstanceId'``)`

## `申请弹性IP，并与EC2绑定
`## 弹性IP可保证管理机实例在停止和重新启动后拥有不变的公网IP地址
`export`` BASTION_EIP``=``$``(``aws ec2 allocate``-``address ``--``region $REGION_EKS ``|`` jq ``-``r ``'.PublicIp'``)`
`aws ec2 associate``-``address ``--``instance``-``id $BASTION_INSTANCE_ID ``--``public``-``ip $BASTION_EIP ``--``region $REGION_EKS`


```



## 二、管理机配置

### 2.1 创建IAM角色，并附加到管理机

可参考：
https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html

* 创建具有管理员权限（**AdministratorAccess**）的EC2 Role
* 将 IAM 角色附加到实例

### 2.2 AWSCLI配置（管理机）

*** 部分AWS镜像中已经预装了AWS CLI命令行工具，则此步骤可忽略***

可参考：
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/install-linux.html
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/cli-services-ec2-instances.html

```
## 登录启动的管理机
ssh -i "hkg-key.pem" ubuntu@$BASTION_EIP

## 系统更新
sudo apt update -y
sudo apt upgrade -y

## 如更新后提示需要重新启动完成重新启动
sudo reboot

## 确认Python版本为3.4以上 
python3 --version

## 安装pip
sudo apt install python3-pip -y

## 安装awscli
`pip3 install awscli ``--``upgrade ``--``user`

`## 查看awscli版本`
`aws ``--``version`
`## aws-cli/1.18.6 Python/3.5.2 Linux/4.4.0-1102-aws botocore/1.15.6`

`## 测试AWS CLI配置是否正确`
`## 正常会显示当前账号下存储桶信息或无报错空信息
REGION_EKS=ap-east-1
export AWS_DEFAULT_REGION=$REGION_EKS`
`aws s3 ls`

```



### 2.3 Docker部署

*** 部分AWS镜像中已经预装了Docker组件，但仍建议通过以下步骤完成Docker新版本的安装***

可参考：
https://docs.docker.com/install/linux/docker-ce/ubuntu/

```
## Docker安装

sudo apt-get remove docker docker-engine docker.io containerd runc -y
sudo apt autoremove -y

sudo apt-get update -y

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update -y

sudo apt-get install docker-ce docker-ce-cli containerd.io -y

## 查看当前Docker CE有效版本
sudo apt-cache madison docker-ce

## 简单测试
## 正常会显示 “Hello from Docker!” 字样
sudo docker run hello-world

## 授权Ubuntu用户拥有Docker的操作权限
## 需注销并重新登录后权限生效
sudo usermod -aG docker $USER

## 查看Docker信息
## 可关注其中的版本信息，如“Server Version: 19.03.6”
docker info

```



### 2.4 eksctl部署

eksctl是用于在 Amazon EKS 上创建和管理 Kubernetes 集群的简单命令行实用程序。eksctl 命令行实用程序提供了创建和管理 Amazon EKS 集群的最快、最简单的方式。
有关更多信息以及查看官方文档，可参考：
eksctl 入门
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/eksctl.html
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/getting-started-eksctl.html

eksctl - The official CLI for Amazon EKS
https://eksctl.io/


```
## 创建当前用户根目录下名为download的目录
## 此目录将用于后续文件下载等目的，也可根据需要更改为其他目录名
mkdir -p ~/download
cd ~/download

## 查看eksctl latest版本：https://github.com/weaveworks/eksctl/releases
## 下载eksctl latest最新稳定版本
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/eksctllatest

## 查看当前版本
eksctl version
## 0.14.0

## 特殊情况下，也可指定具体eksctl版本下载
## eksctl 0.15.0版本将支持中国区域EKS，目前已有非正式版本 0.15.0-rc.0可用

curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/0.15.0-rc.0/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/eksctl15rc
eksctl15rc version
## 0.15.0-rc.0

```

### 2.5 kubectl部署

Kubectl 是一个命令行接口，用于对 Kubernetes 集群运行命令。

可参考：
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/install-kubectl.html
https://kubernetes.io/zh/docs/reference/kubectl/overview/

```
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
Client Version: v1.14.7-eks-1861c5
Server Version: v1.14.9-eks-502bfb

```



## 三、EKS控制层面创建

一个 Amazon EKS 集群包含两个主要组件：

* Amazon EKS 控制层面
* 向控制层面注册的 Amazon EKS 工作线程节点


*** 本文将分成两个阶段进行分别创建，以便更好的自定义所需的配置和资源。***

可参考：
什么是 Amazon EKS
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/what-is-eks.html

Amazon EKS 集群
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/clusters.html

eksctl：Creating a cluster
https://eksctl.io/usage/creating-and-managing-clusters/


```
## EKS集群名
EKS_CLUSTER_NAME=EKS-HKG
## AWS区域
REGION_EKS=ap-east-1
## 节点组名称
NODE_GROUP_NAME="NG-UNMANAGED-C5-4x"
## 可自定义Tag标签信息，用于后续的费用跟踪及其他管理（可选项）
TAG="Environment=Alpha-Test,Application=Shiny"
## 配置文件方式，可参考：
## https://github.com/weaveworks/eksctl/blob/master/examples/02-custom-vpc-cidr-no-nodes.yaml


eksctl create cluster \
  --name=$EKS_CLUSTER_NAME \
  --region=$REGION_EKS \
  --tags $TAG \
  --without-nodegroup \
  --asg-access \
  --full-ecr-access \
  --appmesh-access \
  --alb-ingress-access

## 附加选项的说明，增加下列选项在EKS集群创建中将自动创建相关的IAM策略
/*
Cluster and nodegroup add-ons flags:
      --asg-access            enable IAM policy for cluster-autoscaler
      --external-dns-access   enable IAM policy for external-dns
      --full-ecr-access       enable full access to ECR
      --appmesh-access        enable full access to AppMesh
      --alb-ingress-access    enable full access for alb-ingress-controller
*/


## 如需删除创建的EKS集群，可使用下面的命令
## eksctl delete cluster --name=$EKS_CLUSTER_NAME --region=$REGION_EKS

## 集群配置通常需要 10 到 15 分钟
## 集群将自动创建所需的VPC/安全组/IAM 角色/EKS API服务等资源

## 集群访问测试
watch -n 2 kubectl get svc

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.100.0.1   <none>        443/TCP   11m


```

终端将显示创建过程
[Image: image.png]
eksctl将通过AWS Cloudformation服务完成集群创建，可在控制台Cloudformation服务中查看创建过程
[Image: image.png]

## 四、EKS节点组创建



### 4.1 EFS存储创建

在 多用户的Shiny 应用环境中经常会使用到可多个Shiny容器甚至多个节点需要共享使用同一存储的场景，在本地数据中心经常会使用可共享的NAS存储基于NFS协议来满足需求。
在AWS 平台中我们可以使用EFS服务。EFS服务可提供简单、可扩展、完全托管的弹性 NFS 文件系统，并可与 AWS 其他云服务配合使用。
参考：
https://aws.amazon.com/cn/efs/


```
## 对于将 EFS 作为持久存储，Kubernetes 及 EKS 提供了多种方式，可在 Pod 及 deployment 中使用
## 可参考：
## https://github.com/kubernetes-incubator/external-storage/tree/master/aws/efs
## https://aws.amazon.com/cn/premiumsupport/knowledge-center/eks-persistent-storage/
## 但目前由 ShinyProxy 启动的容器并不支持在Pod或者Deployment使用此方式，只能在其配置中通过 container-volumes 参数让Shiny容器mount所处节点上的“本地”路径
## 参考 https://www.shinyproxy.io/configuration/
## container-volumes: list of docker volumes to mount into the container; can be specified along
## container-volumes: [ "/host/path1:/container/path1", "/host/path2:/container/path2" ]

```

为解决此冲突，目前可通过下面的方式实现。我们将在EKS的节点启动时完成 EFS 在EKS节点上的挂载，并通过 ShinyProxy的配置来完成后续Shiry容器启动时的路径映射及使用。
参考：
https://github.com/weaveworks/eksctl/blob/master/examples/05-advanced-nodegroups.yaml

参照下面的文档创建在EKS集群所处的AWS区域创建EFS存储，并完成安全组及挂载点设置。
记录下创建成功后的EFS集群ID。

```
## EFS 使用参考
## 为 Amazon EFS 创建资源
https://docs.aws.amazon.com/zh_cn/efs/latest/ug/creating-using.html
https://docs.aws.amazon.com/zh_cn/efs/latest/ug/mounting-fs.html

## 为使节点能够挂载 EFS存储，需要执行下面的命令。
## 我们将在节点组创建的配置文件中完成此三条命令在节点启动过程中的自动执行
## 并在 ShinyProxy 的 application.yml 配置文件中为对应的Shiny容器启用挂载
## 如 container-volumes: ["/mnt/data_zs/#{proxy.userId}:/root/Shiny_seurat/Users/#{proxy.userId}"]
## 注意 container-volumes 中路径的一致性

## sudo mkdir -p /mnt/data_zs/
## sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-8c5ead41.efs.ap-east-1.amazonaws.com:/ /mnt/data_zs/
## sudo chmod -R 777 /mnt/data_zs
```



### 4.2 托管节点组与非托管节点组

* 从 Kubernetes 版本 1.14 和[平台版本](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/platform-versions.html) `eks.3` 开始，在 Amazon EKS 集群上支持 托管节点组
    * 参考：https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/managed-node-groups.html
* 托管节点组的含义
    * 使用 Amazon EKS 托管节点组，您无需单独预配置或注册 Amazon EC2 实例以提供计算容量来运行 Kubernetes 应用程序。您可以通过单个操作为集群创建、更新或终止节点。节点运行使用您的 AWS 账户中最新 Amazon EKS 优化的 AMI，而节点更新和终止正常耗尽节点，以确保应用程序保持可用状态。
    * 所有托管节点均作为 Amazon EC2 Auto Scaling 组的一部分进行预配置，由 Amazon EKS 为您管理。所有资源（包括实例和 Auto Scaling 组在内）在您的 AWS 账户中运行。
    * Amazon EKS 托管节点组既可以在公有子网也可以在私有子网中启动。唯一的要求是子网具有出站 Internet 访问权限。Amazon EKS 会自动将公有 IP 与作为托管节点组一部分启动的实例关联，以确保这些实例可以成功加入集群。


用户可根据应用场景选择不同的节点组类型。
考虑到目前项目中可能涉及的一些特殊需求，测试阶段建议先使用**非托管节点组**，参见方式一。

方式一中配置使用EC2 Spot方式，可以在测试阶段节省费用，后期再修改为按需方式启动EC2节点。


### 4.3 方式一：参数文件 + 非托管节点组 + Spot实例

```
mkdir -p ~/download
cd ~/download

## 编辑NodeGroup配置文件，文件名可自定义
## 相关参数可参考：https://eksctl.io/usage/schema/
## eksctl 0.14.0版本后可只指定一种实例类型，之前需要同时指定多种EC2实例类型
## 参数部分可根据实际需求进行修改，如EC2实例类型、数量、EBS卷大小等
## 如需要启动大量EC2实例，需要提前提交提升limit申请给支持团队
## 可参考：https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/ec2-resource-limits.html

vi NG-UNMANAGED-C5-4x.yaml

apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: EKS-HKG
  region: ap-east-1

nodeGroups:
  - name: NG-UNMANAGED-C5-4x
    minSize: 2
    maxSize: 10
    desiredCapacity: 3
    volumeSize: 50
    preBootstrapCommands:
      - 'sudo mkdir -p /mnt/data_zs/'
      - 'sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-8c5ead41.efs.ap-east-1.amazonaws.com:/ /mnt/data_zs/'
      - 'sudo chmod -R 777 /mnt/data_zs'
    instancesDistribution:
      maxPrice: 1
      instanceTypes: ["c5.2xlarge"] # eksctl 0.14.0版本后可只指定一种实例类型
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 1
    ssh:
      allow: true
      publicKeyName: hkg-key
    labels: {role: worker}
    tags:
      {
      "Environment": "Alpha-Test",
      "Application": "ShinyProxy"
      }
    iam:
      withAddonPolicies:
        externalDNS: true
        certManager: true
        albIngress: true
        appMesh: true
        autoScaler: true
        cloudWatch: true
        ebs: true
        efs: true
        fsx: true

## 创建NodeGroup
eksctl create nodegroup --config-file=./NG-UNMANAGED-C5-4x.yaml

## 在创建异常的情况下，需要删除之前失败的NodeGroup后重新创建
## eksctl delete nodegroup --config-file=./NG-UNMANAGED-C5-4x.yaml --approve

## 创建完成后可手工管理NodeGroup的伸缩，如将原节点数量从2调整为3
## 后续将增加自动扩展功能
eksctl scale nodegroup  --cluster EKS-HKG --name NG-UNMANAGED-C5-4x --nodes 3

## 输出显示类似下面信息：
/*
[ℹ]  scaling nodegroup stack "eksctl-EKS-HKG-nodegroup-NG-UNMANAGED-C5-4x" in cluster eksctl-EKS-HKG-cluster
[ℹ]  scaling nodegroup, desired capacity from "2" to 3
*/

```

### 4.4 方式二：eksctl命令行 + 托管节点组+ 按需实例

*** 注意：此方式也可创建非托管节点组，通过 —managed 参数进行区分 ***


```
## 环境变量设置
## EKS集群名
EKS_CLUSTER_NAME=EKS-HKG
## AWS区域
REGION_EKS=ap-east-1
## Node Group名
NODE_GROUP_NAME="NG-MANAGED-C5-2x"
## 节点SSH KeyPair名
KEYPAIR_NAME=hkg-key
## 节点实例类型
NODE_TYPE="c5.2xlarge"
## 节点存储类型, 有效的选项为: gp2, io1, sc1, st1) (缺省为"gp2")
NODE_VOLUME_TYPE=gp2
## 节点存储大小
NODE_VOLUME_SIZE=50
## 节点组中节点数量：最小值/最大值/预期值(total number of nodes/default 2)
NODE_MIN=1  ## 不能为0
NODE_MAX=10  ## 后续可调整
NODE_DESIRE=2  ## 不能为0
## Tag标签信息，不可包含空格
TAG="Environment=Alpha-Test,Application=Shiny" 

eksctl create nodegroup \
  --cluster $EKS_CLUSTER_NAME \
  --region=$REGION_EKS \
  --version latest \
  --name $NODE_GROUP_NAME \
  --node-type $NODE_TYPE \
  --nodes $NODE_DESIRE \
  --nodes-min $NODE_MIN \
  --nodes-max $NODE_MAX \
  --ssh-access \
  --ssh-public-key=$KEYPAIR_NAME \
  --node-volume-size $NODE_VOLUME_SIZE \
  --tags $TAG \
  --asg-access \
  --full-ecr-access \
  --appmesh-access \
  --alb-ingress-access \
  --managed

## 部分其他附加参数说明
## 可通过 eksctl create nodegroup --help 命令查看
/*
--managed                        Create EKS-managed nodegroup

IAM addons flags:
  --asg-access            ## enable IAM policy for cluster-autoscaler
  --external-dns-access   ## enable IAM policy for external-dns
  --full-ecr-access       ## enable full access to ECR
  --appmesh-access        ## enable full access to AppMesh
  --alb-ingress-access    ## enable full access for alb-ingress-controller
*/
  

## 部分托管节点不支持的选项
  --node-private-networking \
  --node-ami auto \
  --node-volume-type gp2 \
 
## 部分创建异常的情况下，需要删除之前失败的NodeGroup后重新创建
eksctl delete nodegroup --cluster $EKS_CLUSTER_NAME --region=$REGION_EKS --name $NODE_GROUP_NAME
```



## 五、EKS集群监控

### 5.1 系统状态监控

```
## 查看节点状态
kubectl get nodes --watch

NAME                                        STATUS   ROLES    AGE     VERSION
ip-10-0-23-193.ap-east-1.compute.internal   Ready    <none>   4m39s   v1.14.8-eks-b8860f
ip-10-0-32-39.ap-east-1.compute.internal    Ready    <none>   11m     v1.14.9-eks-1f0ca9
ip-10-0-77-207.ap-east-1.compute.internal   Ready    <none>   11m     v1.14.9-eks-1f0ca9
ip-10-0-94-150.ap-east-1.compute.internal   Ready    <none>   4m41s   v1.14.8-eks-b8860f

## 查看系统pod状态
kubectl -n kube-system get pods --watch

NAME                       READY   STATUS    RESTARTS   AGE
aws-node-59dtj             1/1     Running   0          10m
aws-node-7prws             1/1     Running   0          3m5s
aws-node-c8tjf             1/1     Running   0          10m
aws-node-h74s5             1/1     Running   0          3m7s
coredns-7f9f46845d-j2xfq   1/1     Running   0          16m
coredns-7f9f46845d-qqgfz   1/1     Running   0          16m
kube-proxy-9888l           1/1     Running   0          10m
kube-proxy-lcsl5           1/1     Running   0          3m7s
kube-proxy-n2xhw           1/1     Running   0          3m5s
kube-proxy-thk5t           1/1     Running   0          10m


```

### 5.2 查看集群信息

```
## 查看集群信息
aws eks describe-cluster --name $EKS_CLUSTER_NAME --region=$REGION_EKS

{
    "cluster": {
        "createdAt": 1582697259.478,
        "resourcesVpcConfig": {
            "endpointPublicAccess": true,
            "subnetIds": [
                "subnet-03d7d115ab859fd4a",
                "subnet-084c9fa15dea87166",
                "subnet-07a403b7c8f61581d",
                "subnet-0d2d7f04ebf574725",
                "subnet-03fcea76e5cfc6162",
                "subnet-0cb4f0e3da3d5ed58"
            ],
            "vpcId": "vpc-0dd8ca463f58264fc",
            "clusterSecurityGroupId": "sg-063178a4accf6aec0",
            "securityGroupIds": [
                "sg-00ff7a529171535bd"
            ],
            "endpointPrivateAccess": true,
            "publicAccessCidrs": [
                "0.0.0.0/0"
            ]
        },
**        "platformVersion": "eks.8",**
        "certificateAuthority": {
            "data": "..."
        },
**        "version": "1.14",**
        "name": "EKS-HKG",
        "arn": "arn:aws:eks:ap-east-1:xxxxxxxxxxxx:cluster/EKS-HKG",
        "tags": {},
        "status": "ACTIVE",
        "identity": {
            "oidc": {
                "issuer": "https://oidc.eks.ap-east-1.amazonaws.com/id/28DAA68726EF330A08B3F0D2E87E85A4"
            }
        },
        "roleArn": "arn:aws:iam::xxxxxxxxxxxxx:role/eksctl-EKS-HKG-cluster-ServiceRole-9E86V1S361XF",
        "logging": {
            "clusterLogging": [
                {
                    "types": [
                        "api",
                        "audit",
                        "authenticator",
                        "controllerManager",
                        "scheduler"
                    ],
                    "enabled": true
                }
            ]
        },
**        "endpoint": "https://28DAA68726EF330A08B3F0D2E87E85A4.sk1.ap-east-1.eks.amazonaws.com"**
    }
}
```

### 5.3 查看NodeGroup信息

```
## 如果已设置 AWS_DEFAULT_REGION 环境变量，可以在eksctl中忽略 --region 参数
REGION_EKS=ap-east-1
export AWS_DEFAULT_REGION=$REGION_EKS
EKS_CLUSTER_NAME=EKS-HKG

## 查看NodeGroup 信息
eksctl get nodegroups --cluster $EKS_CLUSTER_NAME --region $REGION_EKS

CLUSTER    NODEGROUP        CREATED            MIN SIZE    MAX SIZE    DESIRED CAPACITY    INSTANCE TYPE    IMAGE ID
EKS-HKG    NG-UNMANAGED-C5-4x    2020-02-26T13:39:14Z    1        10        2            c5.4xlarge    ami-08b907abb121da5a5
```

### 5.4 为EKS集群启用Cloudwatch监控

可为 EKS集群开启 Cloudwatch监控，便于分析和处理发生的异常。

可参考：
Amazon EKS 控制层面日志记录
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/control-plane-logs.html

```
## Enabled CloudWatch logging for cluster "EKS-HKG" in "ap-east-1"
## 参考链接：https://eksctl.io/usage/cloudwatch-cluster-logging/
## enable types: api, audit, authenticator, controllerManager, scheduler

eksctl utils update-cluster-logging --enable-types all --approve --region=ap-east-1 --cluster=EKS-HKG
```

## 六、部署 Kubernetes 控制面板（可选）

参考：
教程：部署 Kubernetes Web UI (控制面板)
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/dashboard-tutorial.html


```
mkdir -p ~/download
cd ~/download

##安装jq
sudo apt install jq -y

##部署metrics server
DOWNLOAD_URL=$(curl -Ls "https://api.github.com/repos/kubernetes-sigs/metrics-server/releases/latest" | jq -r .tarball_url)
DOWNLOAD_VERSION=$(grep -o '[^/v]*$' <<< $DOWNLOAD_URL)
curl -Ls $DOWNLOAD_URL -o metrics-server-$DOWNLOAD_VERSION.tar.gz
mkdir metrics-server-$DOWNLOAD_VERSION
tar -xzf metrics-server-$DOWNLOAD_VERSION.tar.gz --directory metrics-server-$DOWNLOAD_VERSION --strip-components 1
kubectl apply -f metrics-server-$DOWNLOAD_VERSION/deploy/1.8+/

## 查看部署
kubectl get deployment metrics-server -n kube-system


## 下载最新的Dashboard部署文件
## https://github.com/kubernetes/dashboard
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc5/aio/deploy/recommended.yaml

## 修改 recommended.yaml 文件
**## 在确保访问安全的情况下，可添加参数延长Token的过期时间（单位为分钟，默认为15分钟） **
**## 或 在登录界面增加 Skip 按钮**

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
**            ****-**** ****--****token****-****ttl****=****43200**
**            ****-**** ****--****enable****-****skip****-****login**

## 通过kubectl应用配置
kubectl apply -f recommended.yaml

## 创建 eks-admin-service-account.yaml 文件

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

## 通过kubectl应用配置
kubectl apply -f eks-admin-service-account.yaml

## 获取登录Token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')

## 启用代理
kubectl proxy

## 如需要从本地访问控制面板，可启用SSH Tunnel
ssh -L 8001:localhost:8001 -A ubuntu@EC2公网IP

## 浏览器访问下面的链接，并输入之前获取的Token
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login

```




## 七、自动伸缩功能配置

在Amazon EKS 集群中提供了多种自动扩展的配置方式，支持多种类型的 Kubernetes 自动扩展：

* [Cluster Autoscaler](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/cluster-autoscaler.html) — Kubernetes Cluster Autoscaler 在 Pod 由于缺少资源而无法启动时，或者在集群中的节点利用率不足使其 Pod 可以重新调度到集群中的其他节点上时，自动调整集群中的节点数。 
* [Horizontal Pod Autoscaler](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/horizontal-pod-autoscaler.html) — Kubernetes Horizontal Pod Autoscaler 根据资源的 CPU 利用率，自动扩展部署、复制控制器或副本集中的 Pod 数量。 
* [Vertical Pod Autoscaler](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/vertical-pod-autoscaler.html) — Kubernetes Vertical Pod Autoscaler 为 Pod 自动调整 CPU 和内存预留，以帮助实现“合适规模”的应用程序。这可以帮助您更好地使用集群资源并释放 CPU 和内存用于其他 pod。

本文将主要介绍Cluster Autoscaler 功能，其他功能可参考文档自行配置。
可参考：
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/autoscaling.html

### 7.1 Cluster Autoscaler配置

可参考：
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/cluster-autoscaler.html


```
## 通过 kubectl 应用配置
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"

## 修改对应信息
kubectl -n kube-system edit deployment.apps/cluster-autoscaler

## 编辑 50行，将 <YOUR CLUSTER NAME> 替换为 当前创建的EKS集群名，如 EKS-HKG
## 在此行下添加下列内容

        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false

## 通过 kubectl 应用配置
kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=k8s.gcr.io/cluster-autoscaler:v1.14.7

## 查看Cluster Autoscaler日志
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler

## 部署完成后Cluster Autoscaler即开始工作
## 如没有Pod运行，会将目前NodeGroup中节点数逐渐关停到 NodeGroup 扩展组设置的最小值，如当前设置的2

```

[Image: image.png]
### 7.2 Cluster Autoscaler测试

可参考：
https://eksworkshop.com/beginner/080_scaling/test_ca/

```
## 编辑生成测试文件，为快速查看扩展效果可修改nginx容器的资源配置

cat <<EoF> ./ca-test-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-to-scaleout
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        service: nginx
        app: nginx
    spec:
      containers:
      - image: nginx
        name: nginx-to-scaleout
        resources:
          limits:
            cpu: 500m
            memory: 2048Mi
          requests:
            cpu: 500m
            memory: 2048Mi
EoF

## 通过kubectl 应用配置
kubectl apply -f ./ca-test-nginx.yaml

## 将测试Nginx容器扩展到20个
## 是否触发自动扩展与当前运行的节点数量、节点配置有关
kubectl scale --replicas=20 deployment/nginx-to-scaleout

## 可通过下面的命令监控Nginx容器的部署状态
watch -n 2 kubectl get deployment/nginx-to-scaleout

## 可通过下面的命令监控节点的增加情况
## 也可通过 Cluster Autoscaler 日志观察到节点的扩展信息
kubectl get node -o wide

## 测试完成后删除测试过程的部署
kubectl delete -f ./ca-test-nginx.yaml

```



## 八、ShinyProxy 容器准备

可参考：
三方部署教程
https://medium.com/@rohitsrmuniv/using-shinyproxy-with-kubernetes-eba5bd06230
https://github.com/openanalytics/shinyproxy-config-examples/tree/master/03-containerized-kubernetes

其他参考：
Shinyproxy配置参数说明
https://www.shinyproxy.io/configuration/

为完成ShinyProxy的最终部署展现，我们需要部署几个不同层面的容器到EKS中，包括：
A、ShinyProxy 
B、kube-proxy-sidecar（用于ShinyProxy的辅助管理）
C、Shiny 测试应用

**同时我们将使用AWS ECR服务作为自建容器的镜像仓库。**


### 8.1 AWS ECR配置

Amazon Elastic Container Registry (Amazon ECR) 是一项托管 AWS Docker 镜像仓库服务，安全、可扩展且可靠。通过使用 AWS IAM，Amazon ECR 支持具有基于资源的权限的私有 Docker 存储库，以便特定用户或 Amazon EC2 实例可以访问存储库和镜像。开发人员可以使用 Docker CLI 推送、拉取和管理映像。

*** 在本文中将使用ECR服务进行上一步骤中自建测试Shiny容器的管理***
*** 如果Shiny容器已经存放在本地或其他三方的镜像仓库中，此步骤可忽略***

可参考：
通过控制台创建容器镜像的ECR存储库：
https://docs.aws.amazon.com/zh_cn/AmazonECR/latest/userguide/getting-started-console.html
AWS CLI参考：
https://docs.aws.amazon.com/cli/latest/reference/ecr/index.html


```
## 通过AWS CLI方式创建容器镜像的ECR存储库
## 可参考： https://docs.aws.amazon.com/zh_cn/AmazonECR/latest/userguide/getting-started-cli.html

REGION_EKS=ap-east-1
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
    

## 登录ECR服务
$(aws ecr get-login --no-include-email --region ap-east-1)


```



### 8.2 创建shiny测试应用

*** 可自行选择用于测试的R应用容器，或将目前的R应用容器化***
*** 如已有就绪的R应用容器，此步骤可忽略，如需将容器发布到AWS ECR容器镜像仓库进行管理，可参考下面相应的步骤进行***

我们选择来自 [www.shinyproxy.io](http://www.shinyproxy.io/) 网站的一个标准简单应用作为测试R应用

可参考：
https://www.shinyproxy.io/deploying-apps/


```
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
    --region ap-east-1
    
## 通过浏览器访问 EC2 弹性IP地址:8888 端口，测试Shiny应用是否正常

## 记录并注释掉Dockerfile文件中最后的 CMD 行，并重新build容器

vi ~/download/Shinyproxy/shiny-application/shinyproxy-template/Dockerfile

**# CMD ["R", "-e", "shiny::runApp('/root/euler')"]**

## 容器内R应用的启动后续将由ShinyProxy通过接口进行调度
## 重新build容器
sudo docker build -t shiny_eks_demo/shiny-application ./shinyproxy-template/

## 标记上传容器镜像，注意更换AWS账号 xxxxxxxxxx
## ECR中容器标签如“0.1.0”，可用于控制多次发布的不同容器应用版本
docker tag shiny_eks_demo/shiny-application:latest xxxxxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/shiny-application:0.1.0

## 查看本地标记后images
docker images
REPOSITORY                                                            TAG                 IMAGE ID            CREATED             SIZE
xxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/shiny-application        0.1.0              1de990a83277        36 minutes ago      919MB

## 推送Images到ECR中
docker push xxxxxxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/shiny-application:0.1.0


```



### 8.3 创建**kube-proxy-sidecar**

kube-proxy-sidecar 容器在此部署场景中完成对不同登录用户的处理，对于每个独立的用户生成新的EKS Pod

此步骤完成 **kube-proxy-sidecar 容器创建并上传到AWS ECR**

```
## 需根据情况修改命令中的AWS账号、区域信息

mkdir -p ~/download
cd ~/download

## kube-proxy-sidecar
## The kube-proxy-sidecar container handles the different users login, creating a new pod for every user login.

git clone https://github.com/rohitsrmuniv/Shinyproxy.git
cd Shinyproxy

## 创建容器并推送到AWS ECR服务，容器标签可自定义
docker build -t xxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/kube-proxy-sidecar:0.1.0 kube-proxy-sidecar/

docker push xxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/kube-proxy-sidecar:0.1.0

```



### 8.4 创建ShinyProxy

**关于image-pull-secret参数**

ShinyProxy 的配置文件中使用 image-pull-secret 参数指定 ShinyProxy 去获取 Shiny 应用镜像时的凭据。
在目前的EKS版本（1.4）中已不需要为ShinyProxy生成针对 AWS ECR服务的凭据。
需要设置 image-pull-secret的位置均留空即可。

可参考：
proxy.kubernetes.image-pull-secret: the name of a secret to use for pulling images from a registry
https://www.shinyproxy.io/configuration/


```
cd ~/download/Shinyproxy/shinyproxy-application/

## 修改Dockerfile 文件，更新为ShinyProxy 稳定最新版本
## 可通过 https://www.shinyproxy.io/downloads/ 查看ShinyProxy版本信息

vi Dockerfile

FROM openjdk:8-jre

RUN mkdir -p /opt/shinyproxy/
RUN wget https://www.shinyproxy.io/downloads/shinyproxy-**2.3.0**.jar -O /opt/shinyproxy/shinyproxy.jar
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
  - name: xiaoping
    password: xiaoping123
    groups: admins
  - name: yun
    password: yun123
    groups: admins
  - name: fshi
    password: fshi123
    groups: admins
  - name: user
    password: User@123
    groups: guest
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
  - id: 00_demo_shiny
    display-name: Simple Shiny Application Demo
    description: https://github.com/openanalytics/shinyproxy-template
    container-cmd: ["R", "-e", "shiny::runApp('/root/euler')"]
    container-image: 861504766936.dkr.ecr.ap-east-1.amazonaws.com/shiny-application:0.1.0
  - id: 01_hello
    display-name: Hello Application
    description: Application which demonstrates the basics of a Shiny app
    container-cmd: ["R", "-e", "shinyproxy::run_01_hello()"]
    container-image: openanalytics/shinyproxy-demo
    access-groups: [admins, guest, scientists, mathematicians]
  - id: 06_tabsets
    display-name: Openanalytics shinyproxy-demo tabsets
    description: Application which demonstrates a Shiny app
    container-cmd: ["R", "-e", "shinyproxy::run_06_tabsets()"]
    container-image: openanalytics/shinyproxy-demo
    access-groups: [admins, guest, scientists, mathematicians]
  - id: dash-demo
    display-name: Dash Demo Application
    description: https://github.com/openanalytics/shinyproxy-dash-demo
    port: 8050
    container-cmd: ["python", "app.py"]
    container-image: openanalytics/shinyproxy-dash-demo
    access-groups: [admins, guest, scientists, mathematicians]
  - id: seuratv3wizard
    display-name: seuratv3wizard
    description: https://github.com/nasqar/seuratv3wizard
    port: 80
    container-cmd: ["/usr/bin/shiny-server.sh"]
    container-image: 861504766936.dkr.ecr.ap-east-1.amazonaws.com/seuratv3wizard:0.1.0
    access-groups: [admins, guest, scientists, mathematicians]
  - id: scsat
    display-name: scsat
    description: None
    container-cmd: ["R", "-e", 'shiny::runApp("/root/Shiny_seurat")']
    container-image: 861504766936.dkr.ecr.ap-east-1.amazonaws.com/scsat:0.1.0
    container-volumes: ["/mnt/data_zs/#{proxy.userId}:/root/Shiny_seurat/Users/#{proxy.userId}"]
    access-groups: admins

spring:
  servlet:
    multipart:
      max-file-size: 200MB
      max-request-size: 200MB

logging:
  file:
    shinyproxy.log
    
    
## 创建容器并推送到ECR服务，标签可自定义
docker build -t xxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/shinyproxy-application:2.3.0 .

docker push xxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/shinyproxy-application:2.3.0


```



## 九、配置ALB Ingress 控制器

AWS弹性负载均衡器（Elastic Load Balancing） 支持三种类型的负载均衡器：

* Application Load Balancer
* Network Load Balancer
* Classic Load Balancer


默认配置下，ShinyProxy部署时使用AWS Classic 负载均衡器进行部署。AWS Classic 负载均衡器为AWS早期的负载均衡器服务，将逐渐被新的AWS 应用负载均衡器或网络负载均衡器服务替代，新服务提供更好的应用特性及性能。

本文将介绍如何使用AWS 应用负载均衡器进行ShinyProxy的部署。

可参考：
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/alb-ingress.html

```
## 环境变量设置
REGION_EKS=ap-east-1
export AWS_DEFAULT_REGION=$REGION_EKS
EKS_CLUSTER_NAME=EKS-HKG

## 创建 IAM OIDC 提供程序，并将该提供程序与您的集群关联
eksctl utils associate-iam-oidc-provider \
    --region $REGION_EKS \
    --cluster $EKS_CLUSTER_NAME \
    --approve

## 为 ALB 入口控制器 Pod 创建一个名为 `ALBIngressControllerIAMPolicy` 的 IAM 策略，该策略允许此 Pod 代表您调用 AWS API
aws iam create-policy \
    --policy-name ALBIngressControllerIAMPolicy \
    --policy-document https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/iam-policy.json

## 在 `kube-system` 命名空间中创建一个名为 `alb-ingress-controller` 的 Kubernetes 服务账户，并创建集群角色和针对 ALB 入口控制器的集群角色绑定，以便用于以下命令。
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/rbac-role.yaml

## 使用以下命令部署 ALB 入口控制器
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/alb-ingress-controller.yaml

## 使用以下命令打开 ALB 入口控制器部署清单以进行编辑
kubectl edit deployment.apps/alb-ingress-controller -n kube-system

## 在 `--ingress-class=alb` 行之后，为集群名称添加相应内容
## cluster-name 为当前EKS集群名称
## aws-vpc-id 为当前EKS集群使用的VPC的ID
## aws-region 为当前EKS集群使用的AWS区域
## 添加相应的行后，保存并关闭文件

        - --ingress-class=alb
        - --cluster-name=EKS-HKG
        - --aws-vpc-id=vpc-05144792f5d04f052
        - --aws-region=ap-east-1

## 使用以下命令确认 ALB 入口控制器是否正在运行
kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
alb-ingress-controller-69fc86d866-8hbkx   1/1     Running   0          2d1h


```



## 十、部署ShinyProxy

### 10.1 创建Shiny专属命名空间

为更方便管理和控制Shiny容器的使用，为Shiny应用创建专用的命令空间

```
## 创建EKS集群的Kubernetes 命名空间 —— 名称为 Shiny
kubectl create ns shiny

```



### 10.2 为ShinyProxy创建EKS相关认证、服务、负载均衡设置、部署

```
cd ~/download/Shinyproxy/

## 编辑 sp-service.yaml 文件，修改为以下内容

kind: Service
apiVersion: v1
metadata:
  name: shinyproxy
  namespace: shiny
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
## ALB的Annotations可用于修改ALB负载均衡器属性，可参考： 
## https://docs.aws.amazon.com/zh_cn/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-type

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: "shinyproxy-ingress"
  namespace: "shiny"
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

```
## 编辑 sp-deployment.yaml 文件，修改为以下内容
## 需根据情况修改配置中的AWS账号

apiVersion: apps/v1
kind: Deployment
metadata:
  name: shinyproxy
  namespace: shiny
spec:
  selector:
    matchLabels:
      run: shinyproxy
  replicas: 2
  template:
    metadata:
      labels:
        run: shinyproxy
    spec:
      containers:
      - name: shinyproxy
        image: xxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/shinyproxy-application:2.3.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
      - name: kube-proxy-sidecar
        image: xxxxxxxxxxxx.dkr.ecr.ap-east-1.amazonaws.com/kube-proxy-sidecar:0.1.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8001
      imagePullSecrets:
      

```

```
## sp-authorization.yaml 文件无需修改，内容如下：

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: shinyproxy-auth
subjects:
  - kind: ServiceAccount
    name: default
    namespace: shiny
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

```
## 如已使用 Classic负载均衡器方式 部署过Shinyroxy服务
## 先删除原有 Classic Load Balancer 方式
kubectl delete -f sp-service.yaml
kubectl delete -f sp-deployment.yaml
kubectl delete -f sp-shinyingress.yaml

## 使用Application Load Balancer 方式进行部署
kubectl apply -f sp-service.yaml
kubectl apply -f sp-deployment.yaml
kubectl apply -f sp-shinyingress.yaml
kubectl apply -f sp-shinyingress.yaml

```

```
## 获取 ShinyProxy 服务所使用的AWS负载均衡器信息

kubectl get ingress -n shiny
NAME                 HOSTS   ADDRESS                                                                  PORTS   AGE
shinyproxy-ingress   *       46972372-shiny-shinyproxyi-xxxx-xxxxxxxxxx.ap-east-1.elb.amazonaws.com   80      21h

## 通过浏览器访问AWS负载均衡器进行测试
## AWS负载均衡器有一个约几分钟的创建和生效过程，可通过AWS控制台确认负载均衡器状态正常后再进行访问

```


[Image: image.png]

### 10.3 控制Shiny应用启动的节点

在实际的应用场景中，常常有这样的需求，希望某个Shiny应用能够运行在指定的节点上，比如选择某种指定配置的EC2服务，或者在指定的节点运行指定的Shiny容器。我们可以通过ShinyProxy提供的参数配置及Kubernetes所提供的“节点选择”功能实现。


```
## 是用上面介绍过的方法，启动不同配置的EC2节点组
## 给不同配置的节点组增加 自定义的节点标签
kubectl label nodes -l alpha.eksctl.io/nodegroup-name=NG-UNMANAGED-C5-x NodeSize=c5.xlarge
kubectl label nodes -l alpha.eksctl.io/nodegroup-name=NG-UNMANAGED-C5-2x NodeSize=c5.2xlarge
```

```
## 修改ShinyProxy配置文件application.yml中 kubernetes 节的配置
## 与上个步骤中所做的标签一致即可（Key=Value形式）

  kubernetes:
    internal-networking: true
    url: http://localhost:8001
    namespace: shiny
    image-pull-policy: IfNotPresent
    image-pull-secret:
    node-selector: NodeSize=c5.xlarge**
       
**
```


[Image: image.png]


## 十一、EKS 简单监控

可参考：
https://kubernetes.io/zh/docs/reference/kubectl/overview/

AWS EKS除通过使用Cloudwatch进行监控外，还可与开源生态中主流的Kubernetes管理工具、监控工具等良好集成，如Kubernetes Metrics Server、Prometheus、Grafana等。

可参考相关链接自行进行部署：
Prometheus 的控制层面指标
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/prometheus.html
https://eksworkshop.com/intermediate/240_monitoring/

安装 Kubernetes Metrics Server
https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/metrics-server.html


```
## 查看 EKS 集群节点信息
kubectl get node -o wide

## 查看 EKS 集群系统Pod信息
kubectl -n kube-system get pods -o wide

## 查看Shiny相关Pods状态
kubectl -n shiny get pods -o wide

## 查看当前Shinyproxy Pod信息
## 可了解当前使用的容器版本等
kubectl describe -n shiny pods/shinyproxy-xxxxxxxxxxxxxxx-xxxxx

## 查看Shinyproxy日志
kubectl logs -f -n shiny -c shinyproxy shinyproxy-xxxxxxxxx-xxxxxxx

## 如果更新容器及相应的配置文件，需删除后再次提交生效
## kubectl delete -f sp-authorization.yaml
kubectl delete -f sp-service.yaml
kubectl delete -f sp-deployment.yaml

## kubectl create -f sp-authorization.yaml
kubectl create -f sp-service.yaml
kubectl create -f sp-deployment.yaml
```



## 参考资料：

rohitsrmuniv / Shinyproxy
https://medium.com/@rohitsrmuniv/using-shinyproxy-with-kubernetes-eba5bd06230
https://github.com/rohitsrmuniv/Shinyproxy

### AWS CLI

AWS Command Line Interface 介绍
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/cli-chap-welcome.html
CLI安装
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/install-linux.html
基础使用指南：
https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/cli-services-ec2-instances.html
命令参考：
https://docs.aws.amazon.com/cli/latest/reference/ec2/

### VPC

https://docs.aws.amazon.com/zh_cn/vpc/latest/userguide/what-is-amazon-vpc.html
https://docs.aws.amazon.com/zh_cn/vpc/latest/userguide/VPC_Scenario2.html
https://docs.aws.amazon.com/zh_cn/vpc/latest/userguide/vpc-subnets-commands-example.html

### eksctl

https://eksctl.io/

ALB Ingress
https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/controller/how-it-works/
https://github.com/kubernetes-sigs/aws-alb-ingress-controller

[Image: image.png]


