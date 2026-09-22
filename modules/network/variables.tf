variable "name" {
  description = "Prefix for named resources, e.g. \"auditflow-dev\"."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ. Cheaper; less resilient to an AZ outage. Fine for dev, worth turning off for prod."
  type        = bool
  default     = true
}

variable "nat_gateway_enabled" {
  description = "Create NAT gateway(s) for the private subnets. false leaves them with no route out, which is fine while nothing runs in them; the S3 gateway endpoint still works."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
