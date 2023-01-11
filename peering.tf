data "aws_caller_identity" "current" {}
resource "aws_vpc_peering_connection" "peering" {
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_vpc_id   = module.vpc_important.vpc_id
  vpc_id        = module.vpc.vpc_id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between public and important vpc"
  }
  
}
