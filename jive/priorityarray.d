/**
License: public domain
Authors: Simon Bürger
*/

module jive.priorityarray;

private import std.algorithm;
private import std.range;
private import jive.array;

/**
 * Array-like structure with fast access to the smallest element.
 *
 * Implemented using a segment tree.
 * TODO: more array-like operations (e.g. pushBack, popBack, maybe iteration)
 */
struct PriorityArray(V)
{
	// NOTE: seg[0] is unused, all unused are set to -1. length of seg is always an even power of 2
	private Array!int seg;

	private Array!V data;

	/** constructor for given size */
	this(size_t size)
	{
		data.resize(size);

		size_t sizeRounded = 2;
		while(sizeRounded < size)
			sizeRounded *= 2;
		seg.resize(sizeRounded, -1);
		for(int i = 0; i < length/2; ++i)
			seg[seg.length/2 + i] = i*2;
		for(int i = cast(int)seg.length/2-1; i >= 0; --i)
			seg[i] = seg[2*i];
	}

	/** constructor taking a range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V) && hasLength!Stuff)
	{
		this(data.length);
		size_t i = 0;
		foreach(x; data)
			this[i++] = x;
	}

	/** number of elements in the array */
	size_t length() const @property
	{
		return data.length;
	}

	/** ditto */
	size_t opDollar() const @property
	{
		return data.length;
	}

	/** read-only access to the i'th element */
	inout(V) opIndex(size_t i) inout
	{
		return data[i];
	}

	/** read-only access to all elements */
	const(V)[] opSlice() const
	{
		return data[];
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
	size_t minIndex() const
	{
		return seg[1];
	}

	/** returns smallest element ( O(1) ) */
	ref const(V) min() const
	{
		return data[seg[1]];
	}
}

///
/+@nogc+/ nothrow pure @safe unittest
{
	auto a = PriorityArray!int([7,9,2,3,4,1,6,5,8,0]);
	assert(a[] == [7,9,2,3,4,1,6,5,8,0]);

	assert(a.minIndex == 9);
	assert(a.min == 0);

	a[9] = 100;

	assert(a.minIndex == 5);
	assert(a.min == 1);

	a[2] = -3;

	assert(a.minIndex == 2);
	assert(a.min == -3);
}
