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
