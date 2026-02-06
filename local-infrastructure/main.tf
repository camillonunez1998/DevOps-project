terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = "eu-north-1"
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

