provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("./.gcp/terraform-key.json")
}

# Network
resource "google_compute_network" "vpc_network" {
  name                    = "mig-lb-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "mig-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

# Firewall
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}
# Service Account
resource "google_service_account" "mig_sa" {
  account_id   = "mig-instance-sa"
  display_name = "MIG Instance Service Account"
}

resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.mig_sa.email}"
}

# Cloud SQL
resource "google_sql_database_instance" "main" {
  name                = "mig-sql-instance"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = "false"
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
    }
  }
}

resource "google_sql_database" "database" {
  name     = "app_db"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "user" {
  name     = "app_user"
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

# Instance Template
resource "google_compute_instance_template" "mig_template" {
  name_prefix  = "mig-template-"
  machine_type = "e2-micro"
  tags         = ["http-server", "allow-ssh"]

  service_account {
    email  = google_service_account.mig_sa.email
    scopes = ["cloud-platform"]
  }

  disk {
    source_image = "debian-cloud/debian-11"
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link
    access_config {}
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Instance Group
resource "google_compute_instance_group_manager" "mig" {
  name               = "mig-group"
  base_instance_name = "mig-instance"
  zone               = "${var.region}-a"

  version {
    instance_template = google_compute_instance_template.mig_template.id
  }

  target_size = 1

  auto_healing_policies {
    health_check      = google_compute_health_check.http-health-check.id
    initial_delay_sec = 300
  }
}

# Load Balancer
resource "google_compute_health_check" "http-health-check" {
  name = "http-health-check"

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "backend" {
  name        = "mig-backend-service"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10

  backend {
    group = google_compute_instance_group_manager.mig.instance_group
  }

  health_checks = [google_compute_health_check.http-health-check.id]
}

resource "google_compute_url_map" "url-map" {
  name            = "mig-url-map"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "http-proxy" {
  name    = "mig-http-proxy"
  url_map = google_compute_url_map.url-map.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "mig-http-forwarding-rule"
  target     = google_compute_target_http_proxy.http-proxy.id
  port_range = "80"
}
