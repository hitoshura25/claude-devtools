# Common Terraform Fixes

## Hardcoded Credentials

<Bad>
provider "aws" { access_key = "AKIA..." }
</Bad>

<Good>
provider "aws" { } # Uses env vars or IAM role
</Good>

## Permissive Security Groups

<Bad>
cidr_blocks = ["0.0.0.0/0"]
</Bad>

<Good>
cidr_blocks = [var.allowed_cidr]
</Good>

## Missing Encryption

<Bad>
resource "aws_s3_bucket" "x" { bucket = "my-bucket" }
</Bad>

<Good>
resource "aws_s3_bucket_server_side_encryption_configuration" "x" {
  bucket = aws_s3_bucket.x.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
</Good>

## Missing Logging

<Bad>
resource "aws_s3_bucket" "x" { bucket = "my-bucket" }
</Bad>

<Good>
resource "aws_s3_bucket_logging" "x" {
  bucket        = aws_s3_bucket.x.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-logs/"
}
</Good>

## Public Access Block Missing

<Bad>
resource "aws_s3_bucket" "x" { bucket = "my-bucket" }
</Bad>

<Good>
resource "aws_s3_bucket_public_access_block" "x" {
  bucket                  = aws_s3_bucket.x.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
</Good>

## RDS Without Deletion Protection

<Bad>
resource "aws_db_instance" "x" {
  instance_class = "db.t3.micro"
}
</Bad>

<Good>
resource "aws_db_instance" "x" {
  instance_class       = "db.t3.micro"
  deletion_protection  = true
  storage_encrypted    = true
  backup_retention_period = 7
}
</Good>
