terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP region for the resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for the VM."
  type        = string
  default     = "us-central1-a"
}

variable "vaultmesh_agent_image" {
  description = "The container image for the VaultMesh agent."
  type        = string
  default     = "vaultmesh/workstation:v1.2.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Confidential A3 VM with H100 GPU (8x GPUs)
resource "google_compute_instance" "vaultmesh_confidential_gpu" {
  name         = "vaultmesh-confidential-a3"
  machine_type = "a3-highgpu-8g"
  zone         = var.zone

  # Enable Confidential Computing with Intel TDX
  confidential_instance_config {
    enable_confidential_compute = true
    confidential_instance_type  = "TDX"
  }

  boot_disk {
    initialize_params {
      image = "projects/ml-images/global/images/family/ml-vm-gpu-debian-12"
      size  = 200
    }
  }

  network_interface {
    network    = "default"
    access_config {}
  }

  # Secure Boot and vTPM for attestation chain of trust
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      set -ex

      # Install NVIDIA drivers
      apt-get update
      apt-get install -y linux-headers-$(uname -r)
      /opt/google/install-gpu-driver.sh

      # Install Docker
      apt-get install -y docker.io
      systemctl start docker
      systemctl enable docker

      # Install Google Attestation tools
      apt-get install -y wget
      wget https://storage.googleapis.com/gce-confidential-computing-tools/attestation-tools.tar.gz
      tar -xzf attestation-tools.tar.gz

      # Perform initial attestation
      mkdir -p /var/lib/vaultmesh
      ./attestation_verifier --attestation_type=TDX > /var/lib/vaultmesh/gcp_attestation_quote.json

      # Run VaultMesh agent container
      docker run -d --restart=always \
        --name vaultmesh-agent \
        --gpus all \
        -v /var/lib/vaultmesh:/var/lib/vaultmesh:ro \
        -e VAULTMESH_ATTESTATION_MODE=gcp_confidential \
        -e VAULTMESH_ATTESTATION_EVIDENCE=/var/lib/vaultmesh/gcp_attestation_quote.json \
        "${var.vaultmesh_agent_image}"
    EOF
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  tags = ["vaultmesh-confidential-gpu"]
}

output "attestation_verification_service_url" {
  description = "The URL for Google's attestation verification service"
  value       = "https://confidentialcomputing.googleapis.com/v1/projects/${var.project_id}/locations/global/attestation"
}

output "instance_ip" {
  description = "The public IP address of the confidential VM"
  value       = google_compute_instance.vaultmesh_confidential_gpu.network_interface[0].access_config[0].nat_ip
}
