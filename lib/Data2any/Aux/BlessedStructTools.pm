package Data2any::Aux::BlessedStructTools;

use Modern::Perl;
use namespace::autoclean;
#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use version; our $VERSION = '' . version->parse("v0.5.2");
use 5.012000;

#-------------------------------------------------------------------------------
use Moose;

extends qw(AppState::Ext::Constants);

use AppState;
use AppState::NodeTree::Node;
use AppState::NodeTree::NodeGlobal;

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
    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_DOCSELECTED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_CONFADDDED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_INPUTFILESELECTED',qw(M_INFO M_SUCCESS));
#    $self->const( '',qw(M_INFO M_SUCCESS));

    $self->const( 'C_NOPROCESS',qw(M_WARNING M_FORCED));
    $self->const( 'C_NODENOTCREATED',qw(M_ERROR M_FAIL));
    $self->const( 'C_CONFADDFAIL',qw(M_ERROR M_FAIL));
    $self->const( 'C_FILENOTDEFINED',qw(M_ERROR M_FAIL));
    $self->const( 'C_SELECTFAIL',qw(M_ERROR M_FAIL));
    $self->const( 'C_DOCNBRNOTFOUND',qw(M_WARNING M_FORCED));
#    $self->const( '',qw(M_ERROR M_FAIL));

    __PACKAGE__->meta->make_immutable;
  }
}

################################################################################
# Default method to intercept call unless defined in module
#
sub process
{
  my( $self) = @_;
  $self->wlog( 'Subroutine process() not defined in package '
             . $self->get_data_item('module_name')
             , $self->C_NOPROCESS
             );
}

################################################################################
#
sub mk_node
{
  my( $self, $nodename, $parent_node, $value, $attributes) = @_;

  my $node;

  if( defined $nodename and $nodename and !ref($nodename) )
  {
    $node = AppState::NodeTree::Node->new( name => $nodename);
    $node->attributes($attributes) if ref($attributes) eq 'HASH';
    $parent_node->link_with_node($node);

#    if( ref($parent_node) eq 'AppState::NodeTree::Node' )
#    {
#      $node->parent($parent_node);
#      $parent_node->pushChild($node);
#    }
  }

  else
  {
    $self->wlog( "Node '$nodename' is not created", $self->C_NODENOTCREATED);
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

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  my $yd = $self->get_data_item('node_data');
  my $attr = {};

  $attr->{id} = $yd->{id} if $yd->{id};
  $attr->{class} = $yd->{class} if $yd->{class};
#  $attr->{name} = $yd->{name} if $yd->{name};

  return $attr;
}

################################################################################
#
sub set_default_attributes
{
  my( $self, $node, $idPrefix) = @_;

  my $yd = $self->get_data_item('node_data');
  my $attr = {};
  $idPrefix //= '';

  $node->addAttr(id => $yd->{id} . "_$idPrefix") if $yd->{id};
  $node->addAttr(class => $yd->{class}) if $yd->{class};
#  $node->addAttr(name => $yd->{name} . "_$idPrefix") if $yd->{name};
}

#-------------------------------------------------------------------------------

1;
