## 构建完备的运维和监控体系

### 常用 EKS 监控指令

```
## 查看集群信息
Amazon EKS describe-cluster --name $EKS_CLUSTER_NAME --region=$REGION_EKS

## 查看NodeGroup 信息
eksctl get nodegroups --cluster $EKS_CLUSTER_NAME --region $REGION_EKS

## 查看节点状态
kubectl get nodes -o wide

## 查看系统pod状态
kubectl -n kube-system get pods -o wide

## 查看用户Pods状态
kubectl get pods -o wide

## 查看当前Shinyproxy Pod信息，如希望了解当前使用的容器版本等
kubectl describe pods/shinyproxy-xxxxxxxxxxxxxxx-xxxxx

## 查看Shinyproxy的运行日志，如希望了解运行情况及故障分析
kubectl logs -f -c shinyproxy shinyproxy-xxxxxxxxx-xxxxxxx


```

### 为EKS集群启用Cloudwatch监控

可为 EKS集群节启 Cloudwatch监控，在出现故障或者异常时，可便于分析和处理发生的异常，同时也便于将监控日志和信息发送给AWS 服务支持团队进行更深入的分析。可参考：[Amazon EKS 控制层面日志记录](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/control-plane-logs.html)

```
## 我们可以通过控制台或下面的指令来完成 EKS 集群的监控功能开启
eksctl utils update-cluster-logging --enable-types all --approve --region=cn-northwest-1 --cluster=EKS集群名

```

### 为EKS集群配置图形管理面板

可为 EKS 集群配置更便于查看、管理集群、节点、Pod等运行状态的图形管理面板，完成配置后，用户可以很方便的在面板中查看到集群不同层面的运行情况、资源耗用情况、异常及故障信息等。您可参考教程：[部署 Kubernetes Web UI (控制面板)](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/dashboard-tutorial.html) 完成相应配置。


