package Data2any::Aux::BlessedStructTools;

use version; our $VERSION = '' . version->parse("v0.5.5");
use 5.012000;

use Modern::Perl;
use namespace::autoclean;
#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

#-------------------------------------------------------------------------------
use Moose;

extends qw(AppState::Plugins::Log::Constants);

use AppState;
use AppState::Plugins::NodeTree::Node;
use AppState::Plugins::NodeTree::NodeGlobal;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
#def_sts( 'C_DOCSELECTED',       'M_INFO');
#def_sts( 'C_CONFADDDED',        'M_INFO');
#def_sts( 'C_INPUTFILESELECTED', 'M_INFO');
def_sts( 'C_NOPROCESS',         'M_WARN', 'Subroutine process() not defined in package %s');
def_sts( 'C_NODENOTCREATED',    'M_ERROR', 'Node %s is not created');
#def_sts( 'C_CONFADDFAIL',       'M_ERROR');
#def_sts( 'C_FILENOTDEFINED',    'M_ERROR');
#def_sts( 'C_SELECTFAIL',        'M_ERROR');
#def_sts( 'C_DOCNBRNOTFOUND',    'M_WARN');

#-------------------------------------------------------------------------------
# Object data is set by the NodeTree module. The data names that are set are;
#
# attribute_name
#              Name of the attribute to which this object is assigned
#
# module_name  Class name of this module. It is used to require the module
#              and after that to call new(object_data=>{...})
#
# node         Node name
#
# node_data    This is a blessed structure created by the YAML module upon
#              encountering '!perl/modulename'. It holds the structure to
#              calculate the result with process(). There will be a call to
#              process() for the actual process of extending the nodetree.
#
# parent_node  Node of the parent
#
# type         Type of the object data. This is a way to see which part is
#              used to create the module.
#              Types can be;
#                Type                  Example
#                --------------------  ----------------------------------------
#                C_NT_NODEMODULE       - !perl/modulename
#                C_NT_VALUEDMODULE     - node attr=text: !perl/modulename
#                C_NT_ATTRIBUTEMODULE  - node attr=text:
#                                          extAttr: !perl/modulename
#
# Not all attributes are used always. It depends on the type attribute which is
# set by the NodeTree module when a certain situation has been found in the raw
# data.
#
# When type is C_NT_NODEMODULE
# The used attributes: module_name, parent_node, node_data
#
# When type is C_NT_VALUEDMODULE
# The used attributes: module_name, parent_node, node_data
#
# When type is C_NT_ATTRIBUTEMODULE
# The used attributes: node, attribute_name, module_name, parent_node,
#                      node_data
#
has object_data =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , default           => sub { return {}; }
    , handles           =>
      { add_data_item           => 'set'
      , get_data_item           => 'get'
      , del_data_item           => 'delete'
      , get_data_item_keys      => 'keys'
      , item_exists             => 'exists'
      , item_defined            => 'defined'
      , clear_data              => 'clear'
      , nbr_data_items          => 'count'
      }
    );

################################################################################
#
sub BUILD
{
  my($self) = @_;

  AppState->instance->log_init('.BT');

  if( $self->meta->is_mutable )
  {

    __PACKAGE__->meta->make_immutable;
  }
}

################################################################################
# Default method to intercept call unless defined in module
#
sub process
{
  my( $self) = @_;
  $self->log( $self->C_NOPROCESS, [$self->get_data_item('module_name')]);
}

################################################################################
#
sub mk_node
{
  my( $self, $nodename, $parent_node, $attributes) = @_;

  my $node;

  if( defined $nodename and $nodename and !ref($nodename) )
  {
    $node = AppState::Plugins::NodeTree::Node->new(name => $nodename);
    $self->set_default_attributes($node);
    $node->add_attribute(%$attributes) if ref($attributes) eq 'HASH';
    $parent_node->link_with_node($node);
  }

  else
  {
    $self->log( $self->C_NODENOTCREATED, [$nodename]);
  }

  return $node;
}

################################################################################
#
sub extend_node_tree
{
  my( $self, $rawData) = @_;

  # Get NodeTree object
  #
  my $nt = AppState->instance->get_app_object('NodeTree');

  # Build the tree from the raw data at the document root into a nodetree
  #
  my $parent_node = $self->get_data_item('parent_node');

  $nt->convert_to_node_tree( $rawData, $parent_node);
}

################################################################################
#
sub get_default_attributes
{
  my($self) = @_;

  my $yd = $self->get_data_item('node_data');
  my $attr = {};

  $attr->{id} = $yd->{id} if $yd->{id};
  $attr->{class} = $yd->{class} if $yd->{class};

  return $attr;
}

################################################################################
#
sub set_default_attributes
{
  my( $self, $node) = @_;

  my $yd = $self->get_data_item('node_data');
  my $attr = {};

  $node->add_attribute(id => $yd->{id}) if $yd->{id};
  $node->add_attribute(class => $yd->{class}) if $yd->{class};
}

#-------------------------------------------------------------------------------

1;
