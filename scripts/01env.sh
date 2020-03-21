#!/bin/bash

## 全局环境配置
## 也可将下述设置加入到本地用户环境的Profile中实现自动设置

REGION_EKS=cn-northwest-1

export AWS_DEFAULT_REGION=$REGION_EKS
export AWS_DEFAULT_OUTPUT=json
export AWS_DEFAULT_PROFILE=zhy
