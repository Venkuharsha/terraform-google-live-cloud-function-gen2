output "function_name" {
  value = google_cloudfunctions2_function.function.name
}

output "function_location" {
  value = google_cloudfunctions2_function.function.location
}

output "service_account_email" {
  value = local.service_account_email
}

output "bucket_name" {
  value = local.bucket_name
}

output "trigger_service_account_email" {
  value = local.trigger_sa_email
}
