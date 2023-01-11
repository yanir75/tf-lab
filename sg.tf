resource "aws_s3_bucket" "bucket" {
  bucket = "my-tf-best-bucket"

}

resource "aws_s3_bucket_acl" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.bucket.id
  key    = "peering.tf"
  content = templatefile(
    "upload/peering.tf",
    {
        important_vpc_id = module.vpc_important.vpc_id
        vpc_id = module.vpc.vpc_id
        important_route_table_id =  module.vpc_important.private_route_table_ids[0]
        vpc_route_table_id = module.vpc.private_route_table_ids[0]
        important_vpc_cidr = module.vpc_important.vpc_cidr_block
        vpc_cidr = module.vpc.vpc_cidr_block
        peering_id = aws_vpc_peering_connection.peering.id
    }
  )

}


module "vpc_important" {
  source = "./modules/vpc"

  name = "${var.vpc_name}_important"
  cidr = var.vpc_cidr_important

  azs             = data.aws_availability_zones.available.zone_ids
  private_subnets = ["${local.subnet_prefix_important}.0.0/24", "${local.subnet_prefix_important}.1.0/24", "${local.subnet_prefix_important}.2.0/24"]
  public_subnets  = ["${local.subnet_prefix_important}.3.0/24", "${local.subnet_prefix_important}.4.0/24", "${local.subnet_prefix_important}.5.0/24"]
  enable_dns_hostnames = true
  enable_nat_gateway = true
  single_nat_gateway = true
}


resource "aws_security_group" "sg_instace" {
  name        = "sg_instace"
  description = "allow other vpc communication"
  vpc_id      = module.vpc_important.vpc_id

  ingress {
    description      = "Allow other vpc communication"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sg_instace"
  }
}

data "aws_iam_policy_document" "sg_instance" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sg_instance" {
  name               = "sg_instance"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.sg_instance.json
}




resource "aws_iam_policy" "sg_instance" {
  name   = "sg_instance"
  path   = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeSecurityGroups*",
          "ec2:AuthorizeSecurityGroupIngress"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


resource "aws_iam_role_policy_attachment" "sg" {
  role       = aws_iam_role.sg_instance.name
  policy_arn = aws_iam_policy.sg_instance.arn
}

resource "aws_iam_instance_profile" "sg_instance" {
  name = "sg_instance"
  role = aws_iam_role.sg_instance.name
}

resource "aws_instance" "sg_instance" {

    subnet_id = module.vpc_important.private_subnets[0]
    iam_instance_profile = aws_iam_instance_profile.sg_instance.name
    associate_public_ip_address = false
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.server-flask.key_name
  vpc_security_group_ids = [aws_security_group.sg_instace.id]
  tags = {
    Name = "security group modifier"
  }
}
