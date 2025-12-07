locals {
  # Bucket logic
  bucket_name = (
    var.bucket_name != null
    ? var.bucket_name
    : "${var.project_id}-${var.function_name}-src"
  )

  bucket_location = coalesce(var.bucket_location, var.region)

  # Service account
  service_account_email = coalesce(
    var.service_account_email,
    try(google_service_account.function_sa.email, null)
  )

  # Trigger service account
  trigger_sa_create = (
    var.trigger_config != null &&
    var.trigger_config.service_account_email == null
  )

  trigger_sa_email = (
    var.trigger_config != null ?
    coalesce(
      var.trigger_config.service_account_email,
      try(google_service_account.trigger_sa.email, null)
    )
    : null
  )
}

# ------------------------------------------------------------------------------
# OPTIONAL BUCKET CREATION
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "function_bucket" {
  count = var.bucket_name == null ? 1 : 0

  name          = local.bucket_name
  project       = var.project_id
  location      = local.bucket_location
  force_destroy = true

  uniform_bucket_level_access = true
}

# ------------------------------------------------------------------------------
# SOURCE ZIP UPLOAD
# ------------------------------------------------------------------------------
data "archive_file" "source_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/archive/${var.function_name}.zip"
}

resource "google_storage_bucket_object" "source_zip" {
  name   = "${var.function_name}-${data.archive_file.source_zip.output_md5}.zip"
  bucket = local.bucket_name
  source = data.archive_file.source_zip.output_path
}

# ------------------------------------------------------------------------------
# OPTIONAL SERVICE ACCOUNT
# ------------------------------------------------------------------------------
resource "google_service_account" "function_sa" {
  count        = var.service_account_email == null ? 1 : 0
  project      = var.project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for ${var.function_name}"
}

resource "google_service_account" "trigger_sa" {
  count        = local.trigger_sa_create ? 1 : 0
  project      = var.project_id
  account_id   = "${var.function_name}-trigger-sa"
  display_name = "Trigger Service Account for ${var.function_name}"
}

# ------------------------------------------------------------------------------
# CLOUD FUNCTION GEN2
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "function" {
  name     = var.function_name
  project  = var.project_id
  location = var.region
  description = var.description

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = local.bucket_name
        object = google_storage_bucket_object.source_zip.name
      }
    }

    environment_variables = var.build_environment_variables
  }

  service_config {
    service_account_email            = local.service_account_email
    environment_variables            = var.environment_variables
    max_instance_count               = var.max_instance_count
    min_instance_count               = var.min_instance_count
    available_memory                 = var.available_memory
    timeout_seconds                  = var.timeout_seconds
    ingress_settings                 = var.ingress_settings
    vpc_connector                    = var.vpc_connector
    vpc_connector_egress_settings    = var.vpc_connector_egress_settings

    dynamic "secret_environment_variables" {
      for_each = var.secret_environment_variables
      iterator = s
      content {
        key        = s.value.key
        secret     = s.value.secret
        project_id = s.value.project_id
        version    = coalesce(s.value.version, "latest")
      }
    }

    dynamic "secret_volumes" {
      for_each = var.secret_volumes
      iterator = sv
      content {
        mount_path = sv.value.mount_path
        secret = sv.value.secret
        project_id = sv.value.project_id

        dynamic "versions" {
          for_each = sv.value.versions
          content {
            version = versions.value.version
            path    = versions.value.path
          }
        }
      }
    }
  }

  dynamic "event_trigger" {
    for_each = var.trigger_config != null ? [1] : []
    content {
      event_type            = var.trigger_config.event_type
      trigger_region        = coalesce(var.trigger_config.region, var.region)
      pubsub_topic          = var.trigger_config.pubsub_topic
      retry_policy          = coalesce(var.trigger_config.retry_policy, "RETRY_POLICY_DO_NOT_RETRY")
      service_account_email = local.trigger_sa_email

      dynamic "event_filters" {
        for_each = var.trigger_config.event_filters
        iterator = f
        content {
          attribute = f.value.attribute
          value     = f.value.value
          operator  = f.value.operator
        }
      }
    }
  }

  labels = var.labels
}

# ------------------------------------------------------------------------------
# IAM — INVOKERS
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function_iam_binding" "invoker" {
  count = length(var.invoker_members) > 0 ? 1 : 0

  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.function.name

  role    = "roles/cloudfunctions.invoker"
  members = var.invoker_members
}
