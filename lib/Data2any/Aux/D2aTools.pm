package Data2any::Aux::D2aTools;

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

has request_document =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 0
    );

################################################################################
#
sub BUILD
{
  my($self) = @_;

  AppState->instance->log_init('.DT');

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
sub get_dollar_var
{
  my( $self, $key) = @_;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data($key);

#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#say STDERR "Get KV: $tbd, $key = ", $tbd->{dollarVariables}{$key};
#  return $tbd->{dollarVariables}{$key};
}

################################################################################
# Store the data in a field in the node global data. Any node can reach this
#
sub set_dollar_var
{
  my( $self, %kvPairs) = @_;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  $node_global->set_global_data(%kvPairs);

#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#  foreach my $key (keys %kvPairs)
#  {
#    $tbd->{dollarVariables}{$key} = $kvPairs{$key};
#  }
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

#-------------------------------------------------------------------------------

1;
