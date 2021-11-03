resource "google_compute_address" "external" {
  name         = "${var.resource_name_prefix}-vault-lb"
  address_type = "EXTERNAL"
}

resource "google_compute_region_health_check" "lb" {
  name = "${var.resource_name_prefix}-vault-lb"

  check_interval_sec = 30
  description        = "The health check of the load balancer for Vault"
  timeout_sec        = 4

  https_health_check {
    port         = 8200
    request_path = var.vault_lb_health_check
  }
}

resource "google_compute_region_backend_service" "lb" {
  health_checks = [google_compute_region_health_check.lb.self_link]
  name          = "${var.resource_name_prefix}-vault-lb"

  description           = "The backend service of the load balancer for Vault"
  load_balancing_scheme = "EXTERNAL"
  port_name             = "https"
  protocol              = "HTTPS"
  timeout_sec           = 10

  backend {
    group = var.instance_group

    balancing_mode  = "UTILIZATION"
    description     = "The instance group of the compute deployment for Vault"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "lb" {
  default_service = google_compute_region_backend_service.lb.self_link
  name            = "${var.resource_name_prefix}-vault-lb"

  description = "The URL map of the internal load balancer for Vault"
}

resource "google_compute_region_target_https_proxy" "lb" {
  name             = "${var.resource_name_prefix}-vault-lb"
  ssl_certificates = [var.ssl_certificate_name]
  url_map          = google_compute_region_url_map.lb.self_link

  description = "The target HTTPS proxy of the internal load balancer for Vault"
}

resource "google_compute_forwarding_rule" "lb" {
  name                  = "${var.resource_name_prefix}-vault-lb"
  ip_address            = google_compute_address.external.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = 443
  target                = google_compute_region_target_https_proxy.lb.self_link
}
