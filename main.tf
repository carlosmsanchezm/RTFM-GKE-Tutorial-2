terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.31.1"
    }
  }
}

terraform {
  backend "gcs" {
    bucket      = "tftest-gke-1"
    prefix      = "tftest-gke-1/terraform.tfstate"
    credentials = "molten-enigma-425106-p0-29c7f9006d4b.json"
  }
}

resource "google_project_service" "required_apis" {
  for_each = toset([
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com", # Adding the GKE API

  ])

  service            = each.key
  project            = "molten-enigma-425106-p0"
  disable_on_destroy = false
}

provider "google" {
  credentials = file("molten-enigma-425106-p0-29c7f9006d4b.json")
  project     = "molten-enigma-425106-p0"
  region      = "us-central1"
  zone        = "us-central1-c"
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
  
  depends_on = [google_project_service.required_apis]
}

#see how to automate this value into the gke configurations
# data "google_service_account" "default" {
#     account_id = "terraform@molten-enigma-425106-p0.iam.gserviceaccount.com"
# }

resource "google_container_cluster" "primary" {
  name                     = "my-gke-cluster"
  location                 = "us-central1"
  remove_default_node_pool = true
  initial_node_count       = 1
  depends_on = [google_project_service.required_apis]
  network            = google_compute_network.vpc_network.name
  deletion_protection = false
  
}


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-small"

    service_account = "terraform@molten-enigma-425106-p0.iam.gserviceaccount.com"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}


output "kubeconfig" {
  value     = google_container_cluster.primary.master_auth[0].client_certificate
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive = true
}