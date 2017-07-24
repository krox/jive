module jive.set;

private import std.range;
private import std.algorithm;
private import std.functional;

/**
 * An ordered set. Internally a red-black-tree. Value-semantics.
 */
struct Set(V, alias _less = "a < b")
{
	//////////////////////////////////////////////////////////////////////
	// internals / debugging
	//////////////////////////////////////////////////////////////////////

	private Node* root = null;
	private size_t count = 0;

	alias less = binaryFun!_less;

	private static struct Node
	{
		Node* left, right; // children
		Node* _parent; // color flag in first bit (newly insered nodes are red)
		V value;	// actual userdata

		inout(Node)* parent() inout @property
		{
			return cast(inout(Node)*)(cast(size_t)_parent&~1);
		}

		void parent(Node* p) @property
		{
			_parent = cast(Node*)(black|cast(size_t)p);
		}

		bool black() const @property
		{
			return cast(size_t)_parent&1;
		}

		void black(bool b) @property
		{
			_parent = cast(Node*)(b|cast(size_t)parent);
		}

		Node* outerLeft()
		{
			Node* node = &this;
			while(node.left !is null)
				node = node.left;
			return node;
		}

		Node* outerRight()
		{
			Node* node = &this;
			while(node.right !is null)
				node = node.right;
			return node;
		}

		Node* succ()
		{
			if(right !is null)
				return right.outerLeft;

			Node* node = &this;
			while(node.parent !is null && node.parent.right is node)
				node = node.parent;
			node = node.parent;
			return node;
		}

		Node* pred()
		{
			if(left !is null)
				return left.outerRight;

			Node* node = &this;
			while(node.parent !is null && node.parent.left is node)
				node = node.parent;
			node = node.parent;
			return node;
		}

		this(V value, Node* parent = null)
		{
			this.value = move(value);
			this.parent = parent;
		}
	}

	void check()
	{
		static int checkNode(Node* node, Node* parent) // return length of black (excluding nil)
		{
			if(node is null)
				return 0;

			assert(node.parent == parent, "incorrect parent pointers");
			int l = checkNode(node.left, node);
			int r = checkNode(node.right, node);
			assert(l == r, "differing black-heights");

			if(!node.black)
			{
				assert(parent, "red root");
				assert(parent.black, "two consecutive red nodes");
				return l;
			}
			else
				return l+1;
		}

		checkNode(root, null);
	}


	///////////////////////////////////////////////////////////////////
	// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		foreach(ref x; data)
			add(x);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		static Node* copyNode(Node* node, Node* parent)
		{
			if(node is null)
				return null;

			Node* r = new Node;
			r.black = node.black;
			r.left = copyNode(node.left, node);
			r.right = copyNode(node.right, node);
			r.parent = parent;
			r.value = node.value;
			return r;
		}

		root = copyNode(root, null);
	}


	////////////////////////////////////////////////////////////////
	// metrics
	//////////////////////////////////////////////////////////////////////

	/** returns: true if set is empty */
	bool empty() const @property nothrow @safe
	{
		return root is null;
	}

	/** returns: number of elements in the set */
	size_t length() const @property nothrow @safe
	{
		return count;
	}

	/** height of tree (for debugging or benchmarking) */
	size_t height() const @property nothrow @safe
	{
		static size_t h(const Node* node) nothrow @safe
		{
			if(node is null)
				return 0;
			return 1 + max(h(node.left), h(node.right));
		}

		return h(root);
	}

	//////////////////////////////////////////////////////////////////////
	// finding, reading
	//////////////////////////////////////////////////////////////////////

	/** private helper, null if not found */
	package inout(Node)* find(T)(auto ref const(T) value) inout
		if(is(typeof(less(T.init, V.init))))
	{
		inout(Node)* node = root;
		while(node !is null && node.value != value)
			if(less(value, node.value))
				node = node.left;
			else
				node = node.right;
		return node;
	}

	/** private helper, null if set is empty */
	package inout(Node)* findApprox(char what, T)(auto ref const(T) value) inout
		if(is(typeof(less(T.init, V.init))))
	{
		inout(Node)* par = null;
		inout(Node)* node = root;

		while (node !is null)
		{
			static if(what == '[')
			{
				if (!less(node.value, value))
					{ par = node; node = node.left; }
				else
					node = node.right;
			}
			else static if(what == '(')
				if (less(value, node.value))
					{ par = node; node = node.left; }
				else
					node = node.right;
			else static if(what == ']')
			{
				if (!less(value, node.value))
					{ par = node; node = node.right; }
				else
					node = node.left;
			}
			else static if(what == ')')
				if (less(node.value, value))
					{ par = node; node = node.right; }
				else
					node = node.left;
			else static assert(false);
		}

		return par;

	}

	/** returns: true if value is found in the set */
	bool opIn_r(T)(auto ref const(T) value) const
		if(is(typeof(less(T.init, V.init))))
	{
		return find(value) !is null;
	}

	//////////////////////////////////////////////////////////////////////
	// add, remove
	//////////////////////////////////////////////////////////////////////

	/**
	 * Add an element to the set.
	 * returns: true if added, false if not (due to duplicate already present)
	 */
	bool add(V value)
	{
		static Node* addRec(ref V value, Node* p)
		{
			if(less(value, p.value))
			{
				if(p.left is null)
					return p.left = new Node(move(value), p);
				else
					return addRec(value, p.left);
			}
			if(less(p.value, value))
			{
				if(p.right is null)
					return p.right = new Node(move(value), p);
				else
					return addRec(value, p.right);
			}

			p.value = move(value); // if value is already present, replace it (relevant for implementation of jive.Map)
			return null;
		}

		Node * node;
		if(root is null)
			node = root = new Node(move(value), null);
		else
			node = addRec(value, root);

		if(node is null)
			return false;

		++count;
		balanceAdd(node);
		return true;
	}

	/**
	 * Add elements from a range to the set.
	 * returns: number of elements added
	 */
	size_t add(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		size_t r = 0;
		foreach(x; data)
			if(add(x))
				++r;
		return r;
	}

	/**
	 * Remove an element from the set.
	 * returns: true if removed, false if not found
	 */
	bool remove(T)(auto ref const(T) v)
		if(is(typeof(less(T.init, V.init))))
	{
		// find the node to be deleted
		Node* n = find(v);
		if(n is null)
			return false;
		--count;

		// reduce to case with at most one child, which is null or red but never black
		Node* child;
		if(n.left is null)
			child = n.right;
		else
		{
			auto pivot = n.left.outerRight();
			n.value = move(pivot.value);
			n = pivot;
			child = n.left;
		}

		// (red) child -> replace once more (NOTE: child is always a leaf)
		if(child !is null)
		{
			n.value = move(child.value);
			n = child;
		}

		balanceRemove(n);

		if(n.parent is null)
			root = null;
		else if(n.parent.left is n)
			n.parent.left = null;
		else
			n.parent.right = null;
		delete n;
		return true;
	}


	//////////////////////////////////////////////////////////////////////
	// Traversal
	//////////////////////////////////////////////////////////////////////

	/**
	 * Range type for iterating over elements of the set.
	 * Implements std.range.isBidirectionalRange
	 */
	struct Range
	{
		private Node* left, right;	// both inclusive

		bool empty() const @property
		{
			return left is null;
		}

		void popFront() @property
		{
			if(left is right)
				left = right = null;
			else
				left = left.succ;
		}

		void popBack() @property
		{
			if(left is right)
				left = right = null;
			else
				right = right.pred;
		}

		ref inout(V) front() inout @property
		{
			return left.value;
		}

		ref inout(V) back() inout @property
		{
			return right.value;
		}

		Range save() @property
		{
			return this;
		}
	}

	/**
	 * returns: range that covers the whole set
	 */
	Range opSlice()
	{
		if(root is null)
			return Range(null, null);
		else
			return Range(root.outerLeft(), root.outerRight);
	}

	/**
	 * returns: range that covers all elements between left and right
	 */
	Range range(string boundaries = "[)", T)(auto ref const(T) left, auto ref const(T) right)
		if(is(typeof(less(T.init, V.init))))
	{
		static assert(boundaries == "[]" || boundaries == "[)" || boundaries == "(]" || boundaries == "()");
		auto l = findApprox!(boundaries[0])(left);
		auto r = findApprox!(boundaries[1])(right);
		if(l is null || r is null || less(r.value, l.value))
			return Range(null, null);
		return Range(l, r);
	}


	//////////////////////////////////////////////////////////////////////
	// balancing (internal)
	//////////////////////////////////////////////////////////////////////

	private void balanceAdd(Node* node)
	{
		// case 1: node is root -> simply make it black
		if(node.parent is null)
			return node.black = true;

		// case 2: parent is black -> all is fine already
		if(node.parent.black)
			return;

		auto grand = node.parent.parent; // cannot be null at this point
		auto uncle = (node.parent is grand.right) ? grand.left : grand.right;

		// case 3: uncle and father are red -> make self/uncle black, grandfather red
		if(uncle && !uncle.black)
		{
			node.parent.black = true;
			uncle.black = true;
			grand.black = false;
			return balanceAdd(grand);
		}

		// case 4: black/no uncle -> one or two rotations
		if(node.parent is grand.left)
		{
			if(node is node.parent.right)
				rotateLeft(node.parent);

			grand.black = false;
			grand.left.black = true;
			rotateRight(grand);
		}
		else
		{
			if(node is node.parent.left)
				rotateRight(node.parent);

			grand.black = false;
			grand.right.black = true;
			rotateLeft(grand);
		}
	}

	private static bool nodeBlack(const(Node)* n)
	{
		if(n is null)
			return true;
		else
			return n.black;
	}

	private void balanceRemove(Node* n) // fixes node's black-height being one too low
	{
		if(!n.black)
			return n.black = true;

		if (n.parent is null) // case 1: node is the root -> everything is fine already
			return;

		if(n.parent.left is n)
		{
			if(!n.parent.right.black) // case 2: red sibling -> recolor parent/sibling and rotate
			{
				n.parent.black = false;
				n.parent.right.black = true;
				rotateLeft(n.parent);
			}

			auto s = n.parent.right;

			if(nodeBlack(s.right))
			{
				if(nodeBlack(s.left)) // case 3/4: two black cousins
				{
					s.black = false;
					return balanceRemove(n.parent);
				}

				// case 5: one black cousin and sibling on appropriate side
				s.black = false;
				s.left.black = true;
				rotateRight(s);
				s = s.parent;
			}

			// case 6
			s.black = nodeBlack(n.parent);
			n.parent.black = true;
			assert (nodeBlack(s.right) == false);
			s.right.black = true;
			rotateLeft(n.parent);
		}
		else
		{
			if(!n.parent.left.black) // case 2: red sibling -> recolor parent/sibling and rotate
			{
				n.parent.black = false;
				n.parent.left.black = true;
				rotateRight(n.parent);
			}

			auto s = n.parent.left;

			if(nodeBlack(s.left))
			{
				if(nodeBlack(s.right)) // case 3/4: two black cousins
				{
					s.black = false;
					return balanceRemove(n.parent);
				}

				// case 5: one black cousin and sibling on appropriate side
				s.black = false;
				s.right.black = true;
				rotateLeft(s);
				s = s.parent;
			}

			// case 6
			s.black = nodeBlack(n.parent);
			n.parent.black = true;
			assert (nodeBlack(s.left) == false);
			s.left.black = true;
			rotateRight(n.parent);
		}
	}

	private void rotateLeft(Node* node)
	{
		Node* pivot = node.right;

		// move middle-branch
		node.right = pivot.left;
		if(pivot.left)
			pivot.left.parent = node;

		// rotate node and pivot
		pivot.parent = node.parent;
		node.parent = pivot;
		pivot.left = node;

		// put it into parent
		if(pivot.parent is null)
			root = pivot;
		else if(pivot.parent.left is node)
			pivot.parent.left = pivot;
		else
			pivot.parent.right = pivot;
	}

	private void rotateRight(Node* node)
	{
		Node* pivot = node.left;

		// move middle-branch
		node.left = pivot.right;
		if(pivot.right)
			pivot.right.parent = node;

		// rotate node and pivot
		pivot.parent = node.parent;
		node.parent = pivot;
		pivot.right = node;

		if(pivot.parent is null)
			root = pivot;
		else if(pivot.parent.left is node)
			pivot.parent.left = pivot;
		else
			pivot.parent.right = pivot;
	}
}
