#Address for the configuration
output "lb_ip" {
  value = aws_lb.load_balancer.dns_name
}