# MSK Serverless rather than a provisioned cluster: no broker count/instance
# type/EBS sizing to plan or re-plan as load grows, scales to throughput
# automatically, and bills per-use - a better fit for a product still
# finding its traffic shape than a fixed-size provisioned cluster.

resource "aws_security_group" "msk_client" {
  name_prefix = "${var.name}-msk-"
  description = "Allows IAM-authenticated Kafka clients inside the VPC to reach MSK Serverless."
  vpc_id      = var.vpc_id

  ingress {
    description = "Kafka (IAM auth)"
    from_port   = 9098
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-msk-client" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_msk_serverless_cluster" "this" {
  cluster_name = var.name

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.msk_client.id]
  }

  tags = var.tags
}
