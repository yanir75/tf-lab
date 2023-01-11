data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  subnet_prefix = join(".",[split(".", var.vpc_cidr)[0],split(".", var.vpc_cidr)[1]])
  subnet_prefix_important = join(".",[split(".", var.vpc_cidr_important)[0],split(".", var.vpc_cidr_important)[1]])
}

module "vpc" {
  source = "./modules/vpc"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.zone_ids
  private_subnets = ["${local.subnet_prefix}.0.0/24", "${local.subnet_prefix}.1.0/24", "${local.subnet_prefix}.2.0/24"]
  public_subnets  = ["${local.subnet_prefix}.3.0/24", "${local.subnet_prefix}.4.0/24", "${local.subnet_prefix}.5.0/24"]
  enable_dns_hostnames = true
  enable_nat_gateway = true
  single_nat_gateway = true
}

data "aws_iam_policy_document" "flask-server" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "list_and_get" {
  statement {
    sid = "ListSecrets"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:List*",
      "ec2:DescribeInstances",
    ]

    resources = [
      "*",
    ]
  }

    statement {
    sid = "GetSpecificSecret"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.secret_flask.arn
    ]
  }


}

resource "aws_iam_policy" "secret_access" {
  name   = "AllowLimitedSecretAccess"
  path   = "/"
  policy = data.aws_iam_policy_document.list_and_get.json
}

resource "aws_iam_role_policy_attachment" "allow_list_secret" {
    role       = aws_iam_role.flask-server.name
  policy_arn = aws_iam_policy.secret_access.arn
}

resource "aws_iam_role" "flask-server" {
  name               = "flask-server"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.flask-server.json
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "secret_flask" {
  name = "private_key_pem-${uuid()}"
}

resource "aws_secretsmanager_secret_version" "secret_flask" {
  secret_id     = aws_secretsmanager_secret.secret_flask.id
  secret_string = tls_private_key.key.private_key_pem
}

resource "local_file" "foo" {
    file_permission = "0400"
    content  = tls_private_key.key.private_key_pem
    filename = "key.pem"
}

resource "aws_key_pair" "server-flask" {
  key_name   = "deployer-key"
  public_key = tls_private_key.key.public_key_openssh
}



data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "allow_me" {
  name        = "allow_my_ip"
  description = "Allow my ip"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "Allow my ip"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_my_ip"
  }
}
resource "aws_iam_instance_profile" "flask-server" {
  name = "flask-server"
  role = aws_iam_role.flask-server.name
}

resource "aws_instance" "flask" {
    subnet_id = module.vpc.public_subnets[0]
    iam_instance_profile = aws_iam_instance_profile.flask-server.name
    associate_public_ip_address = true
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.server-flask.key_name
  vpc_security_group_ids = [aws_security_group.allow_me.id]
      connection {
        host = self.public_ip
    type     = "ssh"
    user     = "ubuntu"
    private_key = tls_private_key.key.private_key_pem
  }
  provisioner "file" {
    source      = "app/"
    destination = "/home/ubuntu/"

  }

provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y software-properties-common",
      "sudo add-apt-repository -y ppa:deadsnakes/ppa",
      "sudo apt update",
      "sudo apt install -y python3.8",
      "sudo apt install -y python3-pip",
      "sudo pip3 install Flask",
      "sudo nohup python3 /home/ubuntu/flask-2048/run.py &"
    ]
  }
  tags = {
    "Name" = "frontend"
  }
}