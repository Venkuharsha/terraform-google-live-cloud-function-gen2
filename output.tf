output "function_name" {
  description = "Name of the Cloud Function (Gen2)."
  value       = google_cloudfunctions2_function.tlz_function.name
}

output "function_location" {
  description = "Location of the Cloud Function."
  value       = google_cloudfunctions2_function.tlz_function.location
}

output "service_account_email" {
  description = "Service account email used by the function."
  value       = local.service_account_email
}

output "bucket_name" {
  description = "Bucket name used for the function source."
  value       = local.bucket
}

output "trigger_service_account_email" {
  description = "Trigger service account email, if created."
  value       = local.trigger_sa_email
}