# Praxis Declarative Infrastructure Hypervisor
# Cloud Module: Kubernetes Manifest and Pod Synthesizer
#
# Generates Kubernetes v1 Pod, Deployment, Service, and CRD manifests
# directly from Praxis container image and microVM specifications.

let
  yaml = import ../../lib/yaml.nix;

in
rec {
  # Synthesizes a Kubernetes Service manifest
  makeService = {
    name,
    namespace ? "default",
    appLabel,
    port,
    targetPort ? port,
    type ? "ClusterIP",
  }: {
    apiVersion = "v1";
    kind = "Service";
    metadata = {
      inherit name namespace;
      labels = { app = appLabel; };
    };
    spec = {
      inherit type;
      selector = { app = appLabel; };
      ports = [
        {
          name = "http";
          inherit port targetPort;
          protocol = "TCP";
        }
      ];
    };
  };

  # Synthesizes a Kubernetes Deployment manifest
  makeDeployment = {
    name,
    namespace ? "default",
    appLabel,
    replicas ? 3,
    image,
    port ? 8080,
    env ? {},
  }: {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata = {
      inherit name namespace;
      labels = { app = appLabel; };
    };
    spec = {
      inherit replicas;
      selector = {
        matchLabels = { app = appLabel; };
      };
      template = {
        metadata = {
          labels = { app = appLabel; };
        };
        spec = {
          containers = [
            {
              name = appLabel;
              inherit image;
              ports = [
                { containerPort = port; }
              ];
              env = builtins.map (k: {
                name = k;
                value = toString env.${k};
              }) (builtins.sort (a: b: a < b) (builtins.attrNames env));
            }
          ];
        };
      };
    };
  };

  # Renders manifest to YAML string
  renderK8sManifest = manifest:
    yaml.toYAML manifest;
}
