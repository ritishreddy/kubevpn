provider "aws" {
  region = "ap-southeast-2"  # Set your desired AWS region here
}

resource "aws_vpc" "kubevpn" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "kubevpn"
  }
}

# Define the availability zones in the region
variable "availability_zones" {
  default = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
}

# Create three subnets in different availability zones
resource "aws_subnet" "kubevpn_subnets" {
  count = length(var.availability_zones)
  vpc_id     = aws_vpc.kubevpn.id
  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true  # Enable public IPs for instances in these subnets
  tags = {
    Name = "kubevpn-subnet-${element(var.availability_zones, count.index)}"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "kubevpn_igw" {
  vpc_id = aws_vpc.kubevpn.id
}

# Create a route table
resource "aws_route_table" "kubevpn_route_table" {
  vpc_id = aws_vpc.kubevpn.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kubevpn_igw.id
  }
}

# Associate subnets with the route table
resource "aws_route_table_association" "kubevpn_subnet_associations" {
  count          = length(aws_subnet.kubevpn_subnets)
  subnet_id      = aws_subnet.kubevpn_subnets[count.index].id
  route_table_id = aws_route_table.kubevpn_route_table.id
}
# Define a security group that allows all inbound and outbound traffic
resource "aws_security_group" "kubevpn_sg" {
  name        = "kubevpn-sg"
  description = "Security group for kubevpn instances"

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.kubevpn.id
}

# Create three Ubuntu EC2 instances
resource "aws_instance" "kubevpn_instances" {
  count         = 3
  ami           = "ami-0310483fb2b488153"  # Ubuntu 20.04 LTS AMI ID for ap-southeast-2
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.kubevpn_subnets[*].id, count.index)

  security_groups = [aws_security_group.kubevpn_sg.name]

  tags = {
    Name = "kubevpn-instance-${count.index}"
  }
}
