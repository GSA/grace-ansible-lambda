resource "aws_vpc_endpoint" "ec2" {
  vpc_id       = data.aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.ec2"
  security_group_ids = [aws_security_group.allow_ec2_vpce.id]
}

resource "aws_security_group" "allow_ec2_vpce" {
  name        = "allow_ec2_vpce"
  description = "Allow access to the EC2 VPCE"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}