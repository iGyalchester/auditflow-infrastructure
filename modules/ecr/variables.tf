variable "name" {
  description = "Environment-scoped prefix, e.g. auditflow-dev."
  type        = string
}

variable "services" {
  description = "Platform services (name => container port). Must stay in sync with modules/ecs."
  type        = map(number)
  default = {
    api-gateway-service = 8080
    ingestion-service   = 8081
    enrichment-service  = 8082
    alerting-service    = 8083
    reporting-service   = 8084
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
