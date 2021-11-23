// Praxis Execution Engine
// Generators: Hardened Systemd Service Unit Synthesizer

pub struct SystemdGenerator;

impl SystemdGenerator {
    pub fn new() -> Self {
        Self
    }

    pub fn generate_service_unit(
        &self,
        name: &str,
        exec_start: &str,
        user: &str,
        dependencies: &[&str],
        sandbox: bool,
    ) -> String {
        let after_line = if !dependencies.is_empty() {
            format!("After={}\n", dependencies.join(" "))
        } else {
            "".to_string()
        };

        let sandbox_lines = if sandbox {
            r#"ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true
ProtectKernelTunables=true
ProtectControlGroups=true
MemoryDenyWriteExecute=true
"#
        } else {
            ""
        };

        format!(
            r#"[Unit]
Description=Praxis Managed Service - {}
{}
[Service]
Type=simple
User={}
ExecStart={}
Restart=always
RestartSec=5
{}
[Install]
WantedBy=multi-user.target
"#,
            name, after_line, user, exec_start, sandbox_lines
        )
    }
}
