import json
import sys
import uuid
import random
from pathlib import Path

# ---------- CONFIG ----------
MIN_NODES = 10
MAX_NODES = 1_000_000
DEFAULT_NODES = 10
OUTPUT_FILE = "DBInitial.json"
# ----------------------------

def make_node(node_id=None, parent_id=None, value=None, is_deleted=None):
    """Create a single node (no children)."""
    return {
        "type": "node",
        "id": node_id or str(uuid.uuid4()),
        "parentId": parent_id,
        "value": value or f"Node {uuid.uuid4().hex[:8]}",
        "isDeleted": False,
        "children": []
    }

def build_tree(total_nodes):
    """Builds a random tree with ~total_nodes nodes."""
    root = make_node(value="Root")
    nodes = [root]
    all_nodes = [root]

    # While not enough nodes, randomly attach new ones to existing parents
    while len(all_nodes) < total_nodes:
        parent = random.choice(nodes)
        child = make_node(parent_id=parent["id"])
        parent["children"].append(child)
        all_nodes.append(child)

        # Occasionally mark this node as a new parent candidate
        if random.random() < 0.7:
            nodes.append(child)

    return [root]

def main():
    try:
        n = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_NODES
        n = max(MIN_NODES, min(n, MAX_NODES))
    except ValueError:
        n = DEFAULT_NODES

    data = build_tree(n)
    output = Path(__file__).parent / OUTPUT_FILE

    with open(output, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"✅ Generated ~{len(flatten_tree(data))} nodes into {output}")

def flatten_tree(data):
    """Flatten nested structure just to count nodes."""
    result = []
    def recurse(nodes):
        for node in nodes:
            result.append(node)
            recurse(node["children"])
    recurse(data)
    return result

if __name__ == "__main__":
    main()
