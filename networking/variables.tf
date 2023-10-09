variable "vpc_cidr" {
  type        = string
  description = "Custom VPC"
  default     = "10.0.0.0/16"
}

#variable "public_subnet_cidrs" {
#  type        = list(string)
#  description = "Public Subnet CIDR values"
#  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#}

#variable "private_subnet_cidrs" {
#  type        = list(string)
#  description = "Private Subnet CIDR values"
#  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
#}

variable "subnet_cidr_bits" {
  type        = number
  description = "Number of bits borrowed from the original cidr i.e VPC cidr for subnetting"
  default     = 8
}

variable "azs" {
  type        = number
  description = "Availability Zones"
  default     = 3
}

data "aws_availability_zones" "available" {
  state = "available"
}