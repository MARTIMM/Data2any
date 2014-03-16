package Data2any::Tools;

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

#-------------------------------------------------------------------------------
#
has version =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => $VERSION
    );

# Filename and its type with data which must be translated to xml.
#
has inputFile =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'hasInputFile'
    , writer            => 'setInputFile'
    );

has dataFileType =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => 'Yaml'
    , writer            => 'setDataFileType'
    );

# Data in memory to be translated to xml. This is to have another way
# to give the data
#
has inputData =>
    ( is                => 'ro'
    , isa               => 'Any'
    , predicate         => 'hasInputData'
    , writer            => 'setInputData'
    );

# Label to store the data from inputFile or inputData with.
#
has dataLabel =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'hasDataLabel'
    , writer            => 'setDataLabel'
    , default           => 'internal'
    );

has dropPreviousConfig =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    );

has requestDocument =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 0
    );

# Object data is set by the NodeTree module. The data names that are set are
# type          Type of the object data. This is a way to see which part is
#               used to create the module.
#               Types can be;
#                 Type                  Example
#                 --------------------  ----------------------------------------
#                 C_NT_NODEMODULE       - !perl/modulename
#                 C_NT_VALUEDMODULE     - node attr=text: !perl/modulename
#                 C_NT_ATTRIBUTEMODULE  - node attr=text:
#                                           extAttr: !perl/modulename
#
#
# type          C_NT_NODEMODULE
# moduleName    Class name of this module. It is used to require the module
#               and after that to call new(objectData=>{...})
# parentNode    Node of the parent
# nodeData      This is a blessed structure created by the YAML module upon
#               encountering '!perl/modulename'. It holds the structure to
#               calculate the result with process(). There will be a call to
#               process() for the actual process of extending the nodetree.
# tree_build_data Hash for user convenience. It can communicate information from
#               one node object to the other because it is given to every
#               node object.
#
#
# type          C_NT_VALUEDMODULE
# moduleName    Class name of this module. It is used to require the module
#               and after that to call new(objectData=>{...})
# parentNode    Node of the parent
# nodeData      This is a blessed structure created by the YAML module upon
#               encountering '!perl/modulename'. It holds the structure to
#               calculate the result with process(). There will be a call to
#               process() to get the value of the current node.
# tree_build_data Hash for user convenience. It can communicate information from
#               one node object to the other because it is given to every
#               node object.
#
#
# type          C_NT_ATTRIBUTEMODULE
# node          Node name
# attributeName Name of the attribute to which this object is assigned
# moduleName    Class name of this module. It is used to require the module
#               and after that to call new(objectData=>{...})
# parentNode    Node of the parent
# nodeData      This is a blessed structure created by the YAML module upon
#               encountering '!perl/modulename'. It holds the structure
#               to calculate the result with process().
# tree_build_data Hash for user convenience. It can communicate information from
#               one node object to the other because it is given to every
#               node object.
#
has objectData =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , default           => sub { return {}; }
    , handles           =>
      { addDataItem     => 'set'
      , getDataItem     => 'get'
      , delDataItem     => 'delete'
      , getDataItemKeys => 'keys'
      , itemExists      => 'exists'
      , itemDefined     => 'defined'
      , clearData       => 'clear'
      , nbrDataItems    => 'count'
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
  $self->_log( 'Subroutine process() not defined in package '
            . $self->getDataItem('moduleName')
            , $self->C_NOPROCESS
            );
}

#-------------------------------------------------------------------------------
# Default method to intercept call unless defined in module
#
#sub help
#{
#  my( $self) = @_;
#  $self->_log( [ "Subroutine help() not defined in package"
#              , $self->getDataItem('moduleName')
#              ]
#            , $m->M_WARNING
#            );
#}

#-------------------------------------------------------------------------------
#
sub mkNode
{
  my( $self, $nodename, $parentNode, $value, $attributes) = @_;

  my $node;

  if( defined $nodename and $nodename and !ref($nodename) )
  {
    $node = AppState::NodeTree::Node->new( name => $nodename);
    $node->attributes($attributes) if ref($attributes) eq 'HASH';
    $parentNode->link_with_node($node);

#    if( ref($parentNode) eq 'AppState::NodeTree::Node' )
#    {
#      $node->parent($parentNode);
#      $parentNode->pushChild($node);
#    }
  }

  else
  {
    $self->_log( "Node '$nodename' is not created", $self->C_NODENOTCREATED);
  }

  return $node;
}

################################################################################
#
sub extendNodeTree
{
  my( $self, $rawData) = @_;

  # Get NodeTree object
  #
  my $nt = AppState->instance->get_app_object('NodeTree');

  # Build the tree from the raw data at the document root into a nodetree
  #
  my $parentNode = $self->getDataItem('parentNode');

  $nt->convert_to_node_tree( $rawData, $parentNode);
}

################################################################################
# Load user representation of xml from memory. First add a configuration
# specification of the users input file. Then select and set the configuration.
#
sub loadData
{
  my($self) = @_;

  my $label = 'D2X-' . $self->dataLabel;
  $self->setDataLabel($label);

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  my $log = $app->get_app_object('Log');

  # Check if the user wants the previous data destroyed
  #
  $cfg->drop_config_object($label)
    if defined $self->dropPreviousConfig
    and $self->dropPreviousConfig
    and $cfg->hasConfigObject($label)
    ;


  my $docNbr = $self->requestDocument;
  my $docType = 'data';
  $docNbr //= 0;

  if( $cfg->hasConfigObject($label) )
  {
    $cfg->select_config_object($label);
    $self->checkAndSelectDocNbr($docNbr);
    $self->_log( "$docType '$label doc $docNbr selected", $self->C_DOCSELECTED);
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
      $self->checkAndSelectDocNbr($docNbr);
      $self->_log( "Adding new data2any config '$label', doc $docNbr selected"
                 , $self->C_DOCSELECTED
                 );
    }

    else
    {
      $self->_log( "Failed to add data2any config '$label'"
                 , $self->C_CONFADDFAIL
                 );
    }

    # Set the given data in the configuration
    #
    $cfg->setDocuments($self->inputData);
  }
}

################################################################################
# Load user representation of xml from any location. First add a configuration
# specification of the users input file. Then select and load the configuration.
# The data is saved and the next time this data is used ignoring the filename
# and config type.
#
sub loadInputFile
{
  my($self) = @_;

  my $filename = $self->inputFile;
  if( defined $filename and $filename )
  {
    my $docNbr = $self->requestDocument;
    my $docType = $self->dataFileType;

    my $label = 'D2X-' . $filename;
    $self->setDataLabel($label);
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
      $self->checkAndSelectDocNbr($docNbr);
      $self->_log( "$docType to xml config '$label' doc $docNbr selected"
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
        $self->checkAndSelectDocNbr($docNbr);
        $self->_log( "Adding new data2xml config '$label', doc $docNbr selected"
                   , $self->C_CONFADDDED
                   );
      }

      else
      {
        $self->_log( "Failed to add data2xml config '$label'"
                   , $self->C_CONFADDFAIL
                   );
      }
    }
  }

  else
  {
    $self->_log( "filename not defined", $self->C_FILENOTDEFINED);
  }
}

################################################################################
# Load user data representation of xml from any location. First add a
# configuration specification of the users input file. Then select
# and load the configuration.
#
sub selectInputFile
{
  my( $self, $docNbr) = @_;

  my $label = $self->dataLabel;
  my $cfg = AppState->instance->get_app_object('ConfigManager');
  $docNbr //= 0;

#say STDERR "SIF: Label: $label";
  if( $cfg->hasConfigObject($label) )
  {
    $cfg->select_config_object($label);
    $self->checkAndSelectDocNbr($docNbr);
    $self->_log( "data to config '$label', doc $docNbr selected"
               , $self->C_INPUTFILESELECTED
               );
  }

  else
  {
    $self->_log( "Failed to select data to xml config '$label'"
               , $self->C_SELECTFAIL
               );
  }

  return $cfg->get_current_document;
}

################################################################################
#
sub checkAndSelectDocNbr
{
  my( $self, $docNbr) = @_;

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  $cfg->select_document($docNbr);
  if( $cfg->get_current_document != $docNbr )
  {
    $self->_log( "Requested document not in range, set to"
               . $cfg->get_current_document
               , $self->C_DOCNBRNOTFOUND
               );
  }

  else
  {
    $self->_log( "doc $docNbr selected", $self->C_DOCSELECTED);
  }
}

################################################################################
#
sub getDefaultAttributes
{
  my($self) = @_;

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  my $yd = $self->getDataItem('nodeData');
  my $attr = {};

  $attr->{id} = $yd->{id} if $yd->{id};
  $attr->{class} = $yd->{class} if $yd->{class};
#  $attr->{name} = $yd->{name} if $yd->{name};

  return $attr;
}

################################################################################
#
sub setDefaultAttributes
{
  my( $self, $node, $idPrefix) = @_;

  my $yd = $self->getDataItem('nodeData');
  my $attr = {};
  $idPrefix //= '';

  $node->addAttr(id => $yd->{id} . "_$idPrefix") if $yd->{id};
  $node->addAttr(class => $yd->{class}) if $yd->{class};
#  $node->addAttr(name => $yd->{name} . "_$idPrefix") if $yd->{name};
}

################################################################################
#
sub getDollarVar
{
  my( $self, $key) = @_;

  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#say STDERR "Get KV: $tbd, $key = ", $tbd->{dollarVariables}{$key};
  return $tbd->{dollarVariables}{$key};
}

################################################################################
#
sub setDollarVar
{
  my( $self, %kvPairs) = @_;

  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#say STDERR "Tbd: $tbd";
  foreach my $key (keys %kvPairs)
  {
#say STDERR "Set KV: $key, $kvPairs{$key}";
    $tbd->{dollarVariables}{$key} = $kvPairs{$key};
  }
}

################################################################################
#
sub getDVarNames
{
  my( $self) = @_;
  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
  return (keys %{$tbd->{dollarVariables}});
}

################################################################################
#
sub clearDVars
{
  my( $self) = @_;
  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
  $tbd->{dollarVariables} = {};
}

#-------------------------------------------------------------------------------

1;
