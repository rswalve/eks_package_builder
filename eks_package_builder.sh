#!/bin/bash
# This script makes a directory with a Diode transfer Metadata text file, pulls software, tars the direcctory and moves the .tar file into S3

date_today=$(date +%F)

mkdir ~/eks_mgmt_software
cd ~/eks_mgmt_software

#Adding Diode transfer Metadata
cat <<END >diode_xfer_metadata.txt
originator: Accenture
product: eks
version: $date_today
END

#Download AWS CLI
echo "Downloading AWS CLI"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

#Download Kubectl
echo "Downloading Kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

#Download jq
echo "Downloading jq"
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64

#Download Terraform
echo "Downloading Terraform"
tf_current_version=$(curl -L https://releases.hashicorp.com/terraform/index.json | jq -r '.versions[].builds[].url' | egrep -v 'rc|beta|alpha' | egrep 'linux.*amd64'  | tail -1)
tf_current_version_zip=$(echo "$tf_current_version" | awk -F/ '{print $6}')
curl "$tf_current_version" -o $tf_current_version_zip

#Download Cluster Git Code and move into ~/eks_mgmt_software
echo "Downloading Cluster Git Code" 
mkdir ~/git_folder && cd ~/git_folder
git clone git@git.c3ms.org:jasc-projects/jcc2-dsop/cluster.git
cd ..
tar -czvf cluster.tar ~/eks_mgmt_software


cd ~
mkdir ~/terraform-mirror

cat <<END >main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
END

terraform providers mirror -platform=linux_amd64 ~/terraform-mirror

tar -czvf $date_today-registry.terraform.io.tar ~/terraform-mirror
mv $date_today-registry.terraform.io.tar ~/eks_mgmt_software

tar -czvf $date_today-eks-package.tar ~/eks_mgmt_software

aws s3 cp ~/$date_today-eks-package.tar s3://**s3-bucket**
