module espukiide.gui;

import espukiide.stringhandler : _;

pragma (msg, `TO DO: If the default file is open but has no changes, opening `
/**/ ~ `a new one should overwrite it.`);

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
        // Accel group is used for global keybindings like Control-Q
        import gtk.AccelGroup;
        auto accelGroup = new AccelGroup ();
        mainWindow.addAccelGroup (accelGroup);

        import gtk.Box;
        auto mainBox = new Box (Orientation.VERTICAL, /*Spacing*/ 15);
        // Initializes GUI elements.
            import gtk.MenuBar;
            auto mainMenu = new MenuBar ();
                auto fileMenu = mainMenu.append ("_File");
                import gtk.MenuItem;
                import gdk.Keysyms : GdkKeysyms;
                MenuItem newMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.openFile!true))
                /**/ , `_New`, ``, true, accelGroup, GdkKeysyms.GDK_N);
                fileMenu.append (newMenuIt);
                MenuItem openMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.openFile!false))
                /**/ , `_Open`, ``, true, accelGroup, GdkKeysyms.GDK_O);
                fileMenu.append (openMenuIt);
                MenuItem saveMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.saveCurrentFile)(false))
                /**/ , `_Save`, ``, true, accelGroup, GdkKeysyms.GDK_S);
                fileMenu.append (saveMenuIt);
                import gtkc.gdktypes : GdkModifierType;
                MenuItem saveAsMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.saveCurrentFile)(true))
                /**/ , `S_ave as`, ``, true, accelGroup, GdkKeysyms.GDK_S
                /**/ , GdkModifierType.CONTROL_MASK
                /**/ | GdkModifierType.SHIFT_MASK);
                fileMenu.append (saveAsMenuIt);
                MenuItem closeMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.closeCurrentFile))
                /**/ , `_Close file`, ``, true, accelGroup, GdkKeysyms.GDK_W);
                fileMenu.append (closeMenuIt);
                import gtk.Main;
                MenuItem quitMenuIt = new MenuItem ((n=>Main.quit)
                /**/ , `_Quit`, ``, true, accelGroup, GdkKeysyms.GDK_Q);
                fileMenu.append (quitMenuIt);

            mainBox.add (mainMenu);
            import gtk.Entry;
            mainEntry = new Entry ();
            // Enter key is pressed.
            mainEntry.addOnActivate  (n => tryFun!(GUI.commandEntered) (n));
            mainBox.add (mainEntry);
            import gtk.Label;
            mainOutput = new Label (_("Welcome"));
            mainBox.add (mainOutput);
            import gtk.Notebook;
            notebook = new Notebook ();
            mainBox.add (notebook);
            import espukiide.tab;
            tabs ~= Tab ();
            notebook.appendPage (new Canvas (), tabs [0].absoluteFilePath);
        mainWindow.add (mainBox);

        // Starts the application.
        mainWindow.showAll();
        Main.run();
    }
    /**************************************************************************
     * Tries executing fun with args as arguments.
     * Any exception thrown has its error shown on mainOutput.
     **************************************************************************/
    static void tryFun (alias fun, S ...) (S args) {
        try {
            fun (args);
            mainOutput.setLabel (``);
        } catch (Exception e) {
            assert (mainOutput, `mainOutput is null.`);
            import glib.SimpleXML;
            mainOutput.setMarkup (
            /**/ `<span color='red'>`
            /**/ ~ SimpleXML.markupEscapeText (e.msg, e.msg.length)
            /**/ ~ `</span>`
            );
        }
    }
    static void saveCurrentFile (bool askFileAnyways) {
        currentTab.saveFile (GUI.getFilename (true), askFileAnyways);
    }

    /// Opens or creates a file depending on the new parameter.
    static void openFile (bool newFile)() {
        string filename = `newTab.es`;
        static if (!newFile) {
            filename = GUI.getFilename (false);
            if (!filename) return;
        }
        try {
            auto index = notebook.appendPage (new Canvas (), filename);
            // GTK limitation, child should be visible.
            notebook.showAll;
            notebook.setCurrentPage (index);
            import espukiide.tab;
            tabs ~= Tab ();
            static if (!newFile) {
                currentTab.openFile (filename);
            }
        } catch (Exception e) {
            assert (tabs.length, `Just inserted a tab, it should exist.`);
            tabs = tabs [0 .. $-1];
            throw e;
        }
    }

    static void closeCurrentFile () {
        if (!tabs.length) { // Same as Exit.
            import gtk.Main;
            Main.quit;
        } else {
            import std.algorithm.mutation : remove;
            auto tabPos = currentTabPos;
            tabs = tabs.remove (tabPos);
            notebook.detachTab (
            /**/ notebook.getNthPage (
            /**  **/ notebook.getCurrentPage
            /**/ )
            );
        }
    }
    
    import gtk.Notebook;
    static Notebook notebook     = null; /// Contains the tabs.
    import gtk.Entry;
    static Entry mainEntry       = null; /// Text input.
    import gtk.Label;
    static Label mainOutput      = null; /// Shows messages and errors.
    import gtk.MainWindow;
    static MainWindow mainWindow = null;
    import espukiide.tab;
    static Tab [] tabs    = [];
    @property static Canvas currentCanvas () {
        return cast (Canvas) notebook.getNthPage (notebook.getCurrentPage);
    }

    import gtk.Entry;
    private static void commandEntered (T)(T label) {
        assert (label && label == mainEntry);
        auto command = label.getText;
        debug (2) {
            import std.stdio;
            writeln ("Command: ", command);
        }
        import espukiide.tab;
        currentTab.parseCommand (command);
        mainOutput.setText ("");
        label.setText ("");
    }


    
    @property private static auto ref currentTabPos () {
        import gtk.Notebook;
        auto currentPageNum = notebook.getCurrentPage;
        assert (tabs.length > currentPageNum
        /**/ , `Current page cannot exist in tabs`);
        return currentPageNum;
    }
    @property private static auto ref currentTab () {
        return tabs [currentTabPos];
    }

    @property static void filename (string newFilename) {
        notebook.setTabLabelText (
        /**/ notebook.getNthPage (
        /**  **/ notebook.getCurrentPage
        /**/ )
        /**/ , newFilename);
        notebook.showAll;
    }

    /**************************************************************************
     * Asks the user for a file.
     **************************************************************************/
    static string getFilename (bool saving) {
        import gtk.FileChooserDialog;
        auto fileAction = saving ? FileChooserAction.SAVE 
        /**/ : FileChooserAction.OPEN;
        FileChooserDialog dialogWindow = new FileChooserDialog (`Select file(s)`
        /**/ , mainWindow , fileAction, [_(`Cancel`),_(`Ok`)] /*Button text*/
        /**/ , [ResponseType.CANCEL, ResponseType.OK]);
        dialogWindow.setDoOverwriteConfirmation (true);
        dialogWindow.run;
        dialogWindow.hide;
        /+
        // Segfaults. Tried allowing the selection of multiple files.
        fileChooser.setSelectMultiple (true);
        import glib.ListSG; // Singly-linked list.
        import gobject.Value;
        string [] toRet = [];
        auto filenames = fileChooser.getFilenames.toArray!Value;
        foreach (filename; filenames) {
            toRet ~= filename.getString;
        }
        +/
        return dialogWindow.getFilename;
    }
}

struct GUINode {
    import gtk.Box;
    Box verticalBox = null; /// Contains this entire node.
    Frame frame     = null; /// Contains this nodes data.
    Box childBox    = null; /// Contains this nodes children.
    import gtk.Frame;
    
    mixin NodeLabel;
    @disable this ();
    /**************************************************************************
     *
     * Params:
     *      labelText = Text to display.
     *      node  = Controller node that contains the logic of this graphical
     *            node.
     **************************************************************************/
    this (string labelText, Node * node) {
        assert (node, `There should be a node`);
        this.verticalBox = new Box (Orientation.VERTICAL  , /*Spacing*/ 10);
        import gtkc.gtktypes : GtkAlign;
        this.verticalBox.setHalign (GtkAlign.FILL);
        this.childBox    = new Box (Orientation.HORIZONTAL, /*Spacing*/ 10);
        this.childBox.setHalign (GtkAlign.CENTER);
        this.node = node;
        import std.conv : to;
        import gtk.Frame;
        this.frame = new Frame (node.nodeNumber.to!string);
        this.frame.setHalign (GtkAlign.FILL);
        import espukiide.tab : Node, NodeType;
        if (node.type == NodeType.Declaration) {
            import gtkc.gtktypes : GtkShadowType;
            this.frame.setShadowType (GtkShadowType.NONE);
        }
        this.verticalBox.add (this.frame);
        createLabel (labelText);
        this.frame.add (m_label);
        this.verticalBox.add (this.childBox);
        if (parent) {
            // This box is added to the childBox of the parent.
            parent.childBox.add (this.verticalBox);
        } else {
            // Root node.
            GUI.currentCanvas.rootBox.add (this.verticalBox);
        }
        verticalBox.showAll;
        this.node.valueTriggers ~= (n=> updateState);
        this.node.typeTriggers ~= (n=> updateState);
        this.node.selectedTriggers ~= (n=> updateState);
    }

    /**************************************************************************
     * Deletes this widgets contents.
     **************************************************************************/
    void remove () {
        this.verticalBox.destroy;
        this.verticalBox = null;
        this.childBox    = null;
        this.node        = null;
        this.frame       = null;
    }
    
    /**************************************************************************
     * Returns the GUINode of the parent.
     * Null if it doesn't exist.
     **************************************************************************/
    @property GUINode * parent () {
        assert (this.node);
        return node.parent ? node.parent.guiNode : null;
    }

    @property auto ref type () {
        return this.node.type;
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

    import espukiide.tab : Node;
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
    /**************************************************************************
     * To be used as callback for drawing the background lines.
     **************************************************************************/
    private bool drawn (Scoped!Context cr, Widget widget) {
        import cairo.Surface;
        cr.setSourceRgb (0.5, 0.6, 0.7);
        cr.setLineWidth (2);
        foreach (ref node; GUI.currentTab.nodes) {
            foreach (ref child; node.children) {
                auto bottomJoint = node.guiNode.bottomJoint;
                cr.moveTo (bottomJoint [0], bottomJoint [1]);
                auto topJoint    = child.guiNode.topJoint;
                cr.lineTo (topJoint [0], topJoint [1]);
                cr.stroke;
            }
        }
        /+
        cr.arc (125, 125, 25, 0, 2*3.14159);
        cr.rectangle (10, 10, 20, 20);
        cr.stroke;
        }+/
        return false; // Allows the widgets on the Layout to be rendered.
    }
}

mixin template NodeLabel () {
    import gtk.Box;
    void createLabel (string labelText) {
        import std.range    : repeat, take;
        import std.array    : array;
        import std.bitmanip : BitArray;
        import gtk.Label;
        this.m_label = new Label (``);
        this.m_label.setSelectable (true); // Allows copying their text.
    }
    import gtk.Label;
    private Label label;
    private string labelText;
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
        final switch (this.type) {
            import espukiide.tab : NodeType;
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
    import std.bitmanip : BitArray;
    private BitArray m_attributes;
    import gtk.Label;
    private Label m_label;
}


