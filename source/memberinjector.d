module espukiide.memberinjector;

/******************************************************************************
 * To be used in a mixin.
 * Generates a private variable, a public getter, a setter 
 * and an array of callbacks to be called when the setter is called.
 * Params:
 *      Type = The type of the variable.
 *      name = The name of the variable, the private one will be called 'm_'name
 *      setterFunction = A custom setter function. The default just returns the
 *      same value. The returned value of this is assigned to the variable.
 * Example:
 *      mixin (genVar!(int, "bar"));
 *      Creates an int variable called m_bar, accesible with setter/getter bar.
 *      Also creates barCallbacks, every delegate in it will be called after
 *      bar = something is used.
 ******************************************************************************/
mixin template genVar (Type, string name
/**/ , Type function (Type) setterFunction = (Type newVal){return newVal;}) {
    //TO DO: Check name is a valid variable name.
    enum string typeStr = Type.stringof;
    enum string privateVarName = `m_` ~ name;
    mixin (generateVariable!(typeStr, name));
    mixin (generateSetter!(typeStr, name, `setterFunction`));
    mixin (generateCallbackArray!(typeStr, name));
}

private:

unittest {
    int value = 0;
    struct Example {
        mixin genVar !(int, `foo`, (n=>n*2));
        this (bool) {
            // Callback from the same struct.
            fooCallbacks ~= &internalCallback;
        }
        void internalCallback (int num) {value += num;}
    }
    Example ex = Example (true);
    void externalCallback (int num) {value += num * 2;}
    assert (ex.foo == 0 && value == 0);
    ex.foo = 1;
    import std.conv : text;
    // Modified setter sets to the number * 2;
    assert (ex.foo == 2 && value == 2, text (ex.foo, ` `, value));
    ex.fooCallbacks ~= &externalCallback;
    ex.foo = 1;
    // Both callbacks are called, one sums 2 and the other 4.
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
 * Generates a setter that uses funName to set the value.
 ******************************************************************************/
enum string generateSetter (string typeName, string name, string funName)() {
    /* @property void varName (Type newVal) { m_varName = newVal; } */
    return `@property void ` ~ name ~ `(` ~ typeName ~ ` newVal) {
            m_` ~ name ~ ` = ` ~ funName ~ ` (newVal);
            foreach (callback; ` ~ name ~`Callbacks) {
                callback (` ~ name ~ `);
            }
        }
    `;
}
enum string generateCallbackArray (string typeName, string name) () {
    /* void delegate (type) nameCallbacks; */
    return `void delegate (` ~ typeName ~ `) []` ~ name ~ `Callbacks;`;
}
