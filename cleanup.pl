#!/opt/perl5010001/bin/perl

use KiokuDB;
use Data::Dumper;
$Data::Dumper::Indent=1;

my $k = KiokuDB->connect(
  'bdb:dir=pastebindb',
  transactions => 0,
  create => 1,
);

my $scope = $k->new_scope;

my $bulk = $k->all_objects;
until($bulk->is_done) {
   foreach my $item ( $bulk->items ) {
       next if $item->{expires} == -1;
       if($item->{'time'} + $item->{expires} < time) {
         print Dumper($item);
         $k->delete($item);
       }
   }
}
#print Dumper($bulk);
