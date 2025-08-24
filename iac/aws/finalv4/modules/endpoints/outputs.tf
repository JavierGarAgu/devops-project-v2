output "vpc_endpoint_ids" {
  value = [for ep in aws_vpc_endpoint.interface : ep.id]
}
