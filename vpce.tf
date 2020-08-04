resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = data.aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_id]
  security_group_ids  = [aws_security_group.allow_vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = data.aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_id]
  security_group_ids  = [aws_security_group.allow_vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "events" {
  vpc_id              = data.aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.events"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_id]
  security_group_ids  = [aws_security_group.allow_vpce.id]
  private_dns_enabled = true
}


resource "aws_security_group" "allow_vpce" {
  name        = "allow_vpce"
  description = "Allow access to the VPCE"
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
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }
}
