module jive.array;

private import core.stdc.string : memmove, memcpy;
private import std.range;
private import std.algorithm;

// TODO: figure out if and how to handle const/immutable element types
// TODO: implement toString ?
// TODO: add a couple of @safe, pure and nothrow attributes if applicable (NOTE: that might require such attributes on the postblit of V)
// TODO: avoid unnecessary clearing and copy-constructor of V.init. (NOTE: std.algorithm.move does only clear the source for expensive types)

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
		resize(size);
	}

	/** constructor for given length and init */
	this(size_t size, V val)
	{
		resize(size);
		this[] = val;
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
		buf = buf.ptr[0..count].dup;
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
	void reserve(size_t size, bool overEstimate = false)
	{
		if(size <= buf.length)
			return;

		size_t newSize;
		if(overEstimate)
		{
			newSize = max(buf.length, 1);
			while(newSize < size)
				newSize *= 2;
		}
		else
			newSize = size;

		auto newBuf = new V[newSize];
		moveAll(buf[], newBuf[0..buf.length]);
		delete buf;
		buf = newBuf;
	}


	//////////////////////////////////////////////////////////////////////
	/// indexing
	//////////////////////////////////////////////////////////////////////

	/** default range */
	inout(V)[] opSlice() inout nothrow
	{
		return buf.ptr[0..count]; // '.ptr' avoids bounds-check
	}

	/** indexing */
	ref inout(V) opIndex(size_t i) inout nothrow
	{
		return this[][i];
	}

	/** subrange */
	inout(V)[] opSlice(size_t a, size_t b) inout nothrow
	{
		return this[][a..b];
	}

	void opSliceAssign(V v)
	{
		this[][] = v;
	}

	void opSliceAssign(V v, size_t a, size_t b)
	{
		this[][a..b] = v;
	}

	/** first element */
	ref inout(V) front() inout @property
	{
		return this[][0];
	}

	/** last element */
	ref inout(V) back() inout @property
	{
		return this[][$-1];
	}


	//////////////////////////////////////////////////////////////////////
	/// find
	//////////////////////////////////////////////////////////////////////

	/** find element with given value. returns length if not found */
	size_t find(const V v) const
	{
		return find(v);
	}

	/** ditto */
	size_t find(const ref V v) const
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
	void pushBack(V val)
	{
		reserve(count + 1, true);
		buf.ptr[count] = move(val);
		++count;
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

	/** insert new element at given location. moves all elements behind */
	void insert(size_t i, V data)
	{
		assert(i <= length, "array out of bounds in Array.insert()");
		reserve(count + 1, true);
		memmove(&buf.ptr[i+1], &buf.ptr[i], V.sizeof*(length-i));
		initializeAll(buf.ptr[i..i+1]);
		buf.ptr[i] = move(data);
		++count;
	}

	/** returns removed element */
	V popBack()
	{
		auto r = move(back);
		back = V.init;
		--count;
		return r;
	}

	/** remove i'th element. moves all elements behind */
	V remove(size_t i)
	{
		assert(i < length, "array out of bounds in Array.remove()");
		auto r = move(this[i]);
		memmove(&buf.ptr[i], &buf.ptr[i+1], V.sizeof*(length-i-1));
		initializeAll(buf[count-1..count]);
		--count;
		return r;
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

	/** sets the size to some value. Either cuts of some values (but does not free memory), or fills new ones with V.init */
	void resize(size_t newsize)
	{
		if(newsize > capacity)
			reserve(newsize);
		else
			buf[newsize..count] = V.init;	// destruct truncated elements
		count = newsize;
	}

	/** ditto */
	void resize(size_t newsize, V v)
	{
		if(newsize > capacity)
		{
			reserve(newsize);
			buf[count..newsize] = v;	// TODO: avoid destruction of init-elements
		}
		else
			buf[newsize..count] = V.init;	// destruct truncated elements
		count = newsize;
	}

	/** convert to string */
	string toString() const @property
	{
		import std.conv;
		return to!string(this[]);
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

		initializeAll(buf[a..count]);
		this.resize(a);

		return r;
	}


	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	private V[] buf = null;		// .length = capacity
	private size_t count = 0;	// used size
}
