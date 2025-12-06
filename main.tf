# modules/cloud-function/main.tf

locals {
  bucket = {
    name     = var.bucket_name != null ? var.bucket_name : "${var.project_id}-${var.function_name}-cf-bucket"
    location = var.bucket_location != null ? var.bucket_location : var.region
  }

  prefix                = var.prefix == null ? "" : "${var.prefix}-"
  service_account_email = var.service_account_email != null ? var.service_account_email : google_service_account.default[0].email
}

# Storage Bucket for Function Source
resource "google_storage_bucket" "bucket" {
  count = var.bucket_name == null ? 1 : 0

  project       = var.project_id
  name          = local.bucket.name
  location      = local.bucket.location
  force_destroy = var.bucket_force_destroy

  uniform_bucket_level_access = var.uniform_bucket_level_access

  labels = var.bucket_labels

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_delete_age_days != null ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age        = var.lifecycle_delete_age_days
        with_state = "ARCHIVED"
      }
    }
  }

  dynamic "versioning" {
    for_each = var.lifecycle_delete_age_days != null ? [1] : []
    content {
      enabled = true
    }
  }
}

# Archive Function Source
data "archive_file" "bundle" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.terraform/archive/${var.function_name}.zip"
}

# Upload Source to GCS
resource "google_storage_bucket_object" "bundle" {
  name   = "bundle-${data.archive_file.bundle.output_md5}.zip"
  bucket = var.bucket_name != null ? var.bucket_name : google_storage_bucket.bucket[0].name
  source = data.archive_file.bundle.output_path
}

# Service Account for Function
resource "google_service_account" "default" {
  count = var.service_account_email == null ? 1 : 0

  project      = var.project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service account for ${var.function_name}"
}

# Service Account for Trigger
resource "google_service_account" "trigger" {
  count = local.trigger_sa_create ? 1 : 0

  project      = var.project_id
  account_id   = "${var.function_name}-trigger-sa"
  display_name = "Trigger service account for ${var.function_name}"
}

# Cloud Function Gen2
resource "google_cloudfunctions2_function" "function" {
  project  = var.project_id
  location = var.region
  name     = var.function_name

  description = var.description

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = var.bucket_name != null ? var.bucket_name : google_storage_bucket.bucket[0].name
        object = google_storage_bucket_object.bundle.name
      }
    }

    environment_variables = var.build_environment_variables
    docker_repository     = var.docker_repository

    dynamic "automatic_update_policy" {
      for_each = var.enable_automatic_updates == true ? [1] : []
      content {}
    }

    dynamic "on_deploy_update_policy" {
      for_each = var.enable_on_deploy_update_policy == true ? [1] : []
      content {}
    }
  }

  service_config {
    max_instance_count               = var.max_instance_count
    min_instance_count               = var.min_instance_count
    available_memory                 = var.available_memory
    available_cpu                    = var.available_cpu
    timeout_seconds                  = var.timeout_seconds
    max_instance_request_concurrency = var.max_instance_request_concurrency
    environment_variables            = var.environment_variables
    ingress_settings                 = var.ingress_settings
    all_traffic_on_latest_revision   = var.all_traffic_on_latest_revision
    service_account_email            = local.service_account_email
    vpc_connector                    = var.vpc_connector != null ? var.vpc_connector.name : null
    vpc_connector_egress_settings    = var.vpc_connector_egress_settings != null ? var.vpc_connector_egress_settings : (var.vpc_connector != null ? try(var.vpc_connector.egress_settings, null) : null)

    dynamic "secret_environment_variables" {
      for_each = var.secret_environment_variables
      iterator = secret
      content {
        key        = secret.value.key
        project_id = secret.value.project_id
        secret     = secret.value.secret
        version    = try(secret.value.version, "latest")
      }
    }

    dynamic "secret_volumes" {
      for_each = var.secret_volumes
      iterator = secret
      content {
        mount_path = secret.value.mount_path
        project_id = secret.value.project_id
        secret     = secret.value.secret

        dynamic "versions" {
          for_each = secret.value.versions
          iterator = version
          content {
            version = version.value.version
            path    = version.value.path
          }
        }
      }
    }
  }

  dynamic "event_trigger" {
    for_each = var.trigger_config != null ? [1] : []
    content {
      trigger_region        = try(var.trigger_config.region, var.region)
      event_type            = var.trigger_config.event_type
      pubsub_topic          = var.trigger_config.pubsub_topic
      retry_policy          = try(var.trigger_config.retry_policy, "RETRY_POLICY_DO_NOT_RETRY")
      service_account_email = local.trigger_sa_email

      dynamic "event_filters" {
        for_each = try(var.trigger_config.event_filters, [])
        iterator = filter
        content {
          attribute = filter.value.attribute
          value     = filter.value.value
          operator  = try(filter.value.operator, null)
        }
      }
    }
  }

  labels = var.labels
}

# IAM Binding for Invokers
resource "google_cloudfunctions2_function_iam_binding" "invoker" {
  count = length(var.invoker_members) > 0 ? 1 : 0

  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.function.name

  role    = "roles/cloudfunctions.invoker"
  members = var.invoker_members
}

# IAM Binding for Trigger Service Account
resource "google_cloudfunctions2_function_iam_member" "trigger_invoker" {
  count = local.trigger_sa_email != null ? 1 : 0

  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${local.trigger_sa_email}"
}