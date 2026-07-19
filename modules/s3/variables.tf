variable "bucket_name" {
  type = string
}

variable "kms_key_arn" {
  description = "CMK used to encrypt objects at rest (see modules/kms)."
  type        = string
}

variable "object_lock_retention_days" {
  description = "Minimum retention for evidence objects under S3 Object Lock, COMPLIANCE mode - not even the account root can delete or shorten this."
  type        = number
  default     = 365
}

variable "tags" {
  type    = map(string)
  default = {}
}
