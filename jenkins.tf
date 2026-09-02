resource "aws_instance" "jenkins-master" {
  ami                    = "ami-01a00762f46d584a1" # Ubuntu AMI in ap-south-1
  instance_type          = "t3.medium"  
  key_name               = "devops-key"
  vpc_security_group_ids = ["sg-0827faf1bd8e7f168"]
  iam_instance_profile   = "Jenkins-EC2-Profile"
  user_data = <<-EOF
    #!/bin/bash
    set -e # Exit immediately if a command fails

    # Update system and prepare keyrings
    apt-get update
    mkdir -p /etc/apt/keyrings

    # 1. Create Swapfile (4GB)
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" | tee -a /etc/fstab

    # 2. Install Java 21 and Jenkins
    apt-get install -y openjdk-21-jdk
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    apt-get update
    apt-get install -y jenkins
    systemctl enable --now jenkins

    # 3. Install Terraform
    apt-get install -y gnupg software-properties-common curl
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    apt-get update
    apt-get install -y terraform

    # 4. Install Docker and Docker Compose
    apt-get install -y docker.io docker-compose
    systemctl enable --now docker
    # Add jenkins user to docker group so Jenkins pipelines can run docker commands
    usermod -aG docker jenkins 

    # 5. Install kubectl (Using the modern pkgs.k8s.io repository for v1.30)
    apt-get install -y apt-transport-https ca-certificates
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubectl

    # 6. Install Kustomize
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize

    # 7. Install AWS CLI v2
    apt-get install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install

  EOF

  root_block_device {
    volume_type = "gp3"
    volume_size = 30    
  }

  tags = {
    Name        = "Jenkins-Master"
    Project     = "Trendify"
    Environment = "Dev"
  }
}