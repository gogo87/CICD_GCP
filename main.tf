    provider "google" {
      project     = var.project_id
      zone      = "${var.region}-a"
    }

    # === Validate and enable required APIs ===
resource "null_resource" "check_and_enable_apis" {
  provisioner "local-exec" {
    command = <<EOT
powershell -Command @'
$projectId = "${var.project_id}"
$requiredApis = @("compute.googleapis.com")
$enabledApis = gcloud services list --enabled --project $projectId --format="value(config.name)"

$alreadyEnabled = @()
$justEnabled = @()

foreach ($api in $requiredApis) {
    if ($enabledApis -contains $api) {
        $alreadyEnabled += $api
    } else {
        Write-Host "Enabling API: $api..."
        gcloud services enable $api --project $projectId
        $justEnabled += $api
    }
}

Write-Host "`n✅ Already enabled APIs:"
$alreadyEnabled | ForEach-Object { Write-Host "  - $_" }

if ($justEnabled.Count -gt 0) {
    Write-Host "`n✅ Newly enabled APIs:"
    $justEnabled | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "`n🎉 All required APIs were already enabled."
}
'@
EOT
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