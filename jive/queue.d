module jive.queue;

private import std.algorithm : moveAll, move;

/** simple FIFO structure, implemented as circular buffer */
struct Queue(V)
{
	private V[] buf;
	private size_t posIn, posOut;
	private size_t size;	// NOTE: this is not redundant, because posIn==posOut can either mean the queue is empty or full

	this(this)
	{
		buf = buf.dup;
	}

	bool empty() const nothrow @property @safe
	{
		return size == 0;
	}

	size_t length() const nothrow @property @safe
	{
		return size;
	}

	void push(V val)
	{
		if(size == buf.length)
		{
			assert(posIn == posOut);
			auto newBuf = new V[buf.length ? buf.length * 2 : 4];
			moveAll(buf[posOut..$], newBuf[0..buf.length-posOut]);
			moveAll(buf[0..posIn], newBuf[buf.length-posOut..buf.length]);
			posIn = buf.length;
			posOut = 0;
			buf = newBuf;
		}

		++size;

		buf[posIn] = move(val);
		posIn = (posIn+1)%buf.length;
	}

	V pop()
	{
		assert(size != 0, "buffer underflow");
		--size;
		V v = move(buf[posOut]);
		posOut = (posOut+1)%buf.length;
		return v;
	}
}
