module jive.lazyarray;

import jive.array;

/**
 *  array with fast lazy reset
 *  (and a lot of missing methods cause I'm lazy too)
 */
struct LazyArray(V)
{
	private Array!V vals;
	private Array!ushort time;
	private ushort curr;

	/** indexing */
	ref V opIndex(size_t index)
	{
		if(time[index] != curr)
		{
			time[index] = curr;
			vals[index] = V.init;
		}
		return vals[index];
	}

	/** (lazily) resets all elements to V.init */
	void reset()
	{
		if(curr == ushort.max)
		{
			vals[] = V.init;
			time[] = 0;
			curr = 0;
		}
		else
			++curr;
	}

	/** sets the size to some value. Either cuts of some values (but does not free memory), or fills new ones with V.init */
	void resize(size_t newsize)
	{
		vals.resize(newsize);
		time.resize(newsize);
	}
}
