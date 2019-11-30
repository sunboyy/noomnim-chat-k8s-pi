#! /bin/bash

git clone https://github.com/sunboyy/noomnim-chat-k8s-pi && \
    kubectl apply -k noomnim-chat-k8s-pi/kubernetes && \
    rm -rf noomnim-chat-k8s-pi
