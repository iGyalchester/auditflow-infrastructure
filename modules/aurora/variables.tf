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

variable "kms_key_arn" {
  type = string
}

variable "database_name" {
  type    = string
  default = "auditflow"
}

variable "master_username" {
  type    = string
  default = "auditflow_admin"
}

variable "min_capacity_acu" {
  description = "Aurora Serverless v2 minimum Aurora Capacity Units."
  type        = number
  default     = 0.5
}

variable "max_capacity_acu" {
  type    = number
  default = 4
}

variable "instance_count" {
  description = "Number of db.serverless instances (1 writer + N-1 readers)."
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "Set false for prod so a final snapshot is taken on destroy."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
