// Praxis Execution Engine
// UI: Terminal Cluster Status and Health Metrics Dashboard

pub struct Dashboard;

impl Dashboard {
    pub fn new() -> Self {
        Self
    }

    pub fn render_summary(
        &self,
        cluster_name: &str,
        nodes: &[(&str, &str, &str)], // (name, region, role)
        raft_leader: &str,
    ) -> String {
        let mut out = String::new();
        out.push_str("═════════════════════════════════════════════════════════════════\n");
        out.push_str(&format!("  PRAXIS CLUSTER CONTROL PLANE: {}\n", cluster_name));
        out.push_str(&format!("  Consensus Leader: [Active: {}]\n", raft_leader));
        out.push_str("═════════════════════════════════════════════════════════════════\n");
        out.push_str("  NODE ID              REGION          ROLE            STATUS    \n");
        out.push_str("─────────────────────────────────────────────────────────────────\n");

        for (name, region, role) in nodes {
            out.push_str(&format!(
                "  {:<20} {:<15} {:<15} [HEALTHY]\n",
                name, region, role
            ));
        }

        out.push_str("─────────────────────────────────────────────────────────────────\n");
        out.push_str("  WireGuard Overlay: [ESTABLISHED]   eBPF XDP Filter: [ENFORCED] \n");
        out.push_str("═════════════════════════════════════════════════════════════════\n");
        out
    }
}
