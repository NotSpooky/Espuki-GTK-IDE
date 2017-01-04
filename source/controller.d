module espukiide.controller;

private enum INVALID_NODE = -1; /// Used to test whether a node has been set.
static struct Controller {
    static void parseCommand (string command) {
        import pegged.grammar;
        mixin (grammar (
            `Command:
                # If match [1] is not Empty, then a command matched but there's
                # still more text. It should not recognise.
                EnteredText  <  ValidCommand (Unrecognised / Empty)
                # Syntactically valid command.
                ValidCommand <  # Creates a root node.
                                CreateRoot Expression             /
                                # Creates a child node of the selected
                                # and puts a value in it.
                                SelectNode CreateChild Expression /
                                # Deletes the selected node.
                                SelectNode DeleteNode             /
                                # Puts value in selected node.
                                SelectNode Expression             /
                                # Invalid command.
                                Unrecognised                      /
                                # Do nothing.
                                Empty
                SelectNode   <  GoToNode            / # Select by number.
                                GoToParent          / # Select parent.
                                Empty                 # Use currently selected.
                UnsignedInt  <~ [0-9]+
                Expression   <  Name / Literal / Empty
                Literal      <  UnsignedInt           /
                                StringLit
                StringLit    <~ '\"' (!'\"' ('\\\"' / .))* '\"'
                GoToNode     <  UnsignedInt :">"
                GoToParent   <  ".."
                CreateRoot   <  "]"
                CreateChild  <  "."
                DeleteNode   <  "<"
                Name         <~ [a-zA-Z][a-zA-Z0-9]*
                Unrecognised <~ .+
                Empty        <  eps`
        ));
        auto parsedCommand = Command (command);
        debug {
            import std.stdio;
            writeln (parsedCommand);
        }
        assert (parsedCommand.name == `Command`
        /**/ , `Should match Command at the root.`);
        auto match = parsedCommand.children [0];
        assert (match.name == `Command.EnteredText`
        /**/ , `Should match EnteredText after the root.`);
        import std.exception : enforce;
        enforce (match.children [1].name == `Command.Empty`
        /**/ , `Got more than a single command: ` 
        /**/ ~ match.matches [0] ~ ` <|> ` ~ match.matches [1]);
        match = match.children [0];
        assert (match.name == `Command.ValidCommand`
        /**/ , `ValidCommand should be the first match of EnteredText.`);

        switch (match.children [0].name) {
            case `Command.SelectNode`:
                auto selection     = match.children [0];
                auto selectionType = selection.children [0].name;
                auto selectedNode  = INVALID_NODE;
                if (selectionType == `Command.GoToNode`) {
                    import std.conv : to;
                    selectedNode = selection.matches [0].to!uint;
                } else if (selectionType == `Command.GoToParent`) {
                    auto currentParent = currentNode.parent;
                    enforce (currentParent
                    /**/ , `Tried accessing parent of root node.`);
                    selectedNode = currentParent.nodeNumber;
                } else { // Use currently selected node.
                    assert (selectionType == `Command.Empty`);
                    try {
                        selectedNode = this.currentNode.nodeNumber;
                    } catch (Exception e) {
                        assert (!nodes.length
                        /**/ , `If current node is invalid, then there `
                        /**/ ~ `shouldn't be nodes at all.`);
                    }
                }

                // Node to use has been selected.
                auto following = match.children [1];

                if (following.name == `Command.CreateChild`) {
                    if (selectedNode != INVALID_NODE) {
                        this.currentNode = selectedNode;
                        Controller.addNode (currentNode /* Parent*/
                        /**/ , match.matches [2] /*Value*/
                        /**/ , NodeType.Expression);
                    } else { // No nodes, should create a new node.
                        createRootNode (match.matches [2]);
                    }
                } else if (following.name == `Command.DeleteNode`) {
                    enforce (selectedNode != INVALID_NODE, `No node to delete`);
                    deleteNode (selectedNode);
                } else if (following.name == `Command.Expression`) {
                    if (selectedNode != INVALID_NODE) {
                        this.currentNode = selectedNode;
                        if (following.children [0].name != `Command.Empty`) {
                            // If Empty, should just change current node.
                            this.currentNode.value = following.matches [0];
                        }
                    } else { // There's no current node. Create a root one.
                        createRootNode (following.matches [0]);
                    }
                } else { assert (0, `Unexpected command.`);}
                break;
            case `Command.CreateRoot`:
                createRootNode (match.children [1].matches [0]);
                break;
            case `Command.Empty`:        // Do nothing.
                break;
            case `Command.Unrecognised`: // Invalid command.
                throw new Exception (`Unrecognised command: ` ~ command);
            default:
                assert (false, `Incorrect match: ` ~ match.toString);
        }
    }
    static void createRootNode (string value) {
        Controller.addNode (null /* No parent*/, value, NodeType.Declaration);
    }
    /// All new nodes should be created with this.
    static void addNode (Node * parent, string label
    /**/ , NodeType type) {
        Node * insertedNode = null;
        if (parent) {
            parent.children ~= Node (parent, label, lastCount, type);
            insertedNode = &parent.children [$-1];
        } else { // Root node.
            assert (type == NodeType.Declaration
            /**/ , `Root nodes should be function declarations.`);
            rootNodes ~= Node (parent, label, lastCount, type);
            insertedNode = &rootNodes [$-1];
        }
        // Cannot assign &this in the constructor.
        import espukiide.gui : GUINode;
        insertedNode.guiNode = new GUINode (label, insertedNode);
        nodes [lastCount] = insertedNode;
        currentNode = lastCount;
        lastCount ++;
    }
    static void deleteNode (uint nodeNumber) {
        auto toDelete = nodeNumber in nodes;
        import std.conv : to;
        import std.exception : enforce;
        enforce (toDelete, `Node ` ~ nodeNumber.to!string ~ ` doesn't exist.`);
        // Should delete from rootNodes
        import std.algorithm.searching : countUntil;
        auto nodeToDel = rootNodes.countUntil!((ref a) => &a == *toDelete);
        if (nodeToDel != -1) { // Is in root nodes.
            import std.algorithm.mutation : remove;
            rootNodes = rootNodes.remove (nodeToDel);
        }
        // Should change currentNode if it's the deleted node.
        if (*toDelete == currentNode) { // Current node is changed.
            if (nodes.length > 1) {
                currentNode = (*toDelete).nodeNumber == nodes.keys [0] ? 
                /**/ nodes.keys [1] : nodes.keys [0];
            } else { // No nodes after this one.
                currentNode = INVALID_NODE;
            }
        }
        nodes.remove (nodeNumber);
        // Node should clean itself and its children.
        (*toDelete).cleanUp;
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
        import std.conv : to;
        enforce (toRet, `Tried accessing a non-existent node: `
        /**/ ~ m_currentNode.to!string);
        return * toRet;
    }
    /**************************************************************************
     * Set the currently selected node by index in nodes.
     **************************************************************************/
    @property private static currentNode (uint newVal) {
        if (newVal == INVALID_NODE) { // Doesn't check existence in nodes.
            m_currentNode = INVALID_NODE;
            return;
        }
        import std.exception : enforce;
        enforce (newVal in nodes
        /**/ , `Tried assigning the current node to a non-existent one`);
        import espukiide.gui : Attribute;
        if (m_currentNode != INVALID_NODE) {
            currentNode.guiNode.removeAttribute (Attribute.Selected);
        }
        // Current node has been set.
        m_currentNode = newVal;
        currentNode.guiNode.addAttribute (Attribute.Selected);
    }
    /**************************************************************************
     * Set the currently selected node by node pointer.
     **************************************************************************/
    @property private static currentNode (Node * newVal) {
        this.currentNode = newVal.nodeNumber;
    }
    private static uint m_currentNode = INVALID_NODE;
}

enum NodeType {Expression, Declaration}
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
    @property NodeType type () {return m_type;}
    // A 'destructor'. Should be called before deleting this node.
    private void cleanUp () {
        foreach (ref child; this.children) {
            // Should delete children before this node.
            Controller.deleteNode (child.nodeNumber);
        }
        if (this.parent) {
            import std.algorithm.searching : countUntil;
            auto pos = parent.children.countUntil!(a => a == this);
            assert (pos != -1);
            import std.algorithm.mutation : remove;
            parent.children = parent.children.remove (pos);
        }
        // Should also clean up the GUI.
        this.guiNode.remove;
    }
    private @property void guiNode (GUINode * newNode) { m_guiNode = newNode; }
    private @property void value (string newValue) { 
        m_value = newValue;
        guiNode.text = newValue;
    }
    @disable this ();
    private this (Node * parent, string value, uint nodeNumber, NodeType type) {
        this.parent     = parent;
        this.children   = [];
        this.m_value    = value;
        this.nodeNumber = nodeNumber;
        this.m_type     = type;
    }
    private GUINode * m_guiNode = null;
    private string m_value      = null;
    private NodeType m_type;
}
