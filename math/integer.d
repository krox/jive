module math.integer;

private import std.string : toStringz;
private import std.conv : to;

class IntegerRing
{
	private static IntegerRing instance;

	static this()
	{
		instance = new IntegerRing;
	}

	static IntegerRing opCall()
	{
		return instance;
	}

	alias Integer Element;

	private this() { }

	override string toString() const @property
	{
		return "ℤ";
	}

	Integer opCall(int v) const
	{
		return Integer(v);
	}

	Integer opCall(double v) const
	{
		return Integer(v);
	}

	Integer opCall(string v) const
	{
		return Integer(v);
	}
}

/**
 * BigInteger type with value semantic. Implemented using the GMP library.
 * Mostly compatible with int. Differences include:
 *   * There is a NaN value, to which all Integers are initialized.
 *   * NaNs are not propagated, but instead exceptions are thrown when used
 *   * integer division rounds the quotient towards -infinity. In particular, (a % b) always has the same sign as b.
 */
struct Integer
{
	package mpz_t z;

	enum nan = Integer.init;

	bool isNan() const @property
	{
		return z._mp_d is 0;
	}

	/** constructor for given value */
	this(int v)
	{
		__gmpz_init_set_si(&z, v);
	}

	/** ditto */
	this(double v)
	{
		__gmpz_init_set_d(&z, v);
	}

	/** ditto */
	this(string v)
	{
		if(v == "nan")
			return;

		// TODO: throw exception on bad strings
		__gmpz_init_set_str(&z, toStringz(v), 0);
	}

	/** (expensive) copy constructor */
	this(this)
	{
		if(isNan)
			return;

		version(warn_postblit)
		{
			import std.stdio;
			writefln("WARNING: post-blit on gmp value "~this.toString);
		}

		auto old = z;
		z = z.init;
		__gmpz_init_set(&z, &old);
	}

	version(count_gmp)
	{
		static int destructCount = 0;

		static ~this()
		{
			import std.stdio;
			writefln("GMP integers destructed: %s", destructCount);
		}
	}

	/** destructor */
	~this()
	{
		if(isNan)
			return;

		__gmpz_clear(&z);

		version(count_gmp)
			destructCount++;
	}

	string toString() const @property
	{
		if(isNan)
			return "nan";

		auto buflen = __gmpz_sizeinbase(&z, 10)+2;	// one for sign, one for \0
		auto buf = new char[buflen];
		return to!string(__gmpz_get_str(buf.ptr, 10, &z));
	}

	/** return -1 / 0 / +1, faster than actual compare */
	int sign() const
	{
		return z._mp_size < 0 ? -1 : z._mp_size > 0;
	}

	/** set this to -this */
	void negate()
	{
		if(this.isNan)
			throw new NanException;

		__gmpz_neg(&this.z, &this.z);
	}

	Integer opUnary(string op)() const
	{
		if(isNan)
			throw new NanException;

		static if(op == "+")
			return this;
		else
		{
			Integer r = this;
			r.negate;
			return r;
		}
	}

	Integer opBinary(string op)(int b) const
	{
		Integer r;
		if(this.isNan)
			throw new NanException;

		__gmpz_init(&r.z);

		     static if(op == "+")
		     if(b >= 0) __gmpz_add_ui(&r.z, &this.z, b);
		     else       __gmpz_sub_ui(&r.z, &this.z, -b);
		else static if(op == "-")
			if(b >= 0) __gmpz_sub_ui(&r.z, &this.z, b);
			else       __gmpz_add_ui(&r.z, &this.z, -b);
		else static if(op == "*") __gmpz_mul_si(&r.z, &this.z, b);
		//else static if(op == "/") __gmpz_fdiv_q_si(&r.z, &this.z, b); // TODO (why are there so few *_si functions in gmp?)
		//else static if(op == "%") __gmpz_fdiv_r_si(&r.z, &this.z, b);
		else static assert(false, "binary '"~op~"' is not defined");

		return r;
	}

	Integer opBinary(string op)(const Integer b) const
	{
		return opBinary!op(b);
	}

	Integer opBinary(string op)(ref const Integer b) const
	{
		Integer r;
		if(this.isNan || b.isNan)
			throw new NanException;

		__gmpz_init(&r.z);

		     static if(op == "+") __gmpz_add(&r.z, &this.z, &b.z);
		else static if(op == "-") __gmpz_sub(&r.z, &this.z, &b.z);
		else static if(op == "*") __gmpz_mul(&r.z, &this.z, &b.z);
		else static if(op == "/") __gmpz_fdiv_q(&r.z, &this.z, &b.z);
		else static if(op == "%") __gmpz_fdiv_r(&r.z, &this.z, &b.z);
		else static assert(false, "binary '"~op~"' is not defined");

		return r;
	}

	void opOpAssign(string op)(int b)
	{
		if(this.isNan)
			throw new NanException;

		     static if(op == "+")
		     if(b >= 0) __gmpz_add_ui(&this.z, &this.z, b);
		     else       __gmpz_sub_ui(&this.z, &this.z, -b);
		else static if(op == "-")
			if(b >= 0) __gmpz_sub_ui(&this.z, &this.z, b);
			else       __gmpz_add_ui(&this.z, &this.z, -b);
		else static if(op == "*") __gmpz_mul_si(&this.z, &this.z, b);
		//else static if(op == "/") __gmpz_fdiv_q_si(&r.z, &this.z, b); // TODO (why are there so few *_si functions in gmp?)
		//else static if(op == "%") __gmpz_fdiv_r_si(&r.z, &this.z, b);
		else static assert(false, "binary '"~op~"' is not defined");
	}

	void opOpAssign(string op)(const Integer b)
	{
		opOpAssign!op(b);
	}

	void opOpAssign(string op)(ref const Integer b)
	{
		if(this.isNan || b.isNan)
			throw new NanException;

		     static if(op == "+") __gmpz_add(&this.z, &this.z, &b.z);
		else static if(op == "-") __gmpz_sub(&this.z, &this.z, &b.z);
		else static if(op == "*") __gmpz_mul(&this.z, &this.z, &b.z);
		else static if(op == "/") __gmpz_fdiv_q(&this.z, &this.z, &b.z);
		else static if(op == "%") __gmpz_fdiv_r(&this.z, &this.z, &b.z);
		else static assert(false, "binary-assign '"~op~"' is not defined");
	}

	bool opEquals(int b) const
	{
		if(isNan)
			throw new NanException;

		return __gmpz_cmp_si(&this.z, b) == 0;
	}

	bool opEquals(const Integer b) const
	{
		return opEquals(b);
	}

	bool opEquals(ref const Integer b) const
	{
		if(this.isNan || b.isNan)
			throw new NanException;

		return __gmpz_cmp(&this.z, &b.z) == 0;
	}

	int opCmp(int b) const
	{
		if(isNan)
			throw new NanException;

		return __gmpz_cmp_si(&this.z, b);
	}

	int opCmp(const Integer b) const
	{
		return opCmp(b);
	}

	int opCmp(ref const Integer b) const
	{
		if(this.isNan || b.isNan)
			throw new NanException;

		return __gmpz_cmp(&this.z, &b.z);
	}

	bool isPerfectSquare() const @property
	{
		if(isNan)
			throw new NanException;

		return __gmpz_perfect_square_p(&this.z) != 0;
	}

	auto field() const @property
	{
		return IntegerRing();
	}
}

/** returns floor(sqrt(a)) */
Integer isqrt(ref const Integer a)
{
	if(a.isNan)
		throw new Exception("NaN in sqrt(...)");

	Integer r;
	__gmpz_init(&r.z);
	__gmpz_sqrt(&r.z, &a.z);
	return r;
}

Integer gcd(ref const Integer a, ref const Integer b)
{
	Integer r;
	if(a.isNan || b.isNan)
		throw new NanException;

	__gmpz_init(&r.z);
	__gmpz_gcd(&r.z, &a.z, &b.z);
	return r;
}

/** divide all arguments by their gcd */
void cancelCommonFactors(ref Integer a, ref Integer b)
{
	if(a.isNan || b.isNan)
		throw new NanException;

	Integer g;
	__gmpz_init(&g.z);
	__gmpz_gcd(&g.z, &a.z, &b.z);

	__gmpz_divexact(&a.z, &a.z, &g.z);
	__gmpz_divexact(&b.z, &b.z, &g.z);
}

/** ditto */
void cancelCommonFactors(ref Integer a, ref Integer b, ref Integer c)
{
	if(a.isNan || b.isNan || c.isNan)
		throw new NanException;

	Integer g;
	__gmpz_init(&g.z);
	__gmpz_gcd(&g.z, &a.z, &b.z);
	__gmpz_gcd(&g.z, &g.z, &c.z);

	__gmpz_divexact(&a.z, &a.z, &g.z);
	__gmpz_divexact(&b.z, &b.z, &g.z);
	__gmpz_divexact(&c.z, &c.z, &g.z);
}

class NanException : Exception
{
	this(string file = __FILE__, int line = __LINE__)
	{
		super("encountered Integer.nan in calculation ("~file~":"~to!string(line)~")");
	}
}

package extern(C):

version(Windows)
{
	alias int c_long;
	alias uint c_ulong;
}
else
{
	static if((void*).sizeof > int.sizeof)
	{
		alias long c_long;
		alias ulong c_ulong;
	}
	else
	{
		alias int c_long;
		alias uint c_ulong;
	}
}

alias c_ulong mp_bitcnt_t;

extern immutable int __gmp_bits_per_limb;
extern immutable int __gmp_errno;
extern immutable char* __gmp_version;

private alias size_t limb;

static this()
{
	assert(limb.sizeof*8 == __gmp_bits_per_limb, "wrong gmp limb size");
}

struct mpz_t
{
	int _mp_alloc;
	int _mp_size;
	/*limb * */ size_t _mp_d; // hack to enable const -> non-const assignment. _should_ be fine, cause Integer has value-semantics
}

size_t __gmpz_sizeinbase (const mpz_t* op , int base );

void __gmpz_init(mpz_t* x );
void __gmpz_init2(mpz_t* x ,size_t n);
void __gmpz_clear(mpz_t* x);
void __gmpz_realloc2(mpz_t* x, mp_bitcnt_t n);	// set to 0 if it does not fit

void __gmpz_set    (mpz_t* rop, const mpz_t* op);
void __gmpz_set_ui (mpz_t* rop, c_ulong op);
void __gmpz_set_si (mpz_t* rop, c_long op);
void __gmpz_set_d  (mpz_t* rop, double op);
int  __gmpz_set_str(mpz_t* rop , const char * str , int base );	// white space allowed/ignored, if base=0, 0x/0b&/0 are recognized. returns 0 if entire string is valid number

void __gmpz_swap   (mpz_t* rop1 , mpz_t* rop2 );

void __gmpz_init_set    (mpz_t* rop, const mpz_t* op );
void __gmpz_init_set_ui (mpz_t* rop, c_ulong op);
void __gmpz_init_set_si (mpz_t* rop, c_long op);
void __gmpz_init_set_d  (mpz_t* rop, double op);
int  __gmpz_init_set_str(mpz_t* rop, const char * str, int base);

c_ulong __gmpz_get_ui (const mpz_t* op);
c_long  __gmpz_get_si (const mpz_t* op);
double  __gmpz_get_d  (const mpz_t* op);
double  __gmpz_get_d_2exp (c_long * exp, const mpz_t* op);
char*   __gmpz_get_str(char* str, int base, const mpz_t* op);	// str==null or buffer of size __gmpz_sizeinbase (op, base ) + 2

void __gmpz_add       (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_add_ui    (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_sub       (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_sub_ui    (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_ui_sub    (mpz_t* rop,      c_ulong op1, const mpz_t* op2);
void __gmpz_mul       (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_mul_si    (mpz_t* rop, const mpz_t* op1,       c_long op2);
void __gmpz_mul_ui    (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_addmul    (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_addmul_ui (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_submul    (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_submul_ui (mpz_t* rop, const mpz_t* op1,      c_ulong op2);

void __gmpz_mul_2exp (mpz_t* rop , const mpz_t* op1 , size_t op2 );	// rop = op1*2^op2
void __gmpz_neg (mpz_t* rop , const mpz_t* op );
void __gmpz_abs (mpz_t* rop , const mpz_t* op );

void __gmpz_cdiv_q (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_cdiv_r (mpz_t* r , const mpz_t* n , const mpz_t* d );
void __gmpz_cdiv_qr (mpz_t* q , mpz_t* r , const mpz_t* n , const mpz_t* d );

c_ulong __gmpz_cdiv_q_ui (mpz_t* q , const mpz_t* n, c_ulong d );
c_ulong __gmpz_cdiv_r_ui (mpz_t* r , const mpz_t* n, c_ulong d );
c_ulong __gmpz_cdiv_qr_ui (mpz_t* q , mpz_t* r , const mpz_t* n, c_ulong d );
c_ulong __gmpz_cdiv_ui (const mpz_t* n , c_ulong d );
void __gmpz_cdiv_q_2exp (mpz_t* q , const mpz_t* n , size_t b );
void __gmpz_cdiv_r_2exp (mpz_t* r , const mpz_t* n , size_t b );
void __gmpz_fdiv_q (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_fdiv_r (mpz_t* r , const mpz_t* n , const mpz_t* d );
void __gmpz_fdiv_qr (mpz_t* q , mpz_t* r , const mpz_t* n , const mpz_t* d );
c_ulong __gmpz_fdiv_q_ui (mpz_t* q , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_fdiv_r_ui (mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_fdiv_qr_ui (mpz_t* q , mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_fdiv_ui (const mpz_t* n , c_ulong d );
void __gmpz_fdiv_q_2exp (mpz_t* q , const mpz_t* n , size_t b );
void __gmpz_fdiv_r_2exp (mpz_t* r , const mpz_t* n , size_t b );
void __gmpz_tdiv_q (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_tdiv_r (mpz_t* r , const mpz_t* n , const mpz_t* d );
void __gmpz_tdiv_qr (mpz_t* q , mpz_t* r , const mpz_t* n , const mpz_t* d );
c_ulong __gmpz_tdiv_q_ui (mpz_t* q , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_tdiv_r_ui (mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_tdiv_qr_ui (mpz_t* q , mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_tdiv_ui (const mpz_t* n , c_ulong d );
void __gmpz_tdiv_q_2exp (mpz_t* q , const mpz_t* n , size_t b );
void __gmpz_tdiv_r_2exp (mpz_t* r , const mpz_t* n , size_t b );

void __gmpz_mod (mpz_t* r , const mpz_t* n , const mpz_t* d );
c_ulong __gmpz_mod_ui (mpz_t* r , const mpz_t* n , c_ulong d );

void __gmpz_divexact (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_divexact_ui (mpz_t* q , const mpz_t* n , c_ulong d );

int __gmpz_divisible_p (const mpz_t* n , const mpz_t* d );
int __gmpz_divisible_ui_p (const mpz_t* n , c_ulong d );
int __gmpz_divisible_2exp_p (const mpz_t* n , size_t b );

int __gmpz_congruent_p (const mpz_t* n , const mpz_t* c , const mpz_t* d );
int __gmpz_congruent_ui_p (const mpz_t* n , c_ulong c , c_ulong d );
int __gmpz_congruent_2exp_p (const mpz_t* n , const mpz_t* c , size_t b );

void __gmpz_powm (mpz_t* rop , const mpz_t* base , const mpz_t* exp , const mpz_t* mod );
void __gmpz_powm_ui (mpz_t* rop , const mpz_t* base , c_ulong exp , const mpz_t* mod );
void __gmpz_powm_sec (mpz_t* rop , const mpz_t* base , const mpz_t* exp , const mpz_t* mod );
void __gmpz_pow_ui (mpz_t* rop , const mpz_t* base , c_ulong exp );
void __gmpz_ui_pow_ui (mpz_t* rop , c_ulong base , c_ulong exp);

int __gmpz_root (mpz_t* rop , const mpz_t* op , c_ulong n );	// returns nonzero if exact

void __gmpz_rootrem (mpz_t* root , mpz_t* rem , const mpz_t* u , c_ulong n );
void __gmpz_sqrt (mpz_t* rop , const mpz_t* op );

void __gmpz_sqrtrem (mpz_t* rop1 , mpz_t* rop2 , const mpz_t* op );

int __gmpz_perfect_power_p (const mpz_t* op );	// nonzero if perfect power
int __gmpz_perfect_square_p (const mpz_t* op );

int __gmpz_probab_prime_p (const mpz_t* n , int reps );	// 2=prime, 1=prob.prime, 0=composite, reps~25

void __gmpz_nextprime (mpz_t* rop , const mpz_t* op );
void __gmpz_gcd (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
c_ulong __gmpz_gcd_ui (mpz_t* rop , const mpz_t* op1 , c_ulong op2 );
void __gmpz_gcdext (mpz_t* g , mpz_t* s , mpz_t* t , const mpz_t* a , const mpz_t* b );
void __gmpz_lcm (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_lcm_ui (mpz_t* rop , const mpz_t* op1 , c_ulong op2 );
int __gmpz_invert (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
int __gmpz_jacobi (const mpz_t* a , const mpz_t* b );
int __gmpz_legendre (const mpz_t* a , const mpz_t* p );

int __gmpz_kronecker (const mpz_t* a , const mpz_t* b );
int __gmpz_kronecker_si (const mpz_t* a , c_long b );
int __gmpz_kronecker_ui (const mpz_t* a , c_ulong b );
int __gmpz_si_kronecker (c_long a , const mpz_t* b );
int __gmpz_ui_kronecker (c_ulong a , const mpz_t* b );

mp_bitcnt_t __gmpz_remove (mpz_t* rop , const mpz_t* op , const mpz_t* f );

void __gmpz_fac_ui (mpz_t* rop , c_ulong n );
void __gmpz_2fac_ui (mpz_t* rop , c_ulong n );
void __gmpz_mfac_uiui (mpz_t* rop , c_ulong n , c_ulong m );
void __gmpz_primorial_ui (mpz_t* rop , c_ulong n );
void __gmpz_bin_ui (mpz_t* rop , const mpz_t* n , c_ulong k );
void __gmpz_bin_uiui (mpz_t* rop , c_ulong n , c_ulong k );
void __gmpz_fib_ui (mpz_t* fn , c_ulong n );
void __gmpz_fib2_ui (mpz_t* fn , mpz_t* fnsub1 , c_ulong n );
void __gmpz_lucnum_ui (mpz_t* ln , c_ulong n );
void __gmpz_lucnum2_ui (mpz_t* ln , mpz_t* lnsub1 , c_ulong n );

int __gmpz_cmp (const mpz_t* op1 , const mpz_t* op2 );
int __gmpz_cmp_d (const mpz_t* op1 , double op2 );
int __gmpz_cmp_si (const mpz_t* op1 , c_long op2 );
int __gmpz_cmp_ui (const mpz_t* op1 , c_ulong op2 );

int __gmpz_cmpabs (const mpz_t* op1 , const mpz_t* op2 );
int __gmpz_cmpabs_d (const mpz_t* op1 , double op2 );
int __gmpz_cmpabs_ui (const mpz_t* op1 , c_ulong op2 );

int __gmpz_sgn (const mpz_t* op );

void __gmpz_and (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_ior (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_xor (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_com (mpz_t* rop , const mpz_t* op );

mp_bitcnt_t __gmpz_popcount (const mpz_t* op ); // returns bitcnt.max on negative
mp_bitcnt_t __gmpz_hamdist (const mpz_t* op1 , const mpz_t* op2 ); //returns bitcnt.max if different signs
mp_bitcnt_t __gmpz_scan0 (const mpz_t* op , size_t starting_bit );
mp_bitcnt_t __gmpz_scan1 (const mpz_t* op , size_t starting_bit );
void __gmpz_setbit (mpz_t* rop , size_t bit_index );
void __gmpz_clrbit (mpz_t* rop , size_t bit_index );
void __gmpz_combit (mpz_t* rop , size_t bit_index );
int __gmpz_tstbit (const mpz_t* op , size_t bit_index );
