module jive.bitarray;

private import core.bitop;

/**
 *  similar to Array!bool, but more memory-efficient
 */
struct BitArray
{
	alias limb = size_t;
	enum limbBits = limb.sizeof*8;

	private union
	{
		limb* buf = null;
		limb small;
	}
	private size_t size = 0;	// number of bits in use

	inout(limb)* ptr() inout pure nothrow @property
	{
		if(size <= limbBits)
			return &small;
		else
			return buf;
	}

	/** constructor for given length */
	this(size_t size) pure
	{
		this.size = size;

		if(size > limbBits)
			buf = new ulong[(size+limbBits-1)/limbBits].ptr;
	}

	/** post-blit that does a full copy */
	this(this)
	{
		if(size > limbBits)
			buf = buf[0..(size+limbBits-1)/limbBits].dup.ptr;
	}

	/** number of elements */
	size_t length() const pure nothrow @property @safe
	{
		return size;
	}

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
}
