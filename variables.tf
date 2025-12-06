variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Function"
  type        = string
  default     = "us-central1"
}

variable "function_name" {
  description = "Name of the Cloud Function"
  type        = string
}

variable "description" {
  description = "Description of the Cloud Function"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Runtime for the Cloud Function (e.g., python39, nodejs18, go121)"
  type        = string
}

variable "entry_point" {
  description = "Entry point function name"
  type        = string
}

variable "source_archive_bucket" {
  description = "GCS bucket containing the source code"
  type        = string
}

variable "source_archive_object" {
  description = "GCS object containing the source code zip"
  type        = string
}

variable "trigger_http" {
  description = "Enable HTTP trigger"
  type        = bool
  default     = true
}

variable "available_memory_mb" {
  description = "Memory limit in MB"
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 60
}

variable "environment_variables" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "ingress_settings" {
  description = "Ingress settings (ALLOW_ALL, ALLOW_INTERNAL_ONLY, ALLOW_INTERNAL_AND_GCLB)"
  type        = string
  default     = "ALLOW_ALL"
}

variable "service_account_email" {
  description = "Service account email for the function"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to the function"
  type        = map(string)
  default     = {}
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 0
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "vpc_connector" {
  description = "VPC connector name"
  type        = string
  default     = null
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated invocations"
  type        = bool
  default     = false
}