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
    private static void commandEntered (T)(T entry) {
        assert (entry && entry == mainEntry);
        auto command = entry.getText;
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
        entry.setText ("");
    }
}

struct GUINode {
    import gtk.Box;
    Box verticalBox = null; /// Contains the main info of this node.
    Box childBox    = null; /// Contains this nodes children.
    import gtk.Entry;
    Entry entry     = null; /// Graphical text of the node, might differ from
                            /// information of the controller.
    import espukiide.controller;
    Node * node     = null; /// Controller counterpart.
    
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
        assert (label);
        this.verticalBox = new Box (Orientation.VERTICAL  , /*Spacing*/ 5);
        this.childBox    = new Box (Orientation.HORIZONTAL, /*Spacing*/ 10);
        this.node = node;
        import std.conv : to;
        import gtk.Label;
        this.verticalBox.add (new Label (node.nodeNumber.to!string));
        this.entry = new Entry (label);
        this.entry.setMarginBottom (20);
        this.verticalBox.add (this.entry);
        this.verticalBox.add (this.childBox);
        if (parent) {
            // This box is added to the childBox of the parent.
            parent.childBox.add (this.verticalBox);
        } else {
            // Root node.
            GUI.canvas.rootBox.add (this.verticalBox);
        }
        this.entry.setHasFrame = false;
        GUI.mainWindow.showAll;
    }


    /**************************************************************************
     * Deletes this widgets contents.
     **************************************************************************/
    void remove () {
        this.verticalBox.destroy;
        this.verticalBox = null;
        this.childBox    = null;
        this.entry       = null;
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

    @property void label (string newLabel) {
        assert (this.entry);
        this.entry.setText (newLabel);
    }
    
    /**************************************************************************
     *
     **************************************************************************/
    @property void isCurrentlySelected (bool newValue) {
        assert (this.entry);
        this.entry.setHasFrame (newValue);
    }
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
