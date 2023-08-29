resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.cluster_name}/secrets"
  recovery_window_in_days = 0
}
