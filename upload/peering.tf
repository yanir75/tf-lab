terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
 # fill in
}

data "aws_caller_identity" "current" {}

# resource "aws_vpc_peering_connection" "peering" {
#   peer_owner_id = data.aws_caller_identity.current.account_id
#   peer_vpc_id   = "${important_vpc_id}"
#   vpc_id        = "${vpc_id}"
#   auto_accept   = true

#   tags = {
#     Name = "VPC Peering between public and important vpc"
#   }
  
# }

resource "aws_route" "private_route_add" {
  route_table_id = "${important_route_table_id}"
  destination_cidr_block = "${vpc_cidr}"
  vpc_peering_connection_id = "${peering_id}"
}

resource "aws_route" "private_route_add_opposite" {
  route_table_id = "${vpc_route_table_id}"
  destination_cidr_block = "${important_vpc_cidr}"
  vpc_peering_connection_id = "${peering_id}"
}