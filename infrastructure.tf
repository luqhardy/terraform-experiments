#provider "aws" {
#	region = ""
#	access_key = ""
#	secret_key = ""
#}
#
#resource "aws_ec2" "name" {
#	key1 = "value1"
#	key2 = "value2"
#
#}
# ------------------------------------------------------
# OPTIONAL: NAT GATEWAY (Commented out to prevent charges)
# Uncomment this section if your private EC2 instance needs 
# outbound internet access (e.g., to run yum update).
# Note: AWS charges an hourly rate for NAT Gateways.
# ------------------------------------------------------

/*
# 1. Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "NAT-EIP" }
}

# 2. Create the NAT Gateway in one of the Public Subnets
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id 
  tags          = { Name = "Main-NAT-GW" }

  # Ensures the IGW exists before creating the NAT Gateway
  depends_on = [aws_internet_gateway.igw]
}

# 3. Create a Route Table for the Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  
  tags = { Name = "Private-Route-Table" }
}

# 4. Associate the Private Route Table with your Private Subnet
resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}
*/
