module jive.array;

private import std.range : isInputRange, ElementType, hasLength;
private import std.algorithm : moveAll, move, swap;

// TODO: maybe implement toString and something similar to idup
// TODO: add a couple of @safe, pure and nothrow attributes if applicable (NOTE: that might require such attributes on the postblit of V)

/**
 *  pretty much the thing, STL called vector. never shrinks. value semantic.
 */
struct Array(V)
{
	//////////////////////////////////////////////////////////////////////
	/// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor for given length */
	this(size_t size)
	{
		buf = new V[size];
		count = size;
	}

	/** constructor for given length and init */
	this(size_t size, V val)
	{
		this(size);
		this[] = val;
	}

	this(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + data.length);

		foreach(x; data)
			pushBack(x);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		/*static import std.stdio;
		if(length != 0)
		std.stdio.writefln("called copy-constructor on Array!%s of length %s", V.stringof, length);*/
		buf = buf.ptr[0..count].dup;
	}


	//////////////////////////////////////////////////////////////////////
	/// metrics
	//////////////////////////////////////////////////////////////////////

	/** check for emptiness */
	bool empty() const nothrow @property @safe
	{
		return count == 0;
	}

	/** number of elements */
	size_t length() const nothrow @property @safe
	{
		return count;
	}

	/** ditto */
	size_t opDollar() const nothrow @property @safe
	{
		return count;
	}

	/** number of elements this structure can hold without further allocations */
	size_t capacity() const nothrow @property @safe
	{
		return buf.length;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(size_t size)
	{
		if(size <= buf.length)
			return;

		auto newBuf = new V[size];
		moveAll(buf[], newBuf[0..buf.length]);
		buf = newBuf;
	}


	//////////////////////////////////////////////////////////////////////
	/// indexing
	//////////////////////////////////////////////////////////////////////

	/** indexing */
	ref V opIndex(size_t index)
	{
		return buf.ptr[0..count][index];	// will use correct bounds-check
	}

	/** ditto */
	ref const(V) opIndex(size_t index) const
	{
		return buf.ptr[0..count][index];	// will use correct bounds-check
	}

	/** default range */
	V[] opSlice() nothrow
	{
		return buf.ptr[0..count];	// no bounds-check
	}

	/** ditto */
	const(V)[] opSlice() const nothrow
	{
		return buf.ptr[0..count];	// no bounds-check
	}

	/** range */
	V[] opSlice(size_t start, size_t end)
	{
		return buf.ptr[0..count][start..end];	// correct bounds-check
	}

	/** ditto */
	const(V)[] opSlice(size_t start, size_t end) const
	{
		return buf.ptr[0..count][start..end];	// correct bounds-check
	}

	void opSliceAssign(V value)
	{
		buf.ptr[0..count] = value;	// no bounds-check
	}

	void opSliceAssign(ref V value)
	{
		buf.ptr[0..count] = value;	// no bounds-check
	}

	void opSliceAssign(V value, size_t a, size_t b)
	{
		buf[a..b] = value;	// will use correct bounds-check
	}

	void opSliceAssign(ref V value, size_t a, size_t b)
	{
		buf[a..b] = value;	// will use correct bounds-check
	}

	void opAssign(V[] vals)
	{
		resize(vals.length);
		buf[0..count] = vals[];
	}

	/** first element */
	ref V front() @property
	{
		return buf.ptr[0..count][0];	// will use correct bounds-check
	}

	/** ditto */
	ref const(V) front() const @property
	{
		return buf.ptr[0..count][0];	// will use correct bounds-check
	}

	/** last element */
	ref V back() @property
	{
		return buf.ptr[0..count][$-1];	// will use correct bounds-check
	}

	/** ditto */
	ref const(V) back() const @property
	{
		return buf.ptr[0..count][$-1];	// will use correct bounds-check
	}

	//////////////////////////////////////////////////////////////////////
	/// find
	//////////////////////////////////////////////////////////////////////

	/** find element with given value. returns length if not found */
	size_t find(const /*ref*/ V v) const
	{
		foreach(i, const ref x; this)
			if(v == x)
				return i;
		return this.length;
	}

	//////////////////////////////////////////////////////////////////////
	/// add, remove
	//////////////////////////////////////////////////////////////////////

	/** add some new element to the back */
	void pushBack(T:V)(T val)
	{
		if(count == buf.length)
		{
			auto newBuf = new V[buf.length ? buf.length * 2 : startSize];
			moveAll(buf[], newBuf[0..buf.length]);
			buf = newBuf;
		}
		buf.ptr[count] = move(val);
		++count;
	}

	/** add multiple new elements to the back */
	void pushBack(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + data.length);

		foreach(x; data)
			pushBack(x);
	}

	/** convenience function for pushBack */
	ref Array opCatAssign(T:V)(T data)
	{
		pushBack(data);
		return this;
	}

	/** ditto */
	ref Array opCatAssign(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		pushBack(data);
		return this;
	}

	/** insert new element at given location. shifts all elements behind */
	void insert(size_t pos, V data)
	{
		pushBack(V.init);
		for(size_t i = length-1; i != pos; --i)
			buf[i] = move(buf[i-1]);
		buf[pos] = move(data);
	}

	/** returns removed element */
	V popBack()
	{
		return move(buf[--count]);
	}

	/** remove i'th element (O(n) runtime) */
	void remove(size_t i)
	{
		for(size_t j = i; j < count-1; ++j)
			buf[j] = move(buf[j+1]);
		--count;
	}

	/** remove (at most) one element with value v */
	bool removeValue(const /*ref*/ V v)
	{
		size_t i = find(v);
		if(i == length)
			return false;
		remove(i);
		return true;
	}

	int prune(int delegate(ref V val, ref bool remove) dg)
	{
		size_t a=0;
		size_t b;
		int r;
		for(b = 0; b < length; ++b)
		{
			bool remove = false;
			if(0 != (r = dg(this[b], remove)))
				break;

			if(!remove)
			{
				if(b != a)
					this[a] = move(this[b]);
				++a;
			}
		}

		for(; b < length; ++b)
		{
			if(b != a)
				this[a] = move(this[b]);
			++a;
		}

		this.resize(a);

		return r;
	}

	//////////////////////////////////////////////////////////////////////
	/// comparision
	//////////////////////////////////////////////////////////////////////

	hash_t toHash() const nothrow @trusted @property
	{
		hash_t h = length*17;
		foreach(ref x; buf.ptr[0..count])
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

	/** sets the size to some value. Either cuts of some values (but does not free memory), or fills new ones with v */
	void resize(size_t newsize, V v = V.init)
	{
		if(newsize > capacity)
		{
			reserve(newsize);
			buf[count..newsize] = v;
		}
		else
			buf[newsize..count] = V.init;	// destruct truncated elements
		count = newsize;
	}

	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	private V[] buf = null;		// .length = capacity
	private size_t count = 0;	// used size
	private enum startSize = 4;	// tuneable. No investigation done.
}
