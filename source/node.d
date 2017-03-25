module espukiide.node;


class Node {
    @disable this ();
    /**
     * parentNodeNumber should be INVALID_NODE if non-existent.
     */
    this (string value, Tab tab, uint nodeNumber, uint parentNodeNumber
    /**/ , NodeType type) {
        this.deleted          = false;
        this.value            = value;
        this.nodeNumber       = nodeNumber;
        this.type             = type;
        this.tab              = tab;
        this.parentNodeNumber = parentNodeNumber;
        this.m_guiNode        = new GUINode (this);
    }
    uint nodeNumber;
    uint parentNodeNumber  = -1;
    import nemoutils.memberinjector;
    Triggered!bool      selected;
    Triggered!string    value;
    Triggered!NodeType  type;
    Triggered!(Node []) children;
    /// Whether this node should be deleted already.
    Triggered!bool      deleted;
    import espukiide.tab : Tab;
    Tab tab = null;

    /**
     * Returns the parent from tab.nodes.
     */
    @property auto ref parent () {
        assert (this.tab, `All nodes should have a tab.`);
        if (this.parentNodeNumber == INVALID_NODE) {
            return null;
        } else {
            assert (this.parentNodeNumber in this.tab.nodes
            /**/ , `Parent node not found in nodes.`);
            return this.tab.nodes [this.parentNodeNumber];
        }
    }
    /**
     * Makes a Node parent of this one.
     */
    @property void parent (Node parentNode) {
        if (parentNode) {
            this.parentNodeNumber = parentNode.nodeNumber;
        } else {
            this.parentNodeNumber = INVALID_NODE;
        }
    }
    /// Doesn't allow assignment.
    @property auto guiNode () { return m_guiNode; }
    string toJSON (uint indentationLevel = 0) {
        import espukiide.stringhandler : escape;
        import std.algorithm.iteration : map, joiner;
        import std.conv                : to;
        import std.range               : repeat, take;
        pragma (msg, `TO DO: Make toJSON escape characters correctly.`);
        /// Indent relative to indentationL.
        string indentation (uint extra = 0) {
            return "\n" ~ repeat ('\t').take (indentationLevel + extra).to!string;
        }
        return indentation (1) ~ `{`
            ~ indentation (1) ~ `"type" : "` ~ this.type.to!string ~ `",`
            ~ indentation (1) ~ `"value" : "` ~ this.value.escape ~ `" `
            ~ indentation (2) ~(this.children.length ? `
                    , "children" : [` ~
                        this
                            .children
                            .map! (n=>n.toJSON (indentationLevel + 3))
                            .joiner (`, `)
                            .to!string
                    ~ `] ` 
                    : `` // No children, no need for children attribute.
                    )
            ~ indentation (1) ~ `}`;
    }
    // A 'destructor'. Should be called before deleting this node.
    void controllerDestructor () {
        this.deleted = true;
        foreach (ref child; this.children) {
            // Should delete children before this node.
            this.tab.deleteNode (child.nodeNumber);
        }
        if (this.parent) {
            import std.algorithm.searching : countUntil;
            auto pos = 
                this
                .parent
                .children
                .countUntil!(a => a == this);
            assert (pos != -1);
            // Remove from the children array.
            import std.algorithm.mutation : remove;
            this
                .parent
                .children = 
                this
                .parent
                .children
                .value
                .remove (pos);
        }
    }
    import espukiide.guinode : GUINode;
    private GUINode m_guiNode = null; // Node in the GUI.
}

enum NodeType { Declaration, Expression, Return }
enum INVALID_NODE = -1; /// Used to test whether a node has been set.

/**
 * root is the name of the variable starting the chain, null if it doesn't exist.
 */
auto processChain (Node [] nodes, string root) {
    // Suppose there's a chain root -> b -> c -> {d, e -> f}
    // If the last node is a return, it shouldn't have children and the compiled
    // expression will be `return root.b.c` (assume c didn't have children).
    // If the last node isn't a return and doesn't have children, the expression
    // will be `root.b.c` , NOTE: If there's no exception/mutable state change
    // then this is dead code. (assume c didn't have children).
    // If the last node has children they must be more than 1 (else they would
    // be chained), and a variable should be created to store the intermediate
    // result. NOTE: If any of the children mutates state then the tree must
    // have a defined order for the execution of the children.
    assert (nodes.length);
    import std.algorithm : map;
    import std.range     : join;
    /* Shouldn't add '.' if no root */
    string theChain = (root ? (root ~ ".") : ``) 
    /**/ ~ nodes
    /**/    .map!`a.value`
    /**/    .join (`.`) 
    /**/ ~ ";\n";
    auto lastNode = nodes [$-1];
    if (lastNode.type == NodeType.Return) {
        assert (lastNode.children.length == 0
        /**/ , `Return nodes should have no children`);
        return `return ` ~ theChain;
    } else if (lastNode.children.length) {
        import std.conv : to;
        string variableName = `espukiVar` ~ lastVariableNumber.to!string;
        lastVariableNumber ++;
        return 
            // Variable names shouldn't be used for function declarations.
            variableName ~ ` = ` ~ theChain 
            ~ lastNode
            .children
            .map!(child => child.chain.processChain (variableName))
            .join;
    } else {
        return theChain;
    }
}
private static lastVariableNumber = 0;

private Node [] chain (Node node) {
    Node [] toRet = [node];
    Node currentNode = node;
    while (node.children.length == 1) {
        node = node.children [0];
        toRet ~= node;
    }
    return toRet;
}
string compile (Node node) {
    return processChain (node.chain, null);
}
