module espukiide.gui;

static struct GUI {
    /**************************************************************************
     * Starts running the graphical interface.
     * params:
     *      args The args from main.
     **************************************************************************/
    static void start (string [] args) {
        import gtk.Main : Main;
        // Needed for GTK.
        Main.init(args);
        import gtk.MainWindow;
        mainWindow = new MainWindow ("Espuki IDE");
        mainWindow.setDefaultSize (500, 500);
        import gtk.Box;
        auto mainBox = new Box (Orientation.VERTICAL, /*Spacing*/ 15);
        // Initializes GUI elements.
            import gtk.MenuBar;
            auto mainMenu = new MenuBar ();
                import gtk.MenuItem;
                mainMenu.append ("_File");
            mainBox.add (mainMenu);
            import gtk.Entry;
            mainEntry = new Entry ();
            // Enter key is pressed.
            mainEntry.addOnActivate  (n => commandEntered (n));
            mainBox.add (mainEntry);
            import gtk.Label;
            mainOutput = new Label ("Start by typing a function name.");
            mainBox.add (mainOutput);
            canvas = new Canvas ();
            mainBox.add (canvas);
        mainWindow.add (mainBox);

        // Starts the application.
        mainWindow.showAll();
        Main.run();
    }
    static Canvas canvas         = null;
    import gtk.Entry;
    static Entry mainEntry       = null;
    import gtk.Label;
    static Label mainOutput      = null;
    import gtk.MainWindow;
    static MainWindow mainWindow = null;

    import gtk.Entry;
    private static void commandEntered (T)(T label) {
        assert (label && label == mainEntry);
        auto command = label.getText;
        debug {
            import std.stdio;
            writeln ("Command: ", command);
        }
        try {
            import espukiide.controller;
            Controller.parseCommand (command);
            mainOutput.setText ("");
        } catch (Exception e) {
            mainOutput.setText (e.msg);
        }
        label.setText ("");
    }
}

struct GUINode {
    import gtk.Box;
    Box verticalBox = null; /// Contains the main info of this node.
    Box childBox    = null; /// Contains this nodes children.
    
    @disable this ();
    /**************************************************************************
     *
     * Params:
     *      label = Text to display.
     *      node  = Controller node that contains the logic of this graphical
     *            node.
     **************************************************************************/
    this (string label, Node * node) {
        assert (node, `There should be a node`);
        this.verticalBox = new Box (Orientation.VERTICAL  , /*Spacing*/ 5);
        this.childBox    = new Box (Orientation.HORIZONTAL, /*Spacing*/ 10);
        this.node = node;
        import std.conv : to;
        import gtk.Label;
        this.verticalBox.add (new Label (node.nodeNumber.to!string));

        this.m_label = NodeLabel (label, verticalBox);
        this.verticalBox.add (this.childBox);
        if (parent) {
            // This box is added to the childBox of the parent.
            parent.childBox.add (this.verticalBox);
        } else {
            // Root node.
            GUI.canvas.rootBox.add (this.verticalBox);
            this.m_label.addAttribute (NodeLabel.Attribute.Declaration);
        }
        //this.label.setHasFrame = false;
        GUI.mainWindow.showAll;
    }


    @property void text (string newValue) {
        m_label.text = newValue;
    }
    /**************************************************************************
     * Deletes this widgets contents.
     **************************************************************************/
    void remove () {
        this.verticalBox.destroy;
        this.verticalBox = null;
        this.childBox    = null;
        this.node        = null;
    }
    
    /**************************************************************************
     * Returns the GUINode of the parent.
     * Null if it doesn't exist.
     **************************************************************************/
    @property GUINode * parent () {
        assert (this.node);
        return node.parent ? node.parent.guiNode : null;
    }

    /**************************************************************************
     *
     **************************************************************************/
    @property void isCurrentlySelected (bool newValue) {
        if (newValue) {
            this.m_label.addAttribute (NodeLabel.Attribute.Selected);
        } else {
            this.m_label.removeAttribute (NodeLabel.Attribute.Selected);
        }
    }
    @property auto ref type () {
        assert (this.node);
        import espukiide.controller : Node;
        return this.node.type;
    }

    import gtk.Label;
    private NodeLabel m_label;
    import espukiide.controller : Node;
    private Node * node = null;    /// Controller counterpart.
}

import gtk.Layout;
private class Canvas : Layout {
    import gtk.Box;
    Box rootBox = null;
    this () {
        import gtk.Adjustment;
        super (new Adjustment (0,0,1000,1,10,10)
        /**/ ,new Adjustment (0,0,1000,1,10,10));

        this.setSize (500, 500);
        this.setSizeRequest (500,500);
        addOnDraw (&drawn); // Sets the callback.
        import gtk.Box;
        rootBox = new Box (Orientation.HORIZONTAL, 30);
        this.put (rootBox, 0, 0);
    }

    import cairo.Context;
    import gtk.Widget;
    private bool drawn (Scoped!Context cr, Widget widget) {
        /+
        import cairo.Surface;
        debug {
        cr.setSourceRgb (0.5, 0.6, 0.7);
        cr.setLineWidth (2);
        cr.arc (125, 125, 25, 0, 2*3.14159);
        cr.rectangle (10, 10, 20, 20);
        cr.stroke;
        }+/
        return false; // Allows the contained widgets to be rendered.
    }
}

struct NodeLabel {
    @disable this ();
    import gtk.Box;
    this (string labelText, ref Box box) {
        import std.range    : repeat, take;
        import std.array    : array;
        import std.bitmanip : BitArray;
        this.m_attributes // All initialized to false.
        /**/ = BitArray (false.repeat.take(Attribute.max + 1).array);

        import gtk.Label;
        this.m_label = new Label (``);
        this.text (labelText);
        this.m_label.setMarginBottom (20);
        this.m_label.setSelectable (true); // Allows copying their text.
        box.add (m_label);
    }
    import gtk.Label;
    private Label label;
    private string labelText;
    enum Attribute {Selected, Declaration}
    void addAttribute (Attribute attribute) {
        if (!m_attributes [attribute]) {
            m_attributes [attribute] = true;
            updateState;
        }
    }
    void removeAttribute (Attribute attribute) {
        if (m_attributes [attribute]) {
            m_attributes [attribute] = false;
            updateState;
        }
    }
    @property void text (string newValue) {
        rawText = newValue;
        updateState;
    }
    enum declarationColor = `#00657F`;
    /***************************************************************************
     * Updates the text output.
     * Should be called whenever there's some change to it.
     **************************************************************************/
    private void updateState () {
        string markup = ``;
        m_label.setMarkup (rawText);
        if (m_attributes [Attribute.Selected]) {
            markup ~= `weight='bold' `;
        }
        if (m_attributes [Attribute.Declaration]) {
            markup ~= `size='x-large' color='` ~ declarationColor ~ `'`;
        }
        m_label.setMarkup (`<span ` ~ markup ~ `>` ~ rawText ~ `</span>`);
    }
    import std.bitmanip : BitArray;
    private BitArray m_attributes;
    import gtk.Label;
    private Label m_label;
    string rawText; /// Without formatting.
}
