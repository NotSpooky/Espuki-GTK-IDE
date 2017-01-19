module espukiide.tab;

enum defaultFilename = `newFile.es`;
class Tab {
    @disable this ();
    this (string absoluteFilePath = defaultFilename) {
        this.absoluteFilePath = absoluteFilePath;
    }
    void parseCommand (string command) {
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
        debug (2) {
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
        /**/ ~ match.matches [0] ~ ` ` ~ match.matches [1]);
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
                        this.addNode (currentNode /* Parent*/
                        /**/ , match.matches [2] /*Value*/
                        /**/ , NodeType.Expression);
                    } else { // No nodes, should create a new node.
                        addRootNode (match.matches [2]);
                    }
                } else if (following.name == `Command.DeleteNode`) {
                    enforce (selectedNode != INVALID_NODE, `No node to delete`);
                    this.deleteNode (selectedNode);
                } else if (following.name == `Command.Expression`) {
                    if (selectedNode != INVALID_NODE) {
                        this.currentNode = selectedNode;
                        if (following.children [0].name != `Command.Empty`) {
                            // If Empty, should just change current node.
                            this.currentNode.value = following.matches [0];
                        }
                    } else { // There's no current node. Create a root one.
                        addRootNode (following.matches [0]);
                    }
                } else { assert (0, `Unexpected command.`);}
                break;
            case `Command.CreateRoot`:
                addRootNode (match.children [1].matches [0]);
                break;
            case `Command.Empty`:        // Do nothing.
                break;
            case `Command.Unrecognised`: // Invalid command.
                throw new Exception (`Unrecognised command: ` ~ command);
            default:
                assert (false, `Incorrect match: ` ~ match.toString);
        }
    }

    private void addRootNode (string value) {
        this.addNode (null /* No parent */, value, NodeType.Declaration);
    }

    import espukiide.node : NodeType, Node;
    /// All new nodes should be created with this.
    private auto ref addNode (Node parent, string label, NodeType type) {
        Node insertedNode = null;
        import espukiide.node : Node;
        if (parent) {
            parent.children ~= new Node (label, this, lastCount, parent, type);
            insertedNode = parent.children [$-1];
        } else { // Root node.
            assert (type == NodeType.Declaration
            /**/ , `Root nodes should be function declarations.`);
            rootNodes ~= new Node (label, this, lastCount, parent, type);
            insertedNode = rootNodes [$-1];
        }
        nodes [lastCount] = insertedNode;
        currentNode = lastCount;
        lastCount ++;
        return insertedNode;
    }

    void deleteNode (uint nodeNumber) {
        auto toDelete = nodeNumber in nodes;
        import std.conv : to;
        import std.exception : enforce;
        enforce (toDelete, `Node ` ~ nodeNumber.to!string ~ ` doesn't exist.`);
        // Should delete from rootNodes
        import std.algorithm.searching : countUntil;
        auto nodeToDel = rootNodes.countUntil!((ref a) => a == *toDelete);
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
        (*toDelete).controllerDestructor;
    }

    void saveFile (lazy string filename, bool askFileAnyways) {
        pragma (msg, `TO DO: Append espuki version to saved file.`);
        import std.stdio;
        import std.file : append, write;
        if (askFileAnyways || !savedYet) { // Ask filename.
            string fileToUse = filename;
            if (!fileToUse) return; // User cancelled operation.
            this.absoluteFilePath = fileToUse;
        }
        savedYet = true;
        debug writeln (`Saving `, this.absoluteFilePath);
        this.absoluteFilePath.write (``); // Clears the file.
        import std.algorithm.iteration : joiner, map;
        import std.conv : to;
        import espukiide.node : Node;
        this.absoluteFilePath.append ( 
            `[` ~
            rootNodes
            .map!(n=>n.toJSON)
            .joiner(`, `)
            .to!string
             ~ `]`
        );
    }

    /// Params:
    ///     filename = absolute file path of the opened file.
    void openFile (string filename) {
        pragma (msg, `TO DO: Test NaN and non-ASCII JSON.`);
        import std.stdio;
        debug writeln (`Opening `, filename);
        import std.json;
        import std.file : read;
        import std.conv : to;
        try {
            // File format expects an array with the objects of the root nodes
            // inside.
            JSONValue document = parseJSON (
            /**/ filename.read.to!string
            /**/ , -1 /* No depth checking */
            /**/ , JSONOptions.specialFloatLiterals );
            savedYet = true;
            this.absoluteFilePath = filename;
            foreach (ref newRoot; document.array) {
                this.fromJSON (newRoot, null /* No parent */);
            }
        }
        catch (JSONException e) {
            throw new JSONException (`Error reading file: ` ~ e.msg);
        }
    }

    import std.json : JSONValue;
    private void fromJSON (JSONValue jValue, Node parent) {
        import std.json;
        import std.conv : to;
        auto newNode = this.addNode (parent, jValue [`value`].str
        /**/ , jValue [`type`].str.to!NodeType);
        auto children = `children` in jValue;
        if (children) {
            foreach (child ; children.array) {
                fromJSON (child, newNode);
            }
        }
    }

    /**************************************************************************
     * Get currently selected node.
     **************************************************************************/
    @property private Node currentNode () {
        auto toRet = m_currentNode in nodes;
        import std.exception : enforce;
        import std.conv : to;
        enforce (toRet, `Tried accessing a non-existent node: `
        /**/ ~ m_currentNode.to!string);
        return *toRet;
    }
    /**************************************************************************
     * Set the currently selected node by index in nodes.
     **************************************************************************/
    @property private void currentNode (uint newVal) {
        if (newVal == INVALID_NODE) { // Doesn't check existence in nodes.
            m_currentNode = INVALID_NODE;
            return;
        }
        import std.exception : enforce;
        enforce (newVal in nodes
        /**/ , `Tried assigning the current node to a non-existent one`);
        if (m_currentNode != INVALID_NODE) { 
            // De-selects currently selected node.
            currentNode.selected = false;
        }
        // Current node has been set.
        m_currentNode = newVal;
        currentNode.selected = true;
    }
    /**************************************************************************
     * Set the currently selected node by node pointer.
     **************************************************************************/
    @property private void currentNode (Node newVal) {
        this.currentNode = newVal.nodeNumber;
    }

    Node [uint] nodes; /// All nodes, identified by a number.
    bool modifiedSinceSaved = false; /// If true, should ask when exiting or
                                     /// compiling.
    import espukiide.memberinjector;
    // string absoluteFilePath; /// Filename of the file opened in this tab.
    mixin createTrigger!(string, `absoluteFilePath`);

    private uint lastCount     = 0;     /// Used for assigning ids to new nodes.
    private Node [] rootNodes  = [];    /// Nodes without parent.
    private bool      savedYet = false; /// False in new files until saved.
                                        /// true in opened files.
    import espukiide.node : INVALID_NODE;
    private uint m_currentNode = INVALID_NODE;

}
