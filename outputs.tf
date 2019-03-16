output "Private IP address" {
  description = "Private IP address"
  value       = ["${google_compute_instance.test.*.network_interface.0.network_ip}"]
}

output "Public IP address" {
  description = "Public IP address"
  value       = ["${google_compute_instance.test.*.network_interface.0.access_config.0.nat_ip}"]
}
