// Praxis Execution Engine
// Simulator: Virtual Packet Router and eBPF XDP Filter Emulator

#[derive(Debug, Clone)]
pub struct SimulatedPacket {
    pub protocol: String,
    pub src_ip: String,
    pub dest_ip: String,
    pub dest_port: u16,
    pub payload_len: usize,
}

#[derive(Debug, Clone)]
pub struct SimulatedFilterRule {
    pub name: String,
    pub protocol: String,
    pub dest_port: Option<u16>,
    pub action: String, // "XDP_PASS" or "XDP_DROP"
}

#[derive(Debug)]
pub struct PacketFilterResult {
    pub packet: SimulatedPacket,
    pub matched_rule: Option<String>,
    pub action: String,
    pub passed: bool,
}

pub struct NetworkSimulator {
    pub rules: Vec<SimulatedFilterRule>,
    pub default_action: String,
}

impl NetworkSimulator {
    pub fn new(rules: Vec<SimulatedFilterRule>, default_action: String) -> Self {
        Self {
            rules,
            default_action,
        }
    }

    pub fn evaluate_packet(&self, packet: &SimulatedPacket) -> PacketFilterResult {
        for rule in &self.rules {
            let proto_match = rule.protocol == "any" || rule.protocol.eq_ignore_ascii_case(&packet.protocol);
            let port_match = match rule.dest_port {
                Some(p) => p == packet.dest_port,
                None => true,
            };

            if proto_match && port_match {
                let passed = rule.action == "XDP_PASS";
                return PacketFilterResult {
                    packet: packet.clone(),
                    matched_rule: Some(rule.name.clone()),
                    action: rule.action.clone(),
                    passed,
                };
            }
        }

        let passed = self.default_action == "XDP_PASS";
        PacketFilterResult {
            packet: packet.clone(),
            matched_rule: None,
            action: self.default_action.clone(),
            passed,
        }
    }
}
