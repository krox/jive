module jive.bitarray;

private import core.bitop;

/**
 *  similar to Array!bool, but more memory-efficient. Can also be used similar to Set!size_t.
 */
struct BitArray
{
	//////////////////////////////////////////////////////////////////////
	/// internals
	//////////////////////////////////////////////////////////////////////

	alias limb = size_t;
	enum limbBits = limb.sizeof*8;

	private limb[] buf = null;	// unused bits are always 0
	private size_t size = 0;	// number of bits actually in use

	inout(limb)* ptr() inout pure nothrow @property @safe
	{
		return buf.ptr;
	}

	/** number of elements */
	size_t length() const pure nothrow @property @safe
	{
		return size;
	}

	/** number of limbs in use */
	size_t limbCount() const pure nothrow @property @safe
	{
		return (length + limbBits - 1) / limbBits;
	}

	/** returns limbs in use */
	inout(limb)[] limbs() inout pure nothrow @property
	{
		return ptr[0..limbCount];
	}

	//////////////////////////////////////////////////////////////////////
	/// constructors and whole-array operations
	//////////////////////////////////////////////////////////////////////

	/** constructor for given length */
	this(size_t size) pure
	{
		this.size = size;
		buf = new limb[limbCount];
	}

	/** post-blit that does a full copy */
	this(this)
	{
		buf = limbs.dup;
	}

	void reserve(size_t cap)
	{
		if(cap <= limbBits * buf.length)
			return;

		buf.length = (cap + limbBits - 1) / limbBits;
	}

	/** either cuts of or fills new elements with false */
	void resize(size_t newSize)
	{
		reserve(newSize);

		for(size_t i = newSize; i < size; ++i)
			this[i] = false;
		size = newSize;
	}

	/** count number of elements equal to v */
	size_t count(bool v) const pure nothrow
	{
		// NOTE: relies on unused bits being zero
		size_t c;
		foreach(x; (cast(uint*)ptr)[0..(size+31)/32])
			c += popcnt(x); // why is there only a 32 bit version of popcnt in core.bitop?
		if(v)
			return c;
		else
			return size-c;
	}

	/** set all elements to false */
	void reset() pure nothrow
	{
		limbs[] = 0;
	}

	//////////////////////////////////////////////////////////////////////
	/// indexing and iteration
	//////////////////////////////////////////////////////////////////////

	/** indexing */
	bool opIndex(size_t i) const pure nothrow
	{
		assert(i < size, "BitArray index out of bounds");
		return bt(ptr, i) != 0; // why does bt return an int (and not a bool)?
	}

	/** ditto */
	void opIndexAssign(bool v, size_t i) pure nothrow
	{
		assert(i < size, "BitArray index out of bounds");
		if(v)
			bts(ptr, i);
		else
			btr(ptr, i);
	}

	/** set element i to true. returns false if it already was. */
	bool add(size_t i)
	{
		if(this[i])
			return false;
		this[i] = true;
		return true;
	}

	/** set element i to false. returns false if it already was. */
	bool remove(size_t i)
	{
		if(!this[i])
			return false;
		this[i] = false;
		return true;
	}

	/** iterate over all indices set to true */
	int opApply(int delegate(size_t k) dg) const
	{
		auto c = limbCount;
		auto p = ptr;
		for(size_t i = 0; i < c; ++i)
			if(p[i] != 0)
				for(size_t j = 0; j < limbBits; ++j)
					if((p[i]&(1UL<<j)) != 0)
						if(int r = dg(i*limbBits+j))
							return r;
		return 0;
	}
}
