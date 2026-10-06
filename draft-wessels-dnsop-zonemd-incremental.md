%%%
title = "The MERKLE3-Incremental Scheme for ZONEMD"
docName = "@DOCNAME@"
category = "std"
ipr = "trust200902"
area = "Operations"
workgroup = "DNSOP"
submissiontype = "IETF"
keyword = [""]

[seriesInfo]
name = "Internet-Draft"
value = "draft-ietf-dnsop-zonemd-incremental"
stream = "IETF"
status = "standard"

coding = "utf-8"

[[author]]
  initials = "D."
  surname = "Wessels"
  fullname = "Duane Wessels"
  organization = "Verisign"
  street = "12061 Bluemont Way"
  city = "Reston"
  region = "VA"
  code = "20190"
  country = "US"
  [author.address]
    email = "dwessels@verisign.com"

[[author]]
  initials = "L."
  surname = "Peltan"
  fullname = "Libor Peltan"
  organization = "CZ.NIC"
  country = "Czech Republic"
  [author.address]
    email = "libor.peltan@nic.cz"

[[author]]
  initials = "A."
  surname = "Khanna"
  fullname = "Arya Khanna"
  organization = "NLnet Labs"
  country = "Netherlands"
  [author.address]
    email = "arya@nlnetlabs.nl"


%%%

.# Abstract

   The ZONEMD Resource Record affirms the integrity of whole DNS zones and helps verify their authenticity.
   It embeds a cryptographic hash of the zone data, collated in a configurable way.
   It is used as a checksum for zone transfers between name servers.

   [@!RFC8976] defined a single ZONEMD collation scheme, SIMPLE.
   It is sufficient for small and infrequently updated zones.
   This document introduces the MERKLE3 scheme, targeting large, dynamic zones.
   It uses a Merkle tree to enable parallelism and incremental computation.

{mainmatter}


# Introduction

   A ZONEMD record is generated with a choice of hash function and collation scheme.
   For the hash function, choices of SHA-384 and SHA-512 have been defined.
   The collation scheme decides how the hash function is applied to the zone data.
   The SIMPLE scheme hashes the concatenation of the records in the zone, in canonical order.
   With its definition, [@!RFC8976] notes:

   > For the SIMPLE scheme, the digest is calculated over the zone as a whole.
   > This means that a change to a single RR in the zone requires iterating over all RRs in the zone to recalculate the digest.
   > SIMPLE is a good choice for zones that are small and/or stable, but it is probably not good for zones that are large and/or dynamic.

   SHA-384 and SHA-512 do not support parallelism or efficient incremental computation.
   On average, every change to the zone requires re-hashing half of the zone contents, *serially*.
   Today, ZONEMD computation is the only step for signing a zone that cannot be parallelized.

   This document describes a new collation scheme targeting large, dynamic zones.
   It organizes the records in the zone in a Merkle tree structure.
   Records have fixed positions in the tree, so they are unaffected by additions and removals.
   Changes to the zone only require re-hashing the affected nodes of the tree and their parents.

   Using this scheme, ZONEMD checksums can be computed in a highly-parallel fashion.
   Given the prevalence of many-core CPUs, an order-of-magnitude speedup is achievable.
   Implementations can persist the tree structure for incremental computation, with even better speedups.

## Reserved Words

   The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
   "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
   and "OPTIONAL" in this document are to be interpreted as described
   in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they
   appear in all capitals, as shown here.

# The MERKLE3 Scheme

## Computation

   The MERKLE3 data structure is a trie.
   It consists of four levels:
   level 0 (the root node),
   level 1 (up to 256 nodes),
   level 2 (up to 65,536 nodes),
   and level 3 (individual RRsets).
   The first three levels (0, 1, and 2) are _inner nodes_.
   Nodes in levels 0 and 1 have up to 256 children each.
   Children are identified by an unsigned 8-bit index from 0 to 255.

   Every RRset is individually hashed, using the selected ZONEMD hash algorithm.
   The records in the RRset are sorted in DNSSEC canonical order, serialized in the DNSSEC canonical form, concatenated together, and hashed once.
   Each RRset is assigned to a level-2 node in the tree, based on the first two bytes of its hash.
   The first byte selects a node in level 1 and the second selects a node in level 2.

   Within each level-2 node, RRsets are sorted lexicographically by their hashes.
   These hashes are concatenated and hashed, using the same hash algorithm, to produce the hash of the level-2 node.
   Level-2 nodes that have no children are not hashed at all.

   Then, the hashes of the level-1 nodes are computed.
   The children of each level-1 node (those that exist) are ordered by index.
   The hashes are concatenated and hashed to produce the hash of the level-1 node.
   Again, level-1 nodes that have no children are not hashed at all.

   The root node is hashed from the level-1 nodes in the same way.
   The hash of the root node is the final digest that is stored in the ZONEMD record.

## Worked example

   Consider the following zone:

~~~
example.com.  300   IN   SOA    mname.example.com. rname.example.com. 1 3600 7200 43200 300
example.com.  300   IN   AAAA   2606:4700:10::ac42:93f3
example.com.  300   IN   AAAA   2606:4700:10::6814:179a
~~~

   The first AAAA record is serialized as the following bytes, in hexadecimal:

~~~
07 6578616D706C65 03 636F6D 00 0001 0001 0000012C 0010 2606 4700 0010 0000 0000 0000 AC42 93F3
~~~

   The SOA RRset has a SHA384 hash value of:

~~~
B5EE62F73B9094B4 B0E1FCF899FADBD5 5972359A355C82C9 24CEA28A1B73959E CA9D6D00670FF32A 873B8AD03721A181
~~~

   The first two bytes are relevant. The RRset is positioned under the root
   node, under its (level-1) child node at index 181 (0xB5), under its (level-2)
   child node at index 238 (0xEE).

   TODO: the overall digest for this zone

## MERKLE3 Scheme Inclusion/Exclusion Rules

   The inclusion and exclusion rules for the MERKLE3 scheme
   are identical to those for the SIMPLE scheme, described in
   Section 3.3.1.1 of [@!RFC8976].

## MERKLE3 Scheme Digest Calculation

   A zone digest using the MERKLE3 scheme is calculated
   over the Merkle tree in a bottom-up fashion.
   Each branch node in the
   tree has its own hash value, which is calculated from the elements
   directly beneath it.

   A leaf node's hash value is directly the RRset hash value and corresponds
   to the leaf position in the tree.

   A branch node (including root) hash value is calculated by concatenating
   all of its child node hash values, sorted numerically, as input to the zone
   digest hash function. Note that for branch nodes, their assigned hash value
   may (in fact, usually will) not correspond to its position in the tree
   (and the common prefix of leaves' hash values).

   The root node hash value becomes the zone digest, placed in the
   RDATA of the apex ZONEMD RR.

   Upon a change to a leaf node, the inner node hash values
   are recalculated from the bottom up, until reaching the root node.

## Adding an RRset

   To add an RRset to the MERKLE3 data structure (subject to
   inclusion/exclusion rules), its location is determined as described
   above.
   A new leaf node is added with the RRset's hash, and a path of branch
   nodes up to the tree as well if they don't exist yet.

## Removing an RRset

   To remove an RRset from the MERKLE3 data structure, its
   location is determined as described above.  If the RRset was previously
   placed in the data structure, its full hash value should have
   the corresponding leaf node, from which it is then removed.
   Any branch nodes becoming empty are removed as well.

## Updating an RRset

   Updating an RRset in the MERKLE3 data structure is equivalent
   to removing the former RRset and then adding the updated RRset.

## Recomputing After Changes

   To recompute the MERKLE3 ZONEMD digest it is only necessary
   to update all inner hash values along paths from changed leaf nodes back
   to the root node.

#  IANA Considerations

   IANA is requested to update
   the "ZONEMD Schemes" registry
   on the "Domain Name System (DNS) Parameters" web page
   as follows:

   Value: TBD

   Description: Merkle Tree Incremental ZONEMD collation

   Mnemonic: MERKLE3

   Reference: [this document]

#  Security Considerations

   All security considerations from [@!RFC8976] apply to this
   specification and the MERKLE3 scheme.

#  Performance Considerations

   The MERKLE3 scheme requires an implementation to maintain
   an in-memory Merkle tree data structure of DNS zone data.  This will
   generally be in addition to an implementation's primary data structure
   for referencing zone data.  As a sample data point, the .SE zone from
   2026-06-30 with NN1 records and NN2 RRsets required an additional
   285 MB of memory in the author's proof-of-concept implementation.

   Compared to the SIMPLE scheme ([@!RFC8976]), the time to compute
   an initial MERKLE3 digest can be larger in a single-threaded application, due to the need
   to populate the Merkle tree data structure.
   However, when parallelization and multi-threading are leveraged,
   the MERKLE3 scheme can perform significantly better.

   However, the time to compute updates to the MERKLE3 digest
   are essentially zero on modern computer systems, whereas the SIMPLE
   scheme provides no reduction in time for computing updates.

   The above considerations apply only to well-balanced Merkle trees.
   An attacker with the ability to insert RRsets into a zone may be able to intentionally unbalance the MERKLE3 data structure, similar to the Nurgle attack [@?Nurgle].
   The performance of the MERKLE3 scheme on an unbalanced tree may approach that of the SIMPLE scheme.


#  Privacy Considerations

   This specification has no impact on user privacy.

#  Acknowledgements

   The authors wish to thank
   members of the DNSOP working group
   for their input.

#  Changes

  RFC Editor: Please remove this section before publication.

  This section lists substantial changes to the document as it is being worked on.

  * From -00 to -01
     - this
     - that
     - the other

# Appendix: Design Decisions

## Use of Merkle Tree

   Merkle Tree ensures strong cryptographic properties of the resulting hash
   while enabling tiny updates to the large structure to be processed in
   logarithmic time.

   A proposed alternative was to simply XOR the hashes of individual RRsets.
   This would be much simpler to implement, wouldn't need any persistent
   data structures, would be much faster to compute, and would even allow
   validating an incremental change without accessing the whole zone. However,
   such ZONEMD would not ensure cryptographic protection and could only serve
   as a checksum against random errors.

## Shape of the Tree

   Most of design decisions were around the depth and width (how many child nodes
   a branch node can have) of the Merkle Tree and if it should be a Radix Tree
   (collapsing branch nodes with single child). The following variants were
   experimentally implemented and compared by measuring their time and memory
   complexity in various scenarios (many tiny zones, one TLD-like large zone):

   * Binary Radix Tree
   * 256-ary Radix Tree
   * 256-ary Static Tree with Depth 2
   * 256-ary Static Tree with Depth 3
   * 256-ary Static Tree with Depth 4

   TODO include the exact results here, and how?

   The penultimate option proved versatile and almost best in each scenario.
   Even the proposal of defining more than one ZONEMD Scheme with different tree
   depths proved unnecessary.

   Anyway, the effectivity for tiny zones is not too important since the users
   can simply use the Simple Scheme for them.

## Choice of Atomic Hashable

   Alternatively to hashing each RRset in the zone, it was proposed to either
   separately hash each single Resource Record, or to hash whole Node (all RRsets
   within the Domain Name) together. The former option would ease update processing,
   since adding or removing a RR in an existing RRset would just lead to single update
   in the tree, opposedly to reconstructing the two versions of the affected RRset and
   hashing both; however, the resulting Merkle Tree would be much larger. The latter
   option would lead to smaller Tree, but less effective by re-hashing the two
   versions of the whole node, including the zone apex, which is updated each time
   anyway. In short, using the RRset as the primary hashable object is a compromise,
   a middle ground.

{backmatter}

{numbered="false"}

<reference anchor="Nurgle" target="http://dx.doi.org/10.1109/SP54263.2024.00125">
   <front>
      <title>Nurgle: Exacerbating Resource Consumption in Blockchain State Storage via MPT Manipulation</title>
      <author fullname="Zheyuan He"> <organization></organization> </author>
      <author fullname="Zihao Li"> <organization></organization> </author>
      <author fullname="Ao Qiao"> <organization></organization> </author>
      <author fullname="Xiapu Luo"> <organization></organization> </author>
      <author fullname="Xiaosong Zhang,"> <organization></organization> </author>
      <author fullname="Ting Chen"> <organization></organization> </author>
      <author fullname="Shuwei Song"> <organization></organization> </author>
      <author fullname="Dijun Liu"> <organization></organization> </author>
      <author fullname="Weina Miu"> <organization></organization> </author>
      <date year="2024" month="May"></date>
   </front>
</reference>
