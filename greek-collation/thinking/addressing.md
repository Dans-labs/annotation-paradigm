idea 1: address the space between glyphs, not the glyphs themselves
idea 2: addresses are lists of numbers (so the address space is a tree)
idea 3: addresses remain the same if new versions are added

abc => .a.b.c. => 100 a 101 b 102 c 103

Two possibilities for abxc: 
	.a.b.x#c. 
and 
	.a.b#x.c. 
where # is the new address.

	100 a 101 b 102     x 102,100 c 103
resp.
	100 a 101 b 101,100 x 102     c 103 

There is an arbitrary choice as to where to put the x and the new address: 
	#x before the .c and after the b
or
	x# before the c and after the b.

Can this arbitrary choice be prevented? 

In ordinary sequence alignment:

ab~c => .a.b..c.
abxc => .a.b.x.c.

a b {x, null} c

b
c
{bc}

abcd
abcx
ybcd
{ay}bc{xd}

a xc
a xcd
abxc
{a} {bx} {cx}{cd.}
{a.}{axb}{cx}{cd}
{a}{b.}{x}{c}{d.}

Definition (*glyph*): a glyph is a symbol in a given set of symbols. Think of an UNICODE character.

Definition (*null*): null is a symbol outside the set of glyphs.

Definition (*symbol*): a symbol is either a glyph or null.

Definition (*choice*): a choice is a non-empty subset of symbols. We use it to denote a choice of symbols.

Definition (*null choice*): the null choice is the choice {null}.

Definition (*multi-version sequence*, **mvs** for short): a string of choices.

Definition (*end-version*): an end version of an mvs s is a string obtained by replacing every choice in s by one of its members, and, if that member is null, replacing it by the empty string. (So an end version consists of glyphs).

Definition (*powerseq: P(x)*): the powerseq of an mvs sequence s is the set of all end versions of z

Definition (*mvs-injection*): an mvs-injection is a mapping f between mvss s1 and s2, such that
	f is injective
	f respects the sequence order: 
		c1 < c2 in mvs s1 => f(c1) < f(c2) in mvs s2
	f preserves choices:
		c in mvs s1 => c is a subset of f(c) 

Definition (*conservative mvs-injection*): an mvs-injection f between mvss s1 and s2 is conservative if every choice in s2 outside the image of f is the null-choice. 
	
Definition (*submvs: x < y*): mvs s1 is a submvs of mvs s2, written as s1 < s2, if there is an mvs-injection of s1 into s2.

Definition (*version: x <~ y*): mvs s1 is a version of mvs s2 if 
	s1 is a submvs of s2
	there is a conservative mvs injection of s1 into s2
Essentially this says that a version s1 of s2 is an mvs that is obtained by picking elements from all choices in s2.

Theorem: if s1 <~ s2 then P(s1) is a subset of P(s2).
Proof: let x be a member of P(s1). Let g be a glyph of x. Then there is a corresponding choice c in s1 of which g is a member.
Let f be an mvs-injection of s1 into s2. Consider f(c). Then g is also a member of f(c). etc (the full argument needs an induction on the length of the sequence).

Definition (*collation: x # y*): a collation s1 # s2 of mvss s1 and s2 is a mvs z such that
	(i) x <~ z
	(ii) y <~ z
	(iii) no submvs of z has properties (i) and (ii).

Examples:
Let s1 = {b}, s2 = {c}. 
Then smin = {bc} is a collation of s1 and s2.
Also smax = {b null} {c null} is a collation of s1 and s2.

Let s1 = {a} {b} {c} {g} and s2 = {b} {c} {g} {h} 
Then sx = {ab} {bc} {cg} {gh} is a collation of s1 and s2.
Also sy = {a null} {b} {c} {g} {h null} is a collation of s1 and s2.
Also sz = {a null} {b null} {c null} {g null} {b null} {c null} {g null} {h null} ... ?

Define measures of collations (how good they are).
But, in order to generate addresses, we should not suppose that the collation is optimal! Can we generate addresses for a given collation?

Definition (x!): if x is an mvs, then x! is the subsequence of x obtained by removing all null choices of x.

Definition (x # y): if x and y are mvss, then {x # y} is the set of  minimal mvss z for which 
	x is a submvs of z
	y is a submvs of z

Theorem (least member of {x # y}): For any naked sequence x and y, there is only one member x # y in {x # y} with minimal length.
Proof: Suppose z1 and z2 are members of x # y.
 
An *alignment* of x and y in the sense of collation and least common subsequence is a member of x # y.

Definition (*naked sequence*): a string of symbols.

N.B. Every naked sequence can be seen as a multiversion sequence in which each choice as exactly one element.

Definition (*address*): an address is a value in a totally ordered set of values. Think of a natural number with the less-than ordering, or a string in the lexicographic ordering, or a sequence of numbers in the tree ordering.

Definition: (*addressed sequence*): a string of glyphs where between each pair of symbols there are zero or more addresses.
The addresses must respect the given ordering, i.e. the subsequence of addresses only must be ordered according to the total ordering given with the address space.

N.B. A naked sequence is a special case of an addressed sequence.

Definition (*simply separated sequence*): an addressed sequence x is simply separated if between every pair of symbols there is exactly 1 address; also: before the first symbol is exactly one address, and after the last symbol is exactly one address.


Theorem 1: if x and y are simply-separated, then x # y is simply separated.