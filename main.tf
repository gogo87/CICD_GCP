    provider "google" {
      project     = var.project_id
      zone      = "${var.region}-a"
    }

resource "null_resource" "check_and_enable_apis" {
  provisioner "local-exec" {
    command = "./check-apis.sh ${var.project_id}"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}
    resource  "google_compute_network" "Custom_VPC"{
        name =  "${var.name}-vpc"
        auto_create_subnetworks = false

    }
    
    resource "google_compute_subnetwork" "front_end_sub" {
      name = "front-end-subnet"
      ip_cidr_range = var.front_cidr
      network = google_compute_network.Custom_VPC.self_link
    }

      resource "google_compute_subnetwork" "back_end_sub" {
      name = "back-end-subnet"
      ip_cidr_range = var.back_cidr
      network = google_compute_network.Custom_VPC.self_link
    }

    
      resource "google_compute_subnetwork" "dmz_sub" {
      name = "dmz-subnet"
      ip_cidr_range = var.DMZ_cidr
      network = google_compute_network.Custom_VPC.self_link
    }