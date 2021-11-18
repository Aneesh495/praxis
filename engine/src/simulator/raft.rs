// Praxis Execution Engine
// Simulator: Multi-Node Distributed Raft Consensus Engine with Network Partitions

use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq)]
pub enum RaftRole {
    Follower,
    Candidate,
    Leader,
}

#[derive(Debug, Clone)]
pub struct RaftNode {
    pub id: u64,
    pub current_term: u64,
    pub voted_for: Option<u64>,
    pub role: RaftRole,
    pub log_entries: Vec<String>,
    pub commit_index: usize,
}

impl RaftNode {
    pub fn new(id: u64) -> Self {
        Self {
            id,
            current_term: 0,
            voted_for: None,
            role: RaftRole::Follower,
            log_entries: Vec::new(),
            commit_index: 0,
        }
    }
}

pub struct RaftClusterSimulator {
    pub nodes: HashMap<u64, RaftNode>,
    pub partitioned_nodes: HashSet<u64>,
}

impl RaftClusterSimulator {
    pub fn new(node_ids: &[u64]) -> Self {
        let mut nodes = HashMap::new();
        for &id in node_ids {
            nodes.insert(id, RaftNode::new(id));
        }
        Self {
            nodes,
            partitioned_nodes: HashSet::new(),
        }
    }

    pub fn isolate_node(&mut self, id: u64) {
        self.partitioned_nodes.insert(id);
    }

    pub fn heal_partitions(&mut self) {
        self.partitioned_nodes.clear();
    }

    pub fn trigger_election(&mut self, candidate_id: u64) -> Result<u64, String> {
        let total_nodes = self.nodes.len();
        let quorum = (total_nodes / 2) + 1;

        if self.partitioned_nodes.contains(&candidate_id) {
            return Err(format!("Node {} is partitioned and cannot communicate", candidate_id));
        }

        let new_term = {
            let candidate = self.nodes.get_mut(&candidate_id).ok_or("Candidate node not found")?;
            candidate.current_term += 1;
            candidate.role = RaftRole::Candidate;
            candidate.voted_for = Some(candidate_id);
            candidate.current_term
        };

        let mut votes = 1; // Self-vote

        for (&peer_id, peer) in &mut self.nodes {
            if peer_id == candidate_id || self.partitioned_nodes.contains(&peer_id) {
                continue;
            }

            // Peer votes if term is higher
            if new_term > peer.current_term {
                peer.current_term = new_term;
                peer.voted_for = Some(candidate_id);
                peer.role = RaftRole::Follower;
                votes += 1;
            }
        }

        if votes >= quorum {
            let candidate = self.nodes.get_mut(&candidate_id).unwrap();
            candidate.role = RaftRole::Leader;
            Ok(new_term)
        } else {
            let candidate = self.nodes.get_mut(&candidate_id).unwrap();
            candidate.role = RaftRole::Follower;
            Err(format!("Election failed: achieved {} votes out of {} required for quorum", votes, quorum))
        }
    }

    pub fn replicate_entry(&mut self, entry: String) -> Result<usize, String> {
        let total_nodes = self.nodes.len();
        let quorum = (total_nodes / 2) + 1;

        // Find active leader
        let leader_id = self
            .nodes
            .iter()
            .find(|(&id, n)| n.role == RaftRole::Leader && !self.partitioned_nodes.contains(&id))
            .map(|(&id, _)| id)
            .ok_or("No reachable Raft leader in cluster")?;

        let entry_idx = {
            let leader = self.nodes.get_mut(&leader_id).unwrap();
            leader.log_entries.push(entry.clone());
            leader.log_entries.len() - 1
        };

        let mut replicated_count = 1; // Leader has it

        for (&peer_id, peer) in &mut self.nodes {
            if peer_id == leader_id || self.partitioned_nodes.contains(&peer_id) {
                continue;
            }
            peer.log_entries.push(entry.clone());
            replicated_count += 1;
        }

        if replicated_count >= quorum {
            for (&peer_id, peer) in &mut self.nodes {
                if !self.partitioned_nodes.contains(&peer_id) {
                    peer.commit_index = entry_idx + 1;
                }
            }
            Ok(entry_idx + 1)
        } else {
            Err(format!("Log replication failed: replicated to {} nodes, quorum is {}", replicated_count, quorum))
        }
    }
}
