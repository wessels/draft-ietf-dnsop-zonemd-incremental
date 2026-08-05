%%%
title = "The MT3-Incremental Scheme for ZONEMD"
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
  surname = "Dradjica"
  fullname = "Arya Dradjica"
  organization = "NLNet Labs"
  country = "Netherlands"
  [author.address]
    email = "arya@nlnetlabs.nl"


%%%

.# Abstract

   The ZONEMD Resource Record provides data origin authentication
   and evidence of consistency for
   DNS zones as a whole, by embedding a cryptographic hash inside the
   zone itself.  This allows recipients to verify that zone data has
   not been modified since originally published by the zone operator.

   [@!RFC8976] defined a single ZONEMD collation scheme, the SIMPLE
   scheme, which requires processing all zone data any time the zone
   is updated.  This document describes the MERKLE3 scheme, which
   uses a Merkle tree to more efficiently generate ZONEMD hashes for
   zone updates.

{mainmatter}


# Introduction

   The ZONEMD SIMPLE scheme works by iterating over all RRsets in a zone
   in canonical order.  At each iteration the wire format of each RRset
   is given as input to the hashing function.  This necessarily means
   that any update, insertion, or deletion to the zone requires another
   full iteration over all RRsets.  The SIMPLE scheme is inefficient
   for large zones and for zones with frequent updates.

   This document describes a new ZONEMD collation scheme better suited to
   large zones and zones with frequent updates.  It leverages a Merkle
   tree data structure, which enables efficient updates by recalculating hashes
   only for nodes along the path between the root node and a leaf node.

   The MERKLE3 scheme requires implementations to maintain a Merkle
   tree data structure in memory for efficient updates.

## Reserved Words

   The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
   "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
   and "OPTIONAL" in this document are to be interpreted as described
   in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they
   appear in all capitals, as shown here.

# The MERKLE3 Scheme

## MERKLE3 Data Structure

   The MERKLE3 data structure is a Merkle tree that is three
   levels deep and where every non-leaf node has branches to 256 child
   nodes.

   At depth one is the root node with branches to 256 child nodes.

   At depth two are 256 inner nodes, each of which has branches
   to 256 leaf nodes.

   At depth three are 65,536 leaf nodes.  Each leaf node consists of
   an array/list of a variable number of hash values, one per RRset.
   The RRset hash values are computed by providing the canonical wire
   format of the RRset as input to a hash function.  The hash function
   is determined by the Hash Algorithm field of the ZONEMD record, as
   described in Section 2.2.3 of [@!RFC8976].
   In other words, the list of RRset hashes at the leaf nodes are
   made using the same hash algorithm as is used for the ZONEMD record
   published in the zone.
   At this time only SHA384
   and SHA512 are specified for use with ZONEMD.

   Note: although the description here is for a full tree (i.e., 256 inner
   nodes and 65,536 leaf nodes), an implementation need not always build
   a full tree, depending on the size and contents of a particular zone.
   Nodes can be allocated and connected on demand, only when needed to
   store a particular RRset in the data structure.  Empty or non-existent
   nodes are not used in the digest caulcation algorithm.

## Locating an RRset

   To identify the location of an RRset in the MERKLE3 data structure, its
   hash value is first calculated using the hash algorithm identified by the
   corresponding ZONEMD digest.  Its location in the Merkle tree is
   determined by using the first two binary octets of the hash value.
   The first octet corresponds to the branch index between the root and
   inner nodes.  The second octet corresponds to the branch index
   between the inner and the leaf nodes.

   For example, this example.com AAAA RRset:

~~~
example.com.            300     IN      AAAA    2606:4700:10::ac42:93f3
example.com.            300     IN      AAAA    2606:4700:10::6814:179a
~~~

   has a SHA384 hash value of:

~~~
9cdd7d2db2c820f54df2f64690a68665d3459beacc09f216
57d01848b2d195a95c0e24c3e7458b95b03efbdc8b252def
~~~

   Therefore, the path from the root node to this RRset's leaf node
   would be on the 156th (0x9C) branch from the root to the inner node,
   and the 221st (0xDD) branch from the inner node to the leaf node.


## MERKLE3 Scheme Inclusion/Exclusion Rules

   The inclusion and exclusion rules for the MERKLE3 scheme
   are identical to those for the SIMPLE scheme, described in
   Section 3.3.1.1 of [@!RFC8976].

## MERKLE3 Scheme Digest Calculation

   A zone digest using the MERKLE3 scheme is calculated
   over the Merkle tree in a bottom-up fashion.  Each node in the
   tree has its own hash value, which is calculated from the elements
   directly beneath it.  Empty nodes are ignored.

   A leaf node's hash value is calculated by concatenating all of its per-RRset
   hash values, sorted numerically, as input to the zone digest hash function.

   The root and inner hash values are calculated by concatenating all of
   its child node hash values, sorted by branch index, as input to the zone digest
   hash function.  The root node hash value becomes the zone digest, placed in the
   RDATA of the apex ZONEMD RR.

   Upon a change to a leaf node, the inner node hash values
   are recalculated from the bottom up, until reaching the root node.

## Adding an RRset

   To add an RRset to the MERKLE3 data structure (subject to
   inclusion/exclusion rules), its location is determined as described
   above.  At the corresponding leaf node, the RRset's hash value is
   added to the list of RRset hash values, all of which necessarily
   start with the same two octets.

## Removing an RRset

   To remove an RRset from the MERKLE3 data structure, its
   location is determined as described above.  If the RRset was previously
   placed in the data structure, its full hash value should be present
   in the list at the corresponding leaf node, from which it is then removed.

## Updating an RRset

   Updating an RRset in the MERKLE3 data structure is equivalent
   to removing the former RRset and then adding the updated RRset.

## Recomputing After Changes

   To recompute the MERKLE3 ZONEMD digest it is only necessary
   to update all inner hash values along paths from changed leaf nodes back
   to the root node.

   For example, when adding a new RRset to the MERKLE3 data structure
   the following steps are taken to recompute the ZONEMD digest:

   1. recompute the hash value for the leaf node, from the list of RRset hashes at that leaf node.
   2. recompute the hash value for the inner node that is the parent of the leaf node.
   3. recompute the root node hash value.

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
   (collapsing branch nodes with signle child). The following variants were
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
   in the tree, opposedly to recostructing the two versions of the affected RRset and
   hashing both; however, the resulting Merkle Tree would be much larger. The latter
   option would lead to smaller Tree, but less effective by re-hashing the two
   versions of the whole node, including the zone apex, which is updated each time
   anyway. In short, using the RRset as the primary hashable object is a compromise,
   a middle ground.

{backmatter}

{numbered="false"}
