/**
License: public domain
Authors: Simon Bürger
*/

module jive.bitarray;

private import jive.internal;
private import core.bitop;
private import std.algorithm : max;

/**
 *  Efficient version of Array!bool using only one bit per entry.
 *  But note that the interface is not compatible with Array!bool. In
 *  particular no ranges are provided. This is a design choice because using
 *  a bit-range in general algorithms is often very inefficient. In contrast
 *  specialized algorithms working on BitArray are typically very fast.
 */
struct BitArray
{
	@nogc: nothrow: pure: @safe:

	alias limb = size_t;
	enum limbBits = limb.sizeof*8;

	private limb* _ptr;			// unused bits are always 0
	private size_t _capacity;	// allocated limbs (not bits)
	private size_t _length;

	/** constructor for given length */
	this(size_t size)
	{
		_length = size;
		_capacity = limbCount;
		_ptr = jiveMalloc!limb(limbCount);
		reset();
	}

	/** post-blit that does a full copy */
	this(this) @trusted
	{
		auto newPtr = jiveMalloc!limb(limbCount);
		newPtr[0 .. limbCount] = _ptr[0 .. limbCount];
		_capacity = limbCount;
		_ptr = newPtr;
	}

	/** destructor */
	~this()
	{
		jiveFree(_ptr);
		_ptr = null;
	}

	/** check for emptiness */
	bool empty() const @property
	{
		return _length == 0;
	}

	/** number of elements */
	size_t length() const @property
	{
		return _length;
	}

	/** number of elements this structure can hold without further allocations */
	size_t capacity() const @property
	{
		return _capacity * limbBits;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(size_t newCap, bool overEstimate = false) @trusted
	{
		// bit-count -> limb-count
		newCap = (newCap + limbBits - 1) / limbBits;

		if(newCap <= _capacity)
			return;

		if(overEstimate)
			newCap = max(newCap, 2*_capacity);

		auto newPtr = jiveMalloc!limb(newCap);
		newPtr[0..limbCount] = _ptr[0..limbCount];
		newPtr[limbCount..newCap] = 0;

		jiveFree(_ptr);
		_ptr = newPtr;
		_capacity = newCap;
	}

	inout(limb)* ptr() inout
	{
		return _ptr;
	}

	/** number of limbs in use */
	size_t limbCount() const @property
	{
		return (_length + limbBits - 1) / limbBits;
	}

	/** returns limbs in use */
	inout(limb)[] limbs() inout @property @trusted
	{
		return _ptr[0 .. limbCount];
	}

	/** either cuts of or fills new elements with false */
	void resize(size_t size)
	{
		reserve(size);

		// reset cut of elements. TODO: optimize
		for(size_t i = size; i < _length; ++i)
			this[i] = false;

		_length = size;
	}

	/** count number of elements equal to v */
	size_t count(bool v) const @trusted
	{
		// NOTE: relies on unused bits being zero
		size_t c;
		foreach(x; (cast(uint*)_ptr)[0..(_length+31)/32])
			c += popcnt(x); // why is there only a 32 bit version of popcnt in core.bitop?
		if(v)
			return c;
		else
			return _length-c;
	}

	/** set all elements to false */
	void reset()
	{
		limbs[] = 0;
	}

	/** indexing */
	bool opIndex(string file = __FILE__, int line = __LINE__)(size_t i) const @trusted
	{
		if(boundsChecks && (i >= length))
			assert(false, boundsCheckMsg!(file, line));
		return bt(ptr, i) != 0; // why does bt return an int (and not a bool)?
	}

	/** ditto */
	void opIndexAssign(string file = __FILE__, int line = __LINE__)(bool v, size_t i) @trusted
	{
		if(boundsChecks && (i >= length))
			assert(false, boundsCheckMsg!(file, line));
		if(v)
			bts(ptr, i);
		else
			btr(ptr, i);
	}

	/** toggle element i, returns old value. */
	bool toggle(string file = __FILE__, int line = __LINE__)(size_t i) @trusted
	{
		if(boundsChecks && (i >= length))
			assert(false, boundsCheckMsg!(file, line));
		return btc(ptr, i) != 0;
	}

	// TODO: efficient bitwise operations and some kind of iteration
}

@nogc nothrow pure @safe unittest
{
	auto a = BitArray(5);
	a[1] = true;
	a.toggle(2);
	a.resize(6);
	assert(a[5] == false);
	assert(a.count(true) == 2);
	assert(a.count(false) == 4);
}
