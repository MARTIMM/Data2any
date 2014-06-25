# Tests of several node object types
#
use Modern::Perl;
use Test::Most;
use AppState;
use AppState::NodeTree::Node;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/XmlHelper';
my $test_file = "$config_dir/Work/test_file.yml";


my $app = AppState->instance;
$app->initialize( config_dir => $config_dir);
$app->check_directories;

my $log = $app->get_app_object('Log');
#$log->die_on_error(1);
#$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_level($log->M_ERROR);

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
require_ok('Data2any::Any::IncludeDocument');
can_ok( 'Data2any::Any::IncludeDocument', 'new', 'process');

#-------------------------------------------------------------------------------
# Test type is include
#
my $nt = $app->get_app_object('NodeTree');
my $parent_node = AppState::NodeTree::Node->new(name => 'parentNode');
my $object_data =
   { type => $nt->C_NT_NODEMODULE
   , module_name => 'Data2any::Any::IncludeDocument'
   , parent_node => $parent_node
   , node_data => { type => 'include'
                  , 'reference' => $test_file
                  , document => 0
                  }
   };

my $id = Data2any::Any::IncludeDocument->new(object_data => $object_data);
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

$elm = [qw( D R parentNode test1 T)];
$phase = 'Testing type = include';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_DEPTHFIRST1);
$fail ? fail("$phase failed")
      : pass("$phase passed");

#-------------------------------------------------------------------------------
# Test type is includeThis
#
my $node_global = AppState::NodeTree::NodeGlobal->instance;
$node_global->set_global_data(input_file => $test_file);

$object_data =
{ type => $nt->C_NT_NODEMODULE
, module_name => 'Data2any::Any::IncludeDocument'
, parent_node => AppState::NodeTree::Node->new(name => 'parentNode')
, node_data => { type => 'includeThis', document => 1}
};

$id = Data2any::Any::IncludeDocument->new(object_data => $object_data);
$id->process;

# Cannot use $parent because we use the call Node->new() directly
# and therefor points to the old structure.
#
$dom = $id->btls->get_data_item('parent_node')->xpath_get_root_node;

$nt->node_handler_up($nh);

$elm = [qw( D R parentNode test2 pqr T)];
$phase = 'Testing type = includeThis';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_DEPTHFIRST1);
$fail ? fail("$phase failed")
      : pass("$phase passed");

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$app->cleanup;
File::Path::remove_tree($config_dir);

done_testing();
exit(0);
