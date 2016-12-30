module espukiide.controller;

private enum INVALID_NODE = -1; /// Used to test whether a node has been set.
static struct Controller {
    static void parseCommand (string command) {
        import pegged.grammar;
        mixin (grammar (
            `Command:
                # If match [1] is not Empty, then a command matched but there's
                # still more text. It should not recognise.
                MainC        <  RealCommand (Unrecognised / Empty)
                RealCommand  <  Arrow        / #Node num.
                                Literal      /
                                GoToParent   /
                                NewRootNode  /
                                NewChild     /
                                Expression   /
                                Unrecognised /
                                Empty
                Arrow        <  Number ">"
                Number       <~ [0-9]+
                Literal      <  Number    /
                                StringLit
                StringLit    <~ '\"' (!'\"' ('\\\"' / .))* '\"'
                GoToParent   <  ".." (Literal / Expression / Empty)
                NewRootNode  <  "]" (Literal / Expression / Empty)
                NewChild     <  "." Expression
                Expression   <  Name
                Name         <~ [a-zA-Z][a-zA-Z0-9]*
                Unrecognised <~ .+
                Empty        <  eps`
        ));
        auto parsedCommand = Command (command);
        assert (parsedCommand.name == `Command`
        /**/ , `Should match Command at the root.`);
        auto match = parsedCommand.children [0];
        assert (match.name == `Command.MainC`
        /**/ , `Should match MainC after the root.`);
        import std.exception : enforce;
        enforce (match.children [1].name == `Command.Empty`
        /**/ , `Got more than a single command: ` 
        /**/ ~ match.matches [0] ~ ` <|> ` ~ match.matches [1]);
        match = match.children [0];
        assert (match.name == `Command.RealCommand`
        /**/ , `RealCommand should be the first match of MainC.`);

        match = match.children [0]; // Rule of RealCommand.
        switch ( match.name ) {
            import std.conv : text, to;
            case `Command.Arrow`:
                auto nodeNum = match.matches[0].to!uint;
                Controller.currentNode = nodeNum;
                break;
            case `Command.Literal`:
                if (Controller.nodes.length == 0) { // New node.
                    Controller.addNode (null /*Root*/
                    /**/ , match.matches [0] /*Value*/);
                } else { // Edit current node. Has to be root.
                    enforce (!Controller.currentNode.parent,
                    /**/ `Cannot assign a literal to a non-root node.`);
                    Controller.currentNode.value = match.matches[0];
                }
                break;
            case `Command.Expression`:
                if (Controller.nodes.length == 0) { // New node.
                    Controller.addNode (null /*Root*/
                    /**/ , match.matches [0] /*Value*/);
                } else { // Change current node value.
                    Controller.currentNode.value = match.matches [0];
                }
                break;
            case `Command.GoToParent`:
                enforce (currentNode.parent
                /**/ , `Current node doesn't have a parent`);
                Controller.currentNode = Controller.currentNode.parent;
                if (match.matches [1] != "") {
                    Controller.currentNode.value = match.matches [1];
                }
                break;
            case `Command.NewRootNode`:
                Controller.addNode (null /*Root*/, match.matches[1] /*Value*/);
                break;
            case `Command.NewChild`:
                Controller.addNode (currentNode, match.matches[1] /*Value*/);
                break;
            case `Command.Unrecognised`:
                throw new Exception (`Unrecognised command: ` ~ command);
            case `Command.Empty` : // Do nothing.
                break;
            default:
                assert(false);
        }
    }
    /// All new nodes should be created with this.
    static void addNode (Node * parent, string label) {
        Node * insertedNode = null;
        if (parent) {
            parent.children ~= Node (parent, label, lastCount);
            insertedNode = &parent.children [$-1];
        } else {
            rootNodes ~= Node (parent, label, lastCount);
            insertedNode = &rootNodes [$-1];
        }
        // Cannot assign &this in the constructor.
        import espukiide.gui : GUINode;
        insertedNode.guiNode = new GUINode (label, insertedNode);
        nodes [lastCount] = insertedNode;
        currentNode = lastCount;
        lastCount ++;
    }
    private static Node   [] rootNodes = [];
    private static Node * [uint] nodes; /// All nodes, identified by a number.
    private static uint lastCount = 0;  /// Used for assigning ids to new nodes.
    /**************************************************************************
     * Get currently selected node.
     **************************************************************************/
    @property private static Node * currentNode () {
        auto toRet = m_currentNode in nodes;
        import std.exception : enforce;
        enforce (toRet !is null, `Tried accessing a non-existent node.`);
        return * toRet;
    }
    /**************************************************************************
     * Set the currently selected node by index in nodes.
     **************************************************************************/
    @property private static currentNode (uint newVal) {
        assert ((newVal in nodes) !is null
        /**/ , `Tried assigning currentNode to a non-existent one`);
        if (m_currentNode != INVALID_NODE) {
            currentNode.guiNode.isCurrentlySelected = false;
        }
        m_currentNode = newVal;
        currentNode.guiNode.isCurrentlySelected = true;
    }
    /**************************************************************************
     * Set the currently selected node by node pointer.
     **************************************************************************/
    @property private static currentNode (Node * newVal) {
        this.currentNode = newVal.nodeNumber;
    }
    private static uint m_currentNode = INVALID_NODE;
}

struct Node {
    // All node construction should be made with Controller.addNode;
    import espukiide.gui : GUINode;
    Node [] children = [];
    Node * parent = null;
    uint nodeNumber = INVALID_NODE;
    @property GUINode * guiNode () { 
        assert (m_guiNode, `No guiNode, make sure to call Node.start`);
        return m_guiNode;
    }
    private @property void guiNode (GUINode * newNode) { m_guiNode = newNode; }
    private @property void value (string newValue) { 
        m_value = newValue;
        guiNode.label = newValue;
    }
    @disable this ();
    private this (Node * parent, string value, uint nodeNumber) {
        this.parent     = parent;
        this.children   = [];
        this.m_value    = value;
        this.nodeNumber = nodeNumber;
    }
    private GUINode * m_guiNode = null;
    private string m_value      = null;
}
