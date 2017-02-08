module espukiide.memberinjector;

// TO DO: Put everything in the struct.

/// Used for creating variables that have database-like triggers.
/// They are delegates stored in an array called varNameTriggers.
/// When importing this module, selective imports shouldn't be used.

mixin template createTrigger (Type, string name) {
    enum typeStr = Type.stringof;
    enum string privateVarName = `m_` ~ name;
    import std.traits : isArray, isAssociativeArray, PointerTarget;
    static if (isArray!Type && (!is (Type == string))
    /**/ || isAssociativeArray!Type) {
        mixin (generateArray!(typeStr, name));
    } else {
        mixin (generateVariable!(typeStr, name));
    }
    mixin (generateSetter!(typeStr, name, null));
    mixin (generateTriggerArray!(typeStr, name));
}

/******************************************************************************
 * To be used in a mixin.
 * Generates a private variable, a public getter, a setter 
 * and an array of callbacks to be called when the setter is called (triggers).
 * Params:
 *      Type = The type of the variable.
 *      name = The name of the variable, the private one will be called 'm_'name
 *      setterFunction = A custom setter function. The default just returns the
 *      same value. The returned value of this is assigned to the variable.
 * Example:
 *      mixin (createTrigger!(int, "bar"));
 *      Creates an int variable called m_bar, accesible with setter/getter bar.
 *      Also creates barTriggers, every delegate in it will be called after
 *      bar = something is used.
 ******************************************************************************/
mixin template createTrigger (Type, string name
/**/ , Type function (Type) setterFunction) {
    //TO DO: Check name is a valid variable name.
    enum string typeStr = Type.stringof;
    enum string privateVarName = `m_` ~ name;
    import std.traits : isArray, PointerTarget;
    static if (isArray!Type && !(is (Type == string))) {
        mixin (generateArray!(typeStr, name));
    } else {
        mixin (generateVariable!(Type, name));
    }
    mixin (generateSetter!(typeStr, name, `setterFunction`));
    mixin (generateTriggerArray!(typeStr, name));
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

/******************************************************************************
 * Generates the variable and a getter.
 ******************************************************************************/
enum string generateVariable (string typeName, string name)() {
    import std.conv : to;
    /* private type m_varName; */
    string toRet = `private ` ~ typeName ~ ` m_` ~ name ~ `;`;
    /* @property auto ref varName () { return m_varName; } */
    toRet ~= `@property auto ref ` ~ name ~ `() {
            return m_` ~ name ~ `;
        }
    `;
    return toRet;
}

/******************************************************************************
 * Same as generateVariable but for array types.
 ******************************************************************************/
enum string generateArray (string typeName, string name)() {
    return `private VariableWithTrigger!(` ~ typeName ~ `)  m_` ~ name ~ `;
        @property auto ref ` ~ name ~ `() {
            return m_` ~ name ~ `;
        }`;
}
/******************************************************************************
 * Generates a setter that uses funName to set the value.
 ******************************************************************************/
enum string generateSetter (string typeName, string name, string funName) () {
    /* @property void varName (Type newVal) { m_varName = newVal; } */
    return `@property void ` ~ name ~ `(` ~ typeName ~ ` newVal) {
            m_` ~ name ~ ` = ` 
            // m_name = newVal if funName is null, it calls funName otherwise.
            ~ (funName is null ? `newVal` : funName ~ `(newVal)`) ~ `;
            foreach (trigger; ` ~ name ~`Triggers) {
                trigger (` ~ name ~ `);
            }
        }
    `;
}

enum string generateTriggerArray (string typeName, string name) () {
    /* void delegate (type) nameTriggerss; */
    return `void delegate (` ~ typeName ~ `) []` ~ name ~ `Triggers;`;
}

struct VariableWithTrigger (Type) {

    Type value;
    alias value this;

    import std.traits : isArray, isAssociativeArray;
    static if (isArray!Type) {
        import std.range : ElementType;
        alias BaseType = ElementType!Type;

        void delegate (BaseType) [] appendTriggers;

        /**********************************************************************
         * Overload of appending for normal arrays.
         * Calls all members of appendTriggers with the appended value.
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
    /**/ is (Type == ValueType [IndexType], ValueType, IndexType) 
    ) {
        import std.typecons : Tuple, tuple;
        void delegate (ValueType newVal, IndexType index, bool existedBefore) []
        /**/ indexAssignTriggers;
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

        auto ref remove (IndexType index) {
            foreach (ref trigger; removeTriggers) {
                trigger (value [index], index);
            }
            value.remove (index);
        }
    }
}
