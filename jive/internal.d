module jive.internal;

/**
 * For internal use in the other modules of jive.
 */

private import std.functional : binaryFun;
private import std.typecons;
private import std.typetuple;

template Range(size_t start, size_t stop) {
    static if (start >= stop)
        alias Range = TypeTuple!();
    else
        alias Range = TypeTuple!(Range!(start, stop-1), stop-1);
}

template Times(size_t N, T)
{
	static if(N == 0)
		alias Times = TypeTuple!();
	else
		alias Times = TypeTuple!(T, Times!(N-1,T));
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
