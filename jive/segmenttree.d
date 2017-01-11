module jive.segmenttree;

private import std.algorithm;
private import std.functional;
private import std.range;

private import jive.internal;
private import jive.array;

/**
 * Array with fast access to accumulated values a[i] + a[i+1] + ... + a[j].
 * Implemented using a segment tree where both single element updates and
 * range queries take O(log(n)) time. The operation '+' can be any associative
 * binary function. Commutativity is not required.
 *
 * Limits of the current implementation which could be lifted if necessary:
 *  - There is no precaution taken for types T with expensive copy-constructor.
 *  - The operation needs to have a neutral element.
 *  - The structure is not resizable.
 *  - There is no range (tricky to get updates ).
 *
 * It is possible to also implement range-updates (both set-value and
 * increase-value) as well as range-queries, but that makes the structure
 * significantly more complicated and introduces quite an overhead even if
 * these functions are not actually used. Therefore such a generalized
 * structure should be implemented separately if the need arises.
 */
struct Segtree(T, alias fun, T neutral)
{
	private alias f = binaryFun!fun;

	private T* seg;	// length is 2*offset, with index 0 always unused. More unused if size is not a power of two
	private size_t size;
	private size_t offset;

	/** constructor that sets all elements to v */
	this(size_t size, T v = T.init)
	{
		this(repeat(v).take(size));
	}

	/**
	 * Constructor that gets initial content from arbitrary range.
	 * Takes O(n) time, which is faster than inserting items one by one.
	 */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:T) && hasLength!Stuff)
	{
		this.size = data.length;
		this.offset = roundToPowerOfTwo(size);
		auto seg = new T[2*offset];
		this.seg = seg.ptr;

		size_t i = offset;
		foreach(ref x; data)
			seg[i++] = x;

		for(i = offset-1; i > 0; --i)
			seg[i] = f(seg[2*i], seg[2*i+1]);
	}

	/** number of elements */
	size_t length() const pure nothrow @property @safe
	{
		return size;
	}

	/** Read single element. O(1). */
	T opIndex(string file = __FILE__, int line = __LINE__)(size_t i) const pure nothrow
	{
		if(boundsChecks && i >= size)
			throw new RangeError(file, line);
		return seg[offset + i];
	}

	/** Range query for the interval [i,j). O(log n) time. */
	T opSlice(string file = __FILE__, int line = __LINE__)(size_t a, size_t b) const pure nothrow
	{
		if(boundsChecks && (a > b || b >= size))
			throw new RangeError(file, line);

		// thanks to Oleksandr Bacherikov (http://codeforces.com/blog/entry/18051)
		// for this impressively compact
		T left = neutral;
		T right = neutral;
		for (a += offset, b += offset; a < b; a >>= 1, b >>= 1)
		{
			if (a&1)
				left = f(left, seg[a++]);
			if (b&1)
				right = f(seg[--b], right);
		}
		return f(left, right);
	}

	/** update a single element. O(log n) time. */
	void opIndexAssign(T value, size_t i) pure
	{
		for (seg[i += offset] = value; i >>= 1; )
			seg[i] = f(seg[i<<1], seg[i<<1 | 1]);
	}
}

alias SegtreeSum(T) = Segtree!(T, "a+b", T(0));
alias SegtreeProduct(T) = Segetree!(T, "a*b", T(1));
alias SegtreeMin(T) = Segtree!(T, min, T.max);
alias SegtreeMax(T) = Segtree!(T, max, T.min);

/**
 * Array-like structure with fast access to the smallest element.
 * Implemented using a segment tree.
 */
struct PriorityArray(V)
{
	private Array!int seg; // index 0 is unused, all unused are set to -1. length of seg is always a (even) power of 2
	private Array!V data;

	this(size_t size)
	{
		if(size < 2 || size > int.max)
			throw new Exception("segtree size not supported");

		data.resize(size);

		size_t sizeRounded = 1;
		while(sizeRounded < size)
			sizeRounded *= 2;
		seg.resize(sizeRounded, -1);
		for(int i = 0; i < length/2; ++i)
			seg[seg.length/2 + i] = i*2;
		for(int i = cast(int)seg.length/2-1; i >= 0; --i)
			seg[i] = seg[2*i];
	}

	size_t length() const @property
	{
		return data.length;
	}

	inout(V) opIndex(size_t i) inout
	{
		return data[i];
	}

	/** set element at i to value v ( O(log n) ) */
	void opIndexAssign(V v, size_t _i)
	{
		data[_i] = move(v); // this performs the bounds check, so that the conversion to int is fine
		int i = cast(int)_i;

		int k = cast(int)i/2 + cast(int)seg.length/2;

		if((i^1) < length && data[i^1] < data[i])
			seg[k] = i^1;
		else
			seg[k] = i;

		for(; k != 1; k /= 2)
			if(seg[k^1] != -1 && data[seg[k^1]] < data[seg[k]])
				seg[k/2] = seg[k^1];
			else
				seg[k/2] = seg[k];
	}

	/** returns index of smallest element ( O(1) ) */
	size_t minIndex() const @property
	{
		return seg[1];
	}

	/** returns smallest element ( O(1) ) */
	inout(V) min() inout @property
	{
		return data[seg[1]];
	}
}
