# Trendify Platform

Infrastructure and monitoring configuration for the Trendify application platform. This repository provisions a Jenkins controller on AWS and uses Jenkins to install and configure the Kubernetes monitoring stack for the `trendstore` application running on Amazon EKS.

## What This Repository Does

- Provisions an Ubuntu-based Jenkins EC2 instance with Terraform.
- Installs Jenkins, Terraform, AWS CLI, Docker, `kubectl`, Helm, and Kustomize on the Jenkins host.
- Connects Jenkins to the `trendstore-cluster` EKS cluster in `ap-south-1`.
- Deploys the Prometheus Operator stack, Grafana, and Prometheus Blackbox Exporter with Helm.
- Monitors the Trendify application through Kubernetes metrics and HTTP availability probes.

This repository is the platform and observability layer. Application source code, container images, Kubernetes application manifests, and application delivery pipelines are expected to be maintained by the connected application repository or repositories.

## Repository

| Repository | Purpose |
| --- | --- |
| [Trendify-Platform](https://github.com/shgupta140-max/Trendify-Platform) | Terraform, Jenkins pipeline, and Kubernetes monitoring configuration in this repository. |

## Connected Application

The monitoring configuration connects to the deployed Trendify application using the Kubernetes application identity `trendstore`:

| Integration | Configuration |
| --- | --- |
| Kubernetes namespace | `trendstore` |
| Service label | `app: trendstore` |
| Metrics endpoint | `http://<service>:3000/metrics` through the named Service port `http` |
| Internal health target | `http://trendstore-service.trendstore.svc.cluster.local:3000/` |
| Public health target | `http://trendstore.nikboss.xyz` |
| EKS cluster | `trendstore-cluster` |
| AWS region | `ap-south-1` |

The Git URL for the Trendify application repository is not present in this repository's Git configuration or manifests. Add the application repository link to the table above when it is available. The application repository must expose a Kubernetes Service matching the `trendstore` label and a named `http` port for `ServiceMonitor` discovery.

## Architecture

```text
Terraform
  |
  +--> AWS EC2 Jenkins controller
          |
          +--> AWS EKS: trendstore-cluster
                  |
                  +--> Namespace: monitoring
                  |      +--> kube-prometheus-stack
                  |      +--> Grafana (ALB ingress)
                  |      +--> Blackbox Exporter
                  |
                  +--> Namespace: trendstore
                         +--> Trendify application Service
                         +--> /metrics endpoint
```

## Repository Structure

| Path | Description |
| --- | --- |
| `provider.tf` | Terraform version, AWS provider, backend, and provider declarations. |
| `jenkins.tf` | Jenkins EC2 instance, IAM instance profile, security group attachment, and bootstrap script. |
| `output.tf` | Jenkins public DNS and public IP outputs. |
| `Jenkinsfile` | Pipeline that authenticates to EKS and deploys the monitoring components. |
| `monitoring/custom-values.yml` | Helm values for Grafana ingress, Prometheus storage, and Blackbox Exporter. |
| `service-monitor.yml` | Prometheus Operator `ServiceMonitor` for application metrics. |
| `blackbox-probe.yml` | Prometheus Operator `Probe` for internal and public HTTP checks. |

## Prerequisites

- AWS account with permissions to manage EC2 and access the target EKS cluster.
- An existing S3 bucket named `trendstore-infra-state` in `ap-south-1` for Terraform state.
- An existing EC2 key pair named `devops-key`.
- An existing IAM instance profile named `Jenkins-EC2-Profile` with permissions required by Jenkins to access EKS and deploy Helm releases.
- An existing security group with ID `sg-0827faf1bd8e7f168`, or an updated value in `jenkins.tf`.
- Terraform `>= 1.10.0` for local Terraform operations.
- A Jenkins job configured to use this repository and execute the `Jenkinsfile`.
- An EKS cluster named `trendstore-cluster` and an application namespace named `trendstore`.

## Usage

### Provision Jenkins

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

After applying, retrieve the Jenkins endpoint details:

```bash
terraform output
```

The EC2 bootstrap script installs the required tools and starts Jenkins. Allow a few minutes for cloud-init to complete before opening Jenkins.

### Run the monitoring deployment

The Jenkins pipeline performs these stages:

1. Updates the kubeconfig for `trendstore-cluster`.
2. Adds the Prometheus Community Helm repository.
3. Creates the `monitoring` namespace.
4. Installs or upgrades `kube-prometheus-stack` using `monitoring/custom-values.yml`.
5. Installs or upgrades Prometheus Blackbox Exporter.
6. Applies `service-monitor.yml` and `blackbox-probe.yml`.

To run the equivalent commands manually from a machine with AWS, Helm, and `kubectl` access:

```bash
aws eks update-kubeconfig --region ap-south-1 --name trendstore-cluster
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/custom-values.yml \
  --wait --atomic --cleanup-on-fail
helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter \
  --namespace monitoring \
  --wait --atomic --cleanup-on-fail
kubectl apply -f service-monitor.yml -n monitoring
kubectl apply -f blackbox-probe.yml -n monitoring
```

## Verification

Check the monitoring resources and targets after the pipeline completes:

```bash
kubectl get pods -n monitoring
kubectl get servicemonitor,probe -n monitoring
kubectl get prometheus -n monitoring
kubectl get ingress -n monitoring
```

In Prometheus, confirm that the `trendify-monitor` target is up and that the Blackbox probe reports both configured HTTP targets as healthy. Grafana is exposed through an internet-facing AWS Application Load Balancer.

## Important Configuration Notes

- `monitoring/custom-values.yml` currently contains the Grafana admin password in plain text. Replace it with a Kubernetes Secret or another secret-management mechanism before using this configuration outside a development environment.
- The Grafana ingress is configured for HTTP on port 80. Configure HTTPS, an ACM certificate, and an HTTPS redirect before production use.
- The Terraform configuration uses fixed AMI, security group, key pair, IAM profile, cluster, and state bucket names. Update these values for another AWS account or environment.
- Prometheus requests a `20Gi` `gp2` persistent volume. Confirm that the EKS cluster has a compatible StorageClass.
- The `ServiceMonitor` requires the application Service to expose a port named `http` and a `/metrics` endpoint.

## Cleanup

To remove the Jenkins EC2 instance created by Terraform:

```bash
terraform destroy
```

Monitoring resources installed by Jenkins are managed in the EKS cluster. Remove them separately before destroying the cluster or changing the monitoring deployment.