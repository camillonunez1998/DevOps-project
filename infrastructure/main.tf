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

# 2. The EC2 Instance
resource "aws_instance" "docker_server" {
  ami           = "ami-040750a206b9f6c65" # Amazon Linux 2023 in eu-north-1
  instance_type = "t4g.medium"
  subnet_id     = aws_subnet.subnet_1.id
  vpc_security_group_ids = [aws_security_group.docker_sg.id]

  timeouts {
    create = "5m"
  }
  user_data = <<-EOF
                #!/bin/bash
                # Update system packages
                sudo yum update -y

                # Install Docker via Amazon Linux Extras
                sudo amazon-linux-extras install docker -y
                
                # Start and enable Docker service
                sudo systemctl start docker
                sudo systemctl enable docker

                # Grant ec2-user permissions to run Docker commands
                sudo usermod -aG docker ec2-user

                # Install Docker Compose V2 for ARM64 (aarch64)
                # Create directory for CLI plugins
                sudo mkdir -p /usr/local/lib/docker/cli-plugins/
                
                # Download the ARM64 (aarch64) specific binary
                sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
                
                # Make the binary executable
                sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
                EOF

 }