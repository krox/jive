module math.factorring;

import std.algorithm : move;
import math.integer;


class FactorRing(BaseRing)
{
	BaseRing baseRing;
	BaseRing.Element mod;

	alias Coset!BaseRing Element;

	this(BaseRing baseRing, BaseRing.Element mod)
	{
		this.baseRing = baseRing;
		this.mod = mod;
	}

	override string toString() const @property
	{
		return baseRing.toString ~ "/(" ~ mod.toString ~ ")";
	}

	Element opCall(int val)
	{
		return Element(this, BaseRing.Element(val));
	}

	Element opCall(BaseRing.Element val)
	{
		return Element(this, val);
	}
}

static struct Coset(BaseRing)
{
	const FactorRing!BaseRing ring;
	BaseRing.Element val;

	this(const FactorRing!BaseRing ring, BaseRing.Element val)
	{
		this.ring = ring;
		val %= ring.mod;
		this.val = move(val);
	}

	string toString() const @property
	{
		return "["~val.toString~"]";
	}

	/** replace this with -this */
	void negate()
	{
		val.negate();
		val %= ring.mod;
	}

	/** return 1/this */
	Coset inverse() const @property
	{
		static if(is(BaseRing == IntegerRing))
		{
			Integer x = 0;
			__gmpz_invert(&x.z, &this.val.z, &ring.mod.z);
			return Coset(ring, move(x));
		}
		else
		{
			assert(false, "TODO");
		}
	}

	Coset opBinary(string op, T)(const T rhs) const
		if(is(T == int) || is(T == Integer) || is(T == BaseRing.Element))
	{
		return opBinary!op(rhs);
	}

	Coset opBinary(string op, T)(ref const T rhs) const
		if(is(T == int) || is(T == Integer) || is(T == BaseRing.Element))
	{
		     static if(op == "+") return Coset(ring, val + rhs);
		else static if(op == "-") return Coset(ring, val - rhs);
		else static if(op == "*") return Coset(ring, val * rhs);
		else static assert(false, "binary assign '"~op~"' is not defined");
	}

	Coset opBinary(string op)(const Coset rhs) const
	{
		return opBinary!op(rhs);
	}

	Coset opBinary(string op)(ref const Coset rhs) const
	{
		assert(this.ring is rhs.ring);

		return opBinary!op(rhs.val);
	}

	void opOpAssign(string op, T)(const T rhs)
		if(is(T == int) || is(T == Integer) || is(T == BaseRing.Element))
	{
		opOpAssign!op(rhs);
	}

	void opOpAssign(string op, T)(ref const T rhs)
		if(is(T == int) || is(T == Integer) || is(T == BaseRing.Element))
	{
		     static if(op == "+") val += rhs;
		else static if(op == "-") val -= rhs;
		else static if(op == "*") val *= rhs;
		else static assert(false, "binary assign '"~op~"' is not defined");

		val %= mod;
	}

	void opOpAssign(string op)(const Coset rhs)
	{
		opOpAssign!op(rhs);
	}

	void opOpAssign(string op)(ref const Coset rhs)
	{
		assert(this.ring is rhs.ring);

		 opOpAssign!op(rhs.val);
	}

	bool opEquals(const Coset r) const
	{
		return opEquals(r);
	}

	bool opEquals(ref const Coset r) const
	{
		return val == r.val;
	}
}
