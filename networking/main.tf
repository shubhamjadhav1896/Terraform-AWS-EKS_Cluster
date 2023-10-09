#VPC CREATION
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name                                = "New_VPC"
    "kubernetes.io/cluster/NEW-cluster" = "shared"

  }
}

#PUBLIC SUBNET CREATION BLOCK
resource "aws_subnet" "public_subnets" {
  depends_on = [
    aws_vpc.main
  ]
  count                   = var.azs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                = "Public Subnet ${count.index + 1}"
    "kubernetes.io/cluster/NEW-cluster" = "shared"
    "kubernetes.io/role/elb"            = 1
  }
}

#PRIVATE SUBNET CREATION BLOCK
resource "aws_subnet" "private_subnets" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public_subnets
  ]
  count             = var.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index + var.azs)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name                                = "Private Subnets ${count.index + 1}"
    "kubernetes.io/cluster/NEW-cluster" = "shared"
    "kubernetes.io/role/elb"            = 1
  }
}

#SECURITY GROUP FOR PUBLIC SUBNET
resource "aws_security_group" "public_sg" {
  name   = "public_sg"
  vpc_id = aws_vpc.main.id

  tags = {
    name = "public_sg"
  }
}

#SECURITY GROUP TRAFFIC RULES FOR PUBLIC SUBNET SG
resource "aws_security_group_rule" "sg_ingress_public_443" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg_ingress_public_80" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg_egress_public" {
  security_group_id = aws_security_group.public_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" #egress traffic for all protocols is allowed
  cidr_blocks       = ["0.0.0.0/0"]
}

#SECURITY GROUP FOR DATA PLANE
resource "aws_security_group" "data_plane_sg" {
  name   = "data_plane_sg"
  vpc_id = aws_vpc.main.id

  tags = {
    name = "data_plane_sg"
  }
}

#SECURITY GROUP TRAFFIC RULES FOR DATA PLANE SG
resource "aws_security_group_rule" "nodes" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1 #ingress traffic for all protocols is allowed
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])

}

resource "aws_security_group_rule" "nodes_inbound" {
  description       = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "ingress"
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "nodes_outbound" {
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

#SECURITY GROUP FOR CONTROL PLANE
resource "aws_security_group" "control_plane_sg" {
  name   = "control_plane_sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "control_plane_sg"
  }
}

# SECURITY GROUP TRAFFIC RULES FOR CONTROL PLANE SG
resource "aws_security_group_rule" "control_plane_inbound" {
  security_group_id = aws_security_group.control_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "control_plane_outbound" {
  security_group_id = aws_security_group.control_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

#INTERNET GATEWAY CREATION
resource "aws_internet_gateway" "igw" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public_subnets,
    aws_subnet.private_subnets
  ]
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Demo VPC IGW"
  }
}


#SECONDARY ROUTE TABLE CREATION
resource "aws_route_table" "second_rt" {
  depends_on = [
    aws_vpc.main,
    aws_internet_gateway.igw
  ]
  vpc_id = aws_vpc.main.id

  #NAT Rule
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "2nd Route Table"
  }
}



#PUBLIC SUBNET ASSOCAITION TO 2nd ROUTE TABLE
resource "aws_route_table_association" "public_subnet_asso" {
  count = var.azs

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.second_rt.id
}

#CREATING ELASTIC IP FOR NAT_GATEWAY
resource "aws_eip" "NAT-GATEWAY-EIP" {
  depends_on = [
    aws_route_table_association.public_subnet_asso
  ]
  vpc = true
}


#NAT GATEWAY CREATION
resource "aws_nat_gateway" "NAT_GATEWAY" {
  depends_on = [
    aws_eip.NAT-GATEWAY-EIP
  ]

  allocation_id = aws_eip.NAT-GATEWAY-EIP.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = {
    Name = "Demo_NAT_GATEWAY"
  }
}


#THIRD ROUTE TABLE CREATION
resource "aws_route_table" "third_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GATEWAY.id
  }

  tags = {
    Name = "3rd Route Table"
  }
}

#PRIVATE SUBNET ASSOCAITION TO 3rd ROUTE TABLE
resource "aws_route_table_association" "private_subnet_asso" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public_subnets,
    aws_subnet.private_subnets,
    aws_route_table.second_rt
  ]
  count          = var.azs
   subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.third_rt.id
}

