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
   uses a Merkle Tree to more efficiently generate ZONEMD hashes for
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
   Tree data structure, which requires only hash calcuation updates of
   nodes along the path between the root node and a leaf node.

   The Incremental scheme requires implementations to maintain a Merkle
   tree data structure in memory for efficient updates.

## Reserved Words

   The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
   "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
   and "OPTIONAL" in this document are to be interpreted as described
   in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they
   appear in all capitals, as shown here.

# The MERKLE-INCREMENTAL Scheme

## MERKLE-INCREMENTAL Data Structure

   The MERKLE-INCREMENTAL data strcture is a Merkle Tree that is three
   levels deep and where every non-leaf node has branches to 256 child
   nodes.

   At depth one is the root node with branches to 256 child nodes.

   At depth two are 256 intermediate nodes, each of which has branches
   to 256 leaf nodes.

   At depth three are 65,536 leaf nodes.  Each leaf node consists of
   an array/list of a variable number of hash values, one per RRset.
   The RRset hash values are computed by providing the canonical wire
   format of the RRset as input to a hash function.  The hash function
   is determined by the Hash Algorithm field of the ZONEMD record, as
   described in Section 2.2.3 of [@!RFC8976].  At this time only SHA384
   and SHA512 are specified for use with ZONEMD.

   To place an RRset into the MERKLE-INCREMENTAL data structure, its
   hash value is first calculated.  Its location in the Merkle tree is
   determined by using the first two binary octets of the hash value.
   The first octet corresponds to the branch index between the root and
   intermediate nodes.  The second octet corresponds to the branch index
   between the intermediate and the leaf nodes.

   For example ...


## MERKLE-INCREMENTAL Scheme Inclusion/Exclusion Rules

   The inclusion and exclusion rules for the MERKLE-INCREMENTAL scheme
   are identical to those for the SIMPLE scheme, described in 
   Section 3.3.1.1 of [@!RFC8976].

## MERKLE-INCREMENTAL Scheme Digest Calculation

   A zone digest using the MERKLE-INCREMENTAL scheme is calcluated
   over the Merkle tree in a bottom-up fashion.  Each node in the
   tree has its own hash value, which is calculated from the elements
   directly beneath it.

   A leaf node's hash value is calculated by concatenating all of its per-RRset
   hash values, sorted numerically, as input to the zone digest hash function.

   The root and intermediate hash values are calculated by concatenation all of
   its child node hash values, sorted by branch index, as input to the zone digest
   hash function.  The root node hash value becomes the zone digest, placed in the
   RDATA of the ZONEMD RR.

   Upon a change to a leaf node, the intermediate node hash values
   are recalculated from the bottom up, until reaching the root node.

~~~
Verbatim fixed width
~~~

#  Security Considerations

   Words

#  Operational Considerations

   Words

#   IANA Considerations

   Update the ZONEMD registry

#  Acknowledgements

   The authors wish to thank
   members of the DNSOP working group
   for their input.

#  Changes

  RFC Editor: Please remove this section before publication.

  This section lists substantial changes to the document as it is being worked on.

{backmatter}

{numbered="false"}
