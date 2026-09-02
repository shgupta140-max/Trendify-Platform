output "jenkins-public-dns" {
  value = "Jenkins Public DNS: ${aws_instance.jenkins-master.public_dns}"
}

output "jenkins-public-ip" {
  value = "Jenkins Public IP: ${aws_instance.jenkins-master.public_ip}"
}