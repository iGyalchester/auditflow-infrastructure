variable "name" {
  type = string
}

variable "evidence_bucket_name" {
  type = string
}

variable "evidence_bucket_arn" {
  type = string
}

variable "crawler_schedule" {
  description = "Cron expression (Glue format) for how often to re-crawl the evidence lake for new partitions."
  type        = string
  default     = "cron(0 3 * * ? *)" # daily at 03:00 UTC
}

variable "tags" {
  type    = map(string)
  default = {}
}
