terraform {
  backend "s3" {
    bucket = "reactjs-infra-state"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"
  }
}
