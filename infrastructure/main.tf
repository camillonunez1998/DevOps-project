resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.32.0/20"
  availability_zone       = "eu-north-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
}

resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "subnet_3_association" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.route_table.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "devops-project"
  cluster_version = "1.30"

  # This grants the IAM principal creating the cluster 
  # administrator permissions within the Kubernetes cluster. Without this, 
  # AWS IAM "Full Access" is not enough to run kubectl commands.
  enable_cluster_creator_admin_permissions = true

  # This enables the EKS Access Entry API, which is the modern way to manage 
  # cluster permissions without manually editing the aws-auth ConfigMap.
  authentication_mode = "API_AND_CONFIG_MAP"

  cluster_endpoint_public_access = true

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]

  eks_managed_node_groups = {
    green = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }
}

# Bucket Definition
resource "aws_s3_bucket" "qr_code_bucket" {
  bucket = "qr-code-bucket-camilo"
  
  # Optional: Prevents accidental deletion of the bucket
  force_destroy = true 
}

# Ownership Controls (Mandatory to enable ACLs)
# This defines that you own the objects uploaded, allowing the use of 'public-read'
resource "aws_s3_bucket_ownership_controls" "qr_bucket_ownership" {
  bucket = aws_s3_bucket.qr_code_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Public Access Block (The master switch)
# This must be false to allow any kind of public interaction
resource "aws_s3_bucket_public_access_block" "qr_bucket_access" {
  bucket = aws_s3_bucket.qr_code_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket ACL (Grants the 'public-read' permission at the bucket level)
# This depends on both ownership and the public access block being ready
resource "aws_s3_bucket_acl" "qr_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.qr_bucket_ownership,
    aws_s3_bucket_public_access_block.qr_bucket_access,
  ]

  bucket = aws_s3_bucket.qr_code_bucket.id
  acl    = "public-read"
}

# Bucket Policy (Final layer for public access via URL)
resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.qr_code_bucket.id
  
  depends_on = [aws_s3_bucket_public_access_block.qr_bucket_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadWrite"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.qr_code_bucket.arn}/*"
      },
    ]
  })
}

