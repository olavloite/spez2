/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

terraform {
  required_version = ">= 0.12.0"
}

provider "google" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
}

provider "archive" {}

data "google_client_config" "default" {}
provider "kubernetes" {
  load_config_file = false

  host = google_container_cluster.spez-tailer-cluster.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.spez-tailer-cluster.master_auth[0].cluster_ca_certificate)
  token = data.google_client_config.default.access_token
}

resource "google_spanner_instance" "spez-lpts-instance" {
  name   = "spez-lpts-instance"
  config = "regional-us-central1"

  display_name = "spez-lpts-instance"
  num_nodes    = 1
}

resource "google_spanner_database" "spez-lpts-database" {
  name     = "spez-lpts-database"
  instance = google_spanner_instance.spez-lpts-instance.name

  ddl = [
    "CREATE TABLE lpts (Id INT64 NOT NULL, CommitTimestamp TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true), LastProcessedTimestamp STRING(128) NOT NULL) PRIMARY KEY (Id)"
  ]
}

resource "google_container_cluster" "spez-tailer-cluster" {
  name     = "spez-tailer-cluster"
  location = var.region

  initial_node_count = 1
  node_config {
    machine_type = "n1-standard-2"
  }
}

resource "google_service_account" "spez-tailer-sa" {
  account_id   = "spez-tailer-sa"
  display_name = "Spez Tailer Service Account"
}

resource "google_service_account_key" "spez-tailer-sa-key" {
  service_account_id = google_service_account.spez-tailer-sa.name
}

data "google_service_account_key" "spez-tailer-sa-key" {
  name = google_service_account_key.spez-tailer-sa-key.name
  public_key_type = "TYPE_X509_PEM_FILE"
}

resource "kubernetes_secret" "spez-tailer-sa-secret" {
  metadata {
    name = "service-account"
  }
  data = {
    secret = data.google_service_account_key.spez-tailer-sa-key.public_key
  }
}

resource "kubernetes_service" "spez-tailer-service" {
  metadata {
    name = "spez-tailer-service"
  }
  spec {
    port {
      port = 9010
      name = "jmx-port"
    }
    selector = {
      app = "SpannerTailer"
    }
  }
}

resource "kubernetes_deployment" "spez-tailer-deployment" {
  metadata {
    name = "spez-tailer-deployment"
  }
  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "SpannerTail"
      }
    }

    template {
      metadata {
        labels = {
          app = "SpannerTail"
          version = "v1"
        }
      }
      spec {
        volume {
          name = "service-account"
          secret {
            secret_name = "service-account"
          }
        }
        container {
          name = "spanner-tail"
          image = "gcr.io/retail-common-services-249016/spez"
          image_pull_policy = "Always"
          volume_mount {
            name = "service-account"
            mount_path = "/var/run/secret/cloud.google.com"
            read_only = "true"
          }
          resources {
            limits {
              memory = "16Gi"
            }
            requests {
              memory = "8Gi"
            }
          }
          port {
            container_port = 9010
          }
        }
      }
    }
  }
}

resource "google_pubsub_topic" "spez-ledger-topic" {
  name = "spez-ledger-topic"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_service_account" "spez-lpts-function-sa" {
  account_id   = "spez-lpts-function-sa"
  display_name = "Spez Last Processed Timestamp Function Service Account"
}
data "google_service_account" "spez-lpts-function-sa" {
  #depends_on = [google_service_account.spez-lpts-function-sa]

  account_id = google_service_account.spez-lpts-function-sa.account_id
}

data "archive_file" "local_lpts_source" {
  type        = "zip"
  source_dir  = "../../../functions/lastprocessedtimestamp/"
  output_path = "lpts_source.zip"
}

resource "google_storage_bucket" "function-source" {
  name     = join("", [var.project, "-function-source"])
  location = var.region
}

resource "google_storage_bucket_object" "gcs-lpts-source" {
  name   = "lpts_source.zip"
  bucket = google_storage_bucket.function-source.name
  source = data.archive_file.local_lpts_source.output_path
}

resource "google_cloudfunctions_function" "spez-lpts-function" {
  timeouts {
    create = "10m"
  }

  name        = "spez-lpts-function"
  description = "Spez Last Processed Timestamp Cluster"
  runtime     = "go111"

  entry_point = "LastProcessedTimestamp"
  environment_variables = {
    INSTANCE_NAME = google_spanner_instance.spez-lpts-instance.display_name
    DATABASE_NAME = google_spanner_database.spez-lpts-database.name
    TABLE_NAME    = "lpts"
  }
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.spez-ledger-topic.id
  }
  service_account_email = data.google_service_account.spez-lpts-function-sa.email
  source_archive_bucket = google_storage_bucket.function-source.name
  source_archive_object = google_storage_bucket_object.gcs-lpts-source.name
}
