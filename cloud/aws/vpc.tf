resource "aws_vpc" "this" {
  cidr_block = local.vpc.cidr

  tags = {
    Name = "${local.cluster.name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  tags = {
    Name = "${local.cluster.name}-igw"
  }
}

resource "aws_internet_gateway_attachment" "this" {
  vpc_id              = aws_vpc.this.id
  internet_gateway_id = aws_internet_gateway.this.id
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "this" {
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_subnet" "this" {
  for_each          = { for i in range(local.vpc.subnet_count) : i => i }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value)
  availability_zone = local.azs[each.value % length(local.azs)]

  tags = {
    Name = "${local.cluster.name}-subnet-${each.value}"
  }
}

resource "aws_route_table_association" "a" {
  for_each       = aws_subnet.this
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this.id
}
