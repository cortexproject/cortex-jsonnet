#!/bin/sh
set -e
rm -rf $1
mkdir -p $1
cd $1
tk init --k8s=1.24
jb install github.com/cortexproject/cortex-jsonnet/cortex@main
rm -fr ./vendor/cortex
cp -r ../../cortex ./vendor/
cp vendor/cortex/$(basename $1)/main.jsonnet.example environments/default/main.jsonnet
PAGER=cat tk show environments/default
