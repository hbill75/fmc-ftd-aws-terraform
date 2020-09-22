# Require TF version to be same as or greater than 0.12.28
terraform {
  required_version = ">=0.12.28"

  backend "s3" {
    bucket         = "fmc-ftd-state-bucket-13972486"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-locks"
    encrypt        = true
  }
}

# Download AWS provider
provider "aws" {
  region  = "us-east-1"
  version = "~>3.3.0"
}

# Terraform bootstrapping
module "bootstrap" {
  source                      = "./modules/bootstrap"
  name_of_s3_bucket           = "fmc-ftd-state-bucket-13972486"
  dynamo_db_table_name        = "aws-locks"
  iam_user_name               = "IamUser"
  ado_iam_role_name           = "IamRole"
  aws_iam_policy_permits_name = "IamPolicyPermits"
  aws_iam_policy_assume_name  = "IamPolicyAssume"
}
