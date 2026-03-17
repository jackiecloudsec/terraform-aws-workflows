resource "aws_cloudwatch_event_rule" "this" {
  name          = var.name
  description   = var.description
  event_pattern = var.event_pattern
  tags          = var.tags
}

resource "aws_cloudwatch_event_target" "targets" {
  for_each  = var.targets
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = each.key
  arn       = each.value.arn
  role_arn  = lookup(each.value, "role_arn", null)

  dynamic "input_transformer" {
    for_each = lookup(each.value, "input_template", null) != null ? [1] : []
    content {
      input_paths    = each.value.input_paths
      input_template = each.value.input_template
    }
  }
}
