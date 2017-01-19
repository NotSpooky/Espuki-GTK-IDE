module espukiide.node;


class Node {
    @disable this ();
    this (string value, Tab tab, uint nodeNumber, Node parent, NodeType type) {
        this.deleted    = false;
        this.value      = value;
        this.nodeNumber = nodeNumber;
        this.type       = type;
        this.tab        = tab;
        this.parent     = parent;
        this.m_guiNode  = new GUINode (this);
    }
    Node parent;
    NodeType type;
    bool selected;
    uint nodeNumber;
    import espukiide.memberinjector;
    // bool selected;
    mixin createTrigger!(bool,    `selected`);
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
                .remove (pos);
        }
    }
    import espukiide.guinode : GUINode;
    private GUINode m_guiNode               = null;
}

enum NodeType { Declaration, Expression }
enum INVALID_NODE = -1; /// Used to test whether a node has been set.
