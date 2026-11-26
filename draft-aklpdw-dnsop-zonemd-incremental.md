%%%
title = "The MERKLE3 Incremental Scheme for ZONEMD"
abbrev = "The MERKLE3 ZONEMD Scheme"
docName = "@DOCNAME@"
category = "std"
ipr = "trust200902"
area = "Operations"
workgroup = "DNSOP"
submissiontype = "IETF"
keyword = [""]

[seriesInfo]
name = "Internet-Draft"
value = "@DOCNAME@"
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

   RFC8976 defined a single ZONEMD collation scheme, SIMPLE.
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

   The SIMPLE scheme does not support parallelism or efficient incremental computation.
   Every change to the zone requires re-hashing all of the zone contents, serially.
   For DNSSEC signers, computing ZONEMD with the SIMPLE scheme is the only step that cannot be parallelized.

   This document describes a new collation scheme targeting large, dynamic zones.
   It organizes the records in the zone in a Merkle tree structure.
   Records have fixed positions in the tree, so they are unaffected by additions and removals.
   Changes to the zone only require re-hashing the affected nodes of the tree and their parents.

   Using this scheme, ZONEMD checksums can be computed in a highly-parallel fashion.
   Given the prevalence of many-core CPUs, an order-of-magnitude speedup is achievable.
   Implementations can persist the tree structure for incremental computation, with even better speedups.

<!--
## Reserved Words

   The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
   "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
   and "OPTIONAL" in this document are to be interpreted as described
   in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they
   appear in all capitals, as shown here.
-->

# The MERKLE3 Scheme

## Computation

   The MERKLE3 data structure is a trie.
   It consists of four levels:
   level-0 (the root node),
   level-1 (up to 256 nodes),
   level-2 (up to 65,536 nodes),
   and level-3 (individual RRsets).
   The first three levels (0, 1, and 2) are _inner nodes_.
   Nodes in levels 0 and 1 have up to 256 children each.
   Children are identified by an unsigned 8-bit index from 0 to 255.

   Every RRset is individually hashed, using the selected ZONEMD hash algorithm.
   The records in the RRset are sorted in DNSSEC canonical order, serialized in the DNSSEC canonical form, concatenated together, and hashed once.
   Each RRset is assigned to a level-2 node in the tree, based on the first two bytes of its hash.
   The first byte selects a node in level-1 and the second selects a node in level-2.

   Note: in the incredibly unlikely case that two RRsets have the same hash at level-3 of the tree, they should not be deduplicated: both hashes should be inserted in the tree.

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
example.com.  300  IN  SOA   mname.example.com. rname.example.com. (
                             1 3600 7200 43200 300 )
example.com.   60  IN  NS    ns1.foo.example.
example.com.  300  IN  AAAA  2606:4700:10::ac42:93f3
example.com.  300  IN  AAAA  2606:4700:10::6814:179a
~~~

   The NS RRset is serialized as the following bytes, in hexadecimal:

~~~
07 6578616D706C65 03 636F6D 00 0002 0001 0000003C 0011 03 6E7331 03
666F6F 07 6578616D706C65 00
~~~

   The NS RRset has a SHA384 hash value of:

~~~
089AAD19F7AE6D16 D4BBA103E784AA8F 0E2818E56921C439 5F59EC80A3C4C856
10D50D7D5B3A1DD7 8C51C0ED5A9F45CC
~~~

   The first two bytes are relevant. The RRset is positioned under the root
   node, under its (level-1) child node at index 8 (0x08), under its (level-2)
   child node at index 154 (0x9A).

   The SOA RRset is serialized as the following bytes, in hexadecimal:

~~~
07 6578616D706C65 03 636F6D 00 0006 0001 0000012C 003A 05 6D6E616D65
07 6578616D706C65 03 636F6D 00 05 726E616D65 07 6578616D706C65 03
636F6D 00 00000001 00000E1 000001C2 00000A8C 00000012C
~~~

   The SOA RRset has a SHA384 hash value of:

~~~
B5EE62F73B9094B4 B0E1FCF899FADBD5 5972359A355C82C9 24CEA28A1B73959E
CA9D6D00670FF32A 873B8AD03721A181
~~~

   This RRset is positioned under the root
   node, under its (level-1) child node at index 181 (0xB5), under its (level-2)
   child node at index 238 (0xEE).

   The two records in the AAAA RRset are serialized as the following bytes, in hexadecimal:

~~~
07 6578616D706C65 03 636F6D 00 001C 0001 0000012C 0010 2606 4700 0010
0000 0000 0000 6814 179A
07 6578616D706C65 03 636F6D 00 001C 0001 0000012C 0010 2606 4700 0010
0000 0000 0000 AC42 93F3
~~~

   The AAAA RRset has a SHA-384 hash value of:

~~~
9CDD7D2DB2C820F5 4DF2F64690A68665 D3459BEACC09F216 57D01848B2D195A9
5C0E24C3E7458B95 B03EFBDC8B252DEF
~~~

   This RRset is positioned under the root
   node, under its (level-1) child node at index 156 (0x9C), under its (level-2)
   child node at index 221 (0xDD).

The final MERKLE3 ZONEMD SHA384 digest for this zone is:

~~~
5F0AD47C76A59B6E 287E221C296EA5C8 99AE5D473E4AE0E3 FF0FCEDF3E2345BE
7FC9F27CA1307775 4C98BB53B6288B64
~~~



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

## Merkle Tree Safety Against ZONEMD Hash Collisions

   The security model here assumes an attacker who is in general not able to
   find collisions for the underlying hash algorithm as such (for a given
   input and SHA384/512 hash, find a different input with the same hash),
   but they want to exploit weaknesses int the above defined Merkle Tree
   structure to find a collision in the overall Incremental ZONEMD
   computation (for a given zone contents and its ZONEMD, find a different
   zone contents with the same ZONEMD).

   Known attacks on Merkle trees in various fields of use include inserting
   hash of leaf data into higher level of the tree (instead of having data
   X in a level-3 leaf, put data H(X) into a level-2 leaf, where H is the
   hash function) or exploiting ambiguousity of which subtree a hash comes
   from during branch hash computation (e.g. if a branch node has just one
   child node of lower level and hash H(X), the branch node's hash is always
   H(H(X)) no matter which "slot" the child occupies).

   The former attack scheme is mitigated for Incremental ZONEMD by insisting
   that all leafs are at the same level, so every input data are hashed
   the same amount of times. If an attacker tries to insert H(X) as an RRset
   (where X is an existing RRset in the zone and H is the hash function),
   the collision of intermediate hashes never appears at the same level of
   the tree, and equalness of intermediate hashes across different levels of
   the tree does not do any harm. Especially, substituting one for the other
   does not lead to equal root hash.

   The latter attack scheme is mitigated for Incremental ZONEMD by building
   the hash slot-uniqueness bottom-up. For the level-2 branch nodes (those
   directly above the leaves), the membership and order of each leaf is
   unambiguous as the RRset hash value directly defines its position in the
   tree. Thus, for level-2 nodes themselves, this attack does not provide any
   way to achieve their hash collision. Therefore, the attacker has no chance
   to inject equal hash from different subtree into level-1 branch node to
   achieve hash collision inside a level-1 branch node. The same argument
   applies for stepping up from level-1 branch case to the root node hash,
   which defines the ZONEMD hash.

#  Performance Considerations

   The MERKLE3 scheme requires an implementation to maintain
   an in-memory Merkle tree data structure of DNS zone data.  This will
   generally be in addition to an implementation's primary data structure
   for referencing zone data.  As a sample data point, the .SE zone from
   2026-02-16 with 8 million records and 1.41 million RRsets required an additional
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
   The performance of the MERKLE3 scheme in such an attack may be degraded at a rate proportional to the fraction of RRsets under the attacker's control.
   In other words, an attacker would need to control a significant fraction of RRsets in a large zone in order to affect performance.


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

{backmatter}

# Design Decisions

## Use of Merkle Tree

   Merkle Tree ensures strong cryptographic properties of the resulting hash
   while enabling tiny updates to the large structure to be processed in
   logarithmic time.

   A proposed alternative was to simply XOR the hashes of individual RRsets.
   This would be much simpler to implement, wouldn't need any persistent data
   structures, would be much faster to compute, and would even allow validating
   an incremental change without accessing the whole zone. Unfortunately, such
   a scheme is not cryptographically secure; it could only serve as a checksum
   against random errors.

## Shape of the Tree

   Several variations of the Merkle tree design were considered, focusing on
   its height and branching factor (the number of children of a node). There
   were two main proposals: a radix tree and a static tree.

   In the radix tree proposal, inner nodes that have no siblings would be
   collapsed into their parents. The leaves of the tree (representing individual
   RRsets) would be located at varying depths from the root. Such a binary
   tree would have a maximum height of 256, but due to the uniform distribution
   of nodes by the hash function, the real height would be logarithmic to the
   number of nodes. It would scale dynamically for the size of the zone while
   offering logarithmic-time operations.

   In the static tree proposal, all leaf nodes would be located at exactly the
   same height, and all the nodes above them would exist unconditionally. RRsets
   would be hashed under the leaf nodes. Its operations scale linearly if there
   are many more RRsets than nodes. There were concerns that a single static
   tree scheme would not cater to the performance needs of both medium-sized
   and large zones, that multiple schemes of different configurations would
   be needed.

   These proposals were experimentally implemented with various configurations.
   They were compared by measuring their runtime performance and memory usage in
   various scenarios (many tiny zones and one TLD-like large zone):

   * binary radix tree
   * 256-ary radix tree
   * 256-ary static tree, depth 2
   * 256-ary static tree, depth 3
   * 256-ary static tree, depth 4

   The single-threaded comptuation times of building the whole tree (non-incremental
   update) of 8-million RR `se.` zone were in seconds, respectively:

   Binary radix: 9.11, 256-ary Radix: 7.98, 256-ary Static2: 11.43, Static3: 8.03 Static4: 11.11

   And the memory consumptions of the persistent Merkle tree were in MiB, respectively:

   Binary radix: 616, 256-ary Radix: 369, 256-ary Static2: 279, Static3: 285, Static4: 749

   The penultimate option (256-ary static tree, depth 3) proved versatile and
   almost best in each scenario. It provides good speeds for medium and large
   zones alike. It was not necessary to define multiple static tree schemes to
   cover all needs.

   Note that the needs for very small zones were not considered, as they are
   adequately satisfied by the SIMPLE scheme.

## Granularity of hashing

   While the final design operates on units of RRsets, smaller and larger units
   were considered.

   One proposal considered hashing individual resource records (RRs). This would
   ease the processing of updates: an addition or removal of an RR could be
   processed without knowledge of the RRset it is contained within. But it would
   require many more invocations of the hash function (one per RR instead of one
   per RRset) and would significantly increase the size of the tree.

   Another proposal considered hashing whole Nodes (all the RRsets at a
   particular owner name). This would shrink the Merkle tree, but increase the
   effort to process an update (significantly more data would have to be hashed
   to update a single node). Notably, the zone apex, which often contains many
   RRsets, is affected by every update; this proposal would greatly increase
   the effort for it.

   The accepted proposal, where RRsets are hashed, strikes a balance between
   hashing too many times and hashing too much. The alternative proposals were
   not implemented or experimentally evaluated.

## Hardening of branch nodes hash computation

   It has been suggested that the branch node hash computation might be prone
   to collision attacks as it computes its own hash only from the child nodes'
   hashes in their specified order, but the computation doesn't include the
   information about which "slot" the child hash came from. There had been
   known attacks on Merkle trees in different fields of use where similar
   weakness was used to find different set of underlying data yielding equal
   root node hash.

   The suggested mitigation included inserting some placeholders (e.g. H(""))
   into unused branch node "slots" before the computation. A more efficient
   mitigation would be including a bitmap of used slots (256 bits, each denoting
   if the respective child node exists or is skipped) into branch node hash
   computation. However, in Security considerations we explain why neither is
   necessary. It is beneficial to avoid either of the suggested hardenings
   for the sake of design simplicity, moreover, the former one could also
   introduce serious performance penalty.

# Example Zones with Digests

## Simple EXAMPLE Zone

Here, the EXAMPLE zone contains an SOA record, NS and glue records, and a ZONEMD record.

```
example.      86400   IN  SOA     ns1 admin 2018031900 (
                                  1800 900 604800 86400 )
              86400   IN  NS      ns1
              86400   IN  NS      ns2
              86400   IN  ZONEMD  2018031900 1 1 (
                                  c68090d90a7aed71
                                  6bc459f9340e3d7c
                                  1370d4d24b7e2fc3
                                  a1ddc0b9a87153b9
                                  a9713b3c9ae5cc27
                                  777f98b8e730044c )
ns1           3600    IN  A       203.0.113.63
ns2           3600    IN  AAAA    2001:db8::63
```

## Complex EXAMPLE Zone

Here, the EXAMPLE zone contains duplicate RRs, and an occluded RR, and one out-of-zone RR.

```
example.      86400  IN  SOA     ns1 admin 2018031900 (
                                 1800 900 604800 86400 )
              86400  IN  NS      ns1
              86400  IN  NS      ns2
              86400  IN  ZONEMD  2018031900 1 1 (
                                 a3b69bad980a3504
                                 e1cffcb0fd6397f9
                                 3848071c93151f55
                                 2ae2f6b1711d4bd2
                                 d8b39808226d7b9d
                                 b71e34b72077f8fe )
ns1           3600   IN  A       203.0.113.63
NS2           3600   IN  AAAA    2001:db8::63
occluded.sub  7200   IN  TXT     "I'm occluded but must be digested"
sub           7200   IN  NS      ns1
duplicate     300    IN  TXT     "I must be digested just once"
duplicate     300    IN  TXT     "I must be digested just once"
foo.test.     555    IN  TXT     "out-of-zone data must be excluded"
UPPERCASE     3600   IN  TXT     "canonicalize uppercase owner names"
*             777    IN  PTR     dont-forget-about-wildcards
mail          3600   IN  MX      20 MAIL1
mail          3600   IN  MX      10 Mail2.Example.
sortme        3600   IN  AAAA    2001:db8::5:61
sortme        3600   IN  AAAA    2001:db8::3:62
sortme        3600   IN  AAAA    2001:db8::4:63
sortme        3600   IN  AAAA    2001:db8::1:65
sortme        3600   IN  AAAA    2001:db8::2:64
non-apex      900    IN  ZONEMD  2018031900 1 1 (
                                 616c6c6f77656420
                                 6275742069676e6f
                                 7265642e20616c6c
                                 6f77656420627574
                                 2069676e6f726564
                                 2e20616c6c6f7765 )
```

## EXAMPLE Zone with multiple digests

Here, the EXAMPLE zone contains multiple ZONEMD records. It has both
SHA384 and SHA512 digests using the SIMPLE scheme.  It also includes
ZONEMD records with Scheme and Hash Algorithm
values in the private range (240-254).  These additional
private-range digests are not verifiable.

```
example.      86400  IN  SOA     ns1 admin 2018031900 (
                                 1800 900 604800 86400 )
example.      86400  IN  NS      ns1.example.
example.      86400  IN  NS      ns2.example.
example.      86400  IN  ZONEMD  2018031900 1 1 (
                                 62e6cf51b02e54b9
                                 b5f967d547ce4313
                                 6792901f9f88e637
                                 493daaf401c92c27
                                 9dd10f0edb1c56f8
                                 080211f8480ee306 )
example.      86400  IN  ZONEMD  2018031900 1 2 (
                                 08cfa1115c7b948c
                                 4163a901270395ea
                                 226a930cd2cbcf2f
                                 a9a5e6eb85f37c8a
                                 4e114d884e66f176
                                 eab121cb02db7d65
                                 2e0cc4827e7a3204
                                 f166b47e5613fd27 )
example.      86400  IN  ZONEMD  2018031900 1 240 (
                                 e2d523f654b9422a
                                 96c5a8f44607bbee )
example.      86400  IN  ZONEMD  2018031900 241 1 (
                                 e1846540e33a9e41
                                 89792d18d5d131f6
                                 05fc283e )
ns1.example.  3600   IN  A       203.0.113.63
ns2.example.  86400  IN  TXT     "This example has multiple digests"
NS2.EXAMPLE.  3600   IN  AAAA    2001:db8::63
```

## The URI.ARPA Zone

The following sample zone is the URI.ARPA zone retrieved 2021-01-21. Note
this sample zone has been re-signed with unpublished keys, so that the
added ZONEMD RR also has a signature.

```
uri.arpa.       3600    IN      SOA     sns.dns.icann.org. (
   noc.dns.icann.org. 2018100702 10800 3600 1209600 3600 )
uri.arpa.       3600    IN      RRSIG   SOA 8 2 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    GzQw+QzwLDJr13REPGVmpEChjD1D2XlX0ie1DnWHpgaEw1E/dhs3lCN3+B
    mHd4Kx3tffTRgiyq65HxR6feQ5v7VmAifjyXUYB1DZur1eP5q0Ms2ygCB3
    byoeMgCNsFS1oKZ2LdzNBRpy3oace8xQn1SpmHGfyrsgg+WbHKCT1dY= )
uri.arpa.       86400   IN      NS      a.iana-servers.net.
uri.arpa.       86400   IN      NS      b.iana-servers.net.
uri.arpa.       86400   IN      NS      c.iana-servers.net.
uri.arpa.       86400   IN      NS      ns2.lacnic.net.
uri.arpa.       86400   IN      NS      sec3.apnic.net.
uri.arpa.       86400   IN      RRSIG   NS 8 2 86400 (
    20210217232440 20210120232440 37444 uri.arpa.
    M+Iei2lcewWGaMtkPlrhM9FpUAHXFkCHTVpeyrjxjEONeNgKtHZor5e4V4
    qJBOzNqo8go/qJpWlFBm+T5Hn3asaBZVstFIYky38/C8UeRLPKq1hTTHAR
    YUlFrexr5fMtSUAVOgOQPSBfH3xBq/BgSccTdRb9clD+HE7djpqrLS4= )
uri.arpa.       600     IN      MX      10 pechora.icann.org.
uri.arpa.       600     IN      RRSIG   MX 8 2 600 (
    20210217232440 20210120232440 37444 uri.arpa.
    kQAJQivmv6A5hqYBK8h6Z13ESY69gmosXwKI6WE09I8RFetfrxr24ecdnY
    d0lpnDtgNNSoHkYRSOoB+C4+zuJsoyAAzGo9uoWMWj97/2xeGhf3PTC9me
    Q9Ohi6hul9By7OR76XYmGhdWX8PBi60RUmZ1guslFBfQ8izwPqzuphs= )
uri.arpa.       3600    IN      DNSKEY  256 3 8 (
    AwEAAbMxuFuLeVDuOwIMzYOTD/bTREjLflo7wOi6ieIJhqltEzgjNzmWJf
    9kGwwDmzxU7kbthMEhBNBZNn84zmcyRSCMzuStWveL7xmqqUlE3swL8kLO
    vdZvc75XnmpHrk3ndTyEb6eZM7slh2C63Oh6K8VR5VkiZAkEGg0uZIT3Nj
    sF )
uri.arpa.       3600    IN      DNSKEY  257 3 8 (
    AwEAAdkTaWkZtZuRh7/OobBUFxM+ytTst+bCu0r9w+rEwXD7GbDs0pIMhM
    enrZzoAvmv1fQxw2MGs6Ri6yPKfNULcFOSt9l8i6BVBLI+SKTY6XXeDUQp
    SEmSaxohHeRPMQFzpysfjxINp/L2rGtZ7yPmxY/XRiFPSO0myqwGJa9r06
    Zw9CHM5UDHKWV/E+zxPFq/I7CfPbrrzbUotBX7Z6Vh3Sarllbe8cGUB2UF
    NaTRgwB0TwDBPRD5ER3w2Dzbry9NhbElTr7vVfhaGWeOGuqAUXwlXEg6Cr
    NkmJXJ2F1Rzr9WHUzhp7uWxhAbmJREGfi2dEyPAbUAyCjBqhFaqglknvc= )
uri.arpa.       3600    IN      DNSKEY  257 3 8 (
    AwEAAenQaBoFmDmvRT+/H5oNbm0Tr5FmNRNDEun0Jpj/ELkzeUrTWhNpQm
    ZeIMC8I0kZ185tEvOnRvn8OvV39B17QIdrvvKGIh2HlgeDRCLolhaojfn2
    QM0DStjF/WWHpxJOmE6CIuvhqYEU37yoJscGAPpPVPzNvnL1HhYTaao1VR
    YWQ/maMrJ+bfHg+YX1N6M/8MnRjIKBif1FWjbCKvsn6dnuGGL9oCWYUFJ3
    DwofXuhgPyZMkzPc88YkJj5EMvbMH4wtelbCwC+ivx732l0w/rXJn0ciQS
    OgoeVvDio8dIJmWQITWQAuP+q/ZHFEFHPlrP3gvQh5mcVS48eLX71Bq7c= )
uri.arpa.       3600    IN      RRSIG   DNSKEY 8 2 3600 (
    20210217232440 20210120232440 12670 uri.arpa.
    DBE2gkKAoxJCfz47KKxzoImN/0AKArhIVHE7TyTwy0DdRPo44V5R+vL6th
    UxlQ1CJi2Rw0jwAXymx5Y3Q873pOEllH+4bJoIT4dmoBmPXfYWW7Clvw9U
    PKHRP0igKHmCVwIeBYDTU3gfLcMTbR4nEWPDN0GxlL1Mf7ITaC2Ioabo79
    Ip3M/MR8I3Vx/xZ4ZKKPHtLn3xUuJluPNanqJrED2gTslL2xWZ1tqjsAjJ
    v7JnJo2HJ8XVRB5zBto0IaJ2oBlqcjdcQ/0VlyoM8uOy1pDwHQ2BJl7322
    gNMHBP9HSiUPIOaIDNUCwW8eUcW6DIUk+s9u3GN1uTqwWzsYB/rA== )
uri.arpa.       3600    IN      RRSIG   DNSKEY 8 2 3600 (
    20210217232440 20210120232440 30577 uri.arpa.
    Kx6HwP4UlkGc1UZ7SERXtQjPajOF4iUvkwDj7MEG1xbQFB1KoJiEb/eiW0
    qmSWdIhMDv8myhgauejRLyJxwxz8HDRV4xOeHWnRGfWBk4XGYwkejVzOHz
    oIArVdUVRbr2JKigcTOoyFN+uu52cNB7hRYu7dH5y1hlc6UbOnzRpMtGxc
    gVyKQ+/ARbIqGG3pegdEOvV49wTPWEiyY65P2urqhvnRg5ok/jzwAdMx4X
    Gshiib7Ojq0sRVl2ZIzj4rFgY/qsSO8SEXEhMo2VuSkoJNiofVzYoqpxEe
    GnANkIT7Tx2xJL1BWyJxyc7E8Wr2QSgCcc+rYL6IkHDtJGHy7TaQ== )
uri.arpa.       3600    IN      ZONEMD  2018100702 1 1 (
    0dbc3c4dbfd75777c12ca19c337854b1577799901307c482e9d91d5d15
    cd934d16319d98e30c4201cf25a1d5a0254960 )
uri.arpa.       3600    IN      RRSIG   ZONEMD 8 2 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    QDo4XZcL3HMyn8aAHyCUsu/Tqj4Gkth8xY1EqByOb8XOTwVtA4ZNQORE1s
    iqNqjtJUbeJPtJSbLNqCL7rCq0CzNNnBscv6IIf4gnqJZjlGtHO30ohXtK
    vEc4z7SU3IASsi6bB3nLmEAyERdYSeU6UBfx8vatQDIRhkgEnnWUTh4= )
uri.arpa.       3600    IN      NSEC    ftp.uri.arpa. (
    NS SOA MX RRSIG NSEC DNSKEY ZONEMD )
uri.arpa.       3600    IN      RRSIG   NSEC 8 2 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    dU/rXLM/naWd1+1PiWiYVaNJyCkiuyZJSccr91pJI673T8r3685B4ODMYF
    afZRboVgwnl3ZrXddY6xOhZL3n9V9nxXZwjLJ2HJUojFoKcXTlpnUyYUYv
    VQ2kj4GHAo6fcGCEp5QFJ2KbCpeJoS+PhKGRRx28icCiNT4/uXQvO2E= )
ftp.uri.arpa.   604800  IN      NAPTR   0 0 "" "" (
    "!^ftp://([^:/?#]*).*$!\\1!i" . )
ftp.uri.arpa.   604800  IN      RRSIG   NAPTR 8 3 604800 (
    20210217232440 20210120232440 37444 uri.arpa.
    EygekDgl+Lyyq4NMSEpPyOrOywYf9Y3FAB4v1DT44J3R5QGidaH8l7ZFjH
    oYFI8sY64iYOCV4sBnX/dh6C1L5NgpY+8l5065Xu3vvjyzbtuJ2k6YYwJr
    rCbvl5DDn53zAhhO2hL9uLgyLraZGi9i7TFGd0sm3zNyUF/EVL0CcxU= )
ftp.uri.arpa.   3600    IN      NSEC    http.uri.arpa. (
    NAPTR RRSIG NSEC )
ftp.uri.arpa.   3600    IN      RRSIG   NSEC 8 3 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    pbP4KxevPXCu/bDqcvXiuBppXyFEmtHyiy0eAN5gS7mi6mp9Z9bWFjx/Ld
    H9+6oFGYa5vGmJ5itu/4EDMe8iQeZbI8yrpM4TquB7RR/MGfBnTd8S+sjy
    QtlRYG7yqEu77Vd78Fme22BKPJ+MVqjS0JHMUE/YUGomPkAjLJJwwGw= )
http.uri.arpa.  604800  IN      NAPTR   0 0 "" "" (
    "!^http://([^:/?#]*).*$!\\1!i" . )
http.uri.arpa.  604800  IN      RRSIG   NAPTR 8 3 604800 (
    20210217232440 20210120232440 37444 uri.arpa.
    eTqbWvt1GvTeXozuvm4ebaAfkXFQKrtdu0cEiExto80sHIiCbO0WL8UDa/
    J3cDivtQca7LgUbOb6c17NESsrsVkc6zNPx5RK2tG7ZQYmhYmtqtfg1oU5
    BRdHZ5TyqIXcHlw9Blo2pir1Y9IQgshhD7UOGkbkEmvB1Lrd0aHhAAg= )
http.uri.arpa.  3600    IN      NSEC    mailto.uri.arpa. (
    NAPTR RRSIG NSEC )
http.uri.arpa.  3600    IN      RRSIG   NSEC 8 3 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    R9rlNzw1CVz2N08q6DhULzcsuUm0UKcPaGAWEU40tr81jEDHsFHNM+khCd
    OI8nDstzA42aee4rwCEgijxJpRCcY9hrO1Ysrrr2fdqNz60JikMdarvU5O
    0p0VXeaaJDfJQT44+o+YXaBwI7Qod3FTMx7aRib8i7istvPm1Rr7ixA= )
mailto.uri.arpa.        604800  IN      NAPTR   0 0 "" "" (
    "!^mailto:(.*)@(.*)$!\\2!i" . )
mailto.uri.arpa.        604800  IN      RRSIG   NAPTR 8 3 604800 (
    20210217232440 20210120232440 37444 uri.arpa.
    Ch2zTG2F1plEvQPyIH4Yd80XXLjXOPvMbiqDjpJBcnCJsV8QF7kr0wTLnU
    T3dB+asQudOjPyzaHGwFlMzmrrAsszN4XAMJ6htDtFJdsgTMP/NkHhYRSm
    Vv6rLeAhd+mVfObY12M//b/GGVTjeUI/gJaLW0fLVZxr1Fp5U5CRjyw= )
mailto.uri.arpa.        3600    IN      NSEC    urn.uri.arpa. (
    NAPTR RRSIG NSEC )
mailto.uri.arpa.        3600    IN      RRSIG   NSEC 8 3 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    fQUbSIE6E7JDi2rosah4SpCOTrKufeszFyj5YEavbQuYlQ5cNFvtm8KuE2
    xXMRgRI4RGvM2leVqcoDw5hS3m2pOJLxH8l2WE72YjYvWhvnwc5Rofe/8y
    B/vaSK9WCnqN8y2q6Vmy73AGP0fuiwmuBra7LlkOiqmyx3amSFizwms= )
urn.uri.arpa.   604800  IN      NAPTR   0 0 "" "" (
    "/urn:([^:]+)/\\1/i" . )
urn.uri.arpa.   604800  IN      RRSIG   NAPTR 8 3 604800 (
    20210217232440 20210120232440 37444 uri.arpa.
    CVt2Tgz0e5ZmaSXqRfNys/8OtVCk9nfP0zhezhN8Bo6MDt6yyKZ2kEEWJP
    jkN7PCYHjO8fGjnUn0AHZI2qBNv7PKHcpR42VY03q927q85a65weOO1YE0
    vPYMzACpua9TOtfNnynM2Ws0uN9URxUyvYkXBdqOC81N3sx1dVELcwc= )
urn.uri.arpa.   3600    IN      NSEC    uri.arpa. NAPTR RRSIG NSEC
urn.uri.arpa.   3600    IN      RRSIG   NSEC 8 3 3600 (
    20210217232440 20210120232440 37444 uri.arpa.
    JuKkMiC3/j9iM3V8/izcouXWAVGnSZjkOgEgFPhutMqoylQNRcSkbEZQzF
    K8B/PIVdzZF0Y5xkO6zaKQjOzz6OkSaNPIo1a7Vyyl3wDY/uLCRRAHRJfp
    knuY7O+AUNXvVVIEYJqZggd4kl/Rjh1GTzPYZTRrVi5eQidI1LqCOeg= )
```

## The ROOT-SERVERS.NET Zone

The ROOT-SERVERS.NET zone retrieved 2018-10-21.

```
root-servers.net.     3600000 IN  SOA     a.root-servers.net. (
    nstld.verisign-grs.com. 2018091100 14400 7200 1209600 3600000 )
root-servers.net.     3600000 IN  NS      a.root-servers.net.
root-servers.net.     3600000 IN  NS      b.root-servers.net.
root-servers.net.     3600000 IN  NS      c.root-servers.net.
root-servers.net.     3600000 IN  NS      d.root-servers.net.
root-servers.net.     3600000 IN  NS      e.root-servers.net.
root-servers.net.     3600000 IN  NS      f.root-servers.net.
root-servers.net.     3600000 IN  NS      g.root-servers.net.
root-servers.net.     3600000 IN  NS      h.root-servers.net.
root-servers.net.     3600000 IN  NS      i.root-servers.net.
root-servers.net.     3600000 IN  NS      j.root-servers.net.
root-servers.net.     3600000 IN  NS      k.root-servers.net.
root-servers.net.     3600000 IN  NS      l.root-servers.net.
root-servers.net.     3600000 IN  NS      m.root-servers.net.
a.root-servers.net.   3600000 IN  AAAA    2001:503:ba3e::2:30
a.root-servers.net.   3600000 IN  A       198.41.0.4
b.root-servers.net.   3600000 IN  MX      20 mail.isi.edu.
b.root-servers.net.   3600000 IN  AAAA    2001:500:200::b
b.root-servers.net.   3600000 IN  A       199.9.14.201
c.root-servers.net.   3600000 IN  AAAA    2001:500:2::c
c.root-servers.net.   3600000 IN  A       192.33.4.12
d.root-servers.net.   3600000 IN  AAAA    2001:500:2d::d
d.root-servers.net.   3600000 IN  A       199.7.91.13
e.root-servers.net.   3600000 IN  AAAA    2001:500:a8::e
e.root-servers.net.   3600000 IN  A       192.203.230.10
f.root-servers.net.   3600000 IN  AAAA    2001:500:2f::f
f.root-servers.net.   3600000 IN  A       192.5.5.241
g.root-servers.net.   3600000 IN  AAAA    2001:500:12::d0d
g.root-servers.net.   3600000 IN  A       192.112.36.4
h.root-servers.net.   3600000 IN  AAAA    2001:500:1::53
h.root-servers.net.   3600000 IN  A       198.97.190.53
i.root-servers.net.   3600000 IN  MX      10 mx.i.root-servers.org.
i.root-servers.net.   3600000 IN  AAAA    2001:7fe::53
i.root-servers.net.   3600000 IN  A       192.36.148.17
j.root-servers.net.   3600000 IN  AAAA    2001:503:c27::2:30
j.root-servers.net.   3600000 IN  A       192.58.128.30
k.root-servers.net.   3600000 IN  AAAA    2001:7fd::1
k.root-servers.net.   3600000 IN  A       193.0.14.129
l.root-servers.net.   3600000 IN  AAAA    2001:500:9f::42
l.root-servers.net.   3600000 IN  A       199.7.83.42
m.root-servers.net.   3600000 IN  AAAA    2001:dc3::35
m.root-servers.net.   3600000 IN  A       202.12.27.33
root-servers.net.     3600000 IN  SOA     a.root-servers.net. (
    nstld.verisign-grs.com. 2018091100 14400 7200 1209600 3600000 )
root-servers.net.     3600000 IN  ZONEMD  2018091100 1 1 (
    f1ca0ccd91bd5573d9f431c00ee0101b2545c97602be0a97
    8a3b11dbfc1c776d5b3e86ae3d973d6b5349ba7f04340f79 )
```

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
