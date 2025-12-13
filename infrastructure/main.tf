#Declaration of the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

#Declaration of subnet 1
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

#Declaration of subnet 1
resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
}

#Declaration of subnet 3
resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.32.0/20"
  availability_zone       = "eu-north-1c"
  map_public_ip_on_launch = true
}

#AWS Internet Gateway Resource
resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.main.id
}

#AWS Route Table Resource
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  # Route to the Internet (0.0.0.0/0)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  # Route for local traffic (within the VPC)
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
}

# Associate the routing table with Subnet 1 to make it truly public
resource "aws_route_table_association" "subnet_1_assoc" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route_table.id
}

# Associate the routing table with Subnet 2
resource "aws_route_table_association" "subnet_2_assoc" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.route_table.id
}

# Associate the routing table with Subnet 3
resource "aws_route_table_association" "subnet_3_assoc" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.route_table.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                  = "devops-project-cluster"
  cluster_version               = "1.29"

  cluster_endpoint_public_access = true

  vpc_id                        = aws_vpc.main.id
  subnet_ids                    = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids      = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]

  eks_managed_node_groups = {
    green = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }
}
