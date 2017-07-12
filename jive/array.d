module jive.array;

private import jive.internal;
private import core.stdc.string : memmove, memcpy;
private import core.exception : RangeError;
private import std.range;
private import std.algorithm;
private import std.conv : to;
private import std.format;
private import std.traits;
private import std.meta;



/**
 *  pretty much the thing, STL called vector. never shrinks. value semantic.
 *
 *  If headSize is non-zero, some elements are stored in the struct itself
 *  and not on the heap. This disables some features because "V[]"" cannot be
 *  used as range anymore. But it can improve memory efficiency and cache
 *  performance in extreme cases (i.e. large amounts of very small arrays).
 *
 *  The Size type is used for the internal length and capacity fields. Usually,
 *  size_t is the most sensible choice, but when you really want to minimize
 *  memory usage, you can switch it to uint.
 *
 *  The stored type should not be const/immutable. Use std.typecons.Rebindable.
 */
struct Array(V, Size = size_t, Size headSize = 0)
{
	// TODO: align elements better if V.sizeof is nice

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
	this(this)
	{
		if(count > headSize)
		{
			buf = buf[0..count-headSize].dup.ptr;
			cap = count;
		}
		else
		{
			buf = null;
			cap = headSize;
		}
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

		assert(newCap > headSize);
		V* newBuf = new V[newCap - headSize].ptr;
		if(length > headSize)
			moveAll(buf[0..length-headSize], newBuf[0..length-headSize]);
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
		static if(headSize != 0)
			assert(false);

		return buf;
	}

	/** default range */
	static if(headSize == 0)
	{
		inout(V)[] opSlice() inout pure nothrow
		{
			return buf[0..count];
		}
	}
	else
	{
		auto opSlice() const/*inout*/ pure nothrow
		{
			if(length > headSize)
				return chain(head[], buf[0..length-headSize]);
			else
				return chain(head[0..length], head[0..0]);
		}
	}

	/** subrange */
	inout(V)[] opSlice(string file = __FILE__, int line = __LINE__)(Size a, Size b) inout pure nothrow
	{
		static if(headSize != 0)
			assert(false);

		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);
		return buf[a..b];
	}

	void opSliceAssign(V v)
	{
		return opSliceAssign(move(v), 0, length);
	}

	void opSliceAssign(string file = __FILE__, int line = __LINE__)(V v, Size a, Size b)
	{
		if(boundsChecks && (a > b || b > length))
			throw new RangeError(file, line);

		if(b <= headSize)
			head[a..b] = v;
		else if(a >= headSize)
			buf[a-headSize .. b-headSize] = v;
		else
		{
			head[a..$] = v;
			buf[0..b-headSize] = v;
		}
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(Size i) inout pure nothrow
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);

		if(i < headSize)
			return head[i];
		else
			return buf[i - headSize];
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
	Size find(const V v) const
	{
		return find(v);
	}

	/** ditto */
	Size find(const ref V v) const
	{
		for(Size i = 0; i < length; ++i)
			if(v == this[i])
				return i;
		return length;
	}

	/** returns true if there is an element equal to v. */
	bool containsValue(const V v) const
	{
		return containsValue(v);
	}

	/** ditto */
	bool containsValue(const ref V v) const
	{
		return find(v) != length;
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
		++count;
		for(Size j = length-1; j > i; --j)
			this[j] = move(this[j-1]);
		this[i] = move(data);
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
		for(Size j = i; j < length-1; ++j)
			this[j] = move(this[j+1]);
		--count;
		return r;
	}

	/** remove (at most) one element with value v */
	bool removeValue(const /*ref*/ V v)
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
		auto old = length;
		count = newsize;
		if(old < length)
			this[old..length] = v;
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
		static if(headSize == 0)
		{
			auto r = this[];
			buf = null;
			count = 0;
			cap = headSize;
			return r;
		}
		else assert(false);
	}


	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	private V* buf = null;			// unused elements are undefined
	private Size cap = headSize;	// size of buf
	private Size count = 0;			// used size
	V[headSize] head;
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
	/+~this()
	{
		//delete data;
		// this is not correct, because when called by the GC, the buffer might already be gone
		// TODO: make it work
	}+/

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

/**
 * N-dimensional version of V[].
 */
static struct Slice(V, size_t N = 1, bool cyclic = false)
{
	alias Times!(N, size_t) Index; // multi-dimensional array-index
	alias Range!(0,N) Dimensions;  // 0..N-1, the dimensions

	V* ptr;
	size_t[N] size;
	size_t[N] pitch;

	/** constructor that takes given data or allocates */
	this(Index size, V[] data = null)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			this.pitch[i] = l;
			l *= size[i];
		}

		if(data is null)
			this.ptr = new V[l].ptr;
		else
		{
			if(data.length != l)
				throw new Exception("data size mismatch");
			this.ptr = data.ptr;
		}
	}

	/** constructor that takes an initializer */
	static if(is(V == Unqual!V)) this(Index size, V v)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			this.pitch[i] = l;
			l *= size[i];
		}

		auto data = new V[l];
		data[] = v;
		this.ptr = data.ptr;
	}

	/** total size (= product over all dimension sizes) */
	size_t length() const @property
	{
		size_t r = 1;
		foreach(l; size[])
			r *= l;
		return r;
	}

	/** size of one dimension */
	size_t opDollar(size_t d)() const @property
	{
		return size[d];
	}

	/** Convert multi-index into flat index. Also does bounds checks. */
	size_t rawIndex(string file = __FILE__, int line = __LINE__, bool checks = true)(Index index) const
	{
		size_t offset = 0;
		foreach(i; Dimensions)
		{
			static if(cyclic)
			{
				// NOTE: in this case we treat the index as signed
				index[i] = (cast(ptrdiff_t)index[i]%cast(ptrdiff_t)size[i]+size[i])%size[i];
			}

			if(checks && boundsChecks && index[i] >= size[i])
				throw new RangeError(file, line);

			offset += pitch[i] * index[i];
		}
		return offset;
	}

	/** convert "a..b" expression to a simple tuple taken by opIndex */
	size_t[2] opSlice(size_t d)(size_t a, size_t b) const
	{
		return [a, b];
	}

	/** access a single element */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(Index index) inout
	{
		return ptr[rawIndex!(file,line)(index)];
	}

	/** access a sub-slice of same or lower dimension */
	Slice!(V, staticCount!(size_t[2], I)) opIndex(string file = __FILE__, int line = __LINE__, I...)(I index)
		if(I.length == N)
	{
		Slice!(V, staticCount!(size_t[2], I)) r;

		Index start;
		size_t j = 0;
		foreach(i; Dimensions)
			static if(is(I[i] : size_t))
			{
				if(boundsChecks && index[i] >= size[i])
					throw new RangeError(file, line);

				start[i] = index[i];
			}
			else static if(is(I[i] : size_t[2]))
			{
				if(boundsChecks && index[i][1] > size[i])
					throw new RangeError(file, line);
				if(boundsChecks && index[i][0] > index[i][1])
					throw new RangeError(file, line);

				start[i] = index[i][0];
				r.size[j] = index[i][1]-index[i][0];
				r.pitch[j] = this.pitch[i];
				++j;
			}
			else static assert(false, "unknown type as array index: "~I[i].stringof);
		assert(j == staticCount!(size_t[2], I));
		r.ptr = this.ptr + rawIndex!(file, line, false)(start);
		return r;
	}

	/** pretty printing for N = 2 (i.e. matrices) */
	static if (N==2) string toString() const @property
	{
		string s;
		auto strings = Array2!string(size[0], size[1]);
		auto pitch = Array!size_t(size[1], 0);

		for(size_t i = 0; i < size[0]; ++i)
			for(size_t j = 0; j < size[1]; ++j)
			{
				static if(isFloatingPoint!V || is(V : Complex!R, R))
					strings[i,j] = format("%.3g", this[i,j]);
				else
					strings[i,j] = to!string(this[i,j]);
				pitch[j] = max(pitch[j], strings[i,j].length);
			}

		for(size_t i = 0; i < size[0]; ++i)
		{
			if(i == 0)
				s ~= "⎛";
			else if(i == size[0]-1)
				s ~= "⎝";
			else
				s ~= "⎜";


			for(size_t j = 0; j < size[1]; ++j)
			{
				for(int k = 0; k < pitch[j]+1-strings[i,j].length; ++k)
					s ~= " ";
				s ~= strings[i,j];
			}

			if(i == 0)
				s ~= " ⎞\n";
			else if(i == size[0]-1)
				s ~= " ⎠";
			else
				s ~= " ⎟\n";
		}
		return s;
	}

	/** switch two dimensions */
	Slice transpose(size_t a = 0, size_t b = 1)
	{
		Slice r = this;
		swap(r.size[a], r.size[b]);
		swap(r.pitch[a], r.pitch[b]);
		return r;
	}

	/** ditto */
	Slice!(const(V), N) transpose(size_t a = 0, size_t b = 1) const
	{
		Slice!(const(V), N) r = this;
		swap(r.size[a], r.size[b]);
		swap(r.pitch[a], r.pitch[b]);
		return r;
	}

	/** foreach with indices */
	static if(N != 1) int opApply(in int delegate(Index, ref V) dg) // TODO: inout
	{
		Index index;

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

			if(int r = dg(index, this[index]))
				return r;

			index[0] += 1;
		}
	}

	/** const cast */
	Slice!(const(Unqual!V), N) toConst() const @property
	{
		Slice!(const(Unqual!V), N) r;
		r.size[] = this.size[];
		r.pitch[] = this.pitch[];
		r.ptr = this.ptr;
		return r;
	}

	/** make the const cast implicit */
	static if(!is(const(Unqual!V) == V)) // const -> const and leads to compiler segfault (and is pointless anyway)
		alias toConst this;

	/** equivalent of std.exception.assumeUnique */
	Slice!(immutable(V), N) assumeUnique() const @property
	{
		static import std.exception;
		Slice!(immutable(V), N) r;
		r.size[] = this.size[];
		r.pitch[] = this.pitch[];
		r.ptr = std.exception.assumeUnique(this.ptr[0..1]).ptr;
		return r;
	}

	/** range primitves for N = 1 case */
	static if(N == 1)
	{
		Slice save() pure
		{
			return this;
		}

		bool empty() const pure
		{
			return size[0] == 0;
		}

		ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout pure
		{
			if(boundsChecks && empty)
				throw new RangeError(file, line);
			return ptr[0];
		}

		void popFront(string file = __FILE__, int line = __LINE__)() pure
		{
			if(boundsChecks && empty)
				throw new RangeError(file, line);
			ptr += pitch[0];
			--size[0];
		}
	}
}

alias Array2(V) = MultiArray!(V, 2);
alias Array3(V) = MultiArray!(V, 3);

alias Slice2(V) = Slice!(V, 2);
alias Slice3(V) = Slice!(V, 3);

alias CyclicSlice(V) = Slice!(V, 1, true);
alias CyclicSlice2(V) = Slice!(V, 2, true);
alias CyclicSlice3(V) = Slice!(V, 3, true);
