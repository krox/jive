module math.factorring;

import std.algorithm : move;
import math.integer;


struct Coset(Ring)
{
	Ring val;
	Ring mod;

	this(Ring val, Ring mod)
	{
		this.val = val % mod;
		this.mod = mod;
	}

	this(int val, Ring mod)
	{
		this(Ring(val), mod);
	}

	this(int val, int mod)
	{
		this(Ring(val), Ring(mod));
	}

	string toString() const @property
	{
		return "["~val.toString~"]";
	}

	/** return 1/this */
	Coset inverse() const @property
	{
		static if(is(Ring == Integer))
		{
			return Coset(val.inverseMod(mod), mod);
		}
		else
		{
			assert(false, "TODO");
		}
	}

	Coset opBinary(string op, T)(T rhs) const
		if(is(T == int) || is(T == Integer) || is(T == Ring))
	{
		     static if(op == "+") return Coset(val + rhs, mod);
		else static if(op == "-") return Coset(val - rhs, mod);
		else static if(op == "*") return Coset(val * rhs, mod);
		else static assert(false, "binary assign '"~op~"' is not defined");
	}

	Coset opBinary(string op)(Coset rhs) const
	{
		assert(this.mod == rhs.mod);
		return opBinary!op(rhs.val);
	}

	bool opEquals(Coset r) const
	{
		assert(mod == r.mod);
		return val == r.val;
	}

	bool opEquals(T)(T r) const
		if(!is(T : Coset))
	{
		return opEquals(Coset(r, mod));
	}
}
