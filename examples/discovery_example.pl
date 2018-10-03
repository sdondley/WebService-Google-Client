#!/usr/bin/perl

use strict;
use warnings;
use WebService::Google::Client::Discovery;
use Data::Dumper;
use JSON;
use Text::Table;

my $d = WebService::Google::Client::Discovery->new->discover_all;
print Dumper $d;
           

## Render as nicely formatted MD table

# wrap into an array of rows for table
my $rows = [];
foreach my $r ( @{$d->{items}} )
{
    push @$rows, [ $r->{version}, $r->{title}, $r->{description} ]; ## documentationLink icon-s->{x32|16}  id discoveryRestUrl

}
my $tb = Text::Table->new(
    {is_sep => 1, title => '| ', body => '| '},"Version", 
    {is_sep => 1, title => '| ', body => '| '},"Title", 
    {is_sep => 1, title => '| ', body => '| '},"Description"
);
$tb->load( @$rows );

print $tb;