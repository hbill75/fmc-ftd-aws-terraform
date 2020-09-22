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

/*
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
  security_groups   = [aws_default_security_group.default.id]
  source_dest_check = false

  tags = {
    "Name" = "FMC Management Interface"
  }
}

# Create FTD Management network interface
resource "aws_network_interface" "ftd_management_interface" {

  subnet_id         = aws_subnet.management_subnets.id
  private_ips       = ["10.1.2.11"]
  security_groups   = [aws_default_security_group.default.id]
  source_dest_check = false

  tags = {
    "Name" = "FTD Management Interface"
  }
}

# Create FTD metrics network interface
resource "aws_network_interface" "ftd_metrics_interface" {

  subnet_id         = aws_subnet.management_subnets.id
  private_ips       = ["10.1.2.12"]
  security_groups   = [aws_default_security_group.default.id]
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

resource "aws_network_interface" "outside_interfaces" {
  count = var.availability_zone_count * var.instances_per_az

  subnet_id         = aws_subnet.outside_subnets[floor(count.index / var.instances_per_az)].id
  security_groups   = [aws_security_group.allow_internal_networks.id]
  source_dest_check = false

  tags = {
    "Name" = "FMC Outside Interface ${count.index + 1}"
  }
}
resource "aws_network_interface" "inside_interfaces" {
  count = var.availability_zone_count * var.instances_per_az

  subnet_id         = aws_subnet.inside_subnets[floor(count.index / var.instances_per_az)].id
  security_groups   = [aws_security_group.allow_internal_networks.id]
  source_dest_check = false

  tags = {
    "Name" = "FMC Inside Interface ${count.index + 1}"
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

resource "aws_eip" "nat_gateway_eips" {

  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]

  tags = {
    "Name" = "Management NAT EIP"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "management_nat_gateway" {

  allocation_id = aws_eip.nat_gateway_eips[count.index].id
  subnet_id     = aws_subnet.outside_subnets[count.index].id
  depends_on    = [aws_internet_gateway.internet_gateway]

  tags = {
    "Name" = "ASAv Management NAT Gateway ${count.index + 1}"
  }
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

# Create Outside Route Table
resource "aws_route_table" "route_table_outside" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.vpc_name} Outside Route Table"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.route_table_outside.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}
resource "aws_route_table_association" "route_table_association_outside" {
  count = length(aws_subnet.outside_subnets)

  subnet_id      = aws_subnet.outside_subnets[count.index].id
  route_table_id = aws_route_table.route_table_outside.id
}

# Create Inside Route Table\
resource "aws_route_table" "route_table_inside" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.vpc_name} Inside Route Table"
  }
}

resource "aws_route" "inside_vpn_pool_routes" {
  count = var.availability_zone_count * var.instances_per_az

  route_table_id         = aws_route_table.route_table_inside.id
  destination_cidr_block = cidrsubnet(var.vpn_pool_supernet, (local.vpn_network_bits - var.ip_pool_size_bits[var.instance_size]), count.index)
  network_interface_id   = aws_network_interface.inside_interfaces[count.index].id
}

resource "aws_route" "inside_internal_routes" {
  count = length(var.internal_networks)

  route_table_id         = aws_route_table.route_table_inside.id
  destination_cidr_block = var.internal_networks[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id
}

resource "aws_route_table_association" "route_table_association_inside" {
  count = length(aws_subnet.inside_subnets)

  subnet_id      = aws_subnet.inside_subnets[count.index].id
  route_table_id = aws_route_table.route_table_inside.id
}

# Create Management Route Table
resource "aws_route_table" "management_route_tables" {
  count = var.availability_zone_count

  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.management_nat_gateway[count.index].id
  }

  tags = {
    "Name" = "${var.vpc_name} Management Route Table ${count.index + 1}"
  }
}

resource "aws_route" "management_internal_routes" {
  count = var.availability_zone_count * length(var.internal_networks)

  route_table_id         = aws_route_table.management_route_tables[floor(count.index / length(var.internal_networks))].id
  destination_cidr_block = var.internal_networks[count.index % length(var.internal_networks)]
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id
}

resource "aws_route_table_association" "route_rable_association_management" {
  count = length(aws_subnet.management_subnets)

  subnet_id      = aws_subnet.management_subnets[count.index].id
  route_table_id = aws_route_table.management_route_tables[count.index].id
}

# Set up the ASA configuration file
data "template_file" "asa_config" {
  count = var.availability_zone_count * var.instances_per_az

  depends_on = [random_password.password, aws_subnet.inside_subnets]
  template   = "${file("asa_config_template.txt")}"

  vars = {
    asa_password           = random_password.password.result
    default_gateway_inside = cidrhost(aws_subnet.inside_subnets[floor(count.index / var.instances_per_az)].cidr_block, 1)
    ip_pool_start          = cidrhost(cidrsubnet(var.vpn_pool_supernet, (local.vpn_network_bits - var.ip_pool_size_bits[var.instance_size]), count.index), 1)
    ip_pool_end            = cidrhost(cidrsubnet(var.vpn_pool_supernet,
                                                  (local.vpn_network_bits - var.ip_pool_size_bits[var.instance_size]), count.index),
                                                  var.ip_pool_size_count[var.instance_size])
    ip_pool_mask           = cidrnetmask(cidrsubnet(var.vpn_pool_supernet, (local.vpn_network_bits - var.ip_pool_size_bits[var.instance_size]), count.index))
    smart_account_token    = var.smart_account_token
    throughput_level       = lookup(var.throughput_level, var.instance_size, "1G")
  }
}

# Set up the ASA configuration file
data "template_file" "fmc_config" {

  template   = file("fmc_config.txt")
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

# Create ASAv Instance
resource "aws_instance" "asav" {
  count = var.availability_zone_count * var.instances_per_az

  ami           = data.aws_ami.cisco_asa_lookup.id
  instance_type = var.instance_size
  tags          = {
    Name = "Cisco ASAv RAVPN ${count.index + 1}"
  }

  user_data = data.template_file.asa_config[count.index].rendered

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.management_interfaces[count.index].id
  }

  network_interface {
    device_index = 1
    network_interface_id = aws_network_interface.outside_interfaces[count.index].id
  }

  network_interface {
    device_index = 2
    network_interface_id = aws_network_interface.inside_interfaces[count.index].id
  }
}

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
