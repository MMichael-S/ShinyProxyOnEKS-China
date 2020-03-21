
## II. 管理机配置

为更好的在后续步骤完成EKS集群及相关服务的创建和配置，避免因本地环境异常或网络异常等等因素带来的问题，建议能够配置一台EC2服务器作为管理服务器，此服务器后续也可以作为堡垒机使用，以提供更为安全的AWS服务访问方式。在本文涉及的部署环节中使用一台t3.small（2vCPU/2GB内存）配置类型的EC2即可。如果已经在准备创建EKS集群的AWS区域有正常可用的EC2，此步骤可忽略。我们接下去将进行必要的用户创建、EC2创建并在EC2中完成环境设置及软件部署。

### 创建IAM用户

您需要为使用AWS及完成后续的配置过程拥有已分配适当权限的IAM用户，如果此步骤还未进行，您的AWS账户管理员可参考
此链接进行创建：[创建您的第一个 IAM 管理员用户和组](https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/getting-started_create-admin-group.html)，请妥善保存好您的IAM[用户密码](https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/id_users_create.html#id_users_create_console)及[访问密钥信息](https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey)。

### 启动EC2管理机

使用您的IAM用户完成EC2创建，EC2 Linux实例的启动及连接可参考：[Amazon EC2 Linux 实例入门](https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/EC2_GetStarted.html)
本文以宁夏区域中用户经常使用的Ubuntu 16.04 操作系统镜像为例完成后续的配置，AMI ID为ami-09081e8e3d61f4b9e，可通过AWS控制台查看此AMI的详细信息。
[Image: image.png]EC2启动过程中将提示您创建后续用于连接的[EC2 密钥对](https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/ec2-key-pairs.html)，请妥善保存并注意文件安全。

启动完毕后，可以为EC2申请绑定[弹性IP地址](https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)（Elastic IP）已得到一个不变化的公网IP地址，便于今后的访问。


### 创建IAM角色附加到管理机

为使管理机能够访问AWS服务并具备相应操作权限，需要创建[用于EC2的IAM角色](https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)，并将此IAM 角色附加到实例。为简化权限设置及顺利完成后续步骤，测试阶段可为此IAM角色分配管理员访问策略（*AdministratorAccess Policy*）。但在生产环境中需进行更为严格的权限控制，可参见[IAM 最佳实践](https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/best-practices.html)，与EKS服务相关的IAM权限请参见 [适用于 Amazon EKS 的IAM](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/security-iam.html)。

之后我们可通过SSH连接到管理机，完成后续的管理机软件部署。

* 将 IAM 角色附加到实例

### 管理机配置：AWSCLI

[AWS CLI](https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/cli-chap-welcome.html) 是用于管理 AWS 服务的统一命令行界面工具，此步骤可参考：[在 Linux 上安装 AWS CLI 版本](https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/install-linux.html)。
**注意：部分AMI镜像中已经预装了AWS CLI命令行工具，且AWS CLI 的版本 为1.16.308 或更高版本，则此步骤可忽略。**

```
## Ubuntu系统更新
sudo apt update -y
sudo apt upgrade -y

## 如更新后提示需要重新启动请完成重新启动
sudo reboot

## 确认Python 版本为 2.7.9 或更高版本
python3 --version

## 安装pip 及 awscli
sudo apt install python3-pip -y
`pip3 install awscli ``--``upgrade ``--``user`

`## 查看awscli版本`
`aws ``--``version`

`## 测试AWS CLI配置，``正常情况会显示当前账号下存储桶信息或无报错空信息`
## 如异常请检查是否已成功为EC2绑定了IAM Role
`REGION_EKS``=``cn``-``northwest``-``1`
`export`` AWS_DEFAULT_REGION``=``$REGION_EKS`
`aws s3 ls`
```

### 管理机配置：Docker

EC2管理机中的Docker环境将便于我们测试Shiny容器，并用于后续步骤中Docker容器到ECR镜像仓库的推送过程。
**注意：部分AWS镜像中已经预装了Docker，但仍建议参考[Docker新版本的安装](https://docs.docker.com/install/linux/docker-ce/ubuntu/)完成容器环境的部署。**


```
## Docker安装
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

## 查看当前Docker CE有效版本
sudo apt-cache madison docker-ce

## 简单Docker测试，正常会显示 “Hello from Docker!” 字样
sudo docker run hello-world

## 授权当前用户拥有Docker的操作权限，需注销并重新登录后权限生效
sudo usermod -aG docker $USER

## 查看Docker信息，可关注其中的版本信息，如“Server Version: 19.03.8”
docker info

```



### 管理机配置：eksctl

[eksctl](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/eksctl.html) 是由[Weave works](https://www.weave.works/)提供，用于在 Amazon EKS 上创建和管理 Kubernetes 集群的简单命令行实用程序，相比通过控制台界面或模板方式创建和管理EKS集群，它提供了更为便捷和简单的方式，更多信息，可参考：[eksctl - The official CLI for Amazon EKS](https://eksctl.io/)。

**为配合Amazon EKS服务在宁夏区域和北京区域的成功落地， eksctl 0.15.0正式版本已支持宁夏和北京区域的EKS服务。**


```
## 创建当前用户根目录下名为download的目录，此目录将用于后续文件下载等目的，也可根据需要更改为其他目录名
mkdir -p ~/download
cd ~/download

## 下载eksctl latest最新稳定版本：https://github.com/weaveworks/eksctl/releases
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/eksctl

## 查看当前版本
eksctl version

```

### 管理机配置：kubectl

[Kubectl](https://kubernetes.io/zh/docs/reference/kubectl/overview/) 是用于对 Kubernetes 集群运行指令的命令行接口，在EKS集群创建完成后将通过它来进行管理、监控及应用和服务的部署。部署过程可参考：[安装 kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)。


```
cd ~/download

## 随着EKS集群版本的升级，AWS所提供的kubectl版本可能会在将来发生变化，下载前请阅读安装参考文档获取最新的下载链接和安装方法
curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/kubectl

chmod +x ./kubectl

cp ./kubectl $HOME/.local/bin/kubectl

echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc

kubectl version --short --client

```


## License

This library is licensed under the MIT-0 License. See the LICENSE file.
