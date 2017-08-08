module jive.segmenttree;

private import std.algorithm;
private import std.functional;
private import std.range;

private import jive.internal;
private import jive.array;

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
