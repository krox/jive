module math.numberfield;

import math.integer;
import math.rational;


/**
 * Numbers of the form (a + b * sqrt(d)), with rationals a, b and d a (fixed) squarefree integer (and not 0 or 1).
 */
class QuadraticField
{
	/*immutable*/ Integer d;

	this(int d)
	{
		this(Integer(d));
	}

	this(Integer d)
	{
		if(d.isPerfectSquare)
			throw new Exception("invalid number field (d = "~d.toString~" is square)");

		this.d = move(d);
	}

	override string toString() const @property
	{
		return "ℚ[√"~d.toString~"]"; // yay for unicode :)
	}

	Element opCall(int a)
	{
		return Element(this, Rational(a), Rational(0));
	}

	Element opCall(Integer a)
	{
		return Element(this, Rational(move(a)), Rational(0));
	}

	Element opCall(Rational a)
	{
		return Element(this, move(a), Rational(0));
	}

	Element opCall(int a, int b)
	{
		return Element(this, Rational(a), Rational(b));
	}

	Element opCall(Integer a, Integer b)
	{
		return Element(this, Rational(move(a)), Rational(move(b)));
	}

	Element opCall(Rational a, Rational b)
	{
		return Element(this, move(a), move(b));
	}

	static struct Element
	{
		QuadraticField field;
		Rational a, b;

		string toString() const @property
		{
			return a.toString~"+"~b.toString~"√"~field.d.toString;
		}

		/** return -1 / 0 / +1, possibly faster than actual compare */
		int sign() const
		{
			assert(false, "TODO");
		}

		/** replace this with -this */
		void negate()
		{
			a.negate();
			b.negate();
		}

		/** negate the 'imaginary' part (for d>0 it is not imaginary, but conjugation is still an automorphism) */
		void conjugate()
		{
			b.negate();
		}

		/** returns the norm N(x) = x*conj(x) */
		Rational norm() const @property
		{
			return a*a-b*b*field.d;
		}

		/** replace this with 1/this (nan if this==0) */
		void invert()
		{
			conjugate();
			this /= norm;
		}

		Element opBinary(string op, T)(const T rhs) const
			if(is(T == Rational) || is(T == Integer))
		{
			return opBinary!op(rhs);
		}

		Element opBinary(string op, T)(ref const T rhs) const
			if(is(T == Rational) || is(T == Integer))
		{
			static if(op == "+")
				return Element(a+rhs, b);
			else static if(op == "-")
				return Element(a-rhs, b);
			else static if(op == "*")
				return Element(a*rhs, b*rhs);
			else static if(op == "/")
				return Element(a/rhs , b/rhs);
			else static assert(false, "binary assign '"~op~"' is not defined");
		}

		Element opBinary(string op)(const Element rhs) const
		{
			return opBinary!op(rhs);
		}

		Element opBinary(string op)(ref const Element rhs) const
		{
			assert(this.field is rhs.field);

			     static if(op == "+") return Element(a+rhs.a, b+rhs.b);
			else static if(op == "-") return Element(a-rhs.a, b-rhs.b);
			else static if(op == "*") return Element(a*rhs.a + b*rhs.b*d, a*rhs.b + b*rhs.a);
			else static if(op == "/") auto r = Element(a*rhs.a - b*rhs.b*d, b*rhs.a - a*rhs.b) / rhs.norm;
			else static assert(false, "binary assign '"~op~"' is not defined");
		}

		void opOpAssign(string op, T)(const T r)
			if(is(T == Rational) || is(T == Integer))
		{
			opOpAssign!op(r);
		}

		void opOpAssign(string op, T)(ref const T r)
			if(is(T == Rational) || is(T == Integer))
		{
			     static if(op == "+") { a += r; }
			else static if(op == "-") { a -= r; }
			else static if(op == "*") { a *= r; b *= r; }
			else static if(op == "/") { a /= r; b /= r; }
			else static assert(false, "binary assign '"~op~"' is not defined");
		}

		void opOpAssign(string op)(const Element r)
		{
			opOpAssign!op(r);
		}

		void opOpAssign(string op)(ref const Element r)
		{
			assert(this.field is r.field);

			     static if(op == "+") { a += r.a; b += r.b; }
			else static if(op == "-") { a -= r.a; b -= r.b; }
			else static if(op == "*")
			{
				auto tmp = a*r.a + b*r.b * d;
				b = a*r.b + b*r.a;
				a = move(tmp);
			}
			else static if(op == "/")
			{
				auto tmp = a*r.a - b*r.b * d;
				b = b*r.a - a*r.b;
				a = move(tmp);

				this /= r.norm();
			}
			else static assert(false, "binary assign '"~op~"' is not defined");
		}

		bool opEquals(const Element r) const
		{
			return opEquals(r);
		}

		bool opEquals(ref const Element r) const
		{
			return a == r.a && b == r.b;
		}

		int opCmp(const Element r) const
		{
			return opCmp(r);
		}

		int opCmp(ref const Element r) const
		{
			assert(false, "TODO");
		}

		/** returns largest integer <= this */
		Integer floor() const @property
		{
			if(field.d.sign != 1)
				throw new Exception("floor is not defined in imaginary quadratic fields");

			Integer x = a.denom*b.num;
			x *= x;
			x *= field.d;
			x = isqrt(x); // this root is never exact...

			if(a.denom.sign * b.num.sign == -1)
			{
				x.negate();
				x -= 1; // ... thereforce this is always necessary
			}

			x += a.num * b.denom;
			x /= a.denom*b.denom;

			return x;
		}
	}
}
