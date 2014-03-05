module jive.map;

private import std.range;
private import std.algorithm;
private import jive.set;

/**
 * An ordered map. Value-semantics.
 * TODO: constructors and ranges
 */
struct Map(K,V)
{
	private Set!Entry entries;

	private static struct Entry
	{
		K key;
		V value;

		alias key this; // enables Entry-Entry and Entry-Key comparisons
	}

	/** returns: true if set is empty */
	bool empty() const @property nothrow @safe
	{
		return entries.empty;
	}

	/** returns: number of elements in the set */
	size_t length() const @property nothrow @safe
	{
		return entries.length;
	}

	/** returns: true if key is found in the map */
	bool opIn_r(T)(const T key) const
		if(is(typeof(T.init < K.init)))
	{
		return entries.opIn_r(key);
	}

	/** ditto */
	bool opIn_r(T)(const ref T key) const
		if(is(typeof(T.init < K.init)))
	{
		return entries.opIn_r(key);
	}

	/**
	 * Lookup a key and return the stored value.
	 * If the key is not found, a new entry with value V.init is created.
	 */
	ref V opIndex(const ref K key)
	{
		// TODO: in case the key is not found, we do three lookups of the key. That just not cool.

		auto r = entries.find(key);

		if(r is null)
		{
			entries.add(Entry(key, V.init));
			r = entries.find(key);
			assert(r !is null);
		}

		return r.value.value;
	}

	/**
	 * Lookup a key and return the stored value.
	 * If the key is not found, an exception is thrown.
	 */
	ref const(V) opIndex(const ref K key) const
	{
		auto r = entries.find(key);

		if(r is null)
			throw new Exception("index out of bounds in jive.Map.opIndex");

		return r.value.value;
	}

	/**
	 * Remove a key and associated value from the map.
	 * returns: true if removed, false if not found
	 */
	bool remove(const(K) k)
	{
		return entries.remove(k);
	}

	/** ditto */
	bool remove(ref const(K) k)
	{
		return entries.remove(k);
	}

	/**
	 * Traverse all entries using foreach.
	 */
	int opApply(int delegate(ref K) dg)
	{
		int r = 0;
		foreach(ref e; entries[])
			if((r = dg(e.key)) != 0)
				break;
		return r;
	}

	/**
	 * ditto
	 */
	int opApply(int delegate(ref K, ref V) dg)
	{
		int r = 0;
		foreach(ref e; entries[])
			if((r = dg(e.key, e.value)) != 0)
				break;
		return r;
	}
}
