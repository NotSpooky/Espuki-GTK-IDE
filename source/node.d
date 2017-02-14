module espukiide.node;


class Node {
    @disable this ();
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
    NodeType type;
    uint nodeNumber;
    uint    parentNodeNumber  = -1;
    import nemoutils.memberinjector;
    // bool selected;
    mixin createTrigger!(bool,    `selected` );
    // string value;
    mixin createTrigger!(string,   `value`   );
    // NodeType type;
    mixin createTrigger!(NodeType, `type`    );
    // Node [] children;
    mixin createTrigger!(Node [],  `children`);
    // bool deleted; /// Whether this node should be deleted already.
    mixin createTrigger!(bool,     `deleted` );
    import espukiide.tab : Tab;
    Tab tab = null;

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
    @property void parent (Node parentNode) {
        if (parentNode) {
            this.parentNodeNumber = parentNode.nodeNumber;
        } else {
            this.parentNodeNumber = INVALID_NODE;
        }
    }
    @property auto ref guiNode () {
        return m_guiNode;
    }
    string toJSON () {
        import espukiide.stringhandler : escape;
        import std.algorithm.iteration : map, joiner;
        import std.conv : to;
        pragma (msg, `TO DO: Change toJSON so that it uses std.json and `
        /**/ ~ `escapes characters correctly.`);
        return
            `{
                "type" : "` ~ this.type.to!string ~ `",
                "value" : "` ~ this.value.escape ~ `" `
                 ~ (this.children.length ? `
                    , "children" : [` ~
                        this
                            .children
                            .map! (n=>n.toJSON)
                            .joiner (`, `)
                            .to!string
                    ~ `] ` 
                    : `` // No children, no need for children attribute.
                    ) ~ `
            }`;
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
    private GUINode m_guiNode               = null;
}

enum NodeType { Declaration, Expression }
enum INVALID_NODE = -1; /// Used to test whether a node has been set.
