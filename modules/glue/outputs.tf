output "database_name" {
  value = aws_glue_catalog_database.evidence.name
}

output "crawler_name" {
  value = aws_glue_crawler.evidence.name
}
