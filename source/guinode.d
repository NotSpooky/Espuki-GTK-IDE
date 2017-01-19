module espukiide.guinode;

class GUINode {
    import espukiide.node : Node;
    /**************************************************************************
     **************************************************************************/
    this (Node node) {
        this.node = node;
        this.verticalBox = new Box (Orientation.VERTICAL  , /*Spacing*/ 10);
        import gtkc.gtktypes : GtkAlign;
        this.verticalBox.setHalign (GtkAlign.FILL);
        this.childBox    = new Box (Orientation.HORIZONTAL, /*Spacing*/ 10);
        this.childBox.setHalign (GtkAlign.CENTER);
        import std.conv : to;
        import gtk.Frame;
        this.frame = new Frame (this.node.nodeNumber.to!string);
        this.frame.setHalign (GtkAlign.FILL);
        import espukiide.node : NodeType;
        if (this.node.type == NodeType.Declaration) {
            import gtkc.gtktypes : GtkShadowType;
            this.frame.setShadowType (GtkShadowType.NONE);
        }
        this.verticalBox.add (this.frame);
        createLabel ();
        this.frame.add (m_label);
        this.verticalBox.add (this.childBox);
        if (this.node.parent) {
            // This box is added to the childBox of the parent.
            this.node.parent.guiNode.childBox.add (this.verticalBox);
        } else {
            // Root node.
            import espukiide.gui : GUI;
            GUI.currentCanvas.rootBox.add (this.verticalBox);
        }
        verticalBox.showAll;
        this.node.valueTriggers    ~= (n=> updateState);
        this.node.typeTriggers     ~= (n=> updateState);
        this.node.selectedTriggers ~= (n=> updateState);
        this.node.deletedTriggers  ~= (n=> GUIDestructor (n));
        this.updateState;
    }

    import gtk.Box;
    Box verticalBox = null; /// Contains this entire node.
    Frame frame     = null; /// Contains this nodes data.
    Box childBox    = null; /// Contains this nodes children.
    import gtk.Frame;
    mixin NodeLabel;

    /**************************************************************************
     * Deletes this widgets contents.
     **************************************************************************/
    void GUIDestructor (bool deletedValue) {
        assert (deletedValue, `node's deleted should only change to true`);
        this.verticalBox.destroy;
        this.verticalBox = null;
        this.childBox    = null;
        this.frame       = null;
    }
    
    /**************************************************************************
     * Returns the x and y positions of the middle of the frame at the top
     **************************************************************************/
    @property auto ref topJoint () {
        return [boundingBox.x + (boundingBox.width / 2.0), boundingBox.y];
    }

    /**************************************************************************
     * Returns the x and y positions of the middle of the frame at the bottom.
     **************************************************************************/
    @property auto ref bottomJoint () {
        return [boundingBox.x + (boundingBox.width / 2.0)
        /**/ , boundingBox.y + (boundingBox.height)];
    }

    /**************************************************************************
     * Utility function for bottomJoint and topJoint.
     **************************************************************************/
    private auto ref boundingBox () {
        import gtkc.gdktypes : GdkRectangle;
        GdkRectangle toRet;
        // Uses an out parameter to return.
        this.frame.getAllocation (toRet);
        return toRet;
    }

    import espukiide.node;
    private Node node = null;
}

mixin template NodeLabel () {
    import gtk.Box;
    void createLabel () {
        import gtk.Label;
        this.m_label = new Label (``);
        this.m_label.setSelectable (true); // Allows copying their text.
    }

    enum declarationColor = `#00657F`;
    /***************************************************************************
     * Updates the text output.
     * Should be called whenever there's some change to it.
     **************************************************************************/
    private void updateState () {
        string markup = ``;
        if (this.node.selected) {
            markup ~= `weight='bold' `;
        }
        final switch (this.node.type) {
            import espukiide.node : NodeType;
            case NodeType.Expression: // Use default.
                break;
            case NodeType.Declaration:
                markup ~= `size='x-large' color='` ~ declarationColor ~ `'`;
                break;
        }
        import glib.SimpleXML;
        auto rawText = this.node.value;
        m_label.setMarkup (`<span ` ~ markup ~ `>` 
        /**/ ~ SimpleXML.markupEscapeText (rawText, rawText.length) 
        /**/ ~ `</span>`);
    }
    import gtk.Label;
    private Label label;
    import gtk.Label;
    private Label m_label;
}
