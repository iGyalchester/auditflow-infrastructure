variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "evidence_bucket_arn" {
  type = string
}

variable "release_label" {
  description = "EMR release to run Spark batch jobs on (anomaly-detection scoring over the evidence lake)."
  type        = string
  default     = "emr-7.1.0"
}

variable "max_concurrent_vcpus" {
  type    = number
  default = 32
}

variable "tags" {
  type    = map(string)
  default = {}
}
