module espukiide.memberinjector;

mixin template createTrigger (Type, string name) {
    enum typeStr = Type.stringof;
    enum string privateVarName = `m_` ~ name;
    mixin (generateVariable!(typeStr, name));
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
    mixin (generateVariable!(typeStr, name));
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
 * Generates a setter that uses funName to set the value.
 ******************************************************************************/
enum string generateSetter (string typeName, string name, string funName)() {
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
