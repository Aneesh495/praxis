// Praxis Execution Engine Tests: Simulator

use praxis_core::simulator::{
    MicroVmSimulator, NetworkSimulator, RaftClusterSimulator, SimulatedFilterRule,
    SimulatedPacket, SimulatedVmConfig,
};

#[test]
fn test_microvm_boot_simulation() {
    let sim = MicroVmSimulator::new();
    let config = SimulatedVmConfig {
        vcpus: 2,
        memory_mb: 2048,
        kernel_cmdline: vec!["console=ttyS0".to_string(), "quiet".to_string()],
        root_device: "/dev/vda".to_string(),
        seccomp_enabled: true,
        jaile_chroot: Some("/srv/jailer/node-1".to_string()),
    };

    let report = sim.simulate_boot(&config);
    assert!(report.boot_successful);
    assert!(report.jailer_isolation_enforced);
    assert!(report.pivot_root_executed);
}

#[test]
fn test_network_packet_filter_simulation() {
    let rules = vec![SimulatedFilterRule {
        name: "allow-dns".to_string(),
        protocol: "udp".to_string(),
        dest_port: Some(53),
        action: "XDP_PASS".to_string(),
    }];

    let net_sim = NetworkSimulator::new(rules, "XDP_DROP".to_string());

    let dns_pkt = SimulatedPacket {
        protocol: "udp".to_string(),
        src_ip: "10.0.0.1".to_string(),
        dest_ip: "1.1.1.1".to_string(),
        dest_port: 53,
        payload_len: 40,
    };
    let http_pkt = SimulatedPacket {
        protocol: "tcp".to_string(),
        src_ip: "10.0.0.1".to_string(),
        dest_ip: "1.1.1.1".to_string(),
        dest_port: 80,
        payload_len: 120,
    };

    assert!(net_sim.evaluate_packet(&dns_pkt).passed);
    assert!(!net_sim.evaluate_packet(&http_pkt).passed);
}

#[test]
fn test_raft_consensus_partition_and_recovery() {
    let mut raft = RaftClusterSimulator::new(&[1, 2, 3, 4, 5]);

    // Initial election
    assert!(raft.trigger_election(1).is_ok());

    // Replication
    assert!(raft.replicate_entry("ENTRY_1".to_string()).is_ok());

    // Isolate minority (nodes 4, 5)
    raft.isolate_node(4);
    raft.isolate_node(5);

    // Majority can still commit
    assert!(raft.replicate_entry("ENTRY_2".to_string()).is_ok());

    // Minority candidate cannot achieve quorum
    assert!(raft.trigger_election(4).is_err());

    // Heal partition
    raft.heal_partitions();
}
