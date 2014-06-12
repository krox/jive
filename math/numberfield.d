module math.numberfield;

import math.integer;
import math.rational;


/**
 * Numbers of the form (a + b * sqrt(d)), with rationals a, b and d a (fixed) squarefree integer (and not 0 or 1).
 */


struct Quadratic
{
	Rational a, b;
	Integer d;

	this(Rational a, Rational b, Integer d)
	{
		this.a = a;
		this.b = b;
		this.d = d;
	}

	string toString() const @property
	{
		return a.toString~"+"~b.toString~"√"~d.toString;
	}

	/** return -1 / 0 / +1, possibly faster than actual compare */
	int sign() const
	{
		assert(false, "TODO");
	}

	/** replace this with -this */
	Quadratic opUnary(string op)() const
		if(op == "-")
	{
		return Quadratic(-a, -b, d);
	}

	/** negate the 'imaginary' part (for d>0 it is not imaginary, but conjugation is still an automorphism) */
	Quadratic conjugate() const
	{
		return Quadratic(a, -b, d);
	}

	/** returns the norm N(x) = x*conj(x) */
	Rational norm() const @property
	{
		return a*a-b*b*d;
	}

	/** replace this with 1/this (nan if this==0) */
	Quadratic inverse() const
	{
		return conjugate / norm;
	}

	Quadratic opBinary(string op, T)(T rhs) const
		if(is(T == Rational) || is(T == Integer))
	{
		static if(op == "+")
			return Quadratic(a+rhs, b, d);
		else static if(op == "-")
			return Quadratic(a-rhs, b, d);
		else static if(op == "*")
			return Quadratic(a*rhs, b*rhs, d);
		else static if(op == "/")
			return Quadratic(a/rhs , b/rhs, d);
		else static assert(false, "binary assign '"~op~"' is not defined");
	}

	Quadratic opBinary(string op)(Quadratic rhs) const
	{
		assert(this.field is rhs.field);

		     static if(op == "+") return Quadratic(a+rhs.a, b+rhs.b, d);
		else static if(op == "-") return Quadratic(a-rhs.a, b-rhs.b, d);
		else static if(op == "*") return Quadratic(a*rhs.a + b*rhs.b*d, a*rhs.b + b*rhs.a, d);
		else static if(op == "/") auto r = Quadratic(a*rhs.a - b*rhs.b*d, b*rhs.a - a*rhs.b, d) / rhs.norm;
		else static assert(false, "binary assign '"~op~"' is not defined");
	}

	bool opEquals(Quadratic r) const
	{
		return a == r.a && b == r.b;
	}

	bool opEquals(int r) const
	{
		return a == r && b == 0;
	}

	int opCmp(Quadratic r) const
	{
		assert(false, "TODO");
	}

	/** returns largest integer <= this */
	Integer floor() @property
	{
		if(d.sign != 1)
			throw new Exception("floor is not defined in imaginary quadratic fields");

		Integer x = a.denom*b.num;
		x = isqrt(x*x*d); // this root is never exact...

		if(a.denom.sign * b.num.sign == -1)
			x = -x-1; // ... therefore the "-1" is always necessary

		return (x + a.num * b.denom) / (a.denom*b.denom);
	}
}
