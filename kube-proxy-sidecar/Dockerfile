FROM alpine:3.6
#ADD https://storage.googleapis.com/kubernetes-release/release/v1.15.10/bin/linux/amd64/kubectl /usr/local/bin/kubectl
ADD https://share-aws-nx.s3.cn-northwest-1.amazonaws.com.cn/shiny/kubectlv1.15.10 /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl
EXPOSE 8001
ENTRYPOINT ["/usr/local/bin/kubectl", "proxy"]
