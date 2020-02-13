
provider "google" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
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
  name               = "spez-tailer-cluster"
  location           = var.region

  initial_node_count = 1
  node_config {
    machine_type = "n1-standard-1"
  }
}

resource "google_pubsub_topic" "spez-ledger-topic" {
  name = "spez-ledger-topic"

  message_storage_policy {
    allowed_persistence_regions = [
      var.region
    ]
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

resource "google_cloudfunctions_function" "spez-lpts-function" {
  name        = "spez-lpts-function"
  description = "Spez Last Processed Timestamp Cluster"
  runtime     = "go111"

  entry_point = "LastProcessedTimestamp"
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.spez-ledger-topic.name
  }
  service_account_email = data.google_service_account.spez-lpts-function-sa.email
  source_repository {
    url = "https://github.com/xjdr/spez2/tree/master/functions/lastprocessedtimestamp/*"
  }
}
