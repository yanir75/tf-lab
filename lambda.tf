data "aws_iam_policy_document" "allow_s3" {
  statement {
    sid = "1"

    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.bucket.id}",
    ]
  }

  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.bucket.id}/",
      "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*",
    ]
  }

   statement {
    actions = [
      "ec2:CreateVpcPeeringConnection",
      "ec2:CreateTags",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:AcceptVpcPeeringConnection",
      "ec2:DescribeRouteTables"
    ]

    resources = [
      "*"
    ]
  }


   statement {
    actions = [
      "ec2:CreateRoute",
    ]

    resources = [
      module.vpc_important.table_arn[0],module.vpc.table_arn[0]
    ]
  }
}

resource "aws_iam_policy" "allow_s3" {
  name   = "allow_s3"
  path   = "/"
  policy = data.aws_iam_policy_document.allow_s3.json
}

resource "aws_iam_policy_attachment" "allow_s3" {
  name       = "allow_s3"
  users      = [aws_iam_user.vpc_peering.name]
  policy_arn = aws_iam_policy.allow_s3.arn
}

resource "aws_iam_user" "vpc_peering" {
  name = "vpc_peering"
  path = "/"
}

resource "aws_iam_access_key" "vpc_peering" {
  user = aws_iam_user.vpc_peering.name
}


resource "aws_secretsmanager_secret" "vpc_peering_user" {
  name = "vpc_peering_user-${uuid()}"
}

resource "aws_secretsmanager_secret_version" "vpc_peering_user" {
  secret_id     = aws_secretsmanager_secret.vpc_peering_user.id
  secret_string = "{key = ${aws_iam_access_key.vpc_peering.id} , secret = ${aws_iam_access_key.vpc_peering.secret}}"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "test_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


data "aws_iam_policy_document" "test_lambda" {
  

    statement {
    sid = "GetSpecificSecret"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.vpc_peering_user.arn
    ]
  }


}

resource "aws_iam_policy" "test_lambda" {
  name   = "AllowSecretUserVpcPeering"
  path   = "/"
  policy = data.aws_iam_policy_document.test_lambda.json
}

resource "aws_iam_role_policy_attachment" "test_lambda" {
    role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.test_lambda.arn
}

data "archive_file" "python_lambda_package" {  
  type = "zip"  
  source_file = "lambda/lambda.py" 
  output_path = "lambda/lambda.zip"
}

resource "aws_lambda_function" "get_lambda" {

  filename      = data.archive_file.python_lambda_package.output_path
  function_name = "testLambda"
  role          = aws_iam_role.iam_for_lambda.arn
  runtime       = "python3.9"
  handler       = "lambda.lambda_handler"

  environment {
    variables = {
        vpc_peering = aws_secretsmanager_secret.vpc_peering_user.id
    }
  } 

}