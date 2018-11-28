#!/usr/bin/perl

# do_acl.pl
# Outputs Bind ACLs from geoIP information

use warnings;
use strict;

my $h;
my %ip;   # each hash element is an array reference
my $country;

open $h,$ARGV[0] or die "Error opening input file";

while(<$h>) {
  /^(\S+) (\S+);$/;
  push @{$ip{$2}}, $1;
}

close $h or die "Error closing file";

# Traverse the hash and print the ACLs
for $country (keys %ip) {
  print "acl \"$country\" {\n";
  print "  $_;\n" for (@{$ip{$country}});
  print "};\n\n";
}
