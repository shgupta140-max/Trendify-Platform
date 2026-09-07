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
                sleep time: 30, unit: 'SECONDS' // Native Jenkins sleep step
                script {
                    // Execute kubectl in bash, capture the output, and store it in a Groovy variable
                    def ALB_URL = sh(
                    script: "kubectl get ingress trendstore-alb -n ${APP_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'", 
                    returnStdout: true
                    ).trim()
                    echo "ALB URL: ${ALB_URL}"            
                    // Inject the Groovy variable into the sed command
                    sh "sed -i 's/__ALB_DNS_NAME__/${ALB_URL}/g' blackbox-probe.yml"
            
                    // Apply the final Probe configuration
                    sh "kubectl apply -f blackbox-probe.yml -n ${NAMESPACE}"
                }
            }
        }
    }
}