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

/**
 * N-dimensional version of V[].
 * TODO: possibly remove this in favor of libmir
 */
struct Slice(V, size_t N = 1, bool cyclic = false)
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
	size_t length() const
	{
		size_t r = 1;
		foreach(l; size[])
			r *= l;
		return r;
	}

	/** size of one dimension */
	size_t opDollar(size_t d)() const
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
		auto strings = Slice2!string(size[0], size[1]);
		auto pitch = Array!size_t(size[1], 0);

		for(size_t i = 0; i < size[0]; ++i)
			for(size_t j = 0; j < size[1]; ++j)
			{
				import std.complex;
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

alias Slice2(V) = Slice!(V, 2);
alias Slice3(V) = Slice!(V, 3);

alias CyclicSlice(V) = Slice!(V, 1, true);
alias CyclicSlice2(V) = Slice!(V, 2, true);
alias CyclicSlice3(V) = Slice!(V, 3, true);
