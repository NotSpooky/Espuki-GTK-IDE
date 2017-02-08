module espukiide.guitab;

class GUITab {
    @disable this ();
    import gtk.Notebook;
    this (Tab tab, Notebook notebook) {
        this.tab = tab;
        this.canvas = new Canvas ();
        notebook.appendPage (this.canvas, this.tab.absoluteFilePath);
        notebook.showAll;
        notebook.setCurrentPage (this.canvas);
        this.tab.absoluteFilePath.assignTriggers ~= 
        /**/ (filename => notebook.setTabLabelText (this.canvas, filename));
    }
    import espukiide.tab : Tab;
    private Tab tab           = null;
    private Canvas canvas     = null;
    @property auto ref rootBox () {
        return this.canvas.rootBox;
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
        import espukiide.gui : GUI;
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
