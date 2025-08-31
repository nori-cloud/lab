module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name}-vpc"
  cidr = local.vpc.cidr

  azs            = local.azs
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc.cidr, 8, k)]

  // this is presumably cheaper when we have less than ~8 ec2 instances
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
