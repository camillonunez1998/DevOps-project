#Declaration of the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

#Declaration of subnet 1
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
#  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

# #Declaration of subnet 2
# resource "aws_subnet" "subnet_2" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.16.0/20"
#   availability_zone       = "eu-north-1b"
#   map_public_ip_on_launch = false
# }


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
# resource "aws_route_table_association" "subnet_2_assoc" {
#   subnet_id      = aws_subnet.subnet_2.id
#   route_table_id = aws_route_table.route_table.id
# }

### Deploying the app in the VPC ###

# 1. Security Group to allow Web Traffic
resource "aws_security_group" "docker_sg" {
  name   = "docker-sg"
  vpc_id = aws_vpc.main.id

  # Allow HTTP (Port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH (Port 22) - Optional, for debugging
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Backend API (Port 8000) for QR generation requests
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (so the server can download Docker)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# This resource registers mi SSH public key in AWS
resource "aws_key_pair" "deployer_key" {
  key_name   = "ssh-key-devops-project"
  public_key = file("~/.ssh/id_rsa_aws.pub") # Route to my public key
}

# 2. The EC2 Instance
resource "aws_instance" "docker_server" {
  ami           = "ami-0ea2ed4258c13b100" # Amazon Linux 2023 in eu-north-1
  #t4g.medium is for architecture arm64
  #instance_type = "t4g.medium"
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.subnet_1.id
  vpc_security_group_ids = [aws_security_group.docker_sg.id]
  key_name = aws_key_pair.deployer_key.key_name

  timeouts {
    create = "5m"
  }
  #Installation of docker, docker compose plugin, and passing the content of the compose.yaml file
  user_data = templatefile("install_docker.sh", {
    compose_content = file("${path.module}/../compose.yaml")
  })
 }
