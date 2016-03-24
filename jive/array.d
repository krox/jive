module jive.array;

private import jive.internal;
private import core.stdc.string : memmove, memcpy;
private import core.exception : RangeError;
private import std.range;
private import std.algorithm;
private import std.conv : to;
private import std.traits;

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

	/** pointer to the first element */
	inout(V)* ptr() inout @property
	{
		return buf.ptr;
	}

	/** default range */
	inout(V)[] opSlice() inout nothrow
	{
		return buf.ptr[0..count]; // '.ptr' avoids bounds-check
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(size_t i) inout nothrow
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);
		return buf.ptr[i];
	}

	/** subrange */
	inout(V)[] opSlice(string file = __FILE__, int line = __LINE__)(size_t a, size_t b) inout nothrow
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);
		return buf.ptr[a..b];
	}

	void opSliceAssign(V v)
	{
		this[][] = v;
	}

	void opSliceAssign(string file = __FILE__, int line = __LINE__)(V v, size_t a, size_t b)
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);
		buf.ptr[a..b] = v;
	}

	/** first element */
	ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout @property
	{
		if(boundsChecks && empty)
			throw new RangeError(file, line);
		return buf.ptr[0];
	}

	/** last element */
	ref inout(V) back(string file = __FILE__, int line = __LINE__)() inout @property
	{
		if(boundsChecks && empty)
			throw new RangeError(file, line);
		return buf.ptr[length-1];
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

	/** returns true if there is an element equal to v. */
	bool containsValue(const V v) const
	{
		return containsValue(v);
	}

	/** ditto */
	bool containsValue(const ref V v) const
	{
		foreach(i, const ref x; this)
			if(v == x)
				return true;
		return false;
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
	void insert(string file = __FILE__, int line = __LINE__)(size_t i, V data)
	{
		if(boundsChecks && i > length)
			throw new RangeError(file, line);

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
	V removeIndex(string file = __FILE__, int line = __LINE__)(size_t i)
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);

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
		removeIndex(i);
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
		else if(newsize < count)
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
		else if(newsize < count)
			buf[newsize..count] = V.init;	// destruct truncated elements
		count = newsize;
	}

	/** sets the size and fills everything with one value */
	void assign(size_t newsize, V v)
	{
		resize(newsize);
		this[] = v;
	}

	/** convert to string */
	string toString() const @property
	{
		static if(__traits(compiles, to!string(this[])))
			return to!string(this[]);
		else
			return "[ jive.Array with "~to!string(length)~" elements of type "~V.stringof~" ]";
	}

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

		initializeAll(buf[a..count]);
		this.resize(a);

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

		initializeAll(buf[a..count]);
		this.resize(a);

		return r;
	}

	/** cast this to a slice by removing the internal buffer from the array and returning it as a V[] */
	T opCast(T)()
		if(is(T == V[]))
	{
		auto r = this[];
		buf = null;
		count = 0;
		return r;
	}


	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	private V[] buf = null;		// .length = capacity
	private size_t count = 0;	// used size
}

/**
 *  N-dimensional version of Array!V.
 */
struct MultiArray(V, size_t N)
{
	//////////////////////////////////////////////////////////////////////
	/// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor which allocates memory */
	this(Index size)
	{
		assign(size, V.init);
	}

	/** ditto */
	this(Index size, V val)
	{
		assign(size, val);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		data = data.dup;
	}

	/** destructor */
	~this()
	{
		//delete data;
		// this is not correct, because when called by the GC, the buffer might already be gone
		// TODO: make it work
	}

	//////////////////////////////////////////////////////////////////////
	/// metrics
	//////////////////////////////////////////////////////////////////////

	/** check for emptiness */
	bool empty() const nothrow @property @safe
	{
		return length == 0;
	}

	/** number of elements */
	size_t length() const nothrow @property @safe
	{
		return data.length;
	}

	/** ditto */
	size_t opDollar(size_t i)() const nothrow @property @safe
	{
		return size[i];
	}


	//////////////////////////////////////////////////////////////////////
	/// indexing
	//////////////////////////////////////////////////////////////////////

	/** pointer to the first element */
	inout(V)* ptr() inout @property
	{
		return data.ptr;
	}

	/** default range */
	auto opSlice() /*inout*/ // TODO: figure out why inout does not work here
	{
		return Slice!(V, N)(size, data);
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(Index index) inout
	{
		size_t offset = 0;
		size_t pitch = 1;
		foreach(i; Dimensions)
		{
			if(boundsChecks && index[i] >= size[i])
				throw new RangeError(file, line);

			offset += pitch * index[i];
			pitch *= size[i];
		}
		return data.ptr[offset];
	}

	void opSliceAssign(V v)
	{
		this.data[] = v;
	}


	//////////////////////////////////////////////////////////////////////
	/// comparision
	//////////////////////////////////////////////////////////////////////

	hash_t toHash() const nothrow @trusted @property
	{
		auto a = this.data[];
		return typeid(typeof(a)).getHash(&a);
	}

	bool opEquals(const ref MultiArray other) const
	{
		return this.data[] == other.data[];
	}

	int opCmp(const ref MultiArray other) const
	{
		auto a = this.data[];
		auto b = other.data[];
		return typeid(typeof(a)).compare(&a, &b);
	}

	//////////////////////////////////////////////////////////////////////
	/// misc
	//////////////////////////////////////////////////////////////////////

	/** sets the size and fills everything with one value */
	void assign(Index size, V val)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			l *= size[i];
		}

		data = new V[l];
		data[] = val;
	}

	/** convert to string */
	string toString() const @property
	{
		return "[ jive.MultiArray with "~to!string(length)~" elements of type "~V.stringof~" ]";
	}

	/** cast this to a slice by removing the internal buffer from the array and returning it as a V[] */
	T opCast(T)()
		if(is(T == Slice!(V, 2)))
	{
		auto r = this[];
		data = null;
		size[] = 0;
		return r;
	}


	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	alias Times!(N, size_t) Index; // multi-dimensional array-index
	alias Range!(0,N) Dimensions;  // 0..N-1, the dimensions

	private V[] data;
	private Index size;

	version(D_NoBoundsChecks)
		enum boundsChecks = false;
	else
		enum boundsChecks = true;
}

static struct Slice(V, size_t N)
{
	alias Times!(N, size_t) Index; // multi-dimensional array-index
	alias Range!(0,N) Dimensions;  // 0..N-1, the dimensions

	V[] data;
	Index size;

	/** constructor that allocates data */
	this(Index size)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			l *= size[i];
		}

		this.data = new V[l];
	}

	/** ditto */
	this(Index size, V val)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			l *= size[i];
		}

		auto d = new Unqual!V[l];
		d[] = val;
		this.data = cast(V[])d;
	}

	/** constructor that takes given data */
	this(Index size, V[] data)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			l *= size[i];
		}

		if(data.length != l)
			throw new Exception("data size mismatch");

		this.data = data;
	}

	/** pointer to the first element */
	inout(V)* ptr() inout @property
	{
		return data.ptr;
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(Index index) inout
	{
		size_t offset = 0;
		size_t pitch = 1;
		foreach(i; Dimensions)
		{
			if(boundsChecks && index[i] >= size[i])
				throw new RangeError(file, line);

			offset += pitch * index[i];
			pitch *= size[i];
		}
		return data.ptr[offset];
	}

	/** foreach with indices */
	int opApply(in int delegate(Index, ref V) dg)
	{
		Index index;
		size_t pos = 0;

		while(true)
		{
			foreach(i; Dimensions)
			{
				if(index[i] == size[i])
				{
					static if(i == N-1)
						return 0;
					else
					{
						index[i] = 0;
						index[i+1] += 1;
					}
				}
				else
					break;
			}

			if(int r = dg(index, data[pos]))
				return r;

			index[0] += 1;
			pos += 1;
		}
	}

	/** foreach without indices */
	int opApply(in int delegate(ref V) dg)
	{
		foreach(ref x; data)
			if(int r = dg(x))
				return r;
		return 0;
	}

	/** "cast" to to const elements. Sadly, we have to do this explicitly. Even though T[] -> const(T)[] is implicit. */
	auto toConst() const @property
	{
		return Slice!(const(V),N)(size, data);
	}

	/** equivalent of std.exception.assumeUnique */
	auto assumeUnique() const @property
	{
		static import std.exception;
		return Slice!(immutable(V),N)(size, std.exception.assumeUnique(data));
	}
}

alias Array2(V) = MultiArray!(V, 2);
alias Array3(V) = MultiArray!(V, 3);

alias Slice2(V) = Slice!(V, 2);
alias Slice3(V) = Slice!(V, 3);
