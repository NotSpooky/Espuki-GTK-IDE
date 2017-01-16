module espukiide.node;

import espukiide.tab : Tab;
Node addNode (string value, Tab tab, uint nodeNumber, Node parent
/**/ , NodeType type) {
    auto toReturn = new Node (value, tab, nodeNumber, parent, type);
    import espukiide.tab : ControllerNode;
    toReturn.m_controllerNode = new ControllerNode (toReturn);
    import espukiide.guinode : GUINode;
    toReturn.m_guiNode = new GUINode (toReturn);
    return toReturn;
    pragma (msg, `TO DO: Test without addNode, but using constructor.`);
}

class Node {
    @disable this ();
    private this (string value, Tab tab, uint nodeNumber, Node parent
    /**/ , NodeType type) {
        this.value      = value;
        this.nodeNumber = nodeNumber;
        this.type       = type;
        this.tab        = tab;
        this.parent     = parent;
        // Cannot assign this in constructor, so must use addNode to call this
        // constructor.
    }
    Node parent;
    NodeType type;
    bool selected;
    uint nodeNumber;
    import espukiide.memberinjector;
    // bool selected;
    mixin createTrigger!(bool,    `selected`);
    // string value;
    mixin createTrigger!(string,     `value`);
    // NodeType type;
    mixin createTrigger!(NodeType,    `type`);
    // Node [] children;
    mixin createTrigger!(Node [], `children`);
    import espukiide.tab : Tab, ControllerNode;
    Tab tab                                 = null;
    @property auto ref controllerNode () {
        return m_controllerNode;
    }
    @property auto ref guiNode () {
        return m_guiNode;
    }
    private ControllerNode m_controllerNode = null;
    import espukiide.guinode : GUINode;
    private GUINode m_guiNode               = null;
}

enum NodeType { Declaration, Expression }
private enum INVALID_NODE = -1; /// Used to test whether a node has been set.
