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
        import espukiide.controller;
        tabs ~= Controller ();
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
                import std.stdio;
                import gtk.Main;
                import gdk.Keysyms : GdkKeysyms;
                MenuItem quitMenuIt = new MenuItem ((n=>Main.quit), `_Quit`
                /**/ , ``, true, accelGroup, GdkKeysyms.GDK_Q);
                fileMenu.append (quitMenuIt);
                import espukiide.controller;
                MenuItem openMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.useFile!false))
                /**/ , `_Open`, ``, true, accelGroup, GdkKeysyms.GDK_O);
                fileMenu.append (openMenuIt);
                MenuItem saveMenuIt = new MenuItem (
                /**/ (n=>tryFun!(GUI.useFile!true))
                /**/ , `_Save`,``, true, accelGroup, GdkKeysyms.GDK_S);
                fileMenu.append (saveMenuIt);
            mainBox.add (mainMenu);
            import gtk.Entry;
            mainEntry = new Entry ();
            // Enter key is pressed.
            mainEntry.addOnActivate  (n => tryFun!(GUI.commandEntered) (n));
            mainBox.add (mainEntry);
            import gtk.Label;
            mainOutput = new Label ("Start by typing a function name.");
            mainBox.add (mainOutput);
            import gtk.Notebook;
            notebook = new Notebook ();
            mainBox.add (notebook);
            notebook.appendPage (new Canvas (), `newfile.es`);
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
    /// Opens or saves a file depending on the saving parameter.
    static void useFile (bool saving) () {
        pragma (msg, `TODO: Ask when overwriting.`);
        auto filename = GUI.chooseFile!saving;
        if (!filename) return;
        import espukiide.controller;
        static if (saving) {
            currentTab.saveFile (filename);
        } else {
            tabs ~= Controller ();
            auto index = notebook.appendPage (new Canvas (), filename);
            import std.stdio;
            writeln (`index is: `, index);
            // GTK limitation, child should be visible.
            notebook.showAll;
            notebook.setCurrentPage (index);
            currentTab.openFile (filename);
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
    import espukiide.controller;
    static Controller [] tabs    = [];
    @property static Canvas currentCanvas () {
        return cast (Canvas) notebook.getNthPage (notebook.getCurrentPage);
    }

    import gtk.Entry;
    private static void commandEntered (T)(T label) {
        assert (label && label == mainEntry);
        auto command = label.getText;
        debug {
            import std.stdio;
            writeln ("Command: ", command);
        }
        import espukiide.controller;
        currentTab.parseCommand (command);
        mainOutput.setText ("");
        label.setText ("");
    }

    /**************************************************************************
     * Params:
     *      saving wether its saving (true) or opening files (false).
     **************************************************************************/
    static auto ref chooseFile (bool saving) () {
        pragma (msg, `TO DO: Switch places between filechoosers OK and Cancel`);
        import gtk.FileChooserDialog;
        static if (saving) {
            auto fileAction = FileChooserAction.SAVE;
        } else {
            auto fileAction = FileChooserAction.OPEN;
        }
        auto fileChooser = new FileChooserDialog (`Select file(s)`, mainWindow
        /**/ , fileAction, null /*Button text*/);
        fileChooser.run;
        fileChooser.hide;
        /+static if (saving) {+/
            auto toRet = fileChooser.getFilename;
        /+} else {
            // Segfaults.
            fileChooser.setSelectMultiple (true);
            import glib.ListSG; // Singly-linked list.
            import gobject.Value;
            string [] toRet = [];
            auto filenames = fileChooser.getFilenames.toArray!Value;
            foreach (filename; filenames) {
                toRet ~= filename.getString;
            }
        }+/
        return toRet;
    }
    
    @property static auto ref currentTab () {
        import gtk.Notebook;
        auto currentPageNum = notebook.getCurrentPage;
        import std.stdio;
        writeln (`Using page: `, currentPageNum);
        assert (tabs.length > currentPageNum);
        return (tabs [currentPageNum]);
    }

}

struct GUINode {
    import gtk.Box;
    Box verticalBox = null; /// Contains the main info of this node.
    Box childBox    = null; /// Contains this nodes children.
    
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
        this.verticalBox = new Box (Orientation.VERTICAL  , /*Spacing*/ 5);
        this.childBox    = new Box (Orientation.HORIZONTAL, /*Spacing*/ 10);
        this.node = node;
        import std.conv : to;
        import gtk.Label;
        this.verticalBox.add (new Label (node.nodeNumber.to!string));
        createLabel (labelText);
        this.verticalBox.add (m_label);
        this.verticalBox.add (this.childBox);
        if (parent) {
            // This box is added to the childBox of the parent.
            parent.childBox.add (this.verticalBox);
        } else {
            // Root node.
            GUI.currentCanvas.rootBox.add (this.verticalBox);
        }
        //this.label.setHasFrame = false;
        GUI.mainWindow.showAll;
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

    @property auto ref type () {
        return this.node.type;
    }
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

enum Attribute {Selected}
mixin template NodeLabel () {
    import gtk.Box;
    void createLabel (string labelText) {
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
    }
    import gtk.Label;
    private Label label;
    private string labelText;
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
        if (m_attributes [Attribute.Selected]) {
            markup ~= `weight='bold' `;
        }
        final switch (this.type) {
            import espukiide.controller : NodeType;
            case NodeType.Expression: // Use default.
                break;
            case NodeType.Declaration:
                markup ~= `size='x-large' color='` ~ declarationColor ~ `'`;
                break;
        }
        import glib.SimpleXML;
        m_label.setMarkup (`<span ` ~ markup ~ `>` 
        /**/ ~ SimpleXML.markupEscapeText (rawText, rawText.length) 
        /**/ ~ `</span>`);
    }
    import std.bitmanip : BitArray;
    private BitArray m_attributes;
    import gtk.Label;
    private Label m_label;
    string rawText; /// Without formatting.
}
