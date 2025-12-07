variable "project_id" { type = string }
variable "region"     { type = string }

variable "function_name" { type = string }
variable "description" { type = string, default = "" }

variable "runtime"      { type = string }
variable "entry_point"  { type = string }
variable "source_dir"   { type = string }

# Optional bucket override
variable "bucket_name"     { type = string, default = null }
variable "bucket_location" { type = string, default = null }

# Build & runtime environment variables
variable "environment_variables"      { type = map(string), default = {} }
variable "build_environment_variables" { type = map(string), default = {} }

# Optional SA
variable "service_account_email" { type = string, default = null }

# Compute settings
variable "max_instance_count" { type = number, default = null }
variable "min_instance_count" { type = number, default = null }
variable "available_memory"   { type = string, default = "256M" }
variable "timeout_seconds"    { type = number, default = 60 }

# VPC connector
variable "vpc_connector" { type = string, default = null }
variable "vpc_connector_egress_settings" {
  type    = string
  default = null
}

# Event trigger
variable "trigger_config" {
  type = object({
    event_type    = string
    pubsub_topic  = optional(string)
    region        = optional(string)
    retry_policy  = optional(string)
    service_account_email = optional(string)
    event_filters = optional(list(object({
      attribute = string
      value     = string
      operator  = optional(string)
    })), [])
  })

  default = null
}

# Secrets
variable "secret_environment_variables" {
  type = map(object({
    key        = string
    project_id = string
    secret     = string
    version    = optional(string)
  }))
  default = {}
}

variable "secret_volumes" {
  type = map(object({
    mount_path = string
    project_id = string
    secret     = string
    versions   = list(object({
      version = string
      path    = string
    }))
  }))
  default = {}
}

# IAM
variable "invoker_members" {
  type    = list(string)
  default = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
