module espukiide.gui;

import espukiide.stringhandler : _;
enum defaultFilename = `newFile.es`;

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
            notebook.appendPage (new Canvas (), defaultFilename);
            tabs ~= new Tab (defaultFilename);
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
        try {
            import espukiide.tab;
            static if (newFile) {
                tabs ~= new Tab (defaultFilename);
            } else { // Opening a file.
                string absFilename = GUI.getFilename (false);
                if (!absFilename) return;
                tabs ~= new Tab (absFilename);
            }
            auto index = notebook.appendPage (new Canvas ()
            /**/ , tabs [$-1].absoluteFilePath);
            // GTK limitation, child should be visible.
            notebook.showAll;
            notebook.setCurrentPage (index);
            static if (!newFile) {
                    tabs [$-1].openFile (absFilename);
            }
        } catch (Exception ex) {
            assert (tabs.length, `Just inserted a tab, it should exist.`);
            tabs = tabs [0 .. $-1];
            notebook.detachTab (
            /**/ notebook.getNthPage (
            /**  **/ notebook.getCurrentPage
            /**/ )
            );
            throw ex;
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
