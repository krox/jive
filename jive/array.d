module jive.array;

private import jive.internal;
private import core.stdc.string : memmove, memcpy;
private import core.exception : RangeError;
private import std.range;
private import std.algorithm;
private import std.conv : to;
private import std.traits;


/**
 *  pretty much the thing, STL called vector. never shrinks. value semantic.
 *
 *  The Size type is used for the internal length and capacity fields. Usually,
 *  size_t is the most sensible choice, but when you really want to minimize
 *  memory usage, you can switch it to uint.
 *
 *  The stored type should not be const/immutable. Use std.typecons.Rebindable.
 */
struct Array(V, Size = size_t)
{
	//////////////////////////////////////////////////////////////////////
	/// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor for given length */
	this(Size size)
	{
		resize(size);
	}

	/** constructor for given length and init */
	this(Size size, V val)
	{
		resize(size, val);
	}

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + cast(Size)data.length);

		foreach(ref x; data)
			pushBack(x);
	}

	/** post-blit that does a full copy */
	this(this) pure
	{
		buf = buf[0..count].dup.ptr;
		cap = count;
	}

	/** destructor */
	~this() pure
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
	Size length() const pure nothrow @property @safe
	{
		return count;
	}

	/** ditto */
	Size opDollar() const pure nothrow @property @safe
	{
		return count;
	}

	/** number of elements this structure can hold without further allocations */
	Size capacity() const pure nothrow @property @safe
	{
		return cap;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(Size newCap, bool overEstimate = false)
	{
		if(newCap <= capacity)
			return;

		if(overEstimate)
			newCap = max(newCap, 2*capacity);

		V* newBuf = new V[newCap].ptr;
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
	inout(V)[] opSlice() inout pure nothrow
	{
		return buf[0..count];
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(Size i) inout pure nothrow
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);
		return buf[i];
	}

	/** subrange */
	inout(V)[] opSlice(string file = __FILE__, int line = __LINE__)(Size a, Size b) inout pure nothrow
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);
		return buf[a..b];
	}

	void opSliceAssign(V v) pure
	{
		this[][] = v;
	}

	void opSliceAssign(string file = __FILE__, int line = __LINE__)(V v, Size a, Size b) pure nothrow
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);
		buf[a..b] = v;
	}

	/** first element */
	ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout pure nothrow @property
	{
		return this.opIndex!(file, line)(0);
	}

	/** last element */
	ref inout(V) back(string file = __FILE__, int line = __LINE__)() inout pure nothrow @property
	{
		return this.opIndex!(file, line)(length-1);
	}


	//////////////////////////////////////////////////////////////////////
	/// find
	//////////////////////////////////////////////////////////////////////

	/** find element with given value. returns length if not found */
	Size find(const V v) const pure nothrow
	{
		return find(v);
	}

	/** ditto */
	Size find(const ref V v) const pure nothrow
	{
		foreach(Size i, const ref x; this)
			if(v == x)
				return i;
		return length;
	}

	/** returns true if there is an element equal to v. */
	bool containsValue(const V v) const pure nothrow
	{
		return containsValue(v);
	}

	/** ditto */
	bool containsValue(const ref V v) const pure nothrow
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
		++count;
		back = move(val);
	}

	/** add multiple new elements to the back */
	void pushBack(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + cast(Size)data.length, true);

		foreach(ref x; data)
			pushBack(x);
	}

	/** convenience alias for pushBack */
	alias pushBack opCatAssign;

	/** insert new element at given location. moves all elements behind */
	void insert(string file = __FILE__, int line = __LINE__)(Size i, V data)
	{
		if(boundsChecks && i > length)
			throw new RangeError(file, line);

		reserve(count + 1, true);
		memmove(&buf[i+1], &buf[i], V.sizeof*(length-i));
		initializeAll(buf[i..i+1]);
		buf[i] = move(data);
		++count;
	}

	/** returns removed element */
	V popBack() nothrow
	{
		auto r = move(back);
		--count;
		return r;
	}

	/** remove i'th element. moves all elements behind */
	V removeIndex(string file = __FILE__, int line = __LINE__)(Size i) nothrow
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);

		auto r = move(this[i]);
		memmove(&buf[i], &buf[i+1], V.sizeof*(length-i-1));
		initializeAll(buf[count-1..count]);
		--count;
		return r;
	}

	/** remove (at most) one element with value v */
	bool removeValue(const /*ref*/ V v) nothrow
	{
		Size i = find(v);
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
	void resize(Size newsize, V v = V.init)
	{
		reserve(newsize);
		if(newsize > count)
			buf[count..newsize] = v;
		count = newsize;
	}

	/** sets the size and fills everything with one value */
	void assign(Size newsize, V v)
	{
		resize(newsize);
		this[] = v;
	}

	/** remove all contents but keep allocated memory (same as resize(0)) */
	void clear() pure nothrow
	{
		count = 0;
	}

	/** convert to string */
	string toString() const pure @property
	{
		static if(__traits(compiles, to!string(this[])))
			return to!string(this[]);
		else
			return "[ jive.Array with "~to!string(length)~" elements of type "~V.stringof~" ]";
	}

	int prune(int delegate(ref V val, ref bool remove) dg)
	{
		Size a = 0;
		Size b = 0;
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

	int prune(int delegate(Size i, ref V val, ref bool remove) dg)
	{
		Size a = 0;
		Size b = 0;
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

	/** remove the internal buffer from the array and return it as a V[] */
	V[] release() pure nothrow
	{
		auto r = this[];
		buf = null;
		count = 0;
		cap = 0;
		return r;
	}


	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	private V* buf = null;	// unused elements are undefined
	private Size cap = 0;	// size of buf
	private Size count = 0;	// used size
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
