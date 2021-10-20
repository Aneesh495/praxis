# Praxis Declarative Infrastructure Hypervisor
# Cloud Module: OpenTofu & Terraform HCL2 Generator
#
# Generates typed, validated OpenTofu and Terraform HCL2 configuration blocks
# directly from unified Praxis cluster definitions in pure Nix.

rec {
  # Format an HCL scalar value
  formatHclScalar = val:
    if val == null then "null"
    else if builtins.isBool val then (if val then "true" else "false")
    else if builtins.isInt val then toString val
    else if builtins.isString val then builtins.toJSON val
    else if builtins.isList val then
      let
        items = builtins.map formatHclScalar val;
      in
      "[ " + (builtins.concatStringsSep ", " items) + " ]"
    else
      throw "Praxis formatHclScalar: cannot format complex value: ${builtins.typeOf val}";

  # Generates an HCL block: resource, provider, data, variable, output
  # blockType: "resource"
  # labels: [ "aws_instance" "web" ]
  # attributes: { ami = "ami-123"; instance_type = "t3.micro"; ... }
  renderBlock = blockType: labels: attributes:
    let
      labelStr = builtins.concatStringsSep " " (builtins.map builtins.toJSON labels);
      header = "${blockType} ${labelStr} {";
      keys = builtins.sort (a: b: a < b) (builtins.attrNames attributes);
      bodyLines = builtins.map (k:
        let
          v = attributes.${k};
        in
        if builtins.isAttrs v then
          # Sub-block
          "  ${k} {\n" +
          (builtins.concatStringsSep "\n" (builtins.map (sk: "    ${sk} = ${formatHclScalar v.${sk}}") (builtins.attrNames v))) +
          "\n  }"
        else
          "  ${k} = ${formatHclScalar v}"
      ) keys;
      footer = "}\n";
    in
    builtins.concatStringsSep "\n" ([ header ] ++ bodyLines ++ [ footer ]);

  # Synthesizes an entire Terraform / OpenTofu root module file
  renderTerraformModule = {
    providers ? {},
    resources ? [],
    outputs ? {},
  }:
    let
      providerBlocks = builtins.map (pName:
        renderBlock "provider" [ pName ] providers.${pName}
      ) (builtins.sort (a: b: a < b) (builtins.attrNames providers));

      resourceBlocks = builtins.map (res:
        renderBlock "resource" [ res.type res.name ] res.attributes
      ) resources;

      outputBlocks = builtins.map (oName:
        renderBlock "output" [ oName ] { value = outputs.${oName}; }
      ) (builtins.sort (a: b: a < b) (builtins.attrNames outputs));

      allBlocks = providerBlocks ++ resourceBlocks ++ outputBlocks;
    in
    builtins.concatStringsSep "\n" allBlocks;
}
