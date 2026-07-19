variable "name" {
  type = string
}

variable "callback_urls" {
  type    = list(string)
  default = ["http://localhost:5173/callback"]
}

variable "logout_urls" {
  type    = list(string)
  default = ["http://localhost:5173/"]
}

variable "domain_prefix" {
  description = "Prefix for the Cognito Hosted UI domain, e.g. \"auditflow-dev\" -> auditflow-dev.auth.<region>.amazoncognito.com. Must be globally unique."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
