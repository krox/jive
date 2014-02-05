module jive.bitarray;

/**
 *  similar to Array!bool, but more memory-efficient
 */
struct BitArray
{
	private ulong* buf = null;
	private size_t count = 0;	// number of bits in use

	/** constructor for given length */
	this(size_t size)
	{
		buf = new ulong[(size+63)/64].ptr;
		count = size;
	}

	/** post-blit that does a full copy */
	this(this)
	{
		buf = buf[0..(count+63)/64].dup.ptr;
	}

	/** number of elements */
	size_t length() const nothrow @property @safe
	{
		return count;
	}

	/** indexing */
	bool opIndex(size_t i) const
	{
		assert(i < count, "BitArray index out of bounds");
		return (buf[i/64] >> (i%64)) & 1;
	}

	/** ditto */
	bool opIndexAssign(bool v, size_t i)
	{
		assert(i < count, "BitArray index out of bounds");
		ulong bit = 1UL << (i%64);
		buf[i/64] = (buf[i/64]&~bit) | (v?bit:0);
		return v;
	}
}
