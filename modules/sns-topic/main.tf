resource "aws_sns_topic" "this" {
  name = var.name
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.email_endpoints)
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "lambda" {
  for_each  = var.lambda_endpoints
  topic_arn = aws_sns_topic.this.arn
  protocol  = "lambda"
  endpoint  = each.value
}

resource "aws_sns_topic_policy" "this" {
  count  = var.topic_policy != null ? 1 : 0
  arn    = aws_sns_topic.this.arn
  policy = var.topic_policy
}
