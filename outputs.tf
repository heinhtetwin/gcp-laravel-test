output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.http.ip_address
}

output "cloudsql_connection_name" {
  value = google_sql_database_instance.main.connection_name
}
