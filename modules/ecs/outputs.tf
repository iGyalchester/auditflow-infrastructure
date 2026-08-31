output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "alb_listener_arn" {
  description = "Internal ALB listener - the API Gateway VPC-link integration target."
  value       = aws_lb_listener.http.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "service_names" {
  value = [for s in aws_ecs_service.service : s.name]
}
