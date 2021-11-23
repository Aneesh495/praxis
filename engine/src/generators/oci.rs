// Praxis Execution Engine
// Generators: OCI Image Specification v1.1 Manifest & Descriptor Emitter

pub struct OciGenerator;

impl OciGenerator {
    pub fn new() -> Self {
        Self
    }

    pub fn generate_manifest(
        &self,
        config_digest: &str,
        config_size: u64,
        layer_digests: &[(&str, u64)],
    ) -> String {
        let mut layers_json = Vec::new();
        for (digest, size) in layer_digests {
            layers_json.push(format!(
                r#"    {{
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "{}",
      "size": {}
    }}"#,
                digest, size
            ));
        }

        format!(
            r#"{{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {{
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "{}",
    "size": {}
  }},
  "layers": [
{}
  ]
}}"#,
            config_digest,
            config_size,
            layers_json.join(",\n")
        )
    }
}
