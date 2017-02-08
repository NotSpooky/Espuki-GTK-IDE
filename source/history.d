module espukiide.history;
/// Used for Control-Z (undo) and Control-Y (redo).
class History {
    @disable this ();
    import espukiide.tab;
    this (Tab tab) {
        this.tab = tab;
        import std.stdio;
        this.tab.nodes.indexAssignTriggers ~= &onNodeCreated;
        this.tab.nodes.removeTriggers      ~= &onNodeDeleted;
    }
    Tab tab;

    import espukiide.node : Node;
    void onNodeCreated (Node newNode, uint index, bool existingNode) {
        if (existingNode) {
            assert (0, `TO DO: onNodeCreated with existingNode`);
        } else { // New node.
            pastTimeline ~= [ new NodeAddedAction (newNode) ];
            if (this.deleteFutureOnChanges) {
                futureTimeline = [];
            }
        }
    }

    void onNodeDeleted (Node deletedNode, uint index) {
        pastTimeline ~= [ new NodeDeletedAction (deletedNode)];
        if (this.deleteFutureOnChanges) {
            futureTimeline = [];
        }
    }

    void redo () {
        this.reverting = !this.reverting;
        this.undo;
        this.reverting = !this.reverting;
    }
    void undo () {
        this.deleteFutureOnChanges = false; // Still on the same timeline.
        if (pastTimeline.length) {
            auto snapshot = pastTimeline [$-1];
            // Makes changes go to the future timeline.
            this.reverting = !this.reverting; 
            foreach (ref action; snapshot) {
                action.revert (tab);
            }
            // Goes back to initial value.
            this.reverting = !this.reverting; 
            pastTimeline = pastTimeline [0 .. $-1];
        }
        this.deleteFutureOnChanges = true; // Reverts change.
    }
    @property auto ref pastTimeline () {
        return reverting ? m_futureTimeline : m_pastTimeline;
    }
    @property auto ref futureTimeline () {
        return reverting ? m_pastTimeline : m_futureTimeline;
    }
    private bool reverting = false;
    /// Used for removing the future timeline when the user makes a change so 
    /// that 'redoing' won't redo changes from both timelines.
    private bool deleteFutureOnChanges = true;
    Action [][] m_pastTimeline   = [];
    Action [][] m_futureTimeline = [];
}

pragma (msg, `Espuki meta: `
/**/ ~ `Allow triggers when functions/delegates are called.`);
/+
enum ActionType {
    addNode,     // Reverting should delete the inserted node.
    deleteNode,  // Reverting should reinsert the node.
    valueChanged // 
}; +/

interface Action {
    import espukiide.tab : Tab;
    void revert (ref Tab tab);
    Action opposite ();
}

class NodeAddedAction : Action {
    import espukiide.node : Node;
    this (Node node) {
        this.node = node;
    }
    void revert (ref Tab tab) {
        tab.deleteNode (node.nodeNumber);
    }

    Action opposite () {
        return new NodeDeletedAction (this.node);
    }

    private Node node;
}

class NodeDeletedAction : Action {
    import espukiide.node : Node;
    this (Node node) {
        this.node = node;
    }
    void revert (ref Tab tab) {
        tab.addNode (node.parentNodeNumber, node.value, node.type, node.nodeNumber);
    }

    Action opposite () {
        return new NodeAddedAction (this.node);
    }

    private Node node;
}
