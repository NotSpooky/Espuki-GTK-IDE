module espukiide.memberinjector;

/// Used for creating variables that have database-like triggers.
/// They are delegates stored in an array called varNameTriggers.
/// When importing this module, selective imports shouldn't be used.


/******************************************************************************
 * To be used in a mixin.
 * Generates a private variable, a public getter, a setter 
 * and an array of callbacks to be called when the setter is called (triggers).
 * Params:
 *      Type = The type of the variable.
 *      name = The name of the variable, as a string.
 ******************************************************************************/
mixin template createTrigger (Type, string name) {
    //TO DO: Check name is a valid variable name.
    mixin (`VariableWithTrigger!(Type) m_` ~ name ~ `;`);
    // Getter.
    mixin (`@property auto ref ` ~ name ~ `() {
        return m_` ~ name ~ `;
    }`);
    // Setter.
    mixin (`@property void ` ~ name ~ `(Type rhs) {
        foreach (ref trigger; m_` ~ name ~ `.beforeAssignment) {
            trigger (m_` ~ name ~`);
        }
        m_` ~ name ~ ` = rhs;
        foreach (ref trigger; m_` ~ name ~ `.assignTriggers) {
            trigger (m_` ~ name ~`);
        }
    }`);
}

/* 'private:' Can't mark the functions below as private because then they can't
   be mixed in. */

unittest {
    int value = 0;
    struct Example {
        mixin createTrigger !(int, `foo`, (n=>n*2));
        this (bool) {
            // Callback from the same struct.
            fooTrigger ~= &internalTrigger;
        }
        void internalTrigger (int num) {value += num;}
    }
    Example ex = Example (true);
    void externalTrigger (int num) {value += num * 2;}
    assert (ex.foo == 0 && value == 0);
    ex.foo = 1;
    import std.conv : text;
    // Modified setter sets to the number * 2;
    assert (ex.foo == 2 && value == 2, text (ex.foo, ` `, value));
    ex.fooTriggers ~= &externalTrigger;
    ex.foo = 1;
    // Both triggers are triggers, one sums 2 and the other 4.
    assert (ex.foo == 2 && value == 8, text (ex.foo, ` `, value));
}

struct VariableWithTrigger (Type) {

    Type value;
    alias value this;
    /// Array of triggers that are called whenever `variable = rhs` is used.
    void delegate (Type) [] assignTriggers;
    /// Same as above but called before the assignment is done.
    void delegate (Type) [] beforeAssignment;
    /+ Doesn't work. Assignment implemented in createTrigger.
    void opAssign (T)(T rhs) {
        this.value = rhs;
        foreach (ref trigger; assignTriggers) {
            trigger (this.value);
        }
    }+/

    import std.traits : isArray, isAssociativeArray;
    static if (isArray!Type) {
        import std.range : ElementType;
        alias BaseType = ElementType!Type;

        /// Array of triggers that are called whenever `variable ~= rhs`
        /// is used.
        void delegate (BaseType) [] appendTriggers;

        /**********************************************************************
         * Overload of appending for normal arrays.
         * Calls all members of appendTriggers with the appended value.
         * For example when using `value ~= rhs`.
         **********************************************************************/
        auto ref opOpAssign (string operator) (BaseType rhs) {
            mixin (`this.value ` ~ operator ~ `= rhs;`);
            static if (operator == `~`) {
                // Calls each trigger with the appended value.
                foreach (ref trigger; appendTriggers) {
                    trigger (rhs);
                }
            }
        }
    } else static if ( // Is associative array.
    /**/ is (Type == ValueType [IndexType], ValueType, IndexType) ) {
        import std.typecons : Tuple, tuple;
        /// Array of triggers that are called whenever `variable [index] = rhs`
        /// is used.
        void delegate (ValueType newVal, IndexType index, bool existedBefore) []
        /**/ indexAssignTriggers;
        /// Array of triggers that are called whenever `variable.remove [index]`
        /// is called.
        void delegate (ValueType oldVal, IndexType index) [] removeTriggers;

        /**********************************************************************
         * Overload of indexed appending for associative arrays.
         * Calls all members of indexAssignTriggers with the appended value.
         **********************************************************************/
        auto ref opIndexAssign (ValueType newVal, IndexType index) {
            bool exists = index in value ? true : false;
            value [index] = newVal;
            foreach (ref trigger; indexAssignTriggers) {
                trigger (newVal, index, exists);
            }
        }
        /**********************************************************************
         * Overload of the remove function for associative arrays.
         * Calls all members of removeTriggers with the removed value and index.
         **********************************************************************/
        auto ref remove (IndexType index) {
            foreach (ref trigger; removeTriggers) {
                trigger (value [index], index);
            }
            value.remove (index);
        }
    }
}
