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

#Create the compose.yaml file
cat <<EOF > /home/ec2-user/compose.yaml
${compose_content}
EOF