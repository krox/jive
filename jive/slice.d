module jive.slice;

private import std.traits : Unqual;
private import std.typecons;
private import std.typetuple;

private template Range(size_t start, size_t stop) {
    static if (start >= stop)
        alias Range = TypeTuple!();
    else
        alias Range = TypeTuple!(Range!(start, stop-1), stop-1);
}

private template Times(size_t N, T)
{
	static if(N == 0)
		alias Times = TypeTuple!();
	else
		alias Times = TypeTuple!(T, Times!(N-1,T));
}

/**
 *  N-dimensional version of T[].
 */
struct Slice(T, size_t N = 1)
{
	alias Times!(N, size_t) Index; // multi-dimensional array-index
	alias Range!(0,N) Dimensions;  // 0..N-1, the dimensions

	T[] data;
	Index size;

	alias data this;

	/** constructor that takes given data */
	this(Index size, T[] data)
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

	/** constructor which allocates memory */
	this(Index size)
	{
		size_t l = 1;
		foreach(i; Dimensions)
		{
			this.size[i] = size[i];
			l *= size[i];
		}

		data = new T[l];
	}

	/** ditto */
	static if(is(Unqual!T == T))
	this(Index size, T val)
	{
		this(size);
		data[] = val;
	}

	Slice!(Unqual!T, N) dup() const
	{
		return Slice!(Unqual!T, N)(size, data.dup);
	}

	/** element access */
	ref inout(T) opIndex(Index index) inout
	{
		size_t offset = 0;
		size_t pitch = 1;
		foreach(i; Dimensions)
		{
			assert(index[i] < size[i], "multi-dim-array index out of bounds");
			offset += pitch * index[i];
			pitch *= size[i];
		}
		return data[offset];
	}

	/** foreach with indices */
	int opApply(in int delegate(Index, ref T) dg)
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
	int opApply(in int delegate(ref T) dg)
	{
		foreach(ref x; data)
			if(int r = dg(x))
				return r;
		return 0;
	}

	/** "cast" to to const elements. Sadly, we have to do this explicitly. Even though T[] -> const(T)[] is implicit. */
	Slice!(const(T),N) toConst() const @property
	{
		return Slice!(const(T),N)(size, data);
	}

	/** equivalent of std.exception.assumeUnique */
	Slice!(immutable(T),N) assumeUnique() const @property
	{
		static import std.exception;
		return Slice!(immutable(T),N)(size, std.exception.assumeUnique(data));
	}
}
