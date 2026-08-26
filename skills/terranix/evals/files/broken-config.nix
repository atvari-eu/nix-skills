{ ... }:
{
  resource.null_resource.demo.triggers = {
    instance_type = "${var.instance_type}";
    region_note = "deployed to ${local.region}";
  };
}
