use KiokuDB;
use Data::Dumper;

my $k = KiokuDB->connect(
  'bdb:dir=pastebindb',
  transactions => 0,
  create => 1,
);

my $scope = $k->new_scope;

my $bulk = $k->all_objects;
until($bulk->is_done) {
   foreach my $item ( $bulk->items ) {
       print $item->{time},"\n";
       $k->delete($item);
   }
}
#print Dumper($bulk);
