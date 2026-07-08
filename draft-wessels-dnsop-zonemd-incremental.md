%%%
title = "The Incremental Scheme for ZONEMD"
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


%%%

.# Abstract

   The ZONEMD Resource Record provides data origin authentication for
   DNS zones as a whole, by embedding a cryptographic hash inside the
   zone itself.  This allows recipients to verifiy that zone data has
   not been modified since originally published by the zone operator.

   [@!RFC8976] defined a single ZONEMD coallation scheme, the Simple
   scheme, which requires processing all zone data any time the zone
   is updated.  This document describes the Incremental scheme, which
   uses a Merkle tree to more efficiently generate ZONEMD hashes for
   zone updates.

{mainmatter}


# Introduction

   The ZONEMD Simple scheme works by iterating over all RRsets in zone
   in canonical order.  At each iteration the wire format of each RRset
   is given as input to the hashing function.  This necessarily means
   that any update, insertion, or deletion to the zone requires another
   full iteration over all RRsets.  The Simple scheme is inefficient
   for large zones and for zones with frequent updates.

   This document describes a new ZONEMD collation scheme better suited to
   large zones and zones with frequent updates.  It leverages the Merkle
   tree data structure, which requires only hash calcuation updates of
   nodes along the path between the root node and a leaf node.

   The Incremental scheme requires implementations to maintain a Merkle
   tree data structure in memory for efficient updates.

## Reserved Words

   The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
   "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
   and "OPTIONAL" in this document are to be interpreted as described
   in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they
   appear in all capitals, as shown here.

# The MT3-INCREMENTAL Scheme

## MT3-INCREMENTAL Data Structure

   The MT3-INCREMENTAL data strcture is a Merkle tree that is three
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
   described in Section 2.2.3 of [@!RFC8976].  At this time only SHA384
   and SHA512 are specified for use with ZONEMD.

## Locating an RRset

   To identify the location of an RRset in the MT3-INCREMENTAL data structure, its
   hash value is first calculated using the hash algorithm identified by the
   corresponding ZONEMD digest.  Its location in the Merkle tree is
   determined by using the first two binary octets of the hash value.
   The first octet corresponds to the branch index between the root and
   inner nodes.  The second octet corresponds to the branch index
   between the inner and the leaf nodes.

   For example, this example.com A RRset:

~~~
example.com.            300     IN      A       104.20.23.154
example.com.            300     IN      A       172.66.147.243
~~~

   has a SHA384 hash value of:

~~~
d726b65f13f700b93bc0b1c9501949db2fc4170f76377478
a3bcbececd3a52f0962eef0d47e6f0c64b94eba007e675fd
~~~

   Therefore, the path from the root node to this RRset's leaf node
   would be on the 215th (0xD7) branch from the root to the inner node,
   and the 38th (0x26) branch from the inner node to the leaf node.


## MT3-INCREMENTAL Scheme Inclusion/Exclusion Rules

   The inclusion and exclusion rules for the MT3-INCREMENTAL scheme
   are identical to those for the Simple scheme, described in 
   Section 3.3.1.1 of [@!RFC8976].

## MT3-INCREMENTAL Scheme Digest Calculation

   A zone digest using the MT3-INCREMENTAL scheme is calcluated
   over the Merkle tree in a bottom-up fashion.  Each node in the
   tree has its own hash value, which is calculated from the elements
   directly beneath it.

   A leaf node's hash value is calculated by concatenating all of its per-RRset
   hash values, sorted numerically, as input to the zone digest hash function.

   The root and inner hash values are calculated by concatenating all of
   its child node hash values, sorted by branch index, as input to the zone digest
   hash function.  The root node hash value becomes the zone digest, placed in the
   RDATA of the ZONEMD RR.

   Upon a change to a leaf node, the inner node hash values
   are recalculated from the bottom up, until reaching the root node.

## Adding an RRset

   To add an RRset to the MT3-INCREMENTAL data structure (subject to
   inclusion/exclusion rules), its location is determined as described
   above.  At the corresponding leaf node, the RRset's hash value would
   be added to the list of RRset hash values, all of which necessarily
   start with the same two octets.

## Removing an RRset

   To remove an RRset from the MT3-INCREMENTAL data structure, its
   location is determined as described above.  If the RRset was previously
   placed in the data structure, its full hash value should be present
   in the list at the corresponding leaf node.  It can then be removed
   from the list and

   The root ZONEMD digest is then calculated by updating all hash values
   along the path from the leaf back to the root node.

## Updating an RRset

   Updating an RRset in the MT3-INCREMENTAL data structure is equivalent
   to removing the former RRset and then adding the updated RRset.

## Recomputing After Changes

   To recompute the MT3-INCREMENTAL ZONEMD digest it is only necessary
   to update all inner hash values along paths from changed leaf nodes back
   to the root node.  

   For example, when adding a new RRset to the MT3-INCREMENTAL data structure
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

   Mnemonic: MT3-INCREMENTAL

   Reference: [this document]

#  Security Considerations

   All security considerations from [@!RFC8976] apply to this
   specification and the MT3-INCREMENTAL scheme.

#  Performance Considerations

   The MT3-INCREMENTAL scheme requires an implementation to maintain
   an in-memory Merkle Tree data structure of DNS zone data.  This will
   geneally be in addition to an implementation's primary data structure
   for referencing zone data.  As a sample data point, the .SE zone from
   2026-06-30 with NN1 records and NN2 RRsets required an additional
   285 MB of memory in the author's proof-of-concept implementation.

   Compared to the Simple scheme ([@!RFC8976]), the time to compute
   an initial MT3-INCREMENTAL digest can be larger, due to the need
   to populate the Merkle tree data structure.

   However, the time to compute updates to the MT3-INCREMENTAL digest
   are essentially zero on modern computer systems, whereas the Simple
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


{backmatter}

{numbered="false"}
