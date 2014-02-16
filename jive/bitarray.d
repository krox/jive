module jive.bitarray;

private import core.bitop : popcnt;

/**
 *  similar to Array!bool, but more memory-efficient
 */
struct BitArray
{
	private ulong* buf = null;
	private size_t size = 0;	// number of bits in use

	/** constructor for given length */
	this(size_t size)
	{
		buf = new ulong[(size+63)/64].ptr;
		this.size = size;
	}

	/** post-blit that does a full copy */
	this(this)
	{
		buf = buf[0..(size+63)/64].dup.ptr;
	}

	/** number of elements */
	size_t length() const nothrow @property @safe
	{
		return size;
	}

	/** indexing */
	bool opIndex(size_t i) const
	{
		assert(i < size, "BitArray index out of bounds");
		return (buf[i/64] >> (i%64)) & 1;
	}

	/** ditto */
	bool opIndexAssign(bool v, size_t i)
	{
		assert(i < size, "BitArray index out of bounds");
		ulong bit = 1UL << (i%64);
		buf[i/64] = (buf[i/64]&~bit) | (v?bit:0);
		return v;
	}

	size_t count(bool v)
	{
		// NOTE: relies on unused bits being zero
		size_t c;
		foreach(x; (cast(uint*)buf)[0..(size+31)/32])
			c += popcnt(x);
		if(v)
			return c;
		else
			return size-c;
	}
}
