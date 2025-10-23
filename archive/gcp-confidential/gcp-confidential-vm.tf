terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0" # Use a more standard version constraint
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
  default     = "vaultmesh/workstation:v1.2.0" # Pin to a specific version
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Confidential A3 VM with H100 GPU
resource "google_compute_instance" "vaultmesh_confidential_gpu" {
  name         = "vaultmesh-confidential-a3"
  machine_type = "a3-highgpu-8g" # This type includes 8x H100 80GB GPUs
  zone         = var.zone

  # Enable Confidential Computing with Intel TDX
  confidential_instance_config {
    enable_confidential_compute = true
    confidential_instance_type  = "TDX"
  }

  boot_disk {
    initialize_params {
      # Use a GPU-optimized image for easier driver installation
      image = "projects/ml-images/global/images/family/ml-vm-gpu-debian-12"
      size  = 200 # GPUs need more disk space
    }
  }

  network_interface {
    network    = "default"
    access_config {} # Assigns an ephemeral public IP
  }

  # The 'guest_accelerator' block is deprecated for A3 VMs.
  # The accelerator is defined by the machine_type.

  # Secure Boot and vTPM are essential for the attestation chain of trust.
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # This startup script now installs drivers and performs an initial attestation.
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

      # Perform initial attestation and save for the agent
      # This mimics the initContainer pattern in your K8s Job.
      mkdir -p /var/lib/vaultmesh
      ./attestation_verifier --attestation_type=TDX > /var/lib/vaultmesh/gcp_attestation_quote.json

      # Pull and run your VaultMesh agent container
      docker run -d --restart=always \
        --name vaultmesh-agent \
        --gpus all \
        -v /var/lib/vaultmesh:/var/lib/vaultmesh:ro \
        -e VAULTMESH_ATTESTATION_MODE=gcp_confidential \
        -e VAULTMESH_ATTESTATION_EVIDENCE=/var/lib/vaultmesh/gcp_attestation_quote.json \
        "${var.vaultmesh_agent_image}"
    EOF
  }

  # Allow the instance to be stopped and started
  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  # Tag the instance for firewall rules
  tags = ["vaultmesh-confidential-gpu"]
}

# 3. Output attestation endpoint for VaultMesh proofs
output "attestation_verification_service_url" {
  description = "The URL for Google's attestation verification service. The agent uses this to verify quotes."
  value       = "https://confidentialcomputing.googleapis.com/v1/projects/${var.project_id}/locations/global/attestation"
}

output "instance_ip" {
  description = "The public IP address of the confidential VM."
  value       = google_compute_instance.vaultmesh_confidential_gpu.network_interface[0].access_config[0].nat_ip
}