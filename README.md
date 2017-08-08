# jive
Collection library for the [D programming language](http://dlang.org/). All types are implemented as structs with value semantics. Here is a minimal example to get you started:

```D
import std.stdio;
import jive.orderedset;

void main()
{
    OrderedSet!int a;
    a.add(3); // add a single element to the set
    a.add([5,1,2,3,1,4]); // add multiple elements at once
    a.remove(2); // remove one element

    // Note that the set is always ordered and that there are no duplicates.
    writefln("%s", a[]); // prints "[1, 3, 4, 5]"

    // all collection behave as value types
    auto b = a; // this does a full copy of the set
    b.add(19);
    assert(19 !in a); // a is not affected by changing b
}
```

# Getting Started

This project uses [dub](http://code.dlang.org/), so you can just put a dependency in your `dub.json` or `dub.sdl` and you are done. For an explicit build, use

    dub build          # build the library
    dub test           # run some unittests
    dub build -b ddox  # build the documentation

# Features

This library is heavily inspired by the [C++ STL](http://www.cplusplus.com/reference/stl/), but written in D style. This means that all all collections have associated range-types (instead of iterators) and the naming of methods is different (e.g. `.length` instead of `.size()` and `pushBack` instead of `push_back`. Most importantly the copy-constructor/post-blit does a full copy of the object in order to achive strict value semantics. This means code like

```D
int sum(Array!int a)
{
   int s = 0;
   foreach(x; a)
      s += x;
   return s;
}
```

is generally a bad idea beacuse the array is copied when calling the function. Instead you should use
```D
int sum(const ref Array!int a)
{ ... }
```
or even better
```D
int sum(Range)(Range a)
if(isInputRange!Range && is(ElementType!Stuff == int))
{ ... }
```
which needs to be called like
```D
Array!int a;
auto s = sum(a[]);
```

Note that the `[]` operator on any collection type returns a range which iterates over the elements of the collection.

## Collection Types
- [x] Array (similar to `std::vector`)
- [ ] BlockArray (similar to `std::deque`)
- [x] BitArray (efficient version of `Array!bool`)
- [x] Queue (based on circular buffer)
- [x] Set (based on hash table)
- [x] Map (based on hahs table)
- [x] OrderedSet (based on a red-black tree)
- [ ] OrderedMap (based on a red-black tree)
- [x] PriorityQueue (based on a binary heap)
- [x] PriorityArray (based on a segment tree)

## Other Data Structures
- [x] UnionFind

Note that the list does not include `MultiSet/Map` or `LinkedList` because I am not familiar with any real usecase, so I am not sure about the interface they should provide. For example there are arguments that linked lists should *not* provide a `.length` property, which makes it a very special purpose structure.

If you need these (or any other) structures, please let me know.

# TODO:
- [ ] Compile some nice documentation
- [ ] Custom predicates for all ordered types (only yet done for PriorityQueue)
- [ ] Custom allocators using `std.experimental.allocator`

# Dependencies

None.

# License

All code in this repository is released into the public domain. Feel free to do anything you like with it.
