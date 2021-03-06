# Tests of several node object types
#
use Modern::Perl;
use Test::Most;
use AppState;
use AppState::Plugins::NodeTree::Node;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/XmlHelper';
my $test_file = "$config_dir/Work/test_file.yml";


my $app = AppState->instance;
$app->initialize( config_dir => $config_dir
                , use_work_dir => 1
                , check_directories => 1
                );

my $log = $app->get_app_object('Log');
$log->start_file_logging;
$log->file_log_level($log->M_ERROR);

#-------------------------------------------------------------------------------
# Setup test file. A YAML file with two documents
#
open my $YD, '>', $test_file;
print $YD <<EOTXT;
---
- test1 a=b: xyz
---
- test2 b=c:
   - pqr: t0
EOTXT
close $YD;

#-------------------------------------------------------------------------------
#
require_ok('Data2any::Any::LoremIpsum');
can_ok( 'Data2any::Any::LoremIpsum', 'new', 'process');

#-------------------------------------------------------------------------------
# Test type is standard-1500
#
my $nt = $app->get_app_object('NodeTree');
my $parent_node = AppState::Plugins::NodeTree::Node->new(name => 'parentNode');
my $object_data =
   { type => $nt->C_NT_NODEMODULE
   , module_name => 'Data2any::Any::IncludeDocument'
   , parent_node => $parent_node
   , node_data => { type => 'standard-1500'}
   };

my $id = Data2any::Any::LoremIpsum->new(object_data => $object_data);
$id->process;
my $dom = $parent_node->xpath_get_root_node;

# Testing by traversing the tree
#
my( $elm, $e, $phase, $fail);
my $nh = sub
         { my($n) = @_;
           $e = shift @$elm;
           my $class = ref $n;
           my $str = $class =~ m/NodeDOM$/ ? 'D' : undef;
           $str //= $class =~ m/NodeText$/ ? 'T' : undef;
           $str //= $n->name;
           is( $str, $e, "$phase: $e");
           $fail = 1 unless $str eq $e;
         };

$nt->node_handler_up($nh);

$elm = [qw( D R parentNode T)];
$phase = 'Testing type = standard-1500';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_DEPTHFIRST1);
$fail ? fail("$phase failed")
      : pass("$phase passed");

ok( $parent_node->get_child(0)->value
    =~ m/^Lorem ipsum dolor sit amet, consectetur/
  , "$phase value"
  );

#-------------------------------------------------------------------------------
#
# Test type is tuna-ipsum
#
$nt = $app->get_app_object('NodeTree');
$parent_node = AppState::Plugins::NodeTree::Node->new(name => 'parentNode');
$object_data =
{ type => $nt->C_NT_NODEMODULE
, module_name => 'Data2any::Any::IncludeDocument'
, parent_node => $parent_node
, node_data => { type => 'tuna-ipsum'}
};

$id = Data2any::Any::LoremIpsum->new(object_data => $object_data);
$id->process;
$dom = $parent_node->xpath_get_root_node;

# Testing by traversing the tree
#
$elm = [qw( D R parentNode T)];
$phase = 'Testing type = tuna-ipsum';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_DEPTHFIRST1);
$fail ? fail("$phase failed")
      : pass("$phase passed");

ok( $parent_node->get_child(0)->value
    =~ m/^Moonfish, steelhead, lamprey southern flounder tadp/
  , "$phase value"
  );

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$app->cleanup;
File::Path::remove_tree($config_dir);

done_testing();
exit(0);
