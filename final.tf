


resource "aws_security_group" "final_instance" {
  name        = "final_instance"
  description = "Allow my ip"
  vpc_id      = module.vpc_important.vpc_id



  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "final_instace"
  }
}

data "aws_iam_policy_document" "final_instance" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "final_instance" {
  name               = "final_instance"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.final_instance.json
}




resource "aws_iam_policy" "final_instance" {
  name   = "final_instance"
  path   = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


resource "aws_iam_role_policy_attachment" "final" {
  role       = aws_iam_role.final_instance.name
  policy_arn = aws_iam_policy.final_instance.arn
}

resource "aws_iam_instance_profile" "final_instance" {
  name = "final_instance"
  role = aws_iam_role.final_instance.name
}

resource "aws_instance" "final_instance" {
    subnet_id = module.vpc_important.private_subnets[0]
    iam_instance_profile = aws_iam_instance_profile.final_instance.name
    associate_public_ip_address = false
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.server-flask.key_name
  vpc_security_group_ids = [aws_security_group.final_instance.id]
  tags = {
    "Name" = "final"
  }

}
