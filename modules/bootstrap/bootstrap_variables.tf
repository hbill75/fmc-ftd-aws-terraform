##
# Define variables for Terraform state backend
##

variable "name_of_s3_bucket" {}
variable "dynamo_db_table_name" {}
variable "iam_user_name" {}
variable "ado_iam_role_name" {}
variable "aws_iam_policy_permits_name" {}
variable "aws_iam_policy_assume_name" {}
