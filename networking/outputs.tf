output "vpc-id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}


output "public_subnets" {
  description = "List of IDs of Public Subnets"
  value       = aws_subnet.public_subnets
}

output "private_subnets" {
  description = "List of IDs of Private Subnets"
  value       = aws_subnet.private_subnets
}