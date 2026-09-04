// Pipeline Code

pipeline {
    agent any

    environment {
        AWS_REGION   = "ap-south-1"
        CLUSTER_NAME = "trendstore-cluster" 
        NAMESPACE    = "monitoring"
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
            }
        }

        stage('Deploy ServiceMonitor for Trendify') {
            steps {
                // Apply the ServiceMonitor configuration
                sh "kubectl apply -f service-monitor.yml -n ${NAMESPACE}"
            }
        }
    }
}