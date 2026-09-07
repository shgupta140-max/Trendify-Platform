// Pipeline Code

pipeline {
    agent any

    environment {
        AWS_REGION   = "ap-south-1"
        CLUSTER_NAME = "trendstore-cluster" 
        NAMESPACE    = "monitoring"
        APP_NAMESPACE = "trendstore"
    }

    stages {
        stage('Authenticate to EKS') {
            steps {
                // Generates ~/.kube/config using the Jenkins EC2 Instance Profile
                sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
            }
        }

        stage('Add Helm Repositories') {
            steps {
                sh '''
                    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                    helm repo update
                '''
            }
        }

        stage('Deploy Kube-Prometheus-Stack') {
            steps {
                // Ensure the namespace exists
                sh "kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                
                // Deploy or upgrade the monitoring stack
                sh '''
                    helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
                        --namespace ${NAMESPACE} \
                        -f monitoring/custom-values.yml \
                        --wait \
                        --atomic \
                        --cleanup-on-fail
                '''
                sh "helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter --namespace ${NAMESPACE} --wait --atomic --cleanup-on-fail"
            }
        }

        stage('Deploy ServiceMonitor and BlackBox Probe for Trendify') {
            steps {
                // Apply the ServiceMonitor configuration
                sh "kubectl apply -f service-monitor.yml -n ${NAMESPACE}"
                echo "Waiting for ALB URL to be generated..."
                sleep 30
                ALB_URL=$(kubectl get ingress trendstore-alb -n ${APP_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                echo "ALB URL: ${ALB_URL}"
                // Replace placeholder in blackbox-probe.yml with the actual ALB URL
                sed -i "s/__ALB_DNS_NAME__/$ALB_URL/g" blackbox-probe.yml
                // Apply the BlackBox Probe configuration
                sh "kubectl apply -f blackbox-probe.yml -n ${NAMESPACE}"
            }
        }
    }
}