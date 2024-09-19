resource "aws_vpc" "eks_vpc" {
  # About 65,000 IPs
  cidr_block = "10.0.0.0/16"
  # These tags are used to query the VPC in api terraform.
  tags = {
    name     = "over-reacted-cluster-vpc"
    resource = "eks-demo"
  }
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Default security group of VPC. Doesn't allow any inbound and outbound traffic.
resource "aws_default_security_group" "eks_vpc_default_security_group" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    name     = "over-reacted-cluster-vpc"
    resource = "eks-demo"
  }
}

locals {
  // 4096 IPs assigned to each subnet. // we can do about 16 subnets.
  eks_vpc_public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  eks_vpc_private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]
  azs                          = ["${var.AWS_REGION}a", "${var.AWS_REGION}b"]
}

resource "aws_subnet" "eks_vpc_public_subnets" {
  count             = length(local.eks_vpc_public_subnet_cidrs)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = element(local.eks_vpc_public_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = {
    name     = "public-subnet-${count.index + 1}"
    resource = "eks-demo"
    tier     = "public"
    # These tags are required by K8s control plane.
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "eks_vpc_private_subnets" {
  count             = length(local.eks_vpc_private_subnet_cidrs)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = element(local.eks_vpc_private_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = {
    name                                          = "private-subnet-${count.index + 1}"
    resource                                      = "eks-demo"
    tier                                          = "private"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

# Associate public subnets with Internet gateway.
resource "aws_internet_gateway" "eks_vpc_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    resource    = "over-reacted-cluster-vpc"
    description = "over-reacted-cluster-vpc Internet Gateway"
  }
}

resource "aws_route_table" "eks_vpc_public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_vpc_igw.id
  }

  tags = {
    name        = "over-reacted-cluster-vpc-public-table"
    resource    = "over-reacted-cluster-vpc"
    Description = "Route table for over-reacted-cluster-vpc VPC public subnets"
  }
}

resource "aws_route_table_association" "eks_vpc_public_subnet_asso" {
  count          = length(local.eks_vpc_public_subnet_cidrs)
  subnet_id      = element(aws_subnet.eks_vpc_public_subnets[*].id, count.index)
  route_table_id = aws_route_table.eks_vpc_public_route_table.id
}


# Associate private subnets with NAT gateway. NAT gateway is how private subnets communicate with the internet.

# Elastic IP for NAT.
resource "aws_eip" "eks_vpc_nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.eks_vpc_igw]
}

resource "aws_nat_gateway" "eks_vpc_nat" {
  allocation_id = aws_eip.eks_vpc_nat_eip.id
  # Create this NAT gateway in a public subnet.
  subnet_id  = element(aws_subnet.eks_vpc_public_subnets[*].id, 0)
  depends_on = [aws_internet_gateway.eks_vpc_igw]
  tags = {
    name        = "over-reacted-cluster-vpc-NAT"
    resource    = "over-reacted-cluster-vpc"
    Description = "NAT Gateway for private subnets"
  }
}

resource "aws_route_table" "eks_vpc_private_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_vpc_nat.id
  }
  tags = {
    Name        = "over-reacted-cluster-private-table"
    Resource    = "eks-vpc"
    Description = "Route table for eks_vpc VPC private subnets"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(local.eks_vpc_private_subnet_cidrs)
  subnet_id      = element(aws_subnet.eks_vpc_private_subnets[*].id, count.index)
  route_table_id = aws_route_table.eks_vpc_private_route_table.id
}