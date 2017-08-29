module jive.internal;

/**
 * For internal use in the other modules of jive.
 */

import core.exception : onOutOfMemoryError;
import core.memory : GC;
import std.functional : binaryFun;
//import std.typecons;
//import std.typetuple;
import std.traits : hasIndirections;

private extern(C)
{
	// TODO: switch to core.memory.pureMalloc/pureFree when https://github.com/dlang/druntime/pull/1836 is resolved
	void* malloc(size_t) @system pure @nogc nothrow;
	void free(void*) @system pure @nogc nothrow;
}

/**
 * Wrappers around malloc/free that
 *  - cast to appropriate type
 *  - call GC.addRange/removeRange when neccessary
 */
T* jiveMalloc(T)(size_t n) @trusted /*pure*/ @nogc nothrow
{
	if(n == 0)
		return null;
	auto ptr = cast(T*)malloc(T.sizeof * n);
	if(ptr is null)
		onOutOfMemoryError();
	static if(hasIndirections!T)
		GC.addRange(ptr, T.sizeof * n);
	return ptr;
}

void jiveFree(T)(T* ptr) @trusted /*pure*/ @nogc nothrow
{
	if(ptr is null)
		return;
	static if(hasIndirections!T)
		GC.removeRange(ptr);
	free(ptr);
}

/**
 *  Workaround to make somewhat nice out-of-bounds errors in @nogc code.
 *  TODO: remove when DIP1008 is implemented which should make a simple
 *        'throw new RangeError(file, line)' work even in @nogc code.
 */
template boundsCheckMsg(string file, int line)
{
	import std.format : format;
	static immutable string boundsCheckMsg = format("Array out-of-bounds at %s(%s)", file, line);
}

version(D_NoBoundsChecks)
	enum boundsChecks = false;
else
	enum boundsChecks = true;

template PredicateHelper(alias p, V)
{
	static if(__traits(compiles, binaryFun!p(V.init, V.init)))
	{
		enum dynamicPred = false;
		alias pred = binaryFun!p;
	}
	else static if(__traits(compiles, p.init(V.init, V.init)))
	{
		enum dynamicPred = true;
		p pred;
	}
	else
	{
		enum dynamicPred = false; // for better error messasge

		static assert(false, "invalid predicate: "~p.stringof);
	}
}

size_t roundToPowerOfTwo(size_t x) pure
{
	size_t y = 1;
	while(y < x)
		y *= 2;
	return y;
}
