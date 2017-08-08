/**
License: public domain
Authors: Simon Bürger
*/
module jive.map;

private import std.range;
private import std.algorithm;
private import jive.set;

/**
 * An (unordered map), based on jive.set.
 * Similar to builtin 'V[Key]', but with value-semantics.
 */
struct Map(Key, V)
{
	private Set!Entry entries;

	private static struct Entry
	{
		Key key;
		V value;

		size_t toHash() const @safe /*pure*/ nothrow
		{
			return typeid(Key).getHash(&key);
		}

		bool opEquals(const(Entry) b) const @safe pure nothrow
		{
			return key == b.key;
		}

		bool opEquals(ref const(Entry) b) const @safe pure nothrow
		{
			return key == b.key;
		}

		bool opEquals(const(Key) b) const @safe pure nothrow
		{
			return key == b;
		}

		bool opEquals(ref const(Key) b) const @safe pure nothrow
		{
			return key == b;
		}
	}

	/** returns: true if set is empty */
	bool empty() const pure nothrow @safe
	{
		return entries.empty;
	}

	/** returns: number of elements in the set */
	size_t length() const pure nothrow @safe
	{
		return entries.length;
	}

	/** returns: true if key is found in the map */
	bool opIn_r(T)(auto ref const(T) key) const
		if(is(typeof(T.init == Key.init)))
	{
		return entries.opIn_r(key);
	}

	/**
	 * Lookup a key and return the stored value.
	 * If the key does not currently exist, it is created and its
	 * value set to V.init.
	 */
	ref V opIndex(T)(auto ref const(T) key)
		if(is(typeof(T.init < Key.init)))
	{
		auto r = entries.find(key);

		if(r is null)
		{
			entries.add(Entry(key, V.init));
			r = entries.find(key);
		}

		assert(r !is null);
		return r.value;
	}

	/**
	 * Remove a key and associated value from the map.
	 * returns: true if removed, false if not found
	 */
	bool remove(T)(auto ref const(T) k)
		if(is(typeof(T.init < Key.init)))
	{
		return entries.remove(k);
	}

	/**
	 * Traverse all entries using foreach.
	 * TODO: turn this into ranges
	 */
	int opApply(int delegate(ref Key) dg)
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
	int opApply(int delegate(ref Key, ref V) dg)
	{
		int r = 0;
		foreach(ref e; entries[])
			if((r = dg(e.key, e.value)) != 0)
				break;
		return r;
	}
}

unittest
{
	Map!(int,int) a;
	a[1] = 1;
	a[2] = 2;
	a[1] = 3;
	a.remove(2);

	assert(1 in a);
	assert(2 !in a);
	assert(a.length == 1);
	assert(a[1] == 3);
}
