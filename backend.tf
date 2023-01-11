resource "aws_security_group" "backend" {
  name        = "allow_frontend_backend"
  description = "Allow frontend backend communication"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "Allow frontend backend communication"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups       = [aws_security_group.allow_me.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_frontend_backend"
  }
}

data "aws_iam_policy_document" "backend_server" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend_server" {
  name               = "backend_serverr"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.backend_server.json
}



data "aws_iam_policy_document" "lambda_allow" {
  statement {
    sid = "allowLambda"

    actions = [
      "lambda:List*",
    ]

    resources = [
      "*",
    ]
  }

    statement {
    sid = "allowDownloadLambda"

    actions = [
      "lambda:Get*",
      "lambda:InvokeFunction",
      "lambda:UpdateFunctionCode"
    ]

    resources = [
      aws_lambda_function.get_lambda.arn
    ]
  }



}

resource "aws_iam_role_policy_attachment" "attach_invoke" {
  role       = aws_iam_role.backend_server.name
  policy_arn = aws_iam_policy.lambda_allow.arn
}

resource "aws_iam_policy" "lambda_allow" {
  name   = "lambda_allow"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda_allow.json
}

resource "aws_iam_instance_profile" "backend_server" {
  name = "backend_server"
  role = aws_iam_role.backend_server.name
}

resource "aws_instance" "backend" {
    subnet_id = module.vpc.private_subnets[0]
    iam_instance_profile = aws_iam_instance_profile.backend_server.name
    associate_public_ip_address = false
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.server-flask.key_name
  vpc_security_group_ids = [aws_security_group.backend.id]

  tags = {
    "Name" = "backend"
  }

}