/**
License: public domain
Authors: Simon Bürger
*/

module jive.array;

import jive.internal;
import core.stdc.string : memmove, memcpy;
import core.exception : RangeError;
import std.range;
import std.algorithm;
import std.conv : to;


/**
 *  Array of dynamic size.
 *
 *  If you add elements, new memory will be allocated automatically as needed.
 *  Typically there is more memory allocated than is currently in use. There is
 *  a tradeoff between wasted space and frequency of reallocations. The default
 *  behaviour is to double the capacity every time the allocated memory is
 *  filled up. This ensures that pushBack takes O(1) in amortized time. If you
 *  know the number of elements in advance, you can use reserve to avoid
 *  reallocations, but this is just an optimization and never necessary.
 */
struct Array(V)
{
	//////////////////////////////////////////////////////////////////////
	/// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor for given length */
	this(size_t size)
	{
		resize(size);
	}

	/** constructor for given length and init */
	this(size_t size, V val)
	{
		resize(size, val);
	}

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + data.length);

		foreach(ref x; data)
			pushBack(x);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		buf = buf[0..count].dup.ptr;
		cap = count;
	}

	/** destructor */
	~this()
	{
		//delete buf;
		// this is not correct, because when called by the GC, the buffer might already be gone
		// TODO: make it work
	}


	//////////////////////////////////////////////////////////////////////
	/// metrics
	//////////////////////////////////////////////////////////////////////

	/** check for emptiness */
	bool empty() const pure nothrow @property @safe
	{
		return count == 0;
	}

	/** number of elements */
	size_t length() const pure nothrow @property @safe
	{
		return count;
	}

	/** ditto */
	size_t opDollar() const pure nothrow @property @safe
	{
		return count;
	}

	/** number of elements this structure can hold without further allocations */
	size_t capacity() const pure nothrow @property @safe
	{
		return cap;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(size_t newCap, bool overEstimate = false)
	{
		if(newCap <= capacity)
			return;

		if(overEstimate)
			newCap = max(newCap, 2*capacity);

		auto newBuf = new V[newCap].ptr;
		moveAll(buf[0..length], newBuf[0..length]);
		delete buf;
		buf = newBuf;
		cap = newCap;
	}


	//////////////////////////////////////////////////////////////////////
	/// indexing
	//////////////////////////////////////////////////////////////////////

	/** pointer to the first element */
	inout(V)* ptr() inout pure nothrow @property @safe
	{
		return buf;
	}

	/** default range */
	inout(V)[] opSlice() inout nothrow pure @trusted
	{
		return buf[0..count];
	}

	/** subrange */
	inout(V)[] opSlice(string file = __FILE__, int line = __LINE__)(size_t a, size_t b) inout pure nothrow
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);
		return buf[a..b];
	}

	void opSliceAssign(V v)
	{
		return opSliceAssign(move(v), 0, length);
	}

	void opSliceAssign(string file = __FILE__, int line = __LINE__)(V v, size_t a, size_t b)
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);

		buf[a..b] = v;
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(size_t i) inout pure
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);
		return buf[i];
	}

	/** first element, same as this[0] */
	ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout pure nothrow
	{
		return this.opIndex!(file, line)(0);
	}

	/** last element, same as this[$-1] */
	ref inout(V) back(string file = __FILE__, int line = __LINE__)() inout pure nothrow
	{
		return this.opIndex!(file, line)(length-1);
	}


	//////////////////////////////////////////////////////////////////////
	/// add, remove
	//////////////////////////////////////////////////////////////////////

	/** add some new element to the back */
	void pushBack(V val)
	{
		reserve(count + 1, true);
		++count;
		this.back = move(val);
	}

	/** add multiple new elements to the back */
	void pushBack(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + data.length, true);

		foreach(ref x; data)
			pushBack(x);
	}

	/** convenience alias for pushBack */
	alias pushBack opCatAssign;

	/** returns removed element */
	V popBack() //nothrow
	{
		auto r = move(this.back);
		--count;
		return r;
	}

	/** insert new element at given location. moves all elements behind */
	void insert(string file = __FILE__, int line = __LINE__)(size_t i, V data)
	{
		if(boundsChecks && i > length)
			throw new RangeError(file, line);

		reserve(count + 1, true);
		++count;
		for(size_t j = length-1; j > i; --j)
			this[j] = move(this[j-1]);
		this[i] = move(data);
	}

	/** remove i'th element. moves all elements behind */
	V remove(string file = __FILE__, int line = __LINE__)(size_t i) //nothrow
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);

		auto r = move(this[i]);
		for(size_t j = i; j < length-1; ++j)
			this[j] = move(this[j+1]);
		--count;
		return r;
	}


	//////////////////////////////////////////////////////////////////////
	/// comparision
	//////////////////////////////////////////////////////////////////////

	hash_t toHash() const nothrow @trusted
	{
		hash_t h = length*17;
		foreach(ref x; this[])
			h = 19*h+23*typeid(V).getHash(&x);
		return h;
	}

	bool opEquals(const ref Array other) const
	{
		return this[] == other[];
	}

	int opCmp(const ref Array other) const
	{
		auto a = this[];
		auto b = other[];
		return typeid(typeof(a)).compare(&a, &b);
	}

	//////////////////////////////////////////////////////////////////////
	/// misc
	//////////////////////////////////////////////////////////////////////

	/** sets the size to some value. Either cuts of some values (but does not free memory), or fills new ones with V.init */
	void resize(size_t newsize, V v = V.init)
	{
		reserve(newsize);
		auto old = length;
		count = newsize;
		if(old < length)
			this[old..length] = v;
	}

	/** sets the size and fills everything with one value */
	void assign(size_t newsize, V v)
	{
		resize(newsize);
		this[] = v;
	}

	/** remove all content but keep allocated memory (same as resize(0)) */
	void clear() pure nothrow
	{
		count = 0;
	}

	/** convert to string */
	string toString() const
	{
		static if(__traits(compiles, to!string(this[])))
			return to!string(this[]);
		else
			return "[ jive.Array with "~to!string(length)~" elements of type "~V.stringof~" ]";
	}

	// TODO: move `prune` out of Array and generalize to other containers
	int prune(int delegate(ref V val, ref bool remove) dg)
	{
		size_t a = 0;
		size_t b = 0;
		int r = 0;

		while(b < length && r == 0)
		{
			bool remove = false;
			r = dg(this[b], remove);

			if(!remove)
			{
				if(a != b)
					this[a] = move(this[b]);
				++a;
			}

			++b;
		}

		if(a == b)
			return r;

		while(b < length)
			this[a++] = move(this[b++]);

		count = a;
		return r;
	}

	int prune(int delegate(size_t i, ref V val, ref bool remove) dg)
	{
		size_t a = 0;
		size_t b = 0;
		int r = 0;

		while(b < length && r == 0)
		{
			bool remove = false;
			r = dg(b, this[b], remove);

			if(!remove)
			{
				if(a != b)
					this[a] = move(this[b]);
				++a;
			}

			++b;
		}

		if(a == b)
			return r;

		while(b < length)
			this[a++] = move(this[b++]);

		count = a;
		return r;
	}


	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	private V* buf = null;		// unused elements are undefined
	private size_t cap = 0;		// size of buf
	private size_t count = 0;	// used size
}

unittest
{
	Array!int a;

	a.pushBack(1);
	a.pushBack([2,3,4,5]);
	assert(a.popBack() == 5);
	assert(equal(a[], [1,2,3,4]));

	a[] = 0;
	a[1..3] = 1;
	a.resize(6, 2);
	assert(equal(a[], [0,1,1,0,2,2]));
}
