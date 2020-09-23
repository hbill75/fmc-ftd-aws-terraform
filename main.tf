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

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_subnet

  tags = {
    "Name" = var.vpc_name
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.vpc_name} Internet Gateway"
  }
}

# Create Subnets
resource "aws_subnet" "outside_subnets" {

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    "Name" = "${var.vpc_name} Outside Subnet"
  }
}

resource "aws_subnet" "inside_subnets" {

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    "Name" = "${var.vpc_name} Inside Subnet"
  }
}

resource "aws_subnet" "management_subnets" {

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    "Name" = "${var.vpc_name} Management Subnet"
  }
}

# Create "Allow Internal Networks" Security Group
resource "aws_security_group" "allow_internal_networks" {
  name        = "Allow Internal Networks"
  description = "Security Group to allow internal traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.internal_networks
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "Allow Internal Networks"
  }
}

# Create "Allow SSH/HTTPS" Security Group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "Allow SSH/HTTPS"
  }
}

# Create FMC Management network interface
resource "aws_network_interface" "fmc_management_interface" {

  subnet_id         = aws_subnet.management_subnets.id
  private_ips       = ["10.1.2.10"]
  security_groups   = [aws_default_security_group.default.id,
                       aws_security_group.allow_internal_networks.id]
  source_dest_check = false

  tags = {
    "Name" = "FMC Management Interface"
  }
}

# Create FTD Management network interface
resource "aws_network_interface" "ftd_management_interface" {

  subnet_id         = aws_subnet.management_subnets.id
  private_ips       = ["10.1.2.11"]
  security_groups   = [aws_default_security_group.default.id,
                       aws_security_group.allow_internal_networks.id]
  source_dest_check = false

  tags = {
    "Name" = "FTD Management Interface"
  }
}

# Create FTD metrics network interface
resource "aws_network_interface" "ftd_metrics_interface" {

  subnet_id         = aws_subnet.management_subnets.id
  private_ips       = ["10.1.2.12"]
  security_groups   = [aws_default_security_group.default.id,
                       aws_security_group.allow_internal_networks.id]
  source_dest_check = false

  tags = {
    "Name" = "FTD Metrics Interface"
  }
}

# Create FTD Outside network interface
resource "aws_network_interface" "ftd_outside_interface" {

  subnet_id         = aws_subnet.outside_subnets.id
  private_ips       = ["10.1.0.5"]
  security_groups   = [aws_default_security_group.default.id]
  source_dest_check = false

  tags = {
    "Name" = "FTD Outside Interface"
  }
}

# Create FTD Inside network interface
resource "aws_network_interface" "ftd_inside_interface" {

  subnet_id         = aws_subnet.inside_subnets.id
  private_ips       = ["10.1.1.5"]
  security_groups   = [aws_default_security_group.default.id]
  source_dest_check = false

  tags = {
    "Name" = "FTD Inside Interface"
  }
}

# Create FMC EIP
resource "aws_eip" "fmc_management_eip" {

  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]

  tags = {
    "Name" = "FMC Management EIP"
  }
}

resource "aws_eip_association" "fmc_management_eip_association" {

  network_interface_id = aws_network_interface.fmc_management_interface.id
  allocation_id        = aws_eip.fmc_management_eip.id
}

# Create FTD EIP
resource "aws_eip" "ftd_management_eip" {

  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]

  tags = {
    "Name" = "FTD Management EIP"
  }
}

resource "aws_eip_association" "ftd_management_eip_association" {

  network_interface_id = aws_network_interface.ftd_management_interface.id
  allocation_id        = aws_eip.ftd_management_eip.id
}

# Create Management Route Table
resource "aws_route_table" "route_table_management" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.vpc_name} Management Route Table"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.route_table_management.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "route_table_association_management" {

  subnet_id      = aws_subnet.management_subnets.id
  route_table_id = aws_route_table.route_table_management.id
}

# Create FMC Instance
resource "aws_instance" "fmc1" {

  ami           = "ami-04c5e5e4f84fa7087"
  instance_type = var.fmc_instance_size
  key_name      = "autoscale_project"
  tags = {
    Name = "FMC1"
  }

  user_data = file("fmc_config.txt")

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.fmc_management_interface.id
  }
}

# Create FTD Instance
resource "aws_instance" "ftd1" {

  ami           = "ami-07bbfbc09cd5e69e9"
  instance_type = var.ftd_instance_size
  key_name      = "autoscale_project"
  tags = {
    Name = "FTD1"
  }

  user_data = file("ftd_config.txt")

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.ftd_management_interface.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.ftd_metrics_interface.id
  }

  network_interface {
    device_index         = 2
    network_interface_id = aws_network_interface.ftd_outside_interface.id
  }

  network_interface {
    device_index         = 3
    network_interface_id = aws_network_interface.ftd_inside_interface.id
  }
}

/*
output "inside_ips" {
  value = aws_network_interface.inside_interfaces.*.private_ip
}
output "management_ips" {
  value = aws_network_interface.management_interfaces.*.private_ip
}
output "outside_ips" {
  value = aws_eip.outside_eips.*.public_ip
}
*/
