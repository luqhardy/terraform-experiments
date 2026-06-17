# 1. Create the IAM Role for EC2
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 2. Create the Policy allowing access to your specific bucket
resource "aws_iam_policy" "s3_access_policy" {
  name = "s3-bucket-access-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.my_bucket.arn,
        "${aws_s3_bucket.my_bucket.arn}/*"
      ]
    }]
  })
}

# 3. Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# 4. Create the Instance Profile (required to attach to EC2)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# 5. Attach the profile to your EC2 instance
resource "aws_instance" "my_server" {
  ami                  = "ami-0c55b159cbfafe1f0" # Replace with your AMI
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = { Name = "S3-Connected-Instance" }
}

# Define your bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name-123"
}
