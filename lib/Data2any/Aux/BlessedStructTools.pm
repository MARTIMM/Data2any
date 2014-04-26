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
#
has version =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => $VERSION
    );

# Filename and its type with data which must be translated to xml.
#
has input_file =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'has_input_file'
    , writer            => 'set_input_file'
    );

has data_file_type =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => 'Yaml'
    , writer            => 'set_data_file_type'
    );

# Data in memory to be translated to xml. This is to have another way
# to give the data
#
has input_data =>
    ( is                => 'ro'
    , isa               => 'Any'
    , predicate         => 'has_input_data'
    , writer            => 'set_input_data'
    );

# Label to store the data from input_file or input_data with.
#
has data_label =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'has_data_label'
    , writer            => 'set_data_label'
    , default           => 'internal'
    );

has drop_previous_config =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    );

has request_document =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 0
    );

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

  AppState->instance->log_init('TLS');

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

#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
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
# Load user representation of xml from memory. First add a configuration
# specification of the users input file. Then select and set the configuration.
#
sub load_data
{
  my($self) = @_;

  my $label = 'D2X-' . $self->data_label;
  $self->set_data_label($label);

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  my $log = $app->get_app_object('Log');

  # Check if the user wants the previous data destroyed
  #
  $cfg->drop_config_object($label)
    if defined $self->drop_previous_config
    and $self->drop_previous_config
    and $cfg->hasConfigObject($label)
    ;


  my $docNbr = $self->request_document;
  my $docType = 'data';
  $docNbr //= 0;

  if( $cfg->hasConfigObject($label) )
  {
    $cfg->select_config_object($label);
    $self->check_and_select_doc_nbr($docNbr);
    $self->wlog( "$docType '$label doc $docNbr selected", $self->C_DOCSELECTED);
  }

  else
  {
    $cfg->add_config_object( $label
                           , { location => $cfg->C_CFF_FILEPATH
                             , requestFile => $label
                             }
                           );
    if( $log->is_last_success )
    {
      $self->check_and_select_doc_nbr($docNbr);
      $self->wlog( "Adding new data2any config '$label', doc $docNbr selected"
                 , $self->C_DOCSELECTED
                 );
    }

    else
    {
      $self->wlog( "Failed to add data2any config '$label'"
                 , $self->C_CONFADDFAIL
                 );
    }

    # Set the given data in the configuration
    #
    $cfg->setDocuments($self->input_data);
  }
}

################################################################################
# Load user representation of xml from any location. First add a configuration
# specification of the users input file. Then select and load the configuration.
# The data is saved and the next time this data is used ignoring the filename
# and config type.
#
sub load_input_file
{
  my($self) = @_;

  my $filename = $self->input_file;
  if( defined $filename and $filename )
  {
    my $docNbr = $self->request_document;
    my $docType = $self->data_file_type;

    my $label = 'D2X-' . $filename;
    $self->set_data_label($label);
#say STDERR "Label: $label";

    my $app = AppState->instance;
    my $cfg = $app->get_app_object('ConfigManager');
    my $log = $app->get_app_object('Log');

    $docNbr //= 0;
    $docType //= 'Yaml';

    # Config is named like so "D2X-$filename". Now it is possible to convert
    # more files in several calls. When found, original settings will not be
    # changed. Only document is used to select document.
    #
    if( $cfg->hasConfigObject($label) )
    {
      $cfg->select_config_object($label);
      $self->check_and_select_doc_nbr($docNbr);
      $self->wlog( "$docType to xml config '$label' doc $docNbr selected"
                 , $self->C_DOCSELECTED
                 );
    }

    else
    {
      $cfg->add_config_object( $label
                             , { location => $cfg->C_CFF_FILEPATH
                               , requestFile => $filename
                               , store_type => $docType
                               }
                             );
      if( $log->is_last_success )
      {
        $cfg->load;
        $self->check_and_select_doc_nbr($docNbr);
        $self->wlog( "Adding new data2xml config '$label', doc $docNbr selected"
                   , $self->C_CONFADDDED
                   );
      }

      else
      {
        $self->wlog( "Failed to add data2xml config '$label'"
                   , $self->C_CONFADDFAIL
                   );
      }
    }
  }

  else
  {
    $self->wlog( "filename not defined", $self->C_FILENOTDEFINED);
  }
}

################################################################################
# Load user data representation of xml from any location. First add a
# configuration specification of the users input file. Then select
# and load the configuration.
#
sub select_input_file
{
  my( $self, $docNbr) = @_;

  my $label = $self->data_label;
  my $cfg = AppState->instance->get_app_object('ConfigManager');
  $docNbr //= 0;

#say STDERR "SIF: Label: $label";
  if( $cfg->hasConfigObject($label) )
  {
    $cfg->select_config_object($label);
    $self->check_and_select_doc_nbr($docNbr);
    $self->wlog( "data to config '$label', doc $docNbr selected"
               , $self->C_INPUTFILESELECTED
               );
  }

  else
  {
    $self->wlog( "Failed to select data to xml config '$label'"
               , $self->C_SELECTFAIL
               );
  }

  return $cfg->get_current_document;
}

################################################################################
#
sub check_and_select_doc_nbr
{
  my( $self, $docNbr) = @_;

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  $cfg->select_document($docNbr);
  if( $cfg->get_current_document != $docNbr )
  {
    $self->wlog( "Requested document not in range, set to"
               . $cfg->get_current_document
               , $self->C_DOCNBRNOTFOUND
               );
  }

  else
  {
    $self->wlog( "doc $docNbr selected", $self->C_DOCSELECTED);
  }
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

################################################################################
#
sub get_dollar_var
{
  my( $self, $key) = @_;

  # Remove the '$' on front if there is still one
  #
  $key =~ s/^\$//;
  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data($key);
}

################################################################################
# Store the data in a field in the node global data. Any node can reach this
#
sub set_dollar_var
{
  my( $self, %kvPairs) = @_;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  $node_global->set_global_data(%kvPairs);
}

################################################################################
#
sub get_dvar_names
{
  my( $self) = @_;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data_keys;
  
#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#  return (keys %{$tbd->{dollarVariables}});
}

################################################################################
#
sub clear_dvars
{
  my( $self) = @_;
return;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  $node_global->clear_global_data;

#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#  $tbd->{dollarVariables} = {};
}

#-------------------------------------------------------------------------------

1;
