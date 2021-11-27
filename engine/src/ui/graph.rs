// Praxis Execution Engine
// UI: ASCII / Unicode Topology DAG Graph Visualizer

pub struct GraphVisualizer;

impl GraphVisualizer {
    pub fn new() -> Self {
        Self
    }

    pub fn render_ascii_dag(&self, title: &str, nodes: &[(&str, &[&str])]) -> String {
        let mut out = String::new();
        out.push_str(&format!("┌─ {} ─┐\n", title));

        for (node, deps) in nodes {
            if deps.is_empty() {
                out.push_str(&format!("│  [●] {}\n", node));
            } else {
                out.push_str(&format!("│  [●] {} ──▶ ({})\n", node, deps.join(", ")));
            }
        }

        out.push_str("└─────────────────────────────────────────────┘\n");
        out
    }
}
