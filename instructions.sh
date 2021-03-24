#!/bin/bash
# Author: Daniel Bowder
# Date: March 23, 2020 17:34 PST


# Variables
METALLB_CONFIG_IP_RANGE="172.16.0.210-172.16.0.220";          # CRITICAL
UNIFI_FQDN="unifi.k3s.example.com";                           # CRITICAL
METALLB_UNIFI_IP="172.16.0.212";                              # CRITICAL
METALLB_CONFIG_NAME="my-release-metallb-config";              # CRITICAL

NAMESPACE_NAME="unifi";                                       # arbitrary
METALLB_SHARING_KEY="unifi";                                  # arbitrary
UNIFI_CONFIG_NAME="unifi-config";                             # arbitrary
UNIFI_CONTAINER_NAME="unifi";                                 # arbitrary
UNIFI_APP_NAME="unifi-app";                                   # arbitrary
UNIFI_TCP_SERVICE_NAME="unifi-controller-tcp";                # arbitrary
UNIFI_UDP_SERVICE_NAME="unifi-controller-udp";                # arbitrary




# 1. Install metallb via helm
# helm repo add bitnami https://charts.bitnami.com/bitnami
# helm install my-release bitnami/metallb



# 2. Create metallb config yaml
echo "\
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: default
  name: ${METALLB_CONFIG_NAME}
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${METALLB_CONFIG_IP_RANGE}
" > metallb_config.yaml



# 3. Apply metallb_config.yaml
# kubectl apply -f metallb_config.yaml



# 4. Create a unifi controller namespace
echo "\
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE_NAME}
" > unifi_namespace.yaml



# 5. Define the environment variables for the unifi controller
echo "\
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${UNIFI_CONFIG_NAME}
  namespace: ${NAMESPACE_NAME}
data:
  PUID: \"911\"
  PGID: \"911\"
  MEM_LIMIT: \"1024M\"
" > unifi_configmap.yaml



# 5. Define the container deployment of the unifi controller
# NOTE: I did not include volumes in this deployment. You will need to
#      setup your own persitent volumes/claims on this deployment.
echo "\
kind: Deployment
apiVersion: apps/v1
metadata:
  name: ${UNIFI_FQDN}
  namespace: ${NAMESPACE_NAME}
  labels:
    app: ${UNIFI_APP_NAME}
spec:
  selector:
    matchLabels:
      app: ${UNIFI_APP_NAME}
  replicas: 1
  template:
    metadata:
      namespace: ${NAMESPACE_NAME}
      labels:
        app: ${UNIFI_APP_NAME}
    spec:
      containers:
        - name: ${UNIFI_CONTAINER_NAME}
          image: linuxserver/unifi-controller
          ports:
          - containerPort: 3478
            protocol: UDP
          - containerPort: 10001
            protocol: UDP
          - containerPort: 1900
          - containerPort: 8080
          - containerPort: 8443
          - containerPort: 8880
          - containerPort: 8843
          envFrom:
          - configMapRef:
              name: ${UNIFI_CONFIG_NAME}
          # Add Persistent Volume Claim
" > unifi_deployment.yaml



# 6. Define the services of the unifi contoller in the context of metallb
echo "\
# Thanks to github user \"ttyS0\" for most of this service config: https://github.com/metallb/metallb/issues/530
apiVersion: v1
kind: Service
metadata:
  name: ${UNIFI_TCP_SERVICE_NAME}
  namespace: ${NAMESPACE_NAME}
  annotations:
    metallb.universe.tf/allow-shared-ip: \"${METALLB_SHARING_KEY}\"
spec:
  type: LoadBalancer
  selector:
    app: ${UNIFI_APP_NAME}
  ports:
  - name: unifi-device-inform
    port: 8080
    targetPort: 8080
  - name: unifi-controller-ui
    port: 8443
    targetPort: 8443
  - name: unifi-http
    port: 8880
    targetPort: 8880
  - name: unifi-https
    port: 8843
    targetPort: 8843
  - name: unifi-speed-test
    port: 6789
    targetPort: 6789
  type: LoadBalancer
  loadBalancerIP: ${METALLB_UNIFI_IP}
---
apiVersion: v1
kind: Service
metadata:
  name: ${UNIFI_UDP_SERVICE_NAME}
  namespace: ${NAMESPACE_NAME}
  annotations:
    metallb.universe.tf/allow-shared-ip: \"${METALLB_SHARING_KEY}\"
spec:
  type: LoadBalancer
  selector:
    app: ${UNIFI_APP_NAME}
  ports:
  - name: unifi-discovery
    port: 10001
    targetPort: 10001
    protocol: UDP
  - name: unifi-stun
    port: 3478
    targetPort: 3478
    protocol: UDP
  type: LoadBalancer
  loadBalancerIP: ${METALLB_UNIFI_IP}
" > unifi_service.yaml



#7. Apply the yaml files
# kubectl apply -f unifi_namespace.yaml -f unifi_configmap.yaml -f unifi_deployment.yaml -f unifi_service.yaml
