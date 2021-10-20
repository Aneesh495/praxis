# Praxis Declarative Infrastructure Hypervisor
# Cloud Module: AWS CloudFormation Template Synthesizer
#
# Generates valid AWS CloudFormation JSON templates directly from Praxis
# infrastructure definitions in pure Nix.

let
  json = import ../../lib/json.nix;

in
rec {
  # Synthesizes an AWS CloudFormation template
  # resources: { LogicalId = { Type = "AWS::EC2::Instance"; Properties = { ... }; }; }
  makeCloudFormationTemplate = {
    description ? "Praxis Synthesized Cloud Infrastructure",
    parameters ? {},
    resources ? {},
    outputs ? {},
  }: {
    AWSTemplateFormatVersion = "2010-09-09";
    Description = description;
    Parameters = parameters;
    Resources = resources;
    Outputs = outputs;
  };

  # Renders the template to formatted JSON string
  renderCloudFormationJSON = templateDef:
    json.toJSON (makeCloudFormationTemplate templateDef);
}
